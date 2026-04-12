`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 14:25:14
// Design Name: 
// Module Name: show_who
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


module show_who(
    input clk,
    input rst,
    input [3:0] state,
    input cnt_down_over,
    output reg [3:0] an
);
    reg [3:0] pos;
    reg done_latch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pos <= 4'd0;
            done_latch <= 1'b0;
            an <= 4'h0; // 初始状态四位全开，显示 9
        end else begin
            case (pos)
                4'd0: begin
                    if (state != 4'd0) begin
                        done_latch <= 1'b0;
                        pos <= state;
                    end else begin
                        // 初始空闲显示全部；倒计时结束后的空闲全灭
                        if (done_latch) an <= 4'h0;
                        else an <= 4'hf;
                    end
                end
                4'd1, 4'd2, 4'd4, 4'd8: begin
                    if (cnt_down_over) begin
                        pos <= 4'd0; // 倒计时结束复位
                        done_latch <= 1'b1;
                        an <= 4'h0;
                    end else begin
                        an <= pos; // 选通对应的数码管（Ego1为共阴极需取反或根据实际逻辑调整）
                    end
                end
                default: begin
                    pos <= 4'd0;
                    an <= 4'h0;
                end
            endcase
        end
    end
endmodule
