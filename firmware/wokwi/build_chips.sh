#!/usr/bin/env bash
# Builds every Wokwi custom chip in chips/ to WebAssembly. Needs clang and lld (clang finds wasm-ld next to itself).
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CHIPS_DIR="${SCRIPT_DIR}/chips"
readonly API_HEADER="${CHIPS_DIR}/wokwi-api.h"
readonly API_HEADER_URL="https://wokwi.com/api/chips/wokwi-api.h"
readonly CLANG="${CLANG:-clang}"

# The header is downloaded, never committed.
if [[ ! -f "${API_HEADER}" ]]; then
  echo "[INFO] build_chips: downloading wokwi-api.h"
  curl -fsSL -o "${API_HEADER}" "${API_HEADER_URL}"
fi

# Freestanding build: no WASI libc, so chips must not use malloc or printf.
# -Wno-unused-function: wokwi-api.h defines static helpers that a chip may not use.
for source in "${CHIPS_DIR}"/*.chip.c; do
  output="${source%.c}.wasm"
  echo "[INFO] build_chips: ${source##*/} -> ${output##*/}"
  "${CLANG}" --target=wasm32-unknown-unknown -ffreestanding -nostdlib -O2 \
    -Wall -Wextra -Werror -Wno-unused-function \
    -Wl,--no-entry -Wl,--export-table \
    -o "${output}" "${source}"
done
