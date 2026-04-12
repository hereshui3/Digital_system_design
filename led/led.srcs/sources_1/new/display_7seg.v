module display_7seg (
input clk,
output reg[1:0]led_out
);
//reg[1:0]led_out;
reg[32:0]count=0;
parameter T1MS=50000000;
always@(posedge clk)
    begin
        count<=count+1;
        if(count==T1MS)
            begin
                count<=0;
            end
        else if(count<25000000)
            begin
                led_out<=2'b01;
            end
        else begin
            led_out<=2'b10;
        end
    end
endmodule