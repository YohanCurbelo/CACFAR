----------------------------------------------------------------------------------
-- Engineer: Yohan Curbelo Anglés
-- 
-- Create Date: 15.12.2021
-- Design Name: CACFAR - Behavioral
-- 
-- Description: 
-- Customizable Cell Averaging Constant False Alarm Rate
-- 1. Data is stores in a ring RAM
-- 2. RAM is doble read port so right and left window are accesible at the same time
-- 3. There are 128 divisors available to make the average are saved in luts with 10 
-- and 9 word and fractional length and as a signed format
-- 4. Internal signals have natural growth while output is the same width as input
-- 5. If a positive detection is made on a cell its value will be output. If not output 
-- is zero
-- 
-- Descripcion:
-- Cell Averaging Constant False Alarm Rate configurable
-- 1. Los datos son almacenados en una RAM circular
-- 2. La RAM tiene dos puertos de lectura para acceder al mismo tiempo a las ventanas
-- izquierda y derecha
-- 3. Hay 128 divisores disponibles para hacer el promediado de los valores en las
-- ventanas. Los divisores estan en luts con formato signed [10 9]
-- 4. Las senyales internas tienen crecimiento natural, pero la salida es del mismo
-- ancho que la entrada. 
-- 5. Si una celda resulta en una deteccion positiva su valor es puesto a la salida. 
-- En cambio, la salida sera cero si no hay deteccion.
--
----------------------------------------------------------------------------------


library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;
use     ieee.std_logic_textio.all;

library std;
use     std.textio.all;

