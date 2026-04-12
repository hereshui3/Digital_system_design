`timescale 1ns / 1ps  // 时间单位1ns，时间精度1ps

module time_counter(
    input clk,      // 系统时钟输入
    input key1,     // 计数使能信号(1=计数，0=暂停)
    input rst_n,    // 异步复位信号(高电平有效)
    output [15:0] data // 16位输出数据，分为4个BCD码(千、百、十、个位)
);

reg [15:0] data;    // 输出数据寄存器
reg clk_10Hz = 0;   // 10Hz时钟信号(用于计时)
integer clk_10Hz_cnt; // 时钟分频计数器

// 生成10Hz时钟(假设原时钟为50MHz)
// 50MHz/10Hz = 5,000,000，每个半周期计数2,500,000次
always@(posedge clk) begin 
    if(clk_10Hz_cnt == 32'd5000000-1) begin 
        clk_10Hz_cnt <= 0;
        clk_10Hz <= ~clk_10Hz;  // 时钟翻转
    end
    else begin 
        clk_10Hz <= clk_10Hz;    // 保持当前时钟值
        clk_10Hz_cnt <= clk_10Hz_cnt + 1; // 计数器递增
    end
end

// 定义4个BCD码计数器(个、十、百、千位)
reg [3:0] time_1 = 0;    // 个位计数器(0-9)
reg [3:0] time_10 = 0;   // 十位计数器(0-9)
reg [3:0] time_100 = 0;  // 百位计数器(0-5，模拟秒表的60进制)
reg [3:0] time_1000 = 0; // 千位计数器(0-9)

// 在10Hz时钟上升沿进行计数
always@(posedge clk_10Hz) begin 
    if(rst_n) begin  // 复位信号有效时
        // 所有计数器清零
        time_1 <= 0; 
        time_10 <= 0; 
        time_100 <= 0; 
        time_1000 <= 0; 
        // 输出数据更新为全0
        data[15:0] <= {time_1000, time_100, time_10, time_1}; 
    end 
    else begin  // 正常计数模式
        if(key1 == 1) begin  // 计数使能信号有效
            if(time_1 < 4'b1001) begin  // 个位0-9计数
                time_1 <= time_1 + 1'b1; 
                data[15:0] <= {time_1000, time_100, time_10, time_1}; 
            end 
            else if(time_10 < 4'b1001) begin  // 十位0-9计数(个位满10进位)
                time_10 <= time_10 + 1'b1;
                time_1 <= 4'b0000;  // 个位清零
                data[15:0] <= {time_1000, time_100, time_10, time_1};
            end 
            else if(time_100 < 4'b0101) begin  // 百位0-5计数(模拟60进制)
                time_100 <= time_100 + 1; 
                time_10 <= 4'b0000;  // 十位清零
                time_1 <= 4'b0000;   // 个位清零
                data[15:0] <= {time_1000, time_100, time_10, time_1}; 
            end 
            else if(time_1000 < 4'b1001) begin // 千位0-9计数(百位满6进位)
                time_1000 <= time_1000 + 1'b1; 
                time_100 <= 4'b0000;  // 百位清零
                time_10 <= 4'b0000;   // 十位清零
                time_1 <= 4'b0000;     // 个位清零
                data[15:0] <= {time_1000, time_100, time_10, time_1}; 
            end 
            else begin  // 所有位都达到最大值(9999)，全部清零
                time_1000 <= 4'b0000; 
                time_100 <= 4'b0000; 
                time_10 <= 4'b0000; 
                time_1 <= 4'b0000; 
                data[15:0] <= {time_1000, time_100, time_10, time_1}; 
            end 
        end 
        else begin  // 计数使能信号无效，保持当前值(暂停功能)
            time_1000 <= time_1000; 
            time_100 <= time_100; 
            time_10 <= time_10; 
            time_1 <= time_1; 
            data <= {time_1000, time_100, time_10, time_1};
        end 
    end
end
endmodule