#!/usr/bin/env bash
# Generates the Connect IQ developer (signing) key.
# Commands are taken verbatim from "Using Monkey C from the Command Line" -> "Generating a Key Using OpenSSL":
#   https://developer.garmin.com/connect-iq/reference-guides/monkey-c-command-line-setup/
# The key must be RSA 4096 bit (Getting Started -> "Generating a Developer Key").
# KEEP THE RESULTING FILES: you need the same key to sign every future update of the app on the store.
set -euo pipefail
OUT_DIR="${1:-$HOME/.connectiq-keys}"
mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"
if [ -e "$OUT_DIR/developer_key.der" ]; then
  echo "Refusing to overwrite existing $OUT_DIR/developer_key.der" >&2
  exit 1
fi
openssl genrsa -out "$OUT_DIR/developer_key.pem" 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in "$OUT_DIR/developer_key.pem" -out "$OUT_DIR/developer_key.der" -nocrypt
chmod 600 "$OUT_DIR/developer_key.pem" "$OUT_DIR/developer_key.der"
# Single-line base64 of the DER key, for the GitHub secret CIQ_DEVELOPER_KEY_B64 (see README).
base64 -w0 "$OUT_DIR/developer_key.der" > "$OUT_DIR/developer_key.der.b64"
chmod 600 "$OUT_DIR/developer_key.der.b64"
echo "Created in $OUT_DIR:"
echo "  developer_key.der      -> pass to the compiler with -y"
echo "  developer_key.der.b64  -> content of the GitHub secret CIQ_DEVELOPER_KEY_B64"
echo "BACK THESE FILES UP. Never commit them (they are in .gitignore)."
