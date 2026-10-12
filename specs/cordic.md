# Four-iteration rotation CORDIC: frozen contract v1

Original open spec; MIT license. Implement module `cordic`:

```verilog
module cordic(input clk,rst,valid_in,input [15:0] x_in,y_in,z_in,output valid_out,output [15:0] x_out,y_out,z_out);
```

Inputs before rising edge, outputs sampled one unit after. Synchronous active-high
rst has priority and zeroes all outputs. Interpret x/y/z as signed 16-bit two's
complement. On valid_in compute iterations i=0,1,2,3, constants
[8192,4836,2555,1297] (one turn=65536). If signed z>=0:
next x=x-(y>>>i), next y=y+(x>>>i), next z=z-angle[i]; else:
next x=x+(y>>>i), next y=y-(x>>>i), next z=z+angle[i]. Each x/y pair uses the SAME
old values. Arithmetic shifts round toward negative infinity. Wrap each result
after EACH iteration to signed 16 bits. Register final outputs on acceptance
edge; valid_out follows valid_in unless reset. Outputs hold during bubbles.
No gain correction, range reduction, or saturation. All 16-bit patterns defined;
ordinary tests concentrate on x,y in [-1000,1000], z in [-8192,8192].
