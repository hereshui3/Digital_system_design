`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 11:08:22
// Design Name: 
// Module Name: comp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module comp(A,B,AGTB,ALTB,AEQB);
input[1:0]A,B;
output AGTB,ALTB,AEQB;
reg AGTB,ALTB,AEQB;
always@(*)
begin
    AGTB = 0;
    ALTB = 0;
    AEQB = 0;

    if(A>B)
        AGTB = 1;
    else if(A==B)
        AEQB = 1;
    else
        ALTB = 1;
end
endmodule
