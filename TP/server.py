

import socket
import re, sys
from aes_live_test import AES_ref_py

BUFFER_SIZE = 512
PORT_SERVER = 3002
MAX_PENDING_CONNECTIONS = 5

def to_text(b):
    """bytes/str -> str (unicode en Py3, str en Py2)"""
    try:
        return b.decode("utf-8")
    except AttributeError:
        return b  # deja str en Py2

def to_bytes(s):
    """str -> bytes (Py3) / str (Py2)"""
    try:
        return s.encode("utf-8")
    except AttributeError:
        return s  # deja str en Py2

def compute_response(msg):
    """
    Attend:  AES,ENC,KEY=<32hex>,PT=<32hex>
    Tolere espaces/retours a la ligne.
    Retourne: CT=<32hex>  ou "error"
    """
    try:
        print("[PY] Raw msg: %r" % msg); sys.stdout.flush()
        compact = re.sub(r"\s+", "", msg)
        print("[PY] Compact msg: %s" % compact); sys.stdout.flush()

        m = re.match(r"^AES,ENC,KEY=([0-9A-Fa-f]{32}),PT=([0-9A-Fa-f]{32})$", compact)
        if not m:
            print("[PY][ERROR] Bad message format after compaction"); sys.stdout.flush()
            return "error"

        key_hex = m.group(1).lower()
        pt_hex  = m.group(2).lower()
        print("[PY] Parsed key=%s pt=%s" % (key_hex, pt_hex)); sys.stdout.flush()

        ct_hex = AES_ref_py(pt_hex, key_hex)  # doit renvoyer 32 hex chars
        ct_hex = re.sub(r"[^0-9a-fA-F]", "", ct_hex).lower()
        print("[PY] Ciphertext = %s" % ct_hex); sys.stdout.flush()

        return "CT=" + ct_hex
    except Exception as e:
        print("[PY][EXC] %s" % e); sys.stdout.flush()
        return "error"

def server(PORT):
    """Serveur persistant: traite N requetes; s'arrete quand il recoit STOP."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(('', PORT))
    sock.listen(MAX_PENDING_CONNECTIONS)
    print("Server listening on port %d" % PORT); sys.stdout.flush()

    running = True
    while running:
        conn, addr = sock.accept()
        print("Connection accepted from %s:%d" % (addr[0], addr[1])); sys.stdout.flush()
        try:
            # LIRE UNE SEULE FOIS (pas dattente de fermeture cote client)
            conn.settimeout(5.0)  # pour eviter de bloquer indefiniment
            data = conn.recv(BUFFER_SIZE)
            if not data:
                print("Empty message"); sys.stdout.flush()
                conn.close()
                continue

            msg = to_text(data)
            print("Message received from SV: %s" % msg); sys.stdout.flush()

            compact = re.sub(r"\s+", "", msg)
            if compact.upper() == "STOP":
                conn.sendall(to_bytes("BYE"))
                running = False
            else:
                resp = compute_response(msg)
                conn.sendall(to_bytes(resp))

        except Exception as ex:
            print("Got this error: %r" % ex); sys.stdout.flush()
            try:
                conn.sendall(to_bytes("error"))
            except Exception:
                pass
        finally:
            conn.close()
            print("Connection closed!"); sys.stdout.flush()

    print("Server socket closing..."); sys.stdout.flush()
    sock.close()

if __name__ == "__main__":
    try:
        server(PORT_SERVER)
    except Exception as ex:
        print("Got this python error: "+repr(ex)); sys.stdout.flush()

