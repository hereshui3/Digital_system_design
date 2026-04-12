`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 11:20:48
// Design Name: 
// Module Name: tb_comp
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


module tb_comp(

    );
    reg [1:0] A;
    reg [1:0] B;
    wire AGTB;
    wire ALTB;
    wire AEQB;

    integer i;
    integer j;
    integer errors;

    // DUT instance
    comp uut (
        .A(A),
        .B(B),
        .AGTB(AGTB),
        .ALTB(ALTB),
        .AEQB(AEQB)
    );

    initial begin
        errors = 0;
        A = 2'b00;
        B = 2'b00;

        $display("Start comparator test...");
        $display("   t   A  B | AGTB ALTB AEQB");

        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                A = i[1:0];
                B = j[1:0];
                #10;

                $display("%4t  %0d  %0d |   %0b    %0b    %0b", $time, A, B, AGTB, ALTB, AEQB);

                if ((A > B) && (AGTB !== 1'b1 || ALTB !== 1'b0 || AEQB !== 1'b0)) begin
                    errors = errors + 1;
                    $display("ERROR: A>B but output is wrong");
                end
                else if ((A < B) && (AGTB !== 1'b0 || ALTB !== 1'b1 || AEQB !== 1'b0)) begin
                    errors = errors + 1;
                    $display("ERROR: A<B but output is wrong");
                end
                else if ((A == B) && (AGTB !== 1'b0 || ALTB !== 1'b0 || AEQB !== 1'b1)) begin
                    errors = errors + 1;
                    $display("ERROR: A==B but output is wrong");
                end
            end
        end

        if (errors == 0)
            $display("All test cases passed.");
        else
            $display("Test finished with %0d error(s).", errors);

        $finish;
    end
endmodule
