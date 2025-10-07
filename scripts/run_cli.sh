#!/usr/bin/env bash
set -e
PORT=${PORT:-3002}
ITER=${1:-200}
echo "[run] PORT=$PORT ITER=$ITER"

# lancer le serveur python en arrière-plan
(cd TP && python server.py $PORT) &
SRV_PID=$!
sleep 1

# build si besoin
[ -f TP/client.so ] || ./scripts/build_c.sh

# compilation et simulation
vlib work || true
vlog rtl/*.v TP/aes_tb.sv
vsim -c -sv_lib ./TP/client work.aes_tb +ITERATION_NB=$ITER -do "run -all; quit"

# arrêt propre du serveur
echo "[run] sending STOP"
command -v nc >/dev/null && echo -n "STOP" | nc 127.0.0.1 $PORT || true
kill $SRV_PID 2>/dev/null || true

