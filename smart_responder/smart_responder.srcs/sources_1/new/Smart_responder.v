`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/03/26 14:25:14
// Design Name: 
// Module Name: Smart_responder
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


module Smart_responder(
    input clk,
    input rst_n,       // 复位按键通常是低电平有效
    input [3:0] btn,
    output [3:0] an,
    output [7:0] seg_code
);
    wire rst = ~rst_n; // 转为高电平有效复位供内部使用
    wire [3:0] state;
    wire cnt_down_over; // 倒计时结束
    wire cnt_start;     // 倒计时开始

    // 实例化按键检测
    push_detect u_push_detect(
        .clk(clk),
        .rst(rst),
        .clr(cnt_down_over),
        .btn(btn),
        .state(state)
    );

    // 信号转换逻辑
    assign cnt_start = |state; // 只要有任何一位抢答成功，就开始倒计时

    // 实例化数码管选通
    show_who u_show_who(
        .clk(clk),
        .rst(rst),
        .state(state),
        .cnt_down_over(cnt_down_over),
        .an(an)
    );

    // 实例化倒计时
    count_down u_count_down(
        .clk(clk),
        .rst(rst),
        .cnt_start(cnt_start),
        .seg_code(seg_code),
        .cnt_down_over(cnt_down_over)
    );

endmodule
