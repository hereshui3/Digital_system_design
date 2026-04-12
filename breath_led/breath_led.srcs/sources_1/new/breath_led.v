`timescale 1ns / 1ps  // 时间单位1ns，时间精度1ps

module breath_led(
    input wire sys_clk,     // 系统时钟输入
    input wire sys_rst_n,   // 低电平有效的系统复位信号
    output wire led         // PWM输出驱动LED
);
// 内部寄存器定义
reg [15:0] period_cnt;     // 周期计数器(用于PWM频率控制)
reg [15:0] duty_cycle;     // 占空比控制寄存器(决定LED亮度)
reg inc_dec_flag;          // 增减标志位(0=递增/变亮，1=递减/变暗)

// PWM输出逻辑：当计数值小于占空比时输出高电平，否则低电平
assign led = (duty_cycle <= period_cnt) ? 0 : 1;
// PWM周期计数器逻辑 ========================================
// 产生PWM的基准频率(假设系统时钟50MHz，50000分频得到1kHz PWM频率)
always @(posedge sys_clk) begin 
    if(!sys_rst_n) 
        period_cnt <= 0;           // 复位时清零计数器
    else if(period_cnt == 16'd50000) 
        period_cnt <= 0;           // 达到周期最大值时归零
    else 
        period_cnt <= period_cnt + 1; // 正常计数递增
end
// 呼吸灯亮度控制逻辑 ======================================
always @(posedge sys_clk) begin 
    if(!sys_rst_n) begin   // 复位初始化
        duty_cycle <= 0;   // 占空比初始为0(LED最暗)
        inc_dec_flag <= 0; // 初始设置为亮度递增模式
    end 
    // 只在每个PWM周期结束时更新占空比(保证平滑变化)
    else if(period_cnt == 16'd50000) begin 
        if(inc_dec_flag == 0) begin // 亮度递增模式
            if(duty_cycle == 16'd50000)
                inc_dec_flag <= 1;  // 达到最大亮度后切换为递减模式
            else 
                duty_cycle <= duty_cycle + 10; // 逐步增加亮度(步长10)
        end 
        else begin // 亮度递减模式
            if(duty_cycle == 0) 
                inc_dec_flag <= 0;  // 达到最小亮度后切换为递增模式
            else 
                duty_cycle <= duty_cycle - 10; // 逐步减小亮度(步长10)
        end 
    end 
    else begin // 非周期结束时刻保持当前值
        duty_cycle <= duty_cycle; 
        inc_dec_flag <= inc_dec_flag; 
    end
end 

endmodule