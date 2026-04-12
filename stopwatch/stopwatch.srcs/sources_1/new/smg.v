`timescale 1ns / 1ps  // 时间单位1ns，时间精度1ps

module smg_ip(
    input clk,         // 系统时钟输入
    input [15:0] data,  // 16位输入数据，分为4个4位数分别显示
    output [3:0] sm_wei, // 数码管位选信号(控制哪个数码管亮)
    output [7:0] sm_duan // 数码管段选信号(控制显示什么字符)
);

integer clk_cnt;  // 时钟计数器

// 生成400Hz扫描时钟(假设原时钟为50MHz)
// 50MHz/400Hz = 125000，每个半周期计数62500次
reg clk_400Hz = 0; 
always@(posedge clk) begin
    if(clk_cnt == 32'd125000-1) begin 
        clk_cnt <= 0;
        clk_400Hz = ~clk_400Hz;  // 时钟翻转
    end
    else begin 
        clk_cnt <= clk_cnt + 1;  // 计数器递增
    end
end

// 位选控制信号生成(轮流点亮4个数码管)
reg [3:0] wei_ctrl = 4'b0001;  // 初始选择第一个数码管
always@(posedge clk_400Hz) begin 
    // 循环左移：0001→0010→0100→1000→0001...
    wei_ctrl <= (wei_ctrl == 4'b1000) ? 4'b0001 : {wei_ctrl[2:0], 1'b0};
end

// 根据当前选中的数码管位置，选择对应的4位数据
reg [3:0] duan_ctrl;  // 当前要显示的4位数据
always@(*) 
    case(wei_ctrl) 
        4'b0001: duan_ctrl = data[3:0];   // 第1个数码管显示data[3:0]
        4'b0010: duan_ctrl = data[7:4];   // 第2个数码管显示data[7:4]
        4'b0100: duan_ctrl = data[11:8];   // 第3个数码管显示data[11:8]
        4'b1000: duan_ctrl = data[15:12];  // 第4个数码管显示data[15:12]
        default: duan_ctrl = 4'h0;         // 默认显示0
    endcase

// 7段数码管译码器
// 本工程段码顺序为: a b c d e f g dp (dp在最低位)
reg [7:0] duan;  // 8位段选信号(包含小数点)
reg dp_ctrl;     // 小数点控制(本工程:1亮,0灭)
always@(*) begin 
    case(duan_ctrl) 
        4'h0: duan = 8'b1111_1100; // 0 
        4'h1: duan = 8'b0110_0000; // 1 
        4'h2: duan = 8'b1101_1010; // 2 
        4'h3: duan = 8'b1111_0010; // 3 
        4'h4: duan = 8'b0110_0110; // 4 
        4'h5: duan = 8'b1011_0110; // 5 
        4'h6: duan = 8'b1011_1110; // 6 
        4'h7: duan = 8'b1110_0000; // 7
        4'h8: duan = 8'b1111_1110; // 8 
        4'h9: duan = 8'b1111_0110; // 9 
        4'ha: duan = 8'b1110_1110; // a 
        4'hb: duan = 8'b0011_1110; // b 
        4'hc: duan = 8'b1001_1100; // c 
        4'hd: duan = 8'b0111_1010; // d 
        4'he: duan = 8'b0001_1110; // e 
        4'hf: duan = 8'b1000_1110; // f 
        default: duan = 8'b1111_1100; // 默认显示0
     endcase
end

// 打开第4位和第2位的小数点
// 4'b1000 对应第4位，4'b0010 对应第2位
always@(*) begin
    case(wei_ctrl)
        4'b1000, 4'b0010: dp_ctrl = 1'b1; // 亮
        default:          dp_ctrl = 1'b0; // 灭
    endcase
end

// 输出赋值
assign sm_wei = wei_ctrl;   // 位选信号输出
assign sm_duan = {duan[7:1], dp_ctrl}; // 段选信号输出

endmodule