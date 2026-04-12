`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 10:24:16
// Design Name: 
// Module Name: sim_encoder4_2_new
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


`timescale 1ns/1ps 
module sim_encoder4_2_new; 
reg [3:0] d = 0;
wire [1:0] q;
encoder4_2_new u_encoder4_2(
 .d ( d [3:0] ),
 .q ( q [1:0] )
);
initial
begin
 d = 4'b1110;
 #10 d = 4'b1101;
 #10 d = 4'b1011;
 #10 d = 4'b0111;
 #10 d = 4'b0000;
 $finish;
end
endmodule
