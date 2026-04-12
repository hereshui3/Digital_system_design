`timescale 1ns / 1ps  // 定义时间单位1纳秒，时间精度1皮秒

// 数码管驱动IP模型（支持4位数码管动态扫描）
module smg_ip_model(
    input clk,          // 系统时钟输入（假设50MHz）
    input [15:0] data,  // 16位显示数据（每4位对应1位数码管）
    output [3:0] sm_wei, // 数码管位选信号（低电平有效）
    output [7:0] sm_duan // 数码管段选信号（低电平有效）
);

// ==================== 时钟分频模块 ====================
integer clk_cnt;        // 分频计数器
reg clk_400Hz;          // 分频后时钟（400Hz）

// 将50MHz时钟分频为400Hz（适合人眼观察的动态扫描频率）
always@(posedge clk)
    if(clk_cnt == 124999) begin  // 50MHz/(125000*2)=400Hz
        clk_cnt <= 1'b0;
        clk_400Hz <= ~clk_400Hz; // 时钟翻转
    end
    else
        clk_cnt <= clk_cnt + 1'b1;

// ==================== 位选控制模块 ====================
reg [3:0] wei_ctrl = 4'b0001; // 位选寄存器（初始选中第1位）

// 400Hz时钟驱动位选循环移位（实现动态扫描）
always@(posedge clk_400Hz)
    wei_ctrl <= {wei_ctrl[2:0], wei_ctrl[3]}; // 循环左移（0001→0010→0100→1000→0001）

// ==================== 段选数据选择 ====================
reg [3:0] duan_ctrl; // 当前数码管的数据输入

// 根据位选选择对应的4位数据
always@(wei_ctrl)
    case(wei_ctrl)
        4'b0001: duan_ctrl = data[3:0];   // 第1位数码管
        4'b0010: duan_ctrl = data[7:4];   // 第2位数码管
        4'b0100: duan_ctrl = data[11:8];  // 第3位数码管
        4'b1000: duan_ctrl = data[15:12]; // 第4位数码管
        default: duan_ctrl = 4'hf;        // 异常处理（不显示）
    endcase

// ==================== 数码管译码模块 ====================
reg [7:0] duan; // 段选输出寄存器（共阳极编码）

// 7段数码管译码（0-F的显示编码）
always@(duan_ctrl)
    case(duan_ctrl)
        // 数字0-9的段码（按gfedcba顺序）
        4'h0: duan = 8'b1100_0000; // 0
        4'h1: duan = 8'b1111_1001; // 1
        4'h2: duan = 8'b1010_0100; // 2
        4'h3: duan = 8'b1011_0000; // 3
        4'h4: duan = 8'b1001_1001; // 4
        4'h5: duan = 8'b1001_0010; // 5
        4'h6: duan = 8'b1000_0010; // 6
        4'h7: duan = 8'b1111_1000; // 7
        4'h8: duan = 8'b1000_0000; // 8
        4'h9: duan = 8'b1001_0000; // 9
        
        // 字母A-F的段码
        4'ha: duan = 8'b1000_1000; // A
        4'hb: duan = 8'b1000_0011; // B
        4'hc: duan = 8'b1100_0110; // C
        4'hd: duan = 8'b1010_0001; // D
        4'he: duan = 8'b1000_0110; // E
        4'hf: duan = 8'b1000_1110; // F
        
        default: duan = 8'b1100_0000; // 默认显示0
    endcase

// ==================== 输出驱动 ====================
assign sm_wei = wei_ctrl;   // 位选输出（低电平有效）
assign sm_duan = ~duan;     // 段选输出（转换为低电平有效）

endmodule