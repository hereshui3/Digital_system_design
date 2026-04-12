module seven_seg_driver (
    input wire clk,             // 100MHz clock
    input wire [15:0] score,    // 4-digit BCD score: {thousands, hundreds, tens, ones}
    output reg [7:0] seg,       // Segment (A-G, DP) - Active High
    output reg [7:0] an         // Anode (Digit select) - Active High
);

    reg [17:0] clk_div;
    always @(posedge clk) clk_div <= clk_div + 1;
    wire [2:0] scan_cnt = clk_div[17:15]; // Refresh rate ~1.5kHz

    reg [3:0] dec_digit;
    always @(*) begin
        case (scan_cnt)
            3'd0: begin an = 8'b00000001; dec_digit = score[15:12]; end
            3'd1: begin an = 8'b00000010; dec_digit = score[11:8];  end
            3'd2: begin an = 8'b00000100; dec_digit = score[7:4];   end
            3'd3: begin an = 8'b00001000; dec_digit = score[3:0];   end
            default: begin an = 8'b00000000; dec_digit = 4'h0;      end
        endcase
    end

    // Decimal to 7-segment (Active High for EGo1)
    always @(*) begin
        case (dec_digit)
            4'h0: seg = 8'h3F; 4'h1: seg = 8'h06; 4'h2: seg = 8'h5B; 4'h3: seg = 8'h4F;
            4'h4: seg = 8'h66; 4'h5: seg = 8'h6D; 4'h6: seg = 8'h7D; 4'h7: seg = 8'h07;
            4'h8: seg = 8'h7F; 4'h9: seg = 8'h6F;
            default: seg = 8'h00; // Blank for invalid BCD
        endcase
    end

endmodule
