// =============================================================================
// Module  : uart_rx
// Author  : Ho Minh Thao
// Desc    : FSM-based UART Receiver (8N1)
//           Samples RX line at the CENTER of each bit period
// =============================================================================

module uart_rx #(
    parameter CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_serial,
    output reg        rx_done,
    output reg  [7:0] rx_data
);

localparam S_IDLE      = 3'd0;
localparam S_START_BIT = 3'd1;
localparam S_DATA_BITS = 3'd2;
localparam S_STOP_BIT  = 3'd3;
localparam S_CLEANUP   = 3'd4;

reg [2:0]  state;
reg [2:0]  bit_idx;
reg [15:0] clk_cnt;
reg [7:0]  rx_shift;

// Double-flop synchronizer
reg rx_sync0, rx_sync1;
always @(posedge clk) begin
    rx_sync0 <= rx_serial;
    rx_sync1 <= rx_sync0;
end
wire rx_in = rx_sync1;

always @(posedge clk) begin
    if (!rst_n) begin
        state    <= S_IDLE;
        clk_cnt  <= 0;
        bit_idx  <= 0;
        rx_shift <= 0;
        rx_done  <= 0;
        rx_data  <= 0;
    end else begin
        rx_done <= 0;

        case (state)
            S_IDLE: begin
                clk_cnt <= 0;
                bit_idx <= 0;
                if (rx_in == 1'b0)
                    state <= S_START_BIT;
            end

            S_START_BIT: begin
                if (clk_cnt == (CLKS_PER_BIT - 1) / 2) begin
                    if (rx_in == 1'b0) begin
                        clk_cnt <= 0;
                        state   <= S_DATA_BITS;
                    end else
                        state <= S_IDLE;
                end else
                    clk_cnt <= clk_cnt + 1;
            end

            S_DATA_BITS: begin
                if (clk_cnt < CLKS_PER_BIT - 1)
                    clk_cnt <= clk_cnt + 1;
                else begin
                    clk_cnt  <= 0;
                    rx_shift <= {rx_in, rx_shift[7:1]};
                    if (bit_idx == 3'd7) begin
                        bit_idx <= 0;
                        state   <= S_STOP_BIT;
                    end else
                        bit_idx <= bit_idx + 1;
                end
            end

            S_STOP_BIT: begin
                if (clk_cnt < CLKS_PER_BIT - 1)
                    clk_cnt <= clk_cnt + 1;
                else begin
                    clk_cnt <= 0;
                    state   <= S_CLEANUP;
                    if (rx_in == 1'b1) begin
                        rx_done <= 1'b1;
                        rx_data <= rx_shift;
                    end
                end
            end

            S_CLEANUP: state <= S_IDLE;

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
