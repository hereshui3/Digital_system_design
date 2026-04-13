`timescale 1ns/1ps

module tb_startscreen_dump;
    reg clk;
    reg reset_n;
    reg confirm_btn;
    reg jump_btn;
    reg crouch_btn;
    reg [9:0] x;
    reg [9:0] y;
    reg video_on;

    wire [11:0] rgb;
    wire [15:0] score_out;

    integer f;
    integer xx;
    integer yy;
    integer r8;
    integer g8;
    integer b8;

    game_logic dut (
        .clk(clk),
        .reset_n(reset_n),
        .confirm_btn(confirm_btn),
        .jump_btn(jump_btn),
        .crouch_btn(crouch_btn),
        .x(x),
        .y(y),
        .video_on(video_on),
        .rgb(rgb),
        .score_out(score_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset_n = 1'b0;
        confirm_btn = 1'b0;
        jump_btn = 1'b0;
        crouch_btn = 1'b0;
        video_on = 1'b1;
        x = 10'd0;
        y = 10'd0;

        repeat (6) @(posedge clk);
        reset_n = 1'b1;
        repeat (4) @(posedge clk);

        f = $fopen("start_screen.ppm", "w");
        if (f == 0) begin
            $display("ERROR: failed to open start_screen.ppm");
            $finish;
        end

        $fdisplay(f, "P3");
        $fdisplay(f, "640 480");
        $fdisplay(f, "255");

        for (yy = 0; yy < 480; yy = yy + 1) begin
            y = yy[9:0];
            for (xx = 0; xx < 640; xx = xx + 1) begin
                x = xx[9:0];
                #1;
                r8 = rgb[11:8] * 17;
                g8 = rgb[7:4] * 17;
                b8 = rgb[3:0] * 17;
                $fwrite(f, "%0d %0d %0d\n", r8, g8, b8);
            end
        end

        $fclose(f);
        $display("Generated start_screen.ppm");
        $finish;
    end
endmodule
