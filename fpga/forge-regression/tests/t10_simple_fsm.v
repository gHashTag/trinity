// Test 10: Simple FSM
// Feature: 3-state finite state machine
// States: IDLE -> COUNT -> DISPLAY -> IDLE
// Expected: LED pattern changes every few seconds
module trinity_top (
    input  wire clk,
    output wire led
);
    localparam IDLE = 2'd0;
    localparam COUNT = 2'd1;
    localparam DISPLAY = 2'd2;

    reg [1:0] state = IDLE;
    reg [23:0] timer = 24'd0;
    reg [3:0] count = 4'd0;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (timer == 24'd1000000) begin  // ~20ms at 50MHz
                    state <= COUNT;
                    timer <= 24'd0;
                end else begin
                    timer <= timer + 1'b1;
                end
            end
            COUNT: begin
                if (count == 4'd15) begin
                    state <= DISPLAY;
                end else begin
                    count <= count + 1'b1;
                end
            end
            DISPLAY: begin
                if (timer == 24'd2500000) begin  // ~50ms
                    state <= IDLE;
                    timer <= 24'd0;
                    count <= 4'd0;
                end else begin
                    timer <= timer + 1'b1;
                end
            end
        endcase
    end

    assign led = (state == DISPLAY) && (count[3]);
endmodule
