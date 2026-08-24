# SpyGlass lint —— 文件列表/顶层从环境变量读（由 Makefile 的 LINT_SRCS/LINT_TOP 传入）
# 换模块时只改 Makefile 顶部的 SRCS/TOP，本文件不用动
new_project arc_lint -force
set_option top $env(LINT_TOP)
set_option enableSV09 yes
set_option language_mode mixed
read_file -type verilog $env(LINT_SRCS)
link_design -top $env(LINT_TOP)
current_goal lint/lint_rtl -top $env(LINT_TOP)
run_goal
write_report moresimple > lint_rpt.txt
save_project -force arc_lint
quit -f
