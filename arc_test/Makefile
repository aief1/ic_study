# =====================================================================
# arc 接口 testbench 的 Makefile —— 完整验证流程
# 用法：
#   make all       编译 + 功能仿真
#   make lint      SpyGlass lint（RTL 规则；TB 的 clocking 会有预期误报）
#   make cov       覆盖率（-cm 编译 -> 跑 -> urg 报告）
#   make wave      波形 fsdb（供 Verdi）
#   make verify    完整验证 = lint + compile + sim + cov + wave
#   make verdi     打开波形
#   make clean     清理
# =====================================================================
VCS      ?= vcs
VERDI    ?= verdi
URG      ?= urg
SG_SHELL ?= sg_shell
LICENSE  ?= 27081@ICEDA
export SNPSLMD_LICENSE_FILE := $(LICENSE)

# 源文件 + 顶层【模块名】
SRCS := arc.sv test.sv tb_top.sv
TOP  := tb_top

# 二进制 / 产物
SIMV     := simv
SIMV_DB  := simv_db
SIMV_COV := simv_cov
FSDB     := wave.fsdb
VDB      := simv_cov.vdb
COV_RPT  := cov_rpt
CM       := line+cond+tgl+branch

# lint
LINT_TCL := lint.tcl
LINT_RPT := lint_rpt.txt

.PHONY: all compile sim wave cov lint verify verdi clean

all: compile sim
	@echo "=== ALL DONE: compile + sim ==="

# ---------------- 编译 ----------------
compile: $(SIMV)

$(SIMV): $(SRCS)
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
	       $(SRCS) -top $(TOP) -o $(SIMV) -l compile.log

# ---------------- 运行仿真 ----------------
sim: $(SIMV)
	./$(SIMV) -l run.log

# ---------------- 出波形（先编 simv_db，再跑出 fsdb） ----------------
wave: $(FSDB)

$(SIMV_DB): $(SRCS)
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -debug_access+all +define+DUMP_FSDB \
	       $(SRCS) -top $(TOP) -o $(SIMV_DB) -l compile_db.log

$(FSDB): $(SIMV_DB)
	./$(SIMV_DB) -l run_db.log

# ---------------- 覆盖率 ----------------
# 注意：cov 每次重新编译（vdb 是编译时创建的），保证结果干净、
#       不会出现 vdb 被删而二进制还在导致运行失败的问题
cov:
	@test -d $(VDB) || rm -rf $(SIMV_COV) $(SIMV_COV).daidir
	$(VCS) -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
	       -cm $(CM) -cm_dir $(VDB) -cm_log cm.log \
	       $(SRCS) -top $(TOP) -o $(SIMV_COV) -l compile_cov.log
	./$(SIMV_COV) -cm $(CM) -cm_dir $(VDB) -cm_log cm.log -l cov.log
	$(URG) -dir $(VDB) -format text -report $(COV_RPT) -log urg.log
	@echo "=== COV DONE: 摘要见 $(COV_RPT)/dashboard.txt ==="
	@grep -A2 'Total Coverage Summary' $(COV_RPT)/dashboard.txt

# ---------------- Lint（SpyGlass） ----------------
# 依赖源码：源码/tcl 改了才重跑；SRCS/TOP 经环境变量传给 lint.tcl（换模块只改顶部变量）
lint: $(LINT_TCL) $(SRCS)
	export LINT_SRCS="$(SRCS)"; \
	export LINT_TOP="$(TOP)"; \
	$(SG_SHELL) -tcl $(LINT_TCL) -shell_log_file sg_shell.log
	@echo "=== LINT DONE: 报告见 $(LINT_RPT) ==="
	@grep "Reported Messages" $(LINT_RPT)

# ---------------- 完整验证流程 ----------------
verify: lint compile sim cov wave
	@echo ""
	@echo "=== VERIFY DONE: lint + compile + sim + cov + wave 全部完成 ==="
	@echo "    lint 报告 : $(LINT_RPT)"
	@echo "    cov  报告 : $(COV_RPT)/dashboard.txt"
	@echo "    波形      : $(FSDB)"

# ---------------- Verdi 看波形 ----------------
verdi: $(FSDB)
	$(VERDI) -ssf $(FSDB) $(SRCS) -top $(TOP) &

# ---------------- 清理 ----------------
clean:
	rm -rf $(SIMV) $(SIMV).daidir $(SIMV_DB) $(SIMV_DB).daidir $(SIMV_COV) $(SIMV_COV).daidir
	rm -rf $(VDB) $(COV_RPT) arc_lint csrc
	rm -f  $(FSDB) ucli.key novas_dump.log tb_dump.sv compile*.log run*.log cm.log cov.log urg.log sg_shell.log
