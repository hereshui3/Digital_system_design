`timescale 1ns / 1ps  // 定义时间单位1纳秒，时间精度1皮秒

/*
 * 交通灯控制测试模块
 * 功能：模拟交通灯控制系统，包括：
 * 1. 南北/东西方向倒计时显示
 * 2. 交通灯状态控制（红黄绿）
 * 3. 四状态自动切换逻辑
 */
module test(
    input clk,               // 系统时钟（50MHz）
    output [15:0] data,      // 16位数码管显示数据（南北+东西方向倒计时）
    output [2:0] out_LED3_NS, // 北南方向交通灯（bit2:红, bit1:黄, bit0:绿）
    output [2:0] out_LED3_WE  // 东西方向交通灯（同上）
);

// ==================== 1Hz时钟分频 ====================
reg clk_1Hz = 0;                  // 1Hz时钟信号
integer clk_1Hz_cnt = 0;          // 分频计数器

// 将50MHz时钟分频为1Hz（用于秒级倒计时）
always@(posedge clk)
    if(clk_1Hz_cnt == 50_000_000-1) begin 
        clk_1Hz_cnt <= 1'b0;
        clk_1Hz <= ~clk_1Hz;      // 每秒翻转一次
    end
    else
        clk_1Hz_cnt <= clk_1Hz_cnt + 1'b1;

// ==================== 交通灯状态机 ====================
reg [15:0] data;                 // 数码管显示数据寄存器
reg [2:0] out_LED3_NS, out_LED3_WE; // 交通灯控制寄存器

// 倒计时寄存器定义：
reg [3:0] Time_10 = 2'd2;  // 南北方向十位数（初始20秒）
reg [3:0] Time_1 = 2'd0;   // 南北方向个位数
reg [3:0] time_10 = 2'd2;  // 东西方向十位数（初始23秒）
reg [3:0] time_1 = 2'd3;   // 东西方向个位数

// 交通灯状态定义（二段式状态机）
reg [1:0] Stage = 2'b00;  // 当前状态
/*
 * 状态编码：
 * 00: 南北绿灯，东西红灯
 * 01: 南北红灯，东西绿灯 
 * 10: 南北黄灯，东西红灯
 * 11: 南北红灯，东西黄灯
 */

always@(posedge clk_1Hz) begin 
    case(Stage) 
        // 状态00：南北绿灯，东西红灯
        2'b00: begin 
            if((Time_10==0) & (Time_1==1)) begin // 南北倒计时剩1秒
                Stage <= 2'b10;                  // 切换到黄灯状态
                Time_10 <= 4'd0; Time_1 <= 4'd3; // 设置黄灯时间3秒
                time_10 <= 4'd0; time_1 <= 4'd3;
            end 
            else begin  // 正常倒计时
                // 南北方向倒计时
                if(Time_1==0) begin
                    Time_1 <= 4'd9; 
                    Time_10 <= Time_10-1; 
                end 
                else Time_1 <= Time_1-1; 
                
                // 东西方向倒计时
                if(time_1==0) begin
                    time_1 <= 4'd9; 
                    time_10 <= time_10-1; 
                end 
                else time_1 <= time_1-1; 
            end 
            
            // 更新显示数据和灯状态
            data[15:8] <= {Time_10,Time_1};  // 南北时间
            data[7:0] <= {time_10,time_1};   // 东西时间
            out_LED3_NS <= 3'b001;          // 南北绿灯
            out_LED3_WE <= 3'b100;          // 东西红灯
        end 
        
        // 状态01：南北红灯，东西绿灯
        2'b01: begin
            if((Time_10==0) & (Time_1==4)) begin // 东西倒计时剩4秒
                Stage <= 2'b11;                  // 切换到黄灯状态
                Time_10 <= 4'd0; Time_1 <= 4'd3; // 设置黄灯时间3秒
                time_10 <= 4'd0; time_1 <= 4'd3;
            end 
            else begin  // 正常倒计时
                // 南北方向倒计时
                if(Time_1==0) begin
                    Time_1 <= 4'd9; 
                    Time_10 <= Time_10-1; 
                end 
                else Time_1 <= Time_1-1; 
                
                // 东西方向倒计时
                if(time_1==0) begin
                    time_1 <= 4'd9; 
                    time_10 <= time_10-1; 
                end 
                else time_1 <= time_1-1; 
            end 
            
            data[15:8] <= {Time_10,Time_1};  // 南北时间
            data[7:0] <= {time_10,time_1};   // 东西时间
            out_LED3_WE <= 3'b001;           // 东西绿灯
            out_LED3_NS <= 3'b100;           // 南北红灯
        end 
// 状态10：南北黄灯，东西红灯
        2'b10: begin
            if((Time_10==0) & (Time_1==1)) begin // 黄灯倒计时剩1秒
                Stage <= 2'b01;                  // 切换到东西绿灯状态
                Time_10 <= 4'd2; Time_1 <= 4'd3; // 重置南北时间23秒
                time_10 <= 4'd2; time_1 <= 4'd0; // 重置东西时间20秒
            end 
            else begin  // 黄灯倒计时
                if(Time_1==0) begin
                    Time_1 <= 4'd9; 
                    Time_10 <= Time_10-1; 
                end 
                else Time_1 <= Time_1-1; 
            end 
            
            data[15:8] <= {Time_10,Time_1};  // 南北时间
            data[7:0] <= {Time_10,Time_1};   // 东西时间（显示相同）
            out_LED3_NS <= 3'b010;          // 南北黄灯
            out_LED3_WE <= 3'b100;          // 东西红灯
        end 
        
        // 状态11：南北红灯，东西黄灯
        2'b11: begin
            if((Time_10==0) & (Time_1==1)) begin // 黄灯倒计时剩1秒
                Stage <= 2'b00;                  // 切换到南北绿灯状态
                Time_10 <= 4'd2; Time_1 <= 4'd0; // 重置南北时间20秒
                time_10 <= 4'd2; time_1 <= 4'd3; // 重置东西时间23秒
            end 
            else begin  // 黄灯倒计时
                if(Time_1==0) begin
                    Time_1 <= 4'd9; 
                    Time_10 <= Time_10-1; 
                end 
                else Time_1 <= Time_1-1; 
            end 
            
            data[15:8] <= {Time_10,Time_1};  // 南北时间
            data[7:0] <= {Time_10,Time_1};   // 东西时间（显示相同）
            out_LED3_NS <= 3'b100;          // 南北红灯
            out_LED3_WE <= 3'b010;          // 东西黄灯
        end
        
        // 默认状态（复位）
        default: begin
            Stage <= 2'b00; 
            Time_10 <= 4'd2; Time_1 <= 4'd0;  // 南北20秒
            time_10 <= 4'd2; time_1 <= 4'd3;   // 东西23秒
        end 
    endcase 
end
endmodule