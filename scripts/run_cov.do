vlib work
vlog -cover bcst rtl/*.v TP/aes_tb.sv
vsim -coverage work.aes_tb -sv_lib ./TP/client +ITERATION_NB=500
run -all
coverage save cov/cov_run.ucdb
coverage report -details -cvg -code bcst -output cov/cov_report.txt
quit -f

