module game_logic (
    input wire clk,           // 100MHz system clock
    input wire reset_n,       // Active low reset
    input wire confirm_btn,   // Confirm button for start/retry
    input wire jump_btn,      // Jump button (PB1)
    input wire crouch_btn,    // Crouch button
    input wire [9:0] x,       // Current VGA x
    input wire [9:0] y,       // Current VGA y
    input wire video_on,      // VGA video_on signal
    output reg [11:0] rgb,    // 12-bit color (4R, 4G, 4B)
    output [15:0] score_out   // 4-digit BCD score: {thousands, hundreds, tens, ones}
);

    // 游戏参数：决定地面、角色、速度和随机间隔的基础设定
    parameter GROUND_Y = 400;
    parameter GROUND_COLOR = 12'h0A0;
    parameter SKY_COLOR = 12'h8CF;
    parameter PLAYER_X_INIT = 100;
    parameter PLAYER_WIDTH = 30;
    parameter PLAYER_HEIGHT = 40;
    parameter CROUCH_HEIGHT = 24;
    parameter JUMP_VELOCITY = -13;
    parameter DOUBLE_JUMP_VELOCITY = -10;
    parameter BASE_OBSTACLE_SPEED = 3;
    parameter SPEED_ACCEL_FP = 12'd1; // Q4.8 acceleration quantum
    parameter SCORE_DIST_STEP = 16'd48;
    parameter OBSTACLE_GAP_MIN = 28;
    parameter OBSTACLE_GAP_MAX = 76;
    parameter OBSTACLE_GAP_RANGE = OBSTACLE_GAP_MAX - OBSTACLE_GAP_MIN + 1;
    parameter TERRAIN_GAP_MIN = 96;
    parameter TERRAIN_GAP_MAX = 148;
    parameter TERRAIN_GAP_RANGE = TERRAIN_GAP_MAX - TERRAIN_GAP_MIN + 1;

    // 运行状态：保存玩家、障碍、地形、云朵和分数等动态信息
    // 这一段变量基本覆盖了游戏运行时需要持续更新的所有对象
    reg [9:0] player_x;
    reg [9:0] player_y;
    reg signed [9:0] player_vy;
    reg crouch_active;
    reg [5:0] crouch_timer;
    reg [1:0] jump_count;

    reg signed [11:0] obstacle_x;
    reg [2:0] obstacle_type;
    reg [1:0] obstacle_variant;
    reg obstacle_active;
    reg [7:0] obstacle_wait;

    reg signed [11:0] terrain_x;
    reg [2:0] terrain_type;
    reg [1:0] terrain_variant;
    reg [1:0] terrain_plat2_level;
    reg terrain_active;
    reg [7:0] terrain_wait;

    reg signed [11:0] cloud1_x;
    reg signed [11:0] cloud2_x;
    reg [6:0] cloud1_w;
    reg [6:0] cloud2_w;
    reg [5:0] cloud1_h;
    reg [5:0] cloud2_h;

    reg [7:0] obstacle_speed;
    reg [19:0] speed_fp;      // Q12.8 speed
    reg [7:0] move_frac_acc;  // Fractional carry for smooth movement
    reg [1:0] game_state; // 0: Start, 1: Play, 2: Game Over

    reg [3:0] score_ones;
    reg [3:0] score_tens;
    reg [3:0] score_hundreds;
    reg [3:0] score_thousands;
    assign score_out = {score_thousands, score_hundreds, score_tens, score_ones};
    wire [7:0] score_ch_thousands = 8'h30 + {4'b0000, score_thousands};
    wire [7:0] score_ch_hundreds  = 8'h30 + {4'b0000, score_hundreds};
    wire [7:0] score_ch_tens      = 8'h30 + {4'b0000, score_tens};
    wire [7:0] score_ch_ones      = 8'h30 + {4'b0000, score_ones};

    // 伪随机数发生器：用于决定下一段障碍和地形的类型、间隔和变体
    reg [7:0] lfsr;
    reg [7:0] passed_counter;
    reg [20:0] frame_clk_div;
    reg [15:0] dist_accum;
    reg speed_accel_phase;

    // 每帧实际移动的像素步长：由定点速度换算得到
    reg [11:0] move_step;
    reg [8:0] frac_sum;
    wire [11:0] move_step_12 = move_step;

    // 起始界面Logo：从ROM里读出图片数据，直接按像素显示
    localparam integer LOGO_W = 128;
    localparam integer LOGO_H = 128;
    localparam integer LOGO_X = 8;
    localparam integer LOGO_Y = 8;
    localparam integer LOGO_SIZE = LOGO_W * LOGO_H;
    reg [11:0] logo_mem [0:LOGO_SIZE-1];
    integer logo_addr;
    reg [11:0] logo_rgb;

    initial begin
        $readmemh("logo_rgb444.mem", logo_mem);
    end

    // 根据是否下蹲，动态切换角色高度
    // 玩家当前高度会随下蹲状态变化
    wire [9:0] player_height = crouch_active ? CROUCH_HEIGHT : PLAYER_HEIGHT;
    wire [9:0] player_bottom = player_y + player_height;
    wire signed [11:0] player_x_s = $signed({1'b0, player_x});
    wire signed [11:0] screen_x_s = $signed({1'b0, x});
    wire signed [11:0] obstacle_width_s = $signed({2'b00, obstacle_width});
    wire signed [11:0] terrain_width_s = $signed({2'b00, terrain_width});

    // 障碍物分类：每次重生时用随机数决定类型和变体
    // 不同类型会对应不同宽高、颜色和碰撞规则
    wire obstacle_has_second =
        (obstacle_type == 3'd3) || (obstacle_type == 3'd7) ||
        ((obstacle_type[1:0] == 2'b10) && obstacle_variant[1]);
    wire obstacle_is_floating = (obstacle_type == 3'd2) || (obstacle_type == 3'd5);
    wire [9:0] obstacle_width_base =
        (obstacle_type == 3'd0) ? 10'd22 :
        (obstacle_type == 3'd1) ? 10'd18 :
        (obstacle_type == 3'd2) ? 10'd40 :
        (obstacle_type == 3'd3) ? 10'd18 :
        (obstacle_type == 3'd4) ? 10'd48 :
        (obstacle_type == 3'd5) ? 10'd32 :
        (obstacle_type == 3'd6) ? 10'd20 : 10'd28;
    wire obstacle_is_crouch_gate = (obstacle_type == 3'd2) || (obstacle_type == 3'd5);
    wire [9:0] obstacle_height_base =
        (obstacle_type == 3'd0) ? 10'd34 :
        (obstacle_type == 3'd1) ? 10'd58 :
        (obstacle_type == 3'd2) ? 10'd82 :
        (obstacle_type == 3'd3) ? 10'd30 :
        (obstacle_type == 3'd4) ? 10'd18 :
        (obstacle_type == 3'd5) ? 10'd90 :
        (obstacle_type == 3'd6) ? 10'd46 : 10'd24;
    wire [9:0] obstacle_width = obstacle_width_base + {8'd0, obstacle_variant};
    wire [9:0] obstacle_height = obstacle_height_base + {8'd0, obstacle_variant, 1'b0};
    wire terrain_is_rise = (terrain_type == 3'd0) || (terrain_type == 3'd1);
    wire terrain_is_canyon = (terrain_type == 3'd2) || (terrain_type == 3'd3);

    // 地形尺寸：不同地形对应不同长度和高度
    // 这里把“高台”“峡谷”等地形拆成不同几何形状
    wire [9:0] terrain_width =
        (terrain_type == 3'd0) ? 10'd120 :
        (terrain_type == 3'd1) ? 10'd240 :
        (terrain_type == 3'd2) ? 10'd140 :
        (terrain_type == 3'd3) ? 10'd260 : 10'd64;
    wire [9:0] terrain_height =
        (terrain_type == 3'd0) ? (10'd18 + {8'd0, terrain_variant}) :
        (terrain_type == 3'd1) ? (10'd50 + {8'd0, terrain_variant, 1'b0}) :
        10'd0;
    wire [9:0] terrain_top = GROUND_Y - terrain_height;

    // 长峡谷：分成两段平台，中间留出可跳跃的空隙
    // 这样既增加变化，也避免场景一直只有单一地面
    wire [9:0] canyon_plat_width = 10'd88 + {8'd0, terrain_variant[0], 2'b00};
    wire signed [11:0] canyon_plat_x = terrain_x + $signed(12'sd42);
    wire [9:0] canyon_plat_top = GROUND_Y - (10'd42 + {8'd0, terrain_variant[0], 1'b0});
    wire [9:0] canyon_gap_width = 10'd30 + {8'd0, terrain_variant[1], 3'b000};
    wire [9:0] canyon_plat2_width = 10'd74 + {8'd0, terrain_variant[0], 2'b00};
    wire signed [11:0] canyon_plat2_x = canyon_plat_x + $signed({2'b00, canyon_plat_width}) + $signed({2'b00, canyon_gap_width});
    wire [9:0] canyon_plat2_top =
        (terrain_plat2_level == 2'b00) ? (GROUND_Y - 10'd52) :
        (terrain_plat2_level == 2'b01) ? (GROUND_Y - 10'd60) :
        (terrain_plat2_level == 2'b10) ? (GROUND_Y - 10'd68) : (GROUND_Y - 10'd76);

    wire signed [11:0] obstacle_center_x = obstacle_x + (obstacle_width_s >>> 1);
    // 先判断障碍物和角色是否落在地形/平台上，再决定它们的实际高度
    wire obstacle_over_rise = terrain_active && terrain_is_rise &&
        (obstacle_center_x >= terrain_x) &&
        (obstacle_center_x < terrain_x + $signed({2'b00, terrain_width}));
    // Check if obstacle is on canyon platforms (floats above them)
    wire obstacle_over_canyon_plat = terrain_active && (terrain_type == 3'd3) &&
        (obstacle_center_x >= canyon_plat_x) &&
        (obstacle_center_x < canyon_plat_x + $signed({2'b00, canyon_plat_width}));
    wire obstacle_over_canyon_plat2 = terrain_active && (terrain_type == 3'd3) &&
        (obstacle_center_x >= canyon_plat2_x) &&
        (obstacle_center_x < canyon_plat2_x + $signed({2'b00, canyon_plat2_width}));
    wire obstacle_on_canyon_platform = obstacle_over_canyon_plat || obstacle_over_canyon_plat2;
    wire obstacle_crouch_combo_block = obstacle_is_crouch_gate && obstacle_on_canyon_platform;
    wire [9:0] obstacle_ground_y = 
        obstacle_crouch_combo_block ? GROUND_Y :
        obstacle_over_rise ? terrain_top :
        obstacle_over_canyon_plat2 ? canyon_plat2_top :
        obstacle_over_canyon_plat ? canyon_plat_top : GROUND_Y;

    wire [9:0] obstacle_bottom =
        (obstacle_type == 3'd2) ? (obstacle_ground_y - (10'd30 + {9'd0, obstacle_variant[0]})) :
        (obstacle_type == 3'd5) ? (obstacle_ground_y - (10'd28 + {8'd0, obstacle_variant})) :
        (obstacle_type == 3'd7) ? (obstacle_ground_y - 10'd32) :
        obstacle_ground_y;
    wire [9:0] obstacle_top = obstacle_bottom - obstacle_height;
    wire [11:0] obstacle_color =
        (obstacle_type == 3'd0) ? 12'h333 :
        (obstacle_type == 3'd1) ? 12'h840 :
        (obstacle_type == 3'd2) ? 12'h059 :
        (obstacle_type == 3'd3) ? 12'h770 :
        (obstacle_type == 3'd4) ? 12'h955 :
        (obstacle_type == 3'd5) ? 12'h0A7 :
        (obstacle_type == 3'd6) ? 12'h444 : 12'hB60;

    wire signed [11:0] obstacle2_x = obstacle_x +
        $signed({2'b00, (obstacle_type == 3'd3) ? 10'd28 : 10'd22});
    wire [9:0] obstacle2_width =
        (obstacle_type == 3'd3) ? (10'd16 + {8'd0, obstacle_variant}) : (10'd14 + {8'd0, obstacle_variant[1], obstacle_variant[0]});
    wire [9:0] obstacle2_height =
        (obstacle_type == 3'd3) ? (10'd22 + {8'd0, obstacle_variant}) : (10'd18 + {8'd0, obstacle_variant, 1'b0});
    wire [9:0] obstacle2_bottom =
        (obstacle_type == 3'd3) ? GROUND_Y : (GROUND_Y - 10'd84);
    wire [9:0] obstacle2_top = obstacle2_bottom - obstacle2_height;
    wire signed [11:0] obstacle2_width_s = $signed({2'b00, obstacle2_width});

    wire [9:0] obstacle_active_top = obstacle_top;
    wire [9:0] obstacle_active_bottom = obstacle_bottom;
    wire signed [11:0] player_center_x_s = player_x_s + 12'sd15;
    wire signed [11:0] player_foot_l_s = player_x_s + 12'sd10;
    wire signed [11:0] player_foot_r_s = player_x_s + 12'sd20;

    // 角色是否正在经过地形区域
    wire player_over_terrain = terrain_active &&
        (player_x_s + $signed({2'b00, PLAYER_WIDTH}) > terrain_x) &&
        (player_x_s < terrain_x + terrain_width_s);
    wire player_over_canyon_platform = terrain_active && (terrain_type == 3'd3) &&
        (player_x_s + $signed({2'b00, PLAYER_WIDTH}) > canyon_plat_x) &&
        (player_x_s < canyon_plat_x + $signed({2'b00, canyon_plat_width}));
    wire player_over_canyon_platform2 = terrain_active && (terrain_type == 3'd3) &&
        (player_x_s + $signed({2'b00, PLAYER_WIDTH}) > canyon_plat2_x) &&
        (player_x_s < canyon_plat2_x + $signed({2'b00, canyon_plat2_width}));
    wire player_center_over_terrain = terrain_active &&
        (player_center_x_s >= terrain_x) &&
        (player_center_x_s < terrain_x + terrain_width_s);
    wire player_center_over_canyon_platform = terrain_active && (terrain_type == 3'd3) &&
        (player_center_x_s >= canyon_plat_x) &&
        (player_center_x_s < canyon_plat_x + $signed({2'b00, canyon_plat_width}));
    wire player_center_over_canyon_platform2 = terrain_active && (terrain_type == 3'd3) &&
        (player_center_x_s >= canyon_plat2_x) &&
        (player_center_x_s < canyon_plat2_x + $signed({2'b00, canyon_plat2_width}));
    wire player_feet_touch_ground_outside_canyon = terrain_active && terrain_is_canyon &&
        ((player_foot_l_s < terrain_x) || (player_foot_r_s >= terrain_x + terrain_width_s));
    wire player_feet_over_rise = terrain_active && terrain_is_rise &&
        (player_foot_l_s >= terrain_x) &&
        (player_foot_r_s < terrain_x + terrain_width_s);
    // 角色是否真正站在高台顶面上
    wire player_support_rise = player_feet_over_rise &&
        (player_vy >= 0) &&
        (player_bottom >= terrain_top - 10'd2) &&
        (player_bottom <= terrain_top + 10'd36);
    wire player_on_terrain_top =
        player_support_rise;
    wire player_on_canyon_platform =
        player_over_canyon_platform &&
        (player_bottom >= canyon_plat_top - 10'd1) &&
        (player_bottom <= canyon_plat_top + 10'd6) &&
        (player_vy >= 0);
    wire player_on_canyon_platform2 =
        player_over_canyon_platform2 &&
        (player_bottom >= canyon_plat2_top - 10'd1) &&
        (player_bottom <= canyon_plat2_top + 10'd6) &&
        (player_vy >= 0);
    wire signed [11:0] player_bottom_s = $signed({1'b0, player_bottom});
    wire signed [11:0] terrain_top_s = $signed({2'b00, terrain_top});
    wire signed [11:0] predicted_bottom_s = player_bottom_s + player_vy;
    wire land_on_terrain_cross =
        player_over_terrain && terrain_is_rise &&
        (player_vy >= 0) &&
        (player_bottom_s <= terrain_top_s) &&
        (predicted_bottom_s >= terrain_top_s);
    wire signed [11:0] canyon_plat_top_s = $signed({2'b00, canyon_plat_top});
    wire land_on_canyon_plat_cross =
        player_over_canyon_platform &&
        (player_vy >= 0) &&
        (player_bottom_s <= canyon_plat_top_s) &&
        (predicted_bottom_s >= canyon_plat_top_s);
    wire signed [11:0] canyon_plat2_top_s = $signed({2'b00, canyon_plat2_top});
    wire land_on_canyon_plat2_cross =
        player_over_canyon_platform2 &&
        (player_vy >= 0) &&
        (player_bottom_s <= canyon_plat2_top_s) &&
        (predicted_bottom_s >= canyon_plat2_top_s);

    // Add grace zone for terrain edge: keep player at terrain_top if close, prevents sinking
    wire player_near_terrain_edge = player_over_terrain && terrain_is_rise &&
        (player_y < terrain_top - player_height + 10'd3) &&
        (player_y > terrain_top - player_height - 10'd3);
    
    wire player_in_canyon_void = terrain_active && terrain_is_canyon && player_over_terrain &&
        !player_feet_touch_ground_outside_canyon &&
        !player_on_canyon_platform && !player_on_canyon_platform2;
    wire floor_exists = !player_in_canyon_void;
    wire [9:0] floor_y =
        player_on_canyon_platform2 ? canyon_plat2_top :
        player_on_canyon_platform ? canyon_plat_top :
        (player_near_terrain_edge ? terrain_top :
        (player_support_rise ? terrain_top : GROUND_Y));
    // 吸附窗口：当角色接近地面/平台时，把它轻微“吸”到正确高度，减少穿透
    wire floor_snap_window = floor_exists && (player_vy >= 0) &&
        (player_bottom >= floor_y) && (player_bottom <= floor_y + 10'd28);

    wire obstacle_hit_primary =
        (player_x_s + $signed({2'b00, PLAYER_WIDTH}) > obstacle_x) &&
        (player_x_s < obstacle_x + obstacle_width_s) &&
        (player_y < obstacle_active_bottom) &&
        (player_bottom > obstacle_active_top);
    wire obstacle_hit_secondary = obstacle_has_second &&
        (player_x_s + $signed({2'b00, PLAYER_WIDTH}) > obstacle2_x) &&
        (player_x_s < obstacle2_x + obstacle2_width_s) &&
        (player_y < obstacle2_bottom) &&
        (player_bottom > obstacle2_top);

    wire terrain_side_stuck =
        player_over_terrain &&
        terrain_is_rise &&
        !player_on_terrain_top &&
        (player_bottom > terrain_top + 10'd6);

    wire [9:0] next_obstacle_gap = OBSTACLE_GAP_MIN + ({2'b00, lfsr} % OBSTACLE_GAP_RANGE);
    wire [9:0] next_terrain_gap = TERRAIN_GAP_MIN + ({2'b00, lfsr} % TERRAIN_GAP_RANGE);

    wire [2:0] next_obstacle_type = lfsr[2:0];
    wire [1:0] next_obstacle_variant = {lfsr[6] ^ lfsr[1], lfsr[5] ^ lfsr[0]};
    wire [2:0] next_terrain_kind = {1'b0, lfsr[4:3]};
    wire [1:0] next_terrain_variant = {lfsr[7] ^ lfsr[2], lfsr[6] ^ lfsr[0]};

    // BCD加法：用于把分数按十进制逐位递增
    function [3:0] bcd_inc_digit;
        input [3:0] value;
        begin
            bcd_inc_digit = (value == 4'd9) ? 4'd0 : (value + 1'b1);
        end
    endfunction

    // 四位BCD分数加1，进位规则和十进制数字一致
    function [15:0] bcd_increment;
        input [15:0] value;
        reg [3:0] ones;
        reg [3:0] tens;
        reg [3:0] hundreds;
        reg [3:0] thousands;
        begin
            ones = value[3:0];
            tens = value[7:4];
            hundreds = value[11:8];
            thousands = value[15:12];
            if (ones != 4'd9) begin
                ones = ones + 1'b1;
            end else begin
                ones = 4'd0;
                if (tens != 4'd9) begin
                    tens = tens + 1'b1;
                end else begin
                    tens = 4'd0;
                    if (hundreds != 4'd9) begin
                        hundreds = hundreds + 1'b1;
                    end else begin
                        hundreds = 4'd0;
                        if (thousands != 4'd9)
                            thousands = thousands + 1'b1;
                        else
                            thousands = 4'd0;
                    end
                end
            end
            bcd_increment = {thousands, hundreds, tens, ones};
        end
    endfunction

    // 5x7点阵字库：用于在画面上显示英文和数字
    function [34:0] font5x7;
        input [7:0] ch;
        begin
            case (ch)
                8'h20: font5x7 = 35'b00000_00000_00000_00000_00000_00000_00000; // space
                8'h30: font5x7 = 35'b01110_10001_10011_10101_11001_10001_01110; // 0
                8'h31: font5x7 = 35'b00100_01100_00100_00100_00100_00100_01110; // 1
                8'h32: font5x7 = 35'b01110_10001_00001_00010_00100_01000_11111; // 2
                8'h33: font5x7 = 35'b11110_00001_00001_01110_00001_00001_11110; // 3
                8'h34: font5x7 = 35'b00010_00110_01010_10010_11111_00010_00010; // 4
                8'h35: font5x7 = 35'b11111_10000_10000_11110_00001_00001_11110; // 5
                8'h36: font5x7 = 35'b01110_10000_10000_11110_10001_10001_01110; // 6
                8'h37: font5x7 = 35'b11111_00001_00010_00100_01000_01000_01000; // 7
                8'h38: font5x7 = 35'b01110_10001_10001_01110_10001_10001_01110; // 8
                8'h39: font5x7 = 35'b01110_10001_10001_01111_00001_00001_01110; // 9
                8'h41: font5x7 = 35'b01110_10001_10001_11111_10001_10001_10001; // A
                8'h43: font5x7 = 35'b01110_10001_10000_10000_10000_10001_01110; // C
                8'h45: font5x7 = 35'b11111_10000_10000_11110_10000_10000_11111; // E
                8'h47: font5x7 = 35'b01110_10001_10000_10111_10001_10001_01110; // G
                8'h4B: font5x7 = 35'b10001_10010_10100_11000_10100_10010_10001; // K
                8'h4E: font5x7 = 35'b10001_11001_10101_10011_10001_10001_10001; // N
                8'h4F: font5x7 = 35'b01110_10001_10001_10001_10001_10001_01110; // O
                8'h50: font5x7 = 35'b11110_10001_10001_11110_10000_10000_10000; // P
                8'h52: font5x7 = 35'b11110_10001_10001_11110_10100_10010_10001; // R
                8'h53: font5x7 = 35'b01111_10000_10000_01110_00001_00001_11110; // S
                8'h54: font5x7 = 35'b11111_00100_00100_00100_00100_00100_00100; // T
                8'h55: font5x7 = 35'b10001_10001_10001_10001_10001_10001_01110; // U
                8'h59: font5x7 = 35'b10001_10001_01010_00100_00100_00100_00100; // Y
                default: font5x7 = 35'b00000_00000_00000_00000_00000_00000_00000;
            endcase
        end
    endfunction

    // 从点阵字库中取出某一个像素点是否点亮
    function glyph_bit;
        input [34:0] bitmap;
        input [2:0] row;
        input [2:0] col;
        integer idx;
        begin
            if (row < 3'd7 && col < 3'd5) begin
                idx = 34 - (row * 5 + col);
                glyph_bit = bitmap[idx];
            end else begin
                glyph_bit = 1'b0;
            end
        end
    endfunction

    // 字符放大2倍后的像素判断函数
    function char_px_2x;
        input [9:0] px;
        input [9:0] py;
        input [9:0] ox;
        input [9:0] oy;
        input [7:0] ch;
        reg [34:0] bmp;
        reg [9:0] dx;
        reg [9:0] dy;
        begin
            if (px >= ox && px < (ox + 10'd10) && py >= oy && py < (oy + 10'd14)) begin
                dx = px - ox;
                dy = py - oy;
                bmp = font5x7(ch);
                char_px_2x = glyph_bit(bmp, dy[9:1], dx[9:1]);
            end else begin
                char_px_2x = 1'b0;
            end
        end
    endfunction

    // 主时序更新：处理按键、物理、速度、分数和场景移动
    // 这一块相当于游戏“每一拍”的核心控制逻辑
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            frame_clk_div <= 0;
            player_x <= PLAYER_X_INIT;
            player_y <= GROUND_Y - PLAYER_HEIGHT;
            player_vy <= 0;
            crouch_active <= 0;
            crouch_timer <= 0;
            jump_count <= 0;
            obstacle_x <= 12'sd640;
            obstacle_type <= 0;
            obstacle_variant <= 0;
            obstacle_active <= 0;
            obstacle_wait <= 0;
            terrain_x <= 12'sd900;
            terrain_type <= 0;
            terrain_variant <= 0;
            terrain_plat2_level <= 2'b00;
            terrain_active <= 1'b1;
            terrain_wait <= 8'd0;
            cloud1_x <= 12'sd140;
            cloud2_x <= 12'sd430;
            cloud1_w <= 7'd44;
            cloud2_w <= 7'd56;
            cloud1_h <= 6'd14;
            cloud2_h <= 6'd18;
            obstacle_speed <= BASE_OBSTACLE_SPEED;
            speed_fp <= {{9{1'b0}}, BASE_OBSTACLE_SPEED, 8'h00};
            move_frac_acc <= 8'd0;
            game_state <= 0;
            score_ones <= 0;
            score_tens <= 0;
            score_hundreds <= 0;
            score_thousands <= 0;
            lfsr <= 8'hA5;
            passed_counter <= 0;
            speed_accel_phase <= 1'b0;
            dist_accum <= 16'd0;
        end else begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};

            // 1. 按键处理：开始/重开，或在游戏中执行跳跃和下蹲
            // 游戏未开始时按确认键进入游戏，进行中则响应动作键
            if (game_state != 1) begin
                if (confirm_btn) begin
                    game_state <= 1;
                    player_x <= PLAYER_X_INIT;
                    player_y <= GROUND_Y - PLAYER_HEIGHT;
                    player_vy <= 0;
                    crouch_active <= 0;
                    crouch_timer <= 0;
                    jump_count <= 0;
                    obstacle_x <= 12'sd640;
                    obstacle_type <= next_obstacle_type;
                    obstacle_variant <= next_obstacle_variant;
                    obstacle_active <= 1;
                    obstacle_wait <= 0;
                    terrain_x <= 12'sd900;
                    terrain_type <= next_terrain_kind;
                    terrain_variant <= next_terrain_variant;
                    terrain_plat2_level <= {lfsr[1] ^ lfsr[7], lfsr[2] ^ lfsr[5]};
                    terrain_active <= 1'b1;
                    terrain_wait <= 8'd0;
                    obstacle_speed <= BASE_OBSTACLE_SPEED;
                    speed_fp <= {{9{1'b0}}, BASE_OBSTACLE_SPEED, 8'h00};
                    move_frac_acc <= 8'd0;
                    score_ones <= 0;
                    score_tens <= 0;
                    score_hundreds <= 0;
                    score_thousands <= 0;
                    passed_counter <= 0;
                    dist_accum <= 16'd0;
                end
            end else begin
                // Jump always cancels crouch and can interrupt it
                if (jump_btn && (jump_count < 2)) begin
                    crouch_active <= 0;
                    crouch_timer <= 0;
                    if (jump_count == 0)
                        player_vy <= JUMP_VELOCITY;
                    else
                        player_vy <= DOUBLE_JUMP_VELOCITY;
                    jump_count <= jump_count + 1'b1;
                    player_y <= player_y;
                end else if (crouch_btn && !crouch_active && (player_y >= floor_y - PLAYER_HEIGHT)) begin
                    crouch_active <= 1;
                    crouch_timer <= 6'd42;
                    player_y <= floor_y - CROUCH_HEIGHT;
                    player_vy <= 0;
                    jump_count <= 0;
                end
            end
            
            // 2. 约60Hz的物理刷新：让画面移动和碰撞判断更稳定
            // 这里不是每个100MHz时钟都更新，而是按帧节拍统一推进
            if (frame_clk_div < 21'd1_666_666)
                frame_clk_div <= frame_clk_div + 1;
            else begin
                frame_clk_div <= 0;
                
                if (game_state == 1) begin
                    // 用定点数计算平滑位移，避免速度只能取整数导致发飘
                    // 这一做法可以让加速过程更平滑
                    frac_sum = {1'b0, move_frac_acc} + {1'b0, speed_fp[7:0]};
                    move_step = speed_fp[19:8] + frac_sum[8];
                    move_frac_acc <= frac_sum[7:0];

                    // 速度缓慢递增：每隔一帧加一点，让游戏越来越快
                    // 这样难度会随着时间自然上升
                    speed_accel_phase <= ~speed_accel_phase;
                    if (speed_accel_phase) begin
                        speed_fp <= speed_fp + SPEED_ACCEL_FP;
                    end
                    obstacle_speed <= speed_fp[15:8];

                    // 按前进距离计分：走过一定像素就把BCD分数加1
                    // 不是按时间，而是按实际跑动距离计分
                    if (dist_accum + {4'd0, move_step_12} >= SCORE_DIST_STEP) begin
                        dist_accum <= dist_accum + {4'd0, move_step_12} - SCORE_DIST_STEP;
                        {score_thousands, score_hundreds, score_tens, score_ones} <=
                            bcd_increment({score_thousands, score_hundreds, score_tens, score_ones});
                    end else begin
                        dist_accum <= dist_accum + {4'd0, move_step_12};
                    end

                    // 重力与竖直运动：角色下落、起跳、落地都在这里处理
                    // 这部分决定角色看起来是不是“踩在地上”
                    if (!floor_exists || player_vy < 0 || player_bottom < floor_y || player_bottom > floor_y + 10'd28) begin
                        player_vy <= player_vy + 1'b1;
                        player_y <= player_y + player_vy;
                    end else begin
                        player_y <= floor_y - player_height;
                        if (player_vy > 0)
                            player_vy <= 0;
                    end

                    if (crouch_active) begin
                        if (crouch_timer > 0)
                            crouch_timer <= crouch_timer - 1'b1;
                        else
                            crouch_active <= 0;

                        if (player_vy == 0 && player_y >= floor_y - CROUCH_HEIGHT)
                            player_y <= floor_y - CROUCH_HEIGHT;
                    end

                    if (player_y >= floor_y - player_height && player_vy == 0 && !crouch_active)
                        jump_count <= 0;

                    if (floor_snap_window)
                        player_y <= floor_y - player_height;

                    // 平台落地保护：避免高速下落或二段跳时穿透地形
                    // 先预测下一拍的位置，再判断是否跨过平台顶面
                    if (land_on_terrain_cross) begin
                        player_y <= terrain_top - player_height;
                        player_vy <= 0;
                        jump_count <= 0;
                    end
                    if (land_on_canyon_plat2_cross) begin
                        player_y <= canyon_plat2_top - player_height;
                        player_vy <= 0;
                        jump_count <= 0;
                    end
                    if (land_on_canyon_plat_cross) begin
                        player_y <= canyon_plat_top - player_height;
                        player_vy <= 0;
                        jump_count <= 0;
                    end

                    // 掉出屏幕底部就判定失败
                    // 相当于“坠落死亡”的判定
                    if (player_y > 10'd479)
                        game_state <= 2;

                    // 地形卡住时把角色往左边挤，避免停在异常位置
                    // 这是一个容错处理，防止角色夹在地形边缘
                    if (terrain_side_stuck && (player_x > 0)) begin
                        if (player_x > move_step_12[9:0])
                            player_x <= player_x - move_step_12[9:0];
                        else
                            game_state <= 2;
                    end

                    if (player_x <= 2)
                        game_state <= 2;

                    // 障碍物移动：离屏后先等待，再在右侧重新生成，减少闪烁
                    // 这样障碍物不会在边界上突然跳出来
                    if (obstacle_active) begin
                        // 一直移动到障碍物完全离开左边界
                        if ((obstacle_x + obstacle_width_s) > -12'sd2) begin
                            obstacle_x <= obstacle_x - $signed(move_step_12);
                        end else begin
                            obstacle_active <= 0;
                            obstacle_wait <= next_obstacle_gap[7:0];
                            passed_counter <= passed_counter + 1'b1;
                        end
                    end else if (obstacle_wait > 0) begin
                        obstacle_wait <= obstacle_wait - 1'b1;
                    end else begin
                        obstacle_active <= 1;
                        obstacle_x <= 12'sd704; // spawn farther offscreen to avoid pop-near effect
                        obstacle_type <= next_obstacle_type;
                        obstacle_variant <= next_obstacle_variant;
                    end

                    // 地形移动和重生：同样先等待，避免突然弹出
                    // 让场景过渡更自然
                    if (terrain_active) begin
                        if ((terrain_x + terrain_width_s) > -12'sd2)
                            terrain_x <= terrain_x - $signed(move_step_12);
                        else begin
                            terrain_active <= 1'b0;
                            terrain_wait <= next_terrain_gap[7:0];
                        end
                    end else if (terrain_wait > 0) begin
                        terrain_wait <= terrain_wait - 1'b1;
                    end else begin
                        terrain_active <= 1'b1;
                        terrain_x <= 12'sd768;
                        terrain_type <= next_terrain_kind;
                        terrain_variant <= next_terrain_variant;
                        terrain_plat2_level <= {lfsr[0] ^ lfsr[6], lfsr[3] ^ lfsr[5]};
                    end

                    // 背景视差：这里只画云朵，让背景更有层次
                    // 云朵速度比前景慢，看起来会有远近感
                    if (cloud1_x + $signed({5'b00000, cloud1_w}) > -12'sd2)
                        cloud1_x <= cloud1_x - $signed({1'b0, move_step_12[11:1]});
                    else begin
                        cloud1_x <= 12'sd700 + $signed({4'b0000, lfsr[5:0]});
                        cloud1_w <= 7'd36 + {2'b00, lfsr[4:0]};
                        cloud1_h <= 6'd10 + {2'b00, lfsr[3:0]};
                    end

                    if (cloud2_x + $signed({5'b00000, cloud2_w}) > -12'sd2)
                        cloud2_x <= cloud2_x - $signed({1'b0, move_step_12[11:1]});
                    else begin
                        cloud2_x <= 12'sd760 + $signed({4'b0000, lfsr[6:1]});
                        cloud2_w <= 7'd40 + {2'b00, lfsr[4:0]};
                        cloud2_h <= 6'd12 + {2'b00, lfsr[3:0]};
                    end

                    // 碰撞检测：角色碰到障碍物就结束游戏
                    // 主要检查角色矩形和障碍矩形是否重叠
                    if (obstacle_active && (obstacle_hit_primary || obstacle_hit_secondary)) begin
                        game_state <= 2;
                    end
                end
            end
        end
    end

    // 像素渲染：根据当前坐标决定这一点应该显示什么颜色
    // 这是“逐像素上色”的部分，VGA屏幕上的每个点都在这里判断
    always @(*) begin
        if (!video_on)
            rgb = 12'h000;
        else begin
            logo_rgb = 12'h000;
            if (x >= LOGO_X && x < (LOGO_X + LOGO_W) && y >= LOGO_Y && y < (LOGO_Y + LOGO_H)) begin
                logo_addr = (y - LOGO_Y) * LOGO_W + (x - LOGO_X);
                logo_rgb = logo_mem[logo_addr];
            end

            // 默认背景：天空
            // 后面的地面、角色、障碍会在这个基础上覆盖颜色
            rgb = SKY_COLOR;

            // 地面
            // y坐标达到地平线以下时，画成地面色
            if (y >= GROUND_Y)
                rgb = GROUND_COLOR;

            // 地形：高台或坡面，和障碍物分开绘制
            // 这里先把可走区域画出来，再叠加障碍物
            if (terrain_active && terrain_is_rise &&
                screen_x_s >= terrain_x && screen_x_s < terrain_x + terrain_width_s &&
                y >= terrain_top && y < GROUND_Y)
                rgb = GROUND_COLOR;

            // 地形顶边高亮，方便看清轮廓
            // 只是一个细线效果，不影响碰撞逻辑
            if (terrain_active && terrain_is_rise &&
                screen_x_s >= terrain_x && screen_x_s < terrain_x + terrain_width_s && y == terrain_top)
                rgb = GROUND_COLOR;

            // 峡谷内部直接填成天空色，看起来更像一个空洞
            // 让长峡谷有“断开”的感觉
            if (terrain_active && terrain_is_canyon &&
                screen_x_s >= terrain_x && screen_x_s < terrain_x + terrain_width_s &&
                y >= GROUND_Y)
                rgb = SKY_COLOR;

            // 长峡谷的两段平台
            // 玩家需要跳过中间空隙
            if (terrain_active && terrain_type == 3'd3 &&
                screen_x_s >= canyon_plat_x && screen_x_s < canyon_plat_x + $signed({2'b00, canyon_plat_width}) &&
                y >= canyon_plat_top && y < canyon_plat_top + 10'd10)
                rgb = GROUND_COLOR;
            if (terrain_active && terrain_type == 3'd3 &&
                screen_x_s >= canyon_plat2_x && screen_x_s < canyon_plat2_x + $signed({2'b00, canyon_plat2_width}) &&
                y >= canyon_plat2_top && y < canyon_plat2_top + 10'd10)
                rgb = GROUND_COLOR;

            // 背景云朵：不同速度移动，形成视差效果
            // 这是纯视觉层，不参与碰撞
            if (screen_x_s >= cloud1_x && screen_x_s < cloud1_x + $signed({5'b00000, cloud1_w}) &&
                y >= 10'd72 && y < 10'd72 + cloud1_h)
                rgb = 12'hDFF;
            if (screen_x_s >= (cloud1_x - 12'sd10) && screen_x_s < (cloud1_x - 12'sd10) + $signed({6'b000000, cloud1_w[6:1]}) &&
                y >= 10'd78 && y < 10'd78 + cloud1_h)
                rgb = 12'hEFF;

            if (screen_x_s >= cloud2_x && screen_x_s < cloud2_x + $signed({5'b00000, cloud2_w}) &&
                y >= 10'd106 && y < 10'd106 + cloud2_h)
                rgb = 12'hDFF;
            if (screen_x_s >= (cloud2_x + 12'sd12) && screen_x_s < (cloud2_x + 12'sd12) + $signed({6'b000000, cloud2_w[6:1]}) &&
                y >= 10'd98 && y < 10'd98 + cloud2_h)
                rgb = 12'hEFF;

            // 玩家由头、身体和腿组成，不再只是一个方块
            // 这样人物轮廓更像一个跑者
            if (x >= player_x + 8 && x < player_x + 22 &&
                y >= player_y && y < player_y + 12)
                rgb = 12'hFDB;
            if (x >= player_x + 5 && x < player_x + 25 &&
                y >= player_y + 12 && y < player_y + 30)
                rgb = crouch_active ? 12'h07A : 12'h04E;
            if (x >= player_x + 6 && x < player_x + 12 &&
                y >= player_y + 30 && y < player_y + 40)
                rgb = 12'h222;
            if (x >= player_x + 18 && x < player_x + 24 &&
                y >= player_y + 30 && y < player_y + 40)
                rgb = 12'h222;
            if (x >= player_x + 10 && x < player_x + 20 && y == player_y + 5)
                rgb = 12'h000;

            // 轮廓补色：保证角色在天空背景上更清楚
            // 先画局部，再用轮廓统一一下视觉效果
            if (x >= player_x && x < player_x + PLAYER_WIDTH &&
                y >= player_y && y < player_y + player_height && rgb == SKY_COLOR)
                rgb = crouch_active ? 12'h18C : 12'h29F;

            // 下蹲时的额外细节
            // 让下蹲状态和站立状态看起来有区别
            if (crouch_active &&
                x >= player_x + 4 && x < player_x + 26 &&
                y >= player_y + 18 && y < player_y + 24)
                rgb = 12'h026;

            // 障碍物主体：根据类型画不同形状
            // 不同障碍类型对应不同的通关方式
            if (obstacle_active &&
                screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                y >= obstacle_top && y < obstacle_bottom)
                rgb = obstacle_color;

            // 仙人掌类障碍的侧枝
            // 只是视觉装饰，不影响碰撞矩形
            if (obstacle_active && obstacle_type == 3'd0 &&
                screen_x_s >= obstacle_x - 12'sd5 && screen_x_s < obstacle_x &&
                y >= obstacle_top + 10'd12 && y < obstacle_top + 10'd20)
                rgb = 12'h272;
            if (obstacle_active && obstacle_type == 3'd0 &&
                screen_x_s >= obstacle_x + obstacle_width_s && screen_x_s < obstacle_x + obstacle_width_s + 12'sd5 &&
                y >= obstacle_top + 10'd15 && y < obstacle_top + 10'd23)
                rgb = 12'h272;

            // 带副结构的障碍物
            // 让障碍看起来更复杂一些
            if (obstacle_active && obstacle_has_second &&
                screen_x_s >= obstacle2_x && screen_x_s < obstacle2_x + obstacle2_width_s &&
                y >= obstacle2_top && y < obstacle2_bottom)
                rgb = 12'hBBB;

            // 高障碍的中间装饰条
            // 用于区分不同障碍的外观
            if (obstacle_active && obstacle_type == 3'd1 &&
                screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                y >= obstacle_top + 10'd8 && y < obstacle_top + 10'd11)
                rgb = 12'hB50;

            // 仙人掌的竖向纹理
            // 进一步丰富障碍物外观
            if (obstacle_active && obstacle_type == 3'd0 &&
                screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                y >= obstacle_top && y < obstacle_bottom &&
                ((screen_x_s == obstacle_x + 12'sd4) || (screen_x_s == obstacle_x + 12'sd9)))
                rgb = 12'h262;

            // 第4类障碍的横向框线
            // 增加一点机械风格的感觉
            if (obstacle_active && obstacle_type == 3'd4 &&
                screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                y >= obstacle_top && y < obstacle_bottom &&
                ((y == obstacle_top + 10'd4) || (y == obstacle_top + 10'd9)))
                rgb = 12'hB88;

            // 第6类障碍的中缝
            // 只是装饰线条，不影响玩法
            if (obstacle_active && obstacle_type == 3'd6 &&
                screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                y >= obstacle_top && y < obstacle_bottom &&
                screen_x_s >= obstacle_x + (obstacle_width_s >>> 1) - 12'sd1 &&
                screen_x_s < obstacle_x + (obstacle_width_s >>> 1) + 12'sd1)
                rgb = 12'h666;

            // 需要下蹲通过的障碍，添加警示条
            // 看到这个样式就知道要蹲下
            if (obstacle_active && (obstacle_type == 3'd2 || obstacle_type == 3'd5) &&
                screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                y >= obstacle_top && y < obstacle_bottom &&
                ((y == obstacle_top + 10'd6) || (y == obstacle_top + 10'd12)))
                rgb = 12'h0DF;

            // 需要下蹲通过的障碍，添加通风槽细节
            // 让“门型”障碍更明显
            if (obstacle_active && (obstacle_type == 3'd2 || obstacle_type == 3'd5) &&
                screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                y >= obstacle_top + 10'd8 && y < obstacle_bottom - 10'd2 &&
                ((screen_x_s == obstacle_x + 12'sd5) || (screen_x_s == obstacle_x + 12'sd11)))
                rgb = 12'h045;

            // 第7类障碍的顶部尖刺
            // 提示玩家不要直接撞上去
            if (obstacle_active && obstacle_type == 3'd7 &&
                screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                y >= obstacle_top && y < obstacle_top + 10'd6)
                rgb = 12'hFD2;

            // 浮空障碍的上下边框
            // 主要是做出轮廓，方便辨认
            if (obstacle_type == 3'd2 || obstacle_type == 3'd5)
                if (obstacle_active &&
                    screen_x_s >= obstacle_x && screen_x_s < obstacle_x + obstacle_width_s &&
                    (y == obstacle_top || y == obstacle_bottom - 1))
                    rgb = 12'hFFF;

            // 地面下方的速度条，反映当前难度
            // 速度越高，条越长
            if (y == (GROUND_Y + 14) && x < (obstacle_speed * 44))
                rgb = 12'hFF0;

            // 右上角HUD：任何状态都显示分数
            // HUD就是固定在画面上的提示信息
            if (
                char_px_2x(x, y, 10'd516, 10'd14, 8'h53) || // S
                char_px_2x(x, y, 10'd528, 10'd14, 8'h43) || // C
                char_px_2x(x, y, 10'd540, 10'd14, 8'h4F) || // O
                char_px_2x(x, y, 10'd552, 10'd14, 8'h52) || // R
                char_px_2x(x, y, 10'd564, 10'd14, 8'h45) || // E
                char_px_2x(x, y, 10'd582, 10'd14, score_ch_thousands) ||
                char_px_2x(x, y, 10'd594, 10'd14, score_ch_hundreds) ||
                char_px_2x(x, y, 10'd606, 10'd14, score_ch_tens) ||
                char_px_2x(x, y, 10'd618, 10'd14, score_ch_ones)
            ) begin
                rgb = 12'h111;
            end

            // 开始界面
            // 显示Logo、标题和开始提示
            if (game_state == 0) begin
                if (x >= LOGO_X && x < (LOGO_X + LOGO_W) && y >= LOGO_Y && y < (LOGO_Y + LOGO_H))
                    rgb = logo_rgb;

                if (x >= 10'd110 && x < 10'd530 && y >= 10'd120 && y < 10'd300)
                    rgb = 12'hCEF;

                if (
                    char_px_2x(x, y, 10'd250, 10'd150, 8'h53) || // SUPER
                    char_px_2x(x, y, 10'd262, 10'd150, 8'h55) ||
                    char_px_2x(x, y, 10'd274, 10'd150, 8'h50) ||
                    char_px_2x(x, y, 10'd286, 10'd150, 8'h45) ||
                    char_px_2x(x, y, 10'd298, 10'd150, 8'h52) ||
                    char_px_2x(x, y, 10'd310, 10'd150, 8'h20) ||
                    char_px_2x(x, y, 10'd322, 10'd150, 8'h52) || // RUNNER
                    char_px_2x(x, y, 10'd334, 10'd150, 8'h55) ||
                    char_px_2x(x, y, 10'd346, 10'd150, 8'h4E) ||
                    char_px_2x(x, y, 10'd358, 10'd150, 8'h4E) ||
                    char_px_2x(x, y, 10'd370, 10'd150, 8'h45) ||
                    char_px_2x(x, y, 10'd382, 10'd150, 8'h52)
                )
                    rgb = 12'h013;

                if (
                    char_px_2x(x, y, 10'd220, 10'd210, 8'h50) || // PRESS OK TO START
                    char_px_2x(x, y, 10'd232, 10'd210, 8'h52) ||
                    char_px_2x(x, y, 10'd244, 10'd210, 8'h45) ||
                    char_px_2x(x, y, 10'd256, 10'd210, 8'h53) ||
                    char_px_2x(x, y, 10'd268, 10'd210, 8'h53) ||
                    char_px_2x(x, y, 10'd280, 10'd210, 8'h20) ||
                    char_px_2x(x, y, 10'd292, 10'd210, 8'h4F) ||
                    char_px_2x(x, y, 10'd304, 10'd210, 8'h4B) ||
                    char_px_2x(x, y, 10'd316, 10'd210, 8'h20) ||
                    char_px_2x(x, y, 10'd328, 10'd210, 8'h54) ||
                    char_px_2x(x, y, 10'd340, 10'd210, 8'h4F) ||
                    char_px_2x(x, y, 10'd352, 10'd210, 8'h20) ||
                    char_px_2x(x, y, 10'd364, 10'd210, 8'h53) ||
                    char_px_2x(x, y, 10'd376, 10'd210, 8'h54) ||
                    char_px_2x(x, y, 10'd388, 10'd210, 8'h41) ||
                    char_px_2x(x, y, 10'd400, 10'd210, 8'h52) ||
                    char_px_2x(x, y, 10'd412, 10'd210, 8'h54)
                )
                    rgb = 12'h222;
            end

            // 结束界面
            // 显示最终分数和重试提示
            if (game_state == 2) begin
                if (x >= 10'd90 && x < 10'd550 && y >= 10'd140 && y < 10'd320)
                    rgb = 12'hFDD;

                if (
                    char_px_2x(x, y, 10'd261, 10'd180, 8'h59) || // YOUR SCORE
                    char_px_2x(x, y, 10'd273, 10'd180, 8'h4F) ||
                    char_px_2x(x, y, 10'd285, 10'd180, 8'h55) ||
                    char_px_2x(x, y, 10'd297, 10'd180, 8'h52) ||
                    char_px_2x(x, y, 10'd309, 10'd180, 8'h20) ||
                    char_px_2x(x, y, 10'd321, 10'd180, 8'h53) ||
                    char_px_2x(x, y, 10'd333, 10'd180, 8'h43) ||
                    char_px_2x(x, y, 10'd345, 10'd180, 8'h4F) ||
                    char_px_2x(x, y, 10'd357, 10'd180, 8'h52) ||
                    char_px_2x(x, y, 10'd369, 10'd180, 8'h45)
                )
                    rgb = 12'h600;

                if (
                    char_px_2x(x, y, 10'd297, 10'd214, score_ch_thousands) ||
                    char_px_2x(x, y, 10'd309, 10'd214, score_ch_hundreds) ||
                    char_px_2x(x, y, 10'd321, 10'd214, score_ch_tens) ||
                    char_px_2x(x, y, 10'd333, 10'd214, score_ch_ones)
                )
                    rgb = 12'hD20;

                if (
                    char_px_2x(x, y, 10'd220, 10'd262, 8'h50) || // PRESS OK TO RETRY
                    char_px_2x(x, y, 10'd232, 10'd262, 8'h52) ||
                    char_px_2x(x, y, 10'd244, 10'd262, 8'h45) ||
                    char_px_2x(x, y, 10'd256, 10'd262, 8'h53) ||
                    char_px_2x(x, y, 10'd268, 10'd262, 8'h53) ||
                    char_px_2x(x, y, 10'd280, 10'd262, 8'h20) ||
                    char_px_2x(x, y, 10'd292, 10'd262, 8'h4F) ||
                    char_px_2x(x, y, 10'd304, 10'd262, 8'h4B) ||
                    char_px_2x(x, y, 10'd316, 10'd262, 8'h20) ||
                    char_px_2x(x, y, 10'd328, 10'd262, 8'h54) ||
                    char_px_2x(x, y, 10'd340, 10'd262, 8'h4F) ||
                    char_px_2x(x, y, 10'd352, 10'd262, 8'h20) ||
                    char_px_2x(x, y, 10'd364, 10'd262, 8'h52) ||
                    char_px_2x(x, y, 10'd376, 10'd262, 8'h45) ||
                    char_px_2x(x, y, 10'd388, 10'd262, 8'h54) ||
                    char_px_2x(x, y, 10'd400, 10'd262, 8'h52) ||
                    char_px_2x(x, y, 10'd412, 10'd262, 8'h59)
                )
                    rgb = 12'h111;
            end
        end
    end

endmodule
