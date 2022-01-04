Customizable Cell Averaging Constant False Alarm Rate

Description: 
1. Data is stores in a ring RAM
2. RAM is doble read port so right and left window are accesible at the same time
3. There are 128 divisors available to make the average are saved in luts with 10 
and 9 word and fractional length and as a signed format
4. Internal signals have natural growth while output is the same width as input
5. If a positive detection is made on a cell its value will be output. If not output 
is zero

Descripcion:
1. Los datos son almacenados en una RAM circular
2. La RAM tiene dos puertos de lectura para acceder al mismo tiempo a las ventanas
izquierda y derecha
3. Hay 128 divisores disponibles para hacer el promediado de los valores en las
ventanas. Los divisores estan en luts con formato signed [10 9]
4. Las senyales internas tienen crecimiento natural, pero la salida es del mismo
ancho que la entrada. 
5. Si una celda resulta en una deteccion positiva su valor es puesto a la salida. 
En cambio, la salida sera cero si no hay deteccion.




             ___
i_en    _____| |______________________________________________________
             ___
i_data  _____| |______________________________________________________
                                                    ___
o_en    ____________________________________________| |_______________
                                                    ___
o_data  ____________________________________________| |_______________