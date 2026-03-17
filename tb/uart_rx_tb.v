`timescale 1ns/1ns

module uart_rx_tb;

parameter CLK_PERIOD    = 20;
parameter CLKS_PER_BIT  = 868;
parameter BIT_PERIOD_NS = CLK_PERIOD * CLKS_PER_BIT;

reg        clk;
reg        rst_n;
reg        rx_serial;
wire       rx_done;
wire [7:0] rx_data;

// Latch rx_done để không bỏ lỡ pulse 1 cycle
reg rx_done_latch;
reg [7:0] rx_data_latch;
always @(posedge clk) begin
    if (rx_done) begin
        rx_done_latch <= 1'b1;
        rx_data_latch <= rx_data;
    end
end

uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
    .clk(clk), .rst_n(rst_n),
    .rx_serial(rx_serial),
    .rx_done(rx_done), .rx_data(rx_data)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// Software UART TX model
task drive_byte;
    input [7:0] data;
    input       bad_stop;
    integer i;
    begin
        rx_serial = 1'b0; #(BIT_PERIOD_NS);
        for (i=0; i<8; i=i+1) begin
            rx_serial = data[i]; #(BIT_PERIOD_NS);
        end
        rx_serial = bad_stop ? 1'b0 : 1'b1;
        #(BIT_PERIOD_NS);
        rx_serial = 1'b1;
    end
endtask

integer pass_count=0, fail_count=0, tcnt;

task test_normal;
    input [7:0] data;
    begin
        rx_done_latch = 0;
        drive_byte(data, 0);
        tcnt = 0;
        while (!rx_done_latch && tcnt < CLKS_PER_BIT*5) begin
            @(posedge clk); tcnt = tcnt+1;
        end
        if (rx_done_latch && rx_data_latch===data) begin
            $display("[PASS] 0x%02X received correctly", data);
            pass_count = pass_count+1;
        end else begin
            $display("[FAIL] expected 0x%02X, got 0x%02X, latch=%b",
                      data, rx_data_latch, rx_done_latch);
            fail_count = fail_count+1;
        end
        #(BIT_PERIOD_NS*3);
    end
endtask

task test_framing;
    input [7:0] data;
    begin
        rx_done_latch = 0;
        drive_byte(data, 1);
        tcnt = 0;
        while (!rx_done_latch && tcnt < CLKS_PER_BIT*15) begin
            @(posedge clk); tcnt = tcnt+1;
        end
        if (!rx_done_latch) begin
            $display("[PASS] Framing error rejected correctly");
            pass_count = pass_count+1;
        end else begin
            $display("[FAIL] Framing error NOT caught");
            fail_count = fail_count+1;
        end
        #(BIT_PERIOD_NS*3);
    end
endtask

initial begin
    $dumpfile("sim/waveform/uart_rx.vcd");
    $dumpvars(0, uart_rx_tb);
    rx_serial=1; rst_n=0; rx_done_latch=0;
    repeat(10) @(posedge clk);
    rst_n=1;
    repeat(5) @(posedge clk);

    $display("=== UART RX Testbench ===");
    $display("[TC1] 0x37");          test_normal(8'h37);
    $display("[TC2] 0xA5");          test_normal(8'hA5);
    $display("[TC3] 0x00 (all 0)");  test_normal(8'h00);
    $display("[TC4] 0xFF (all 1)");  test_normal(8'hFF);
    $display("[TC5] Framing error"); test_framing(8'h55);

    $display("=== RESULTS: %0d PASS / %0d FAIL ===", pass_count, fail_count);
    if (fail_count==0) $display("All tests PASSED.");
    $finish;
end

initial begin
    #(BIT_PERIOD_NS*300);
    $display("[TIMEOUT]");
    $finish;
end

endmodule