entity CACFAR is
    generic (
        DATA_WIDTH      :   positive    :=  16;
        DATA_WINDOW     :   positive    :=  64;
        CFAR_WINDOW     :   positive    :=  12;
        GUARD_CELLS     :   positive    :=  4;
        ALPHA           :   positive    :=  5
    );
    port (
        clk             :   in  std_logic;
        rst             :   in  std_logic;
        i_en            :   in  std_logic;
        i_data          :   in  std_logic_vector(DATA_WIDTH-1 downto 0);
        o_en            :   out std_logic;
        o_data          :   out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end CACFAR;

architecture Behavioral of CACFAR is

    -- FSM signals
    type states is (idle, read_cut, cfar_acc, cfar_ave, cfar_threshold, cfar_decision);
    signal state        :   states;

    -- RAM signals
    constant ADDR_WIDTH :   positive    :=  positive(ceil(log2(real(DATA_WINDOW))));
    type ram is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal cells        :   ram         :=  (others => (others => '0'));
    signal w_addr       :   integer range 0 to 2**ADDR_WIDTH-1;         -- write address
    signal left_data    :   std_logic_vector(DATA_WIDTH-1 downto 0);    -- read data port 1
    signal left_addr    :   integer range 0 to 2**ADDR_WIDTH-1;         -- read address port 1 
    signal rigth_data   :   std_logic_vector(DATA_WIDTH-1 downto 0);    -- read data port 2
    signal rigth_addr   :   integer range 0 to 2**ADDR_WIDTH-1;         -- read address port 2
    signal ram_filled   :   boolean;

    -- 10 bits divisors (1/n where 1 < n < 128).
    constant DIVISOR_WIDTH          :   positive    :=  10;
    constant DIVISOR_FRAC_WIDTH     :   positive    :=  9;
    type divisors is array (0 to 127) of std_logic_vector(DIVISOR_WIDTH-1 downto 0);
    
    impure function divisors_from_file (divisors_file_name : in string) return divisors is
        file		divisors_file		:	text is in divisors_file_name;
        variable	divisors_file_line	:   line;
        variable	divisor		:   divisors;
    begin
        for i in 0 to 127 loop   
            readline(divisors_file, divisors_file_line);
            read(divisors_file_line, divisor(i));
        end loop;
        return divisor;
    end function;

    constant divisor        :   divisors    :=    divisors_from_file("divisors.txt");   

    -- Internal constanst and signals
    constant ACC_GROWTH     :   natural     :=  natural(ceil(log2(real(CFAR_WINDOW-GUARD_CELLS))));
    constant ALPHA_WIDTH    :   natural     :=  natural(ceil(log2(real(ALPHA))))+1; 
    constant LOW_CELL       :   natural     :=  GUARD_CELLS/2+1;
    constant HIGH_CELL      :   natural     :=  (CFAR_WINDOW-GUARD_CELLS)/2 + LOW_CELL;
    constant fractional_pad :   signed(DIVISOR_FRAC_WIDTH-1 downto 0)    :=  (others => '0');   -- Zero padding for the fracctional part of cell under test
    signal read_cut_ctr     :   integer range 0 to 1;                                           -- Pointer within each window
    signal window_ptr       :   integer range LOW_CELL to HIGH_CELL+2;                          -- Pointer within each window
    signal cut_addr         :   integer range 0 to 2**ADDR_WIDTH-1;                             -- Pointer to the current cell under test    
    signal cut_data         :   signed(DATA_WIDTH-1 downto 0);                                  -- Value of the current cell under test
    signal cut_data_frac_ext:   signed(DATA_WIDTH+DIVISOR_WIDTH-2 downto 0);                    -- Value of the current cell under test with the fractional part extended
    signal left_acc         :   signed(DATA_WIDTH+ACC_GROWTH-1 downto 0);                       -- Accumulator of the left window
    signal rigth_acc        :   signed(DATA_WIDTH+ACC_GROWTH-1 downto 0);                       -- Accumulator of the rigth window
    signal total_acc        :   signed(DATA_WIDTH+ACC_GROWTH-1 downto 0);                       -- Sum of window accumulators
    signal ave              :   signed(DATA_WIDTH+ACC_GROWTH+DIVISOR_WIDTH-1 downto 0);
    signal threshold        :   signed(DATA_WIDTH+ACC_GROWTH+DIVISOR_WIDTH+ALPHA_WIDTH-1 downto 0);

begin

    -- ram process
    ram_m    :   process(clk)
    begin
        if rising_edge(clk) then 
            -- write port
            if i_en = '1' then 
                cells(w_addr)   <=  i_data;             
            end if;
            
            -- read ports
            left_data       <=  cells(left_addr);   -- Read port 1
            rigth_data      <=  cells(rigth_addr);  -- Read port 2
        end if;
    end process;
    
    -- finite state machine process
    fsm_p       :   process(clk)
    begin
        if rising_edge(clk) then 
            if rst = '0' then      
                ram_filled  <=  false;
                w_addr      <=  0;           
                cut_addr    <=  0;
                window_ptr  <=  GUARD_CELLS/2+1;
                left_addr   <=  0;
                rigth_addr  <=  0;
                read_cut_ctr<=  0;
                o_en        <=  '0';
                cut_data    <=  (others => '0');
                left_acc    <=  (others => '0');
                rigth_acc   <=  (others => '0');
                total_acc   <=  (others => '0');   
                ave         <=  (others => '0');
                threshold   <=  (others => '0');   
                o_data      <=  (others => '0');             
            else
                case state is
                    when idle           =>  o_en    <=  '0';
                            
                                            if i_en = '1' then
                                                -- Update write address port
                                                if w_addr = ram'HIGH then 
                                                    w_addr  <=  ram'LOW;
                                                else
                                                    w_addr  <=  w_addr + 1;
                                                end if;                   
                                                            
                                                -- Update cut address
                                                if w_addr >= 0 and w_addr < CFAR_WINDOW/2 then          -- Corner cases
                                                    cut_addr    <=  ram'HIGH + w_addr - CFAR_WINDOW/2; 
                                                    left_addr   <=  ram'HIGH + w_addr - CFAR_WINDOW/2; 
                                                else                  
                                                    cut_addr    <=  w_addr - CFAR_WINDOW/2;
                                                    left_addr   <=  w_addr - CFAR_WINDOW/2;          
                                                end if; 
                                                
                                                -- State of the ram
                                                if w_addr = ram'HIGH then 
                                                    ram_filled  <=  true;
                                                end if;                                               
                                            
                                                -- Move to next state
                                                if w_addr >= CFAR_WINDOW or ram_filled = true then 
                                                    state   <=  read_cut;  
                                                end if;  
                                            end if;   
                                        
                    when read_cut       =>  if read_cut_ctr = 0 then                -- wait for the cycle that ram needs.
                                                read_cut_ctr    <=  read_cut_ctr + 1;
                                            elsif read_cut_ctr = 1 then             -- Read cut value and move to next state
                                                read_cut_ctr    <=  0;
                                                cut_data       <=  signed(left_data); 
                                                state           <=  cfar_acc;          
                                            end if;                   
                                        
                    when cfar_acc       =>  -- Update window pointer and accumulate data
                                            if window_ptr = LOW_CELL then                       -- Skip guard cells region 
                                                window_ptr  <=  window_ptr + 1;
                                                left_acc    <= (others => '0');  
                                                rigth_acc   <= (others => '0'); 
                                            elsif window_ptr = LOW_CELL+1 then                  -- Wait an extra cycle for data from ram
                                                window_ptr  <=  window_ptr + 1;
                                            elsif window_ptr < HIGH_CELL+2 then                 -- Window region
                                                window_ptr  <=  window_ptr + 1;
                                                left_acc    <=  left_acc  + resize(signed(left_data),  DATA_WIDTH+ACC_GROWTH);  
                                                rigth_acc   <=  rigth_acc + resize(signed(rigth_data), DATA_WIDTH+ACC_GROWTH);  
                                            elsif window_ptr = HIGH_CELL+2 then                 -- Sum of both window accumulation and next state
                                                state       <=  cfar_ave;                                                
                                                window_ptr  <=  LOW_CELL;
                                                total_acc   <=  left_acc + rigth_acc;  
                                            end if;                  

                                            -- Update read address port A
                                            if cut_addr - window_ptr < ram'LOW then 
                                                left_addr   <=  cut_addr + ram'HIGH - window_ptr + 1;  -- Corner case
                                            else
                                                left_addr   <=  cut_addr - window_ptr;
                                            end if;

                                            -- Update read address port B
                                            if cut_addr + window_ptr > ram'HIGH then 
                                                rigth_addr  <=  cut_addr - ram'HIGH + window_ptr - 1;  -- Corner case
                                            else
                                                rigth_addr  <=  cut_addr + window_ptr;
                                            end if;                                                                      

                    when cfar_ave       =>  -- Average
                                            ave     <=  total_acc * signed(divisor(integer(CFAR_WINDOW-GUARD_CELLS))); 
                                            -- Next state
                                            state   <=  cfar_threshold;                                  

                    when cfar_threshold =>  -- Threshold
                                            threshold       <=  to_signed(ALPHA, ALPHA_WIDTH) * ave;
                                            -- Next state
                                            state           <=  cfar_decision;

                    when cfar_decision  =>  -- CUT cfar_decision                    
                                            o_en    <=  '1';
                                            if resize(cut_data_frac_ext, threshold'LENGTH) >= threshold then 
                                                o_data      <=  std_logic_vector(cut_data);
                                            else
                                                o_data      <=  (others => '0');
                                            end if;

                                            -- Next state
                                            state       <=  idle;           
                end case;
            end if;
        end if;
    end process;
    
    cut_data_frac_ext    <=  cut_data & fractional_pad; -- Make threshold and cur to have the same fractional length to obtain a correct comparison result

end Behavioral;