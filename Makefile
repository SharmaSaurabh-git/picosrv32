# Makefile for Picosrv32 simulation
VERILATOR = verilator
VERILATOR_FLAGS = -Wall --cc --exe -O3
TOP_MODULE = tb_picosrv32
SOURCES = rtl/picosrv32.sv tb/tb_picosrv32.sv
EXE = obj_dir/V$(TOP_MODULE)

all: sim

sim: $(EXE)
	@echo "Running simulation..."
	@./$(EXE)

$(EXE): $(SOURCES)
	@echo "Compiling with Verilator..."
	@mkdir -p obj_dir
	$(VERILATOR) $(VERILATOR_FLAGS) $(SOURCES) --top-module $(TOP_MODULE)
	@make -C obj_dir -f V$(TOP_MODULE).mk V$(TOP_MODULE)

clean:
	@rm -rf obj_dir
	@rm -f picosrv32.vcd

.PHONY: all sim clean
