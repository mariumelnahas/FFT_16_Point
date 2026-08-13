vlib work
vmap work work

# RTL compiled WITH coverage instrumentation
vlog -sv -cover bcesf -f rtl_flist.f

# Testbench compiled WITHOUT coverage instrumentation
vlog -sv -f tb_flist.f

# Optimize with matching coverage types
vopt +cover=bcesf -o Wrapper_tb_opt work.Wrapper_tb

# Simulate with coverage collection
vsim -coverage Wrapper_tb_opt

# Exclude the testbench itself from coverage (RTL underneath stays instrumented)
coverage exclude -du Wrapper_tb -code bcefst

run -all

# Coverage summary merged by design unit (no -details, since detailed
# line/branch data can't merge across differently-parameterized instances
# of complex_multiplier, which has a different case-arm count per STAGE)
coverage report -output Verification/coverage_report.txt

# Save coverage database
coverage save -onexit -du Wrapper_tb Verification/coverage.ucdb

quit -f