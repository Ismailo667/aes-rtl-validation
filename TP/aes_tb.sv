`timescale 1ns/1ps

// DPI: lib générée depuis TP/client.cc → vsim ... -sv_lib ./TP/client
import "DPI-C" function string call_client(input string hostname, input int client_port, input string client_msg);

module aes_tb(); 

  // ---- Paramètres généraux ----
  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD      = 2 * CLK_HALF_PERIOD;
  parameter AES_128_BIT_KEY = 0;
  parameter AES_256_BIT_KEY = 1;

  parameter AES_DECIPHER = 1'b0;
  parameter AES_ENCIPHER = 1'b1;

  // ---- Réseau (adapter au besoin) ----
  parameter string HOSTNAME = "tallinn.emse.fr"; // "tallinn.emse.fr"
  parameter int    PORT     = 3002;

  // ---- Signaux DUT / TB ----
  logic            tb_clk = 0;
  logic            tb_reset_n;
  logic            tb_encdec;
  logic            tb_init;
  logic            tb_next;
  logic            tb_ready;
  logic [255 : 0]  tb_key;
  logic            tb_keylen;
  logic [127 : 0]  tb_block;
  logic [127 : 0]  tb_result;
  logic            tb_result_valid;

  // Vars utilitaires
  logic [127 : 0]  ct_ref;
  logic [255 : 0]  nist_aes128_key1 = 256'h2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000;
  logic [127 : 0]  nist_plaintext0  = 128'h3243f6a8885a308d313198a2e0370734;
  logic [127 : 0]  nist_cipher0     = 128'h3925841d02dc09fbdc118597196a0b32;

  int              fin,fout,fout_ref;
  int              status,status_ref;
  string           vectin_ref, vectin;
  string           data_in_str, key_in_str;
  string           DPI_answer, client_msg;
  string           operation_s;


// --- Générateur d'entrées aléatoires ---
class Input_class;
  rand bit [127:0] pt;   // plaintext
  rand bit [127:0] key;  // clé AES-128
  // (Ajoute des constraints si tu veux filtrer certains patterns)
endclass

  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  aes_core dut(
    .clk          (tb_clk),
    .reset_n      (tb_reset_n),

    .encdec       (tb_encdec),
    .init         (tb_init),
    .next         (tb_next),
    .ready        (tb_ready),

    .key          (tb_key),
    .keylen       (tb_keylen),

    .block        (tb_block),
    .result       (tb_result),
    .result_valid (tb_result_valid)
  );

  // Horloge
  always begin : clk_gen
    #CLK_HALF_PERIOD;
    tb_clk = !tb_clk;
  end

  // ---- Scénario principal ----
  initial begin
  int iteration_nb_s = 10;         // défaut si +ITERATION_NB non passé
  Input_class gen = new();
  string op_s;

  if ($value$plusargs("OPERATION=%s", op_s))
    $display("operation = %s", op_s);

  if (!$value$plusargs("ITERATION_NB=%d", iteration_nb_s))
    $display("[SV] +ITERATION_NB non fourni, défaut = %0d", iteration_nb_s);

  init_sim();
  reset_dut();

  // Boucle de vérification aléatoire
  for (int i = 0; i < iteration_nb_s; i++) begin
    assert(gen.randomize()) else $fatal(1, "[SV] randomize() a échoué à l’itération %0d", i);

    // Charger la clé 128 bits dans la partie haute (même mapping que le NIST utilisé)
    tb_key = {gen.key, 128'h0};

    // Configurer le DUT pour chiffrer en AES-128
    setup_operation(AES_ENCIPHER, AES_128_BIT_KEY);

    // Attendre prêt puis envoyer le bloc aléatoire
    @(posedge tb_ready);
    send_data(gen.pt, tb_key);

    // Attendre la sortie valide
    @(posedge tb_result_valid);
    #CLK_PERIOD;

    // Comparaison via Python (oracle) + affichage des deux ciphers
    DPI_comparison(gen.pt, tb_key);
  end

  $finish();
end


  // ===================== Tasks =====================

  // Initialisation de la simulation
  task init_sim;
  begin
    tb_clk      = 0;
    tb_reset_n  = 0;
    tb_encdec   = 0;
    tb_init     = 0;
    tb_next     = 0;
    tb_key      = '0;
    tb_keylen   = 0;
    tb_block    = '0;
    $display("Simulation initialisée");
  end
  endtask // init_sim

  // Initialisation de l'opération (charge la clé à l'init)
  task setup_operation(input logic op, input logic keylen);
  begin
    tb_encdec  = op;             // ENC/DEC
    tb_keylen  = keylen;         // 128/256
    tb_init    = 1;              // pulse d'init (la clé est déjà dans tb_key)
    #CLK_PERIOD;
    tb_init    = 0;
  end
  endtask // setup_operation

  // Envoi d'un bloc (et éventuellement mise à jour clé si tu le souhaites)
  task send_data(input logic [127:0] data_in, input logic [255:0] key_in);
  begin
    tb_block = data_in;
    // tb_key   = key_in; // inutile si déjà chargé à l'init
    #CLK_PERIOD;
    tb_next  = 1;
    #CLK_PERIOD;
    tb_next  = 0;
  end
  endtask // send_data

  // (Optionnel) Comparaison fichier de référence
  task file_comparison;
  begin
    // TODO si besoin : lire un fichier de vecteurs et comparer
  end
  endtask

  // Comparaison via Python & DPI (format protocole TD)
  task DPI_comparison(input logic [127:0] data_in, input logic [255:0] key_in);
    string msg, resp, dut_ct_hex, ref_ct_hex;
  begin
    // message: "AES,ENC,KEY=<32hex>,PT=<32hex>"
    msg = $sformatf("AES,ENC,KEY=%032x,PT=%032x", key_in[255:128], data_in);

    $display("[SV] TX to Python @ %s:%0d => %s", HOSTNAME, PORT, msg);
    resp = call_client(HOSTNAME, PORT, msg);
    $display("[SV] RX from Python => %s", resp);

    // DUT → hex
    dut_ct_hex = $sformatf("%032x", tb_result);

    // Python → hex (accepte "CT=<hex>" ou juste "<hex>")
    if (resp.len() >= 3 && resp.substr(0,2) == "CT=")
      ref_ct_hex = resp.substr(3, resp.len()-1);
    else
      ref_ct_hex = resp;

    if (dut_ct_hex == ref_ct_hex) begin
      $display("[SV][DPI] MATCH  : %s", ref_ct_hex);
    end else begin
      $display("[SV][DPI] MISMATCH:\n  DUT=%s\n  PY =%s", dut_ct_hex, ref_ct_hex);
    end
  end
  endtask // DPI_comparison

  // Affiche le résultat et compare à une référence donnée
  task check_result(input [127:0] cipher_ref);
  begin
    $display("*** Test result");
    if (cipher_ref == tb_result) begin
      $display("Success : 0x%032x", tb_result);
    end else begin
      $display("Failure : DUT : 0x%032x ;\n          REF : 0x%032x", tb_result, cipher_ref);
    end
    $display("");
  end
  endtask // check_result

  // Reset synchrone simple
  task reset_dut;
  begin
    $display("*** Toggle reset.");
    tb_reset_n = 0;
    #(2 * CLK_PERIOD);
    #1
    tb_reset_n = 1;
    @(posedge tb_clk);
  end
  endtask // reset_dut
  
  // --- Functional coverage ---
covergroup aes_cov @(posedge tb_result_valid);
  // ce qu’on couvre à chaque résultat valide
  coverpoint tb_encdec { bins enc = {1'b1}; bins dec = {1'b0}; }
  coverpoint tb_keylen { bins aes128 = {1'b0}; bins aes256 = {1'b1}; }
  coverpoint tb_block;                 // plaintext 128b testé
  coverpoint tb_key[255:128];          // clé 128b (partie utile)
  // (optionnel) croisement
  // cross tb_encdec, tb_keylen;
endgroup

aes_cov cov_inst = new();


endmodule

