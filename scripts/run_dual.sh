#!/usr/bin/env bash
set -euo pipefail

# -------- Params --------
PORT=${PORT:-3002}
ITER=${ITER:-2}
PROJ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJ_ROOT"

echo "[run_dual] PORT=$PORT  ITER=$ITER"
echo "[run_dual] Project root: $PROJ_ROOT"

# -------- Build DPI if missing --------
if [ ! -f TP/client.so ]; then
  echo "[run_dual] Building TP/client.so ..."
  if [ -x ./scripts/build_c.sh ]; then
    ./scripts/build_c.sh
  else
    MGLS_INCLUDE=$(which vsim | sed 's#\(.*\)bin.*#\1include#g')
    g++ -g -DDPI -I . -I "$MGLS_INCLUDE" -shared -Bsymbolic -fPIC TP/client.cc -o TP/client.so
  fi
fi

# -------- Launch server in separate terminal --------
launch_server_cmd="cd \"$PROJ_ROOT/TP\" && python server.py $PORT"

if command -v xterm >/dev/null 2>&1; then
  echo "[run_dual] Launching server in xterm..."
  # -hold garde la fenêtre ouverte; le 'read' ajoute un prompt de sortie si le serveur s'arrête
  xterm -hold -title "AES Server :$PORT" -e bash -lc "$launch_server_cmd; echo; echo '--- server stopped ---'; read -n 1 -p 'press any key to close window...'" &
elif command -v tmux >/dev/null 2>&1; then
  echo "[run_dual] xterm not found; using tmux."
  SESSION=sv_aes
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  tmux new-session -d -s "$SESSION" -n server
  tmux send-keys -t "$SESSION":0.0 "cd '$PROJ_ROOT/TP' && python2 -u server.py $PORT" C-m
  echo "[run_dual] Attach: tmux attach -t $SESSION  (Detach: Ctrl+b d)"
else
  echo "[run_dual][WARN] No xterm/tmux; background mode with log."
  ( eval "$launch_server_cmd" ) > TP/server_bg.log 2>&1 &
  echo "[run_dual] Server log -> TP/server_bg.log"
fi

# -------- Run simulation here --------
echo "[run_dual] Running simulation in current terminal..."
vlib work || true
vlog rtl/*.v TP/aes_tb.sv
vsim -c -sv_lib ./TP/client work.aes_tb +ITERATION_NB=$ITER -do "run -all; quit"

echo
echo "[run_dual] Simulation finished."
echo "[run_dual] Server is still running in its xterm window."
echo "[run_dual] To stop it later from another shell:"
echo "  echo -n 'STOP' | nc 127.0.0.1 $PORT"
echo

