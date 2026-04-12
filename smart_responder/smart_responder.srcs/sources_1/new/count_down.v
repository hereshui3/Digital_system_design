`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 14:25:14
// Design Name: 
// Module Name: count_down
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


module count_down(
    input clk,
    input rst,
    input cnt_start,
    output reg [7:0] seg_code,
    output cnt_down_over
);
    // 假设系统时钟为 100MHz，分频产生 1s 脉冲
    parameter T1S = 100_000_000; 
    reg [26:0] cnt;
    reg [3:0] cnt_down;
    reg cnt_sig;

    // 倒计时为 0 时拉高结束标志，供顶层进行状态清理
    assign cnt_down_over = (cnt_down == 4'd0) && cnt_start;

    // 1秒分频逻辑
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 27'd0;
            cnt_sig <= 1'b0;
        end else if (cnt_start) begin
            if (cnt == T1S - 1) begin
                cnt <= 27'd0;
                cnt_sig <= 1'b1;
            end else begin
                cnt <= cnt + 1;
                cnt_sig <= 1'b0;
            end
        end else begin
            cnt <= 27'd0;
            cnt_sig <= 1'b0;
        end
    end

    // 倒计时逻辑：开始后按 1s 节拍从 9 递减到 0
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt_down <= 4'd9;
        end else if (cnt_sig && cnt_down > 0) begin
            cnt_down <= cnt_down - 1;
        end else if (!cnt_start) begin
            cnt_down <= 4'd9;
        end
    end

    // 译码逻辑 (共阴极示例)
    always @(*) begin
        case (cnt_down)
            4'd0: seg_code = 8'hfc;
            4'd1: seg_code = 8'h60;
            4'd2: seg_code = 8'hda;
            4'd3: seg_code = 8'hf2;
            4'd4: seg_code = 8'h66;
            4'd5: seg_code = 8'hb6;
            4'd6: seg_code = 8'hbe;
            4'd7: seg_code = 8'he0;
            4'd8: seg_code = 8'hfe;
            4'd9: seg_code = 8'hf6;
            default: seg_code = 8'hff;
        endcase
    end
endmodule