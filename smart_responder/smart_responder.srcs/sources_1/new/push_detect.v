`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 14:25:14
// Design Name: 
// Module Name: push_detect
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


module push_detect(
    input clk,
    input rst,
    input clr,
    input [3:0] btn,
    output reg [3:0] state
);
    parameter OVER = 8'hf6;
    reg [3:0] pos;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 4'd0;
            pos <= 4'd0;
        end else if (clr) begin
            // 一轮结束后清空锁存，允许下一轮重新抢答
            state <= 4'd0;
            pos <= 4'd0;
        end else begin
            case (pos)
                4'd0: begin // 初始状态，等待按键
                    if (btn != 4'd0) begin
                        state <= btn;
                        pos <= btn; // 锁定按键位置
                    end
                end
                // 一旦按下，pos 不再为0，除非复位，否则不再进入上方的判断
                4'd1, 4'd2, 4'd4, 4'd8: begin
                    state <= pos;
                    pos <= pos;
                end
                default: pos <= 4'd0;
            endcase
        end
    end
endmodule