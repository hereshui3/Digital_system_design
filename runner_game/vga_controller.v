module vga_controller (
    input wire clk_25m,      // 25MHz pixel clock
    input wire reset_n,      // Active low reset
    output reg h_sync,       // Horizontal sync
    output reg v_sync,       // Vertical sync
    output reg [9:0] x,      // Horizontal coordinate (0-639)
    output reg [9:0] y,      // Vertical coordinate (0-479)
    output reg video_on      // High when in active video region
);

    // 640x480 @ 60Hz Timing
    parameter H_ACTIVE      = 640;
    parameter H_FRONT_PORCH = 16;
    parameter H_SYNC        = 96;
    parameter H_BACK_PORCH  = 48;
    parameter H_TOTAL       = 800;

    parameter V_ACTIVE      = 480;
    parameter V_FRONT_PORCH = 10;
    parameter V_SYNC        = 2;
    parameter V_BACK_PORCH  = 33;
    parameter V_TOTAL       = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    // Horizontal counter
    always @(posedge clk_25m or negedge reset_n) begin
        if (!reset_n)
            h_cnt <= 0;
        else if (h_cnt == H_TOTAL - 1)
            h_cnt <= 0;
        else
            h_cnt <= h_cnt + 1;
    end

    // Vertical counter
    always @(posedge clk_25m or negedge reset_n) begin
        if (!reset_n)
            v_cnt <= 0;
        else if (h_cnt == H_TOTAL - 1) begin
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= 0;
            else
                v_cnt <= v_cnt + 1;
        end
    end

    // Sync signals
    always @(posedge clk_25m or negedge reset_n) begin
        if (!reset_n) begin
            h_sync <= 1'b1;
            v_sync <= 1'b1;
        end else begin
            h_sync <= (h_cnt >= (H_ACTIVE + H_FRONT_PORCH)) && (h_cnt < (H_ACTIVE + H_FRONT_PORCH + H_SYNC)) ? 1'b0 : 1'b1;
            v_sync <= (v_cnt >= (V_ACTIVE + V_FRONT_PORCH)) && (v_cnt < (V_ACTIVE + V_FRONT_PORCH + V_SYNC)) ? 1'b0 : 1'b1;
        end
    end

    // Video region and coordinates
    always @(posedge clk_25m or negedge reset_n) begin
        if (!reset_n) begin
            video_on <= 1'b0;
            x <= 0;
            y <= 0;
        end else begin
            if (h_cnt < H_ACTIVE && v_cnt < V_ACTIVE) begin
                video_on <= 1'b1;
                x <= h_cnt;
                y <= v_cnt;
            end else begin
                video_on <= 1'b0;
                x <= 0;
                y <= 0;
            end
        end
    end

endmodule
