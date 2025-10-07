# AES Hardware Verification — SystemVerilog + DPI-C + Python

This project demonstrates **hardware/software co-simulation** between a SystemVerilog testbench, a C++ DPI layer, and a Python reference model.  
The goal is to verify a **hardware AES-128 ECB encryption core** against a **Python software reference** through socket communication.

---

## 🧩 Overview
The SystemVerilog testbench sends plaintext and keys to the Python server through a C DPI client.  
The Python server computes the AES-128 encryption result using a software model and returns it to the testbench for comparison with the RTL DUT output.

---

## 🗂️ Project Structure
```
simu-aes-sv-dpi/
├── rtl/ # RTL implementation of AES core
│ ├── aes.v
│ ├── aes_core.v
│ ├── aes_encipher_block.v
│ ├── aes_decipher_block.v
│ ├── aes_key_mem.v
│ ├── aes_sbox.v
│ └── aes_inv_sbox.v
│
├── TP/ # Testbench and simulation sources
│ ├── aes_tb.sv # SystemVerilog testbench (randomized verification)
│ ├── client.cc # C++ DPI client (socket interface)
│ ├── server.py # Python server + AES reference model interface
│ └── aes_live_test.py# Pure Python AES model (reference)
│
├── scripts/ # Helper scripts
│ ├── build_c.sh # Build the DPI shared library
│ ├── run_cli.sh # Run server + simulation in background
│ ├── run_dual.sh # Open xterm for server + run simulation
│ └── run_cov.do # ModelSim/Questa coverage script
│
├── cov/ # Coverage reports (generated)
│
└── README.md
```

---

## 🚀 Running the Simulation

### Option 1 — All-in-one (background server)
```bash
./scripts/build_c.sh
PORT=3002 ./scripts/run_cli.sh 200
```
### Option 2 — Dual Terminal (xterm)
```
PORT=2003 ITER=200 ./scripts/run_dual.sh
```
### Option 3 — GUI Mode (ModelSim)
In the ModelSim console:
```
do scripts/run_cov.do
```
Results will appear under cov/.

# Simulation Workflow

<p align="center">
<img width="752" height="675" alt="image" src="https://github.com/user-attachments/assets/0e96e260-1ec8-4534-b063-ab6fe7c3c4e9" />
</p>

# Communication Protocol

<p align="center">
<img width="734" height="856" alt="image" src="https://github.com/user-attachments/assets/5d940969-570b-4fcc-99a0-d019b9ab2af2" />
</p>

# Requirements

- Linux environment with ModelSim or QuestaSim
- Python 2.7.x (used on school server)
- g++ available for DPI compilation
- Optional: xterm for dual-terminal execution

# Useful Commands

| Purpose              | Command                              |
| -------------------- | ------------------------------------ |
| Build C shared lib   | `./scripts/build_c.sh`               |
| Launch server + sim  | `PORT=2003 ./scripts/run_cli.sh 100` |
| Kill server manually | `echo -n "STOP" nc 127.0.0.1 2003`   |
| Run in GUI mode      | `vsim -do scripts/run_cov.do`        |
