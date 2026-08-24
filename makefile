VCS ?= vcs
VERDI ?= verdi
LICENSE  ?= 27081@ICEDA

SRCS := arc.sv test.sv top.sv
TOP := top.sv


.PHONY: all compile sim wave cov lint verdi clean

all: compile sim wave
   @echo "=== ALL DONE: compile + sim + wave ==="

compile : simv
simv : $(SRCS)
export SNPSLMD_LICENSE_FILE=$(LICENSE); \
    $(VCS) -full64 -sverilog -timescale=1ns/1ps -debug_access+all $(SRCS) -top $(TOP) -o simv -l compile.log

sim :simv
./simv -l run.log

wave: wave.fsdb
wave.fsdb :simv 
  @printf 'module tb_dump;\n  top u_tb();\n  initial begin\n    $$fsdbDumpfile("wave.fsdb");\n    $$fsdbDumpvars(0, u_tb);\n  end\nendmodule\n' > tb_dump.sv
  $(VCS) -full64 -sverilog -timescale=1ns/1ps -debug_access+all $(SRCS) -top tb_dump.sv -o simv_db -l compile_db.log
  ./simv_db -l run_db.log

verdi :wave.fsdb
   export SNPSLMD_LICENSE_FILE=$(LICENSE); \
   $(VERDI) -ssf wave.fsdb $(SRCS) -top $(TOP) &



cov:
export SNPSLMD_LICENSE_FILE=$(LICENSE); \
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -debug_access+all -cm line+cond+tgl+branch $(SRCS) -top $(TOP) -o simv_cov -l compile_cov.log
	./simv_cov -cm_dir   .vdb

clean:
	rm -rf simv simv.daidir simv_dump simv_dump.daidir simv_cov simv_cov.daidir csrc
	rm -rf simv_cov.vdb cov_rpt arc_lint
	rm -f  *.fsdb tb_dump.sv compile*.log run*.log cov.log lint.log lint_rpt.txt