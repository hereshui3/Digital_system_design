module runner_top (
    input wire clk,             // 100MHz system clock (P17)
    input wire reset_n_raw,     // Active low reset (P15)
    input wire jump_btn_raw,    // Jump button (U4)
    input wire confirm_btn_raw, // Confirm button (R15)
    input wire crouch_btn_raw,  // Crouch button (R17)
    output wire [3:0] vga_r,    // (F5, C6, C5, B7)
    output wire [3:0] vga_g,    // (B6, A6, A5, D8)
    output wire [3:0] vga_b,    // (C7, E6, E5, E7)
    output wire vga_hs,         // (D7)
    output wire vga_vs,         // (C4)
    output wire [7:0] seg,      // Seven Segment (A-DP)
    output wire [7:0] an        // Anode select
);

    // 100MHz -> 25MHz Clock Divider
    reg [1:0] clk_div;
    always @(posedge clk) begin
        clk_div <= clk_div + 1;
    end
    wire clk_25m = clk_div[1];

    // Reset sync
    reg [1:0] reset_sync;
    always @(posedge clk) reset_sync <= {reset_sync[0], reset_n_raw};
    wire reset_n = reset_sync[1];

    // Button Sync/Debounce/Edge Detect
    localparam BTN_DB_MAX = 18'd200_000; // ~2ms at 100MHz

    reg jump_meta;
    reg jump_sync;
    reg jump_db;
    reg [17:0] jump_db_cnt;
    reg jump_prev;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            jump_meta <= 1'b0;
            jump_sync <= 1'b0;
            jump_db <= 1'b0;
            jump_db_cnt <= 18'd0;
            jump_prev <= 1'b0;
        end else begin
            jump_meta <= jump_btn_raw;
            jump_sync <= jump_meta;

            if (jump_sync != jump_db) begin
                if (jump_db_cnt < BTN_DB_MAX)
                    jump_db_cnt <= jump_db_cnt + 1'b1;
                else begin
                    jump_db <= jump_sync;
                    jump_db_cnt <= 18'd0;
                end
            end else begin
                jump_db_cnt <= 18'd0;
            end

            jump_prev <= jump_db;
        end
    end

    reg crouch_meta;
    reg crouch_sync;
    reg crouch_db;
    reg [17:0] crouch_db_cnt;
    reg crouch_prev;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            crouch_meta <= 1'b0;
            crouch_sync <= 1'b0;
            crouch_db <= 1'b0;
            crouch_db_cnt <= 18'd0;
            crouch_prev <= 1'b0;
        end else begin
            crouch_meta <= crouch_btn_raw;
            crouch_sync <= crouch_meta;

            if (crouch_sync != crouch_db) begin
                if (crouch_db_cnt < BTN_DB_MAX)
                    crouch_db_cnt <= crouch_db_cnt + 1'b1;
                else begin
                    crouch_db <= crouch_sync;
                    crouch_db_cnt <= 18'd0;
                end
            end else begin
                crouch_db_cnt <= 18'd0;
            end

            crouch_prev <= crouch_db;
        end
    end

    reg confirm_meta;
    reg confirm_sync;
    reg confirm_db;
    reg [17:0] confirm_db_cnt;
    reg confirm_prev;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            confirm_meta <= 1'b0;
            confirm_sync <= 1'b0;
            confirm_db <= 1'b0;
            confirm_db_cnt <= 18'd0;
            confirm_prev <= 1'b0;
        end else begin
            confirm_meta <= confirm_btn_raw;
            confirm_sync <= confirm_meta;

            if (confirm_sync != confirm_db) begin
                if (confirm_db_cnt < BTN_DB_MAX)
                    confirm_db_cnt <= confirm_db_cnt + 1'b1;
                else begin
                    confirm_db <= confirm_sync;
                    confirm_db_cnt <= 18'd0;
                end
            end else begin
                confirm_db_cnt <= 18'd0;
            end

            confirm_prev <= confirm_db;
        end
    end

    wire jump_pressed = jump_db && !jump_prev;
    wire crouch_pressed = crouch_db && !crouch_prev;
    wire confirm_pressed = confirm_db && !confirm_prev;

    // VGA Controller
    wire [9:0] pixel_x, pixel_y;
    wire video_on;
    vga_controller vga_inst (
        .clk_25m(clk_25m),
        .reset_n(reset_n),
        .h_sync(vga_hs),
        .v_sync(vga_vs),
        .x(pixel_x),
        .y(pixel_y),
        .video_on(video_on)
    );

    // Game Logic
    wire [11:0] rgb_out;
    wire [15:0] current_score;
    game_logic game_inst (
        .clk(clk),
        .reset_n(reset_n),
        .confirm_btn(confirm_pressed),
        .jump_btn(jump_pressed),
        .crouch_btn(crouch_pressed),
        .x(pixel_x),
        .y(pixel_y),
        .video_on(video_on),
        .rgb(rgb_out),
        .score_out(current_score)
    );

    // Seven Segment Display
    seven_seg_driver seg_inst (
        .clk(clk),
        .score(current_score),
        .seg(seg),
        .an(an)
    );

    // Assign RGB components
    assign vga_r = rgb_out[11:8];
    assign vga_g = rgb_out[7:4];
    assign vga_b = rgb_out[3:0];

endmodule
