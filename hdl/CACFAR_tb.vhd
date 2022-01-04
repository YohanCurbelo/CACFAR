library ieee;
use     ieee.std_logic_1164.all;
use		ieee.std_logic_textio.all;

library std;
use 	std.textio.all;

entity CACFAR_tb is
    generic (
        DATA_WIDTH      :   positive    :=  16;
        DATA_WINDOW     :   positive    :=  64;
        CFAR_WINDOW     :   positive    :=  12;
        GUARD_CELLS     :   positive    :=  4;
        ALPHA           :   positive    :=  5
    );
end CACFAR_tb;

architecture Behavioral of CACFAR_tb is

    -- Clock and reset signals
    constant Tclk           :   time        :=  1 us;
    signal stop_clk         :   boolean     :=  false;

    -- Stimuli signals
    constant latency        :   positive    :=  13;    -- HW Latency
    signal stop_stimuli     :   boolean     :=  false;
    signal periods          :   integer range 0 to DATA_WINDOW; 
    signal ctr              :   integer range 0 to DATA_WINDOW + DATA_WINDOW/2;            
    
    -- DUT signals
    signal clk              :   std_logic;
    signal rst              :   std_logic;
    signal i_en             :   std_logic;
    signal i_data           :   std_logic_vector(DATA_WIDTH-1 downto 0);
    signal o_en             :   std_logic;
    signal o_data           :   std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- DUT instantiation
    DUT :   entity work.CACFAR(Behavioral)
        generic map (
            DATA_WIDTH      => DATA_WIDTH,
            DATA_WINDOW     => DATA_WINDOW,
            CFAR_WINDOW     => CFAR_WINDOW,
            GUARD_CELLS     => GUARD_CELLS,
            ALPHA           => ALPHA
        )
        port map (
            clk             => clk,
            rst             => rst,
            i_en            => i_en,
            i_data          => i_data,
            o_data          => o_data
        );
        
    -- Read stimuli from matlab
    from_txt	:	process
		file		i_file		:	text is in "stimuli.txt";
		variable	file_line	:	line;
		variable	stimuli	    :	std_logic_vector(DATA_WIDTH-1 downto 0);
	begin
	    wait until clk = '1';	    
		while not endfile(i_file) loop	
		    wait until i_en = '1';		    	
			readline(i_file,file_line);
			read(file_line,stimuli);
			i_data	<=	stimuli;
			wait until clk = '1';	
		end loop;
		file_close(i_file);
		wait;
	end process;

    -- Clock process
    clk_p   :   process
    begin
        while not stop_clk loop
            clk     <=  '1';
            wait for Tclk/2;
            clk     <=  '0';
            wait for Tclk/2;
        end loop;
        wait;
    end process;

    -- Reset process
    rst_p   :   process 
    begin
        rst     <=  '0';
        wait for 25 us;
        rst     <=  '1';
        wait;
    end process;

    -- Stimuli process
    stm_p   :   process 
    begin
        while not stop_stimuli loop
            if rst = '0' then
                ctr     <=  0;
                periods <=  0;
                i_en    <=  '0';
            elsif ctr < DATA_WINDOW + DATA_WINDOW/2 then
                if periods = latency then
                    periods <=  0;
                    ctr     <=  ctr + 1;
                    i_en    <=  '1';
                else
                    i_en    <=  '0';
                    periods <=  periods + 1;
                end if;
            else
                ctr          <=  0;
                periods      <=  0;
                i_en         <=  '0';
                stop_stimuli <= true;
            end if;
            wait until clk = '1';
        end loop;
        wait for 25 us;
        stop_clk    <=  true;
        wait for 25 us;
        wait;
    end process;  

end Behavioral;