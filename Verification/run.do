vlib work
vmap work work
vlog -sv -cover bcesf -f rtl_flist.f
vlog -sv -f tb_flist.f
vopt +cover=bcesf -o Wrapper_tb_opt work.Wrapper_tb
vsim -coverage Wrapper_tb_opt
coverage exclude -du Wrapper_tb -code bcefst

run -all

coverage report -output coverage_report.txt
coverage save -onexit -du Wrapper_tb coverage.ucdb

quit -f