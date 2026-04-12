`timescale 1ns / 1ps  // 时间单位1ns，时间精度1ps

module vga(
    input clock,        // 系统输入时钟 100MHz
    input [1:0] switch,  // 模式选择开关输入
    output [2:0] disp_RGB, // VGA RGB数据输出(3位: R,G,B)
    output hsync,        // VGA行同步信号
    output vsync         // VGA场同步信号
);

// 内部寄存器定义
reg [9:0] hcount;       // VGA行扫描计数器(0-799)
reg [9:0] vcount;       // VGA场扫描计数器(0-524)
reg [2:0] data;         // 当前像素数据
reg [2:0] h_dat;        // 横彩条数据
reg [2:0] v_dat;        // 竖彩条数据

// 内部连线定义
wire hcount_ov;         // 行计数结束标志
wire vcount_ov;         // 场计数结束标志
wire dat_act;           // 有效显示区域标志
// VGA时序参数定义(标准640x480@60Hz)
parameter   hsync_end = 10'd95,    // 行同步脉冲结束位置
            hdat_begin = 10'd143,  // 行有效数据开始
            hdat_end = 10'd783,    // 行有效数据结束
            hpixel_end = 10'd799,  // 行扫描总像素数
            vsync_end = 10'd1,     // 场同步脉冲结束位置
            vdat_begin = 10'd34,   // 场有效数据开始
            vdat_end = 10'd514,    // 场有效数据结束
            vline_end = 10'd524;   // 场扫描总行数
// 时钟分频部分 ===========================================
reg vga_clk_50M = 0;    // 50MHz时钟寄存器
reg vga_clk_25M = 0;    // 25MHz时钟寄存器(VGA像素时钟)

// 100MHz->50MHz分频(二分频)
always @(posedge clock) begin
    vga_clk_50M <= ~vga_clk_50M; 
end

// 50MHz->25MHz分频(二分频)
always @(posedge vga_clk_50M) begin
    vga_clk_25M <= ~vga_clk_25M; 
end

// VGA驱动部分 ===========================================
// 行计数器逻辑
always @(posedge vga_clk_25M) begin
    if (hcount_ov)
        hcount <= 10'd0;  // 行计数结束，归零
    else
        hcount <= hcount + 10'd1; // 行计数递增
end
assign hcount_ov = (hcount == hpixel_end); // 行结束判断
// 场计数器逻辑(每行结束时递增)
always @(posedge vga_clk_25M) begin
    if (hcount_ov) begin  // 只在行结束时递增场计数
        if (vcount_ov)
            vcount <= 10'd0;  // 场计数结束，归零
        else
            vcount <= vcount + 10'd1; // 场计数递增
    end
end
assign vcount_ov = (vcount == vline_end); // 场结束判断
// 同步信号生成 ===========================================
assign dat_act = ((hcount >= hdat_begin) && (hcount < hdat_end)) && 
                ((vcount >= vdat_begin) && (vcount < vdat_end)); // 有效显示区域判断
assign hsync = (hcount > hsync_end); // 行同步信号(低电平有效)
assign vsync = (vcount > vsync_end); // 场同步信号(低电平有效)
assign disp_RGB = dat_act ? data : 3'b000; // 有效区域显示数据，否则输出黑色
// 显示数据处理部分 =======================================
// 根据开关选择显示模式
always @(posedge vga_clk_25M) begin
    case(switch[1:0])
        2'd0: data <= h_dat;       // 模式0:横彩条
        2'd1: data <= v_dat;       // 模式1:竖彩条
        2'd2: data <= (v_dat ^ h_dat); // 模式2:棋盘格(异或)
        2'd3: data <= (v_dat ~^ h_dat); // 模式3:反相棋盘格(同或)
    endcase
end
// 竖彩条生成逻辑(按列划分)
always @(posedge vga_clk_25M) begin
    if(hcount < 223)       v_dat <= 3'h7; // 白(111)
    else if(hcount < 303)  v_dat <= 3'h6; // 黄(110)
    else if(hcount < 383)  v_dat <= 3'h5; // 青(101)
    else if(hcount < 463)  v_dat <= 3'h4; // 绿(100)
    else if(hcount < 543)  v_dat <= 3'h3; // 紫(011)
    else if(hcount < 623)  v_dat <= 3'h2; // 红(010)
    else if(hcount < 703)  v_dat <= 3'h1; // 蓝(001)
    else                   v_dat <= 3'h0; // 黑(000)
end
// 横彩条生成逻辑(按行划分)
always @(posedge vga_clk_25M) begin
    if(vcount < 94)        h_dat <= 3'h7; // 白(111)
    else if(vcount < 154)  h_dat <= 3'h6; // 黄(110)
    else if(vcount < 214)  h_dat <= 3'h5; // 青(101)
    else if(vcount < 274)  h_dat <= 3'h4; // 绿(100)
    else if(vcount < 334)  h_dat <= 3'h3; // 紫(011)
    else if(vcount < 394)  h_dat <= 3'h2; // 红(010)
    else if(vcount < 454)  h_dat <= 3'h1; // 蓝(001)
    else                   h_dat <= 3'h0; // 黑(000)
end
endmodule