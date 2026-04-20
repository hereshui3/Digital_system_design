`timescale 1ns / 1ps
`include "Comparator/Comparator.srcs/sources_1/new/comparator.v"//修复路径错误，写成工作区相对路径
module tb_comp;
wire AGTB,ALTB,AEQB;
reg[1:0]A,B;
comp u_comp(.A(A[1:0]),.B(B[1:0]),.AGTB (AGTB),.ALTB (ALTB),.AEQB (AEQB)); 
initial begin
   $dumpfile("tb_comparator.vcd");
   $dumpvars(0, tb_comp);
end

initial
    begin
         // 初始状态：A=00, B从00→11扫描
        A = 2'b00;  // SW1-SW0 
        B = 2'b00;  // SW3-SW2 
        #10 B = 2'b01;  // 10ns后：B=01
        #10 B = 2'b10;  // 20ns：B=10
        #10 B = 2'b11;  // 30ns：B=11
        
        // 第二阶段：A=01, B全组合测试
        #10 A = 2'b01;  // 40ns 
           B = 2'b00;  
        #10 B = 2'b01;  // 50ns
        #10 B = 2'b10;  // 60ns
        #10 B = 2'b11;  // 70ns
        
        // 第三阶段：A=10, B全组合测试
        #10 A = 2'b10;  // 80ns： 
           B = 2'b00;
        #10 B = 2'b01;  // 90ns
        #10 B = 2'b10;  // 100ns
        #10 B = 2'b11;  // 110ns
        
        // 第四阶段：A=11, B全组合测试
        #10 A = 2'b11;  // 120ns
        #10 B = 2'b01;  // 130ns
        #10 B = 2'b10;  // 140ns
        #10 B = 2'b11;  // 150ns：最终测试点
        
        #10 $finish;   
    end
endmodule