`timescale 1ns/1ps

module uart_loopback_tb;

parameter CLK_PERIOD   = 20;
parameter CLKS_PER_BIT = 868;

reg        clk;
reg        rst_n;

// TX side
reg        tx_start;
reg  [7:0] tx_data_in;
wire       tx_serial;
wire       tx_done;

// RX side (loopback: rx_serial = tx_serial)
wire       rx_done;
wire [7:0] rx_data_out;

uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
    .clk(clk), .rst_n(rst_n),
    .tx_start(tx_start), .tx_data(tx_data_in),
    .tx_serial(tx_serial), .tx_done(tx_done)
);

uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
    .clk(clk), .rst_n(rst_n),
    .rx_serial(tx_serial),    // loopback
    .rx_done(rx_done), .rx_data(rx_data_out)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

integer pass_count=0, fail_count=0;

task loopback_send;
    input [7:0] data;
    begin
        @(posedge clk);
        tx_data_in <= data;
        tx_start   <= 1'b1;
        @(posedge clk);
        tx_start   <= 1'b0;

        @(posedge rx_done);
        @(posedge clk);

        if (rx_data_out === data) begin
            $display("[PASS] Loopback 0x%02X -> received 0x%02X", data, rx_data_out);
            pass_count = pass_count+1;
        end else begin
            $display("[FAIL] Loopback 0x%02X -> received 0x%02X", data, rx_data_out);
            fail_count = fail_count+1;
        end

        @(posedge tx_done);
        repeat(10) @(posedge clk);
    end
endtask

initial begin
    $dumpfile("sim/waveform/uart_loopback.vcd");
    $dumpvars(0, uart_loopback_tb);
    tx_start=0; tx_data_in=0; rst_n=0;
    repeat(10) @(posedge clk);
    rst_n=1;
    repeat(5) @(posedge clk);

    $display("=== UART Loopback Testbench (TX -> RX) ===");
    loopback_send(8'hA5);
    loopback_send(8'h3C);
    loopback_send(8'h00);
    loopback_send(8'hFF);
    loopback_send(8'h55);

    $display("=== RESULTS: %0d PASS / %0d FAIL ===", pass_count, fail_count);
    $finish;
end

initial begin
    #(CLK_PERIOD * CLKS_PER_BIT * 300);
    $display("[TIMEOUT]");
    $finish;
end

endmodule
