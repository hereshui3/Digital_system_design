`timescale 1ns / 1ps

module ful_adder(
output cout,
output sum,
input a,
input b,
input cin
);

assign sum = (a ^ b) ^ cin;  

// cout = (A & Cin) | (B & Cin) | (A & B) （计算进位输出）
assign cout = (a & cin) | (b & cin) | (a & b);

endmodule