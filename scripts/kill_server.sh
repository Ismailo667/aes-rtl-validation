#!/usr/bin/env bash
PORT=${1:-2003}
command -v nc >/dev/null && echo -n "STOP" | nc 127.0.0.1 $PORT || true
pkill -f "server.py" || true

