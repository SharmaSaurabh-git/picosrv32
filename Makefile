# Makefile for picosrv32 simulation.
# Primary/verified flow: Icarus Verilog. Compile the DUT and testbench
# as separate sources (the testbench does not `include the RTL).

SOURCES = rtl/picosrv32.sv tb/tb_picosrv32.sv
TOP_MODULE = tb_picosrv32

sim-iverilog:
	@mkdir -p obj_dir
	iverilog -g2012 -o obj_dir/$(TOP_MODULE).vvp $(SOURCES)
	vvp obj_dir/$(TOP_MODULE).vvp

# Verilator alternative (untested in this repo's history -- --binary
# mode needs Verilator 4.106+; use sim-iverilog if unsure).
VERILATOR = verilator
VERILATOR_FLAGS = -Wall --binary --timing -O3 -Wno-DECLFILENAME

sim: obj_dir/V$(TOP_MODULE)
	@echo "Running simulation..."
	@./obj_dir/V$(TOP_MODULE)

obj_dir/V$(TOP_MODULE): $(SOURCES)
	@mkdir -p obj_dir
	$(VERILATOR) $(VERILATOR_FLAGS) $(SOURCES) --top-module $(TOP_MODULE)

clean:
	@rm -rf obj_dir
	@rm -f picosrv32.vcd

.PHONY: sim sim-iverilog clean
