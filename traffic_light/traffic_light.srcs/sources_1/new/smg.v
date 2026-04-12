`timescale 1ns / 1ps  // 定义时间单位1纳秒，时间精度1皮秒
module smg(
    input clk,                // 系统时钟输入（50MHz）
    output [3:0] sm_wei,      // 数码管位选信号（低电平有效）
    output [7:0] sm_duan,     // 数码管段选信号（低电平有效）
    output [2:0] out_LED3_NS, // 北南方向LED灯控制（如：红黄绿）
    output [2:0] out_LED3_WE  // 东西方向LED灯控制（如：红黄绿）
);

// 内部信号定义
wire [15:0] data;  // 16位显示数据（4组4位数码管数据）

/*
 * 实例化测试数据生成模块
 * 功能：产生数码管显示数据和交通灯控制信号
 */
test U0(
    .clk(clk),               // 系统时钟
    .data(data),             // 输出到数码管的16位数据
    .out_LED3_NS(out_LED3_NS), // 北南方向交通灯
    .out_LED3_WE(out_LED3_WE)  // 东西方向交通灯
);

/*
 * 实例化数码管驱动IP核
 * 功能：实现4位数码管的动态扫描显示
 */
smg_ip_model U1(
    .clk(clk),       // 系统时钟
    .data(data),     // 16位显示数据输入
    .sm_wei(sm_wei), // 数码管位选输出
    .sm_duan(sm_duan) // 数码管段选输出
);
endmodule