IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

SRC_RX      = src/uart_rx.v
SRC_TX      = src/uart_tx.v
TB_RX       = tb/uart_rx_tb.v
TB_LOOPBACK = tb/uart_loopback_tb.v

SIM_DIR  = sim
WAVE_DIR = sim/waveform

.PHONY: all rx loopback wave_rx wave_loopback clean

all: rx loopback

rx: $(SIM_DIR)/uart_rx_sim
	$(VVP) $(SIM_DIR)/uart_rx_sim

loopback: $(SIM_DIR)/uart_loopback_sim
	$(VVP) $(SIM_DIR)/uart_loopback_sim

$(SIM_DIR)/uart_rx_sim: $(SRC_RX) $(TB_RX)
	@mkdir -p $(WAVE_DIR)
	$(IVERILOG) -o $@ $^

$(SIM_DIR)/uart_loopback_sim: $(SRC_TX) $(SRC_RX) $(TB_LOOPBACK)
	@mkdir -p $(WAVE_DIR)
	$(IVERILOG) -o $@ $^

wave_rx:
	$(GTKWAVE) $(WAVE_DIR)/uart_rx.vcd &

wave_loopback:
	$(GTKWAVE) $(WAVE_DIR)/uart_loopback.vcd &

clean:
	rm -f $(SIM_DIR)/uart_rx_sim $(SIM_DIR)/uart_loopback_sim
	rm -f $(WAVE_DIR)/*.vcd
