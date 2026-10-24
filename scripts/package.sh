#!/bin/sh
# Assemble the SD card layout under dist/pocket and zip it.
#
#   Cores/masawada.PicoRuby/   core definition JSON + bitstream (from openfpga-litex release)
#   Platforms/picoruby.json    platform definition
#   Assets/picoruby/common/    boot.bin (firmware), main.rb (default script), examples/
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE_NAME="masawada.PicoRuby"
PLATFORM="picoruby"
RELEASE_DIR="${ROOT}/.cache/openfpga-litex-0.1.0"
BITSTREAM="${RELEASE_DIR}/Cores/agg23.RISCV/riscv.rev"
BOOT_BIN="${ROOT}/firmware/build/boot.bin"
OUT="${ROOT}/dist/pocket"

[ -f "${BITSTREAM}" ] || "${ROOT}/scripts/fetch-bitstream.sh"
[ -f "${BOOT_BIN}" ] || { echo "firmware not built: run make -C firmware" >&2; exit 1; }

rm -rf "${OUT}"
mkdir -p "${OUT}/Cores/${CORE_NAME}" "${OUT}/Platforms" "${OUT}/Assets/${PLATFORM}/common"

cp "${ROOT}"/core/core.json "${ROOT}"/core/data.json "${ROOT}"/core/video.json \
   "${ROOT}"/core/input.json "${ROOT}"/core/interact.json "${ROOT}"/core/audio.json \
   "${ROOT}"/core/variants.json "${ROOT}"/core/info.txt \
   "${OUT}/Cores/${CORE_NAME}/"
cp "${BITSTREAM}" "${OUT}/Cores/${CORE_NAME}/riscv.rev"
cp "${ROOT}/core/platform.json" "${OUT}/Platforms/${PLATFORM}.json"
cp "${BOOT_BIN}" "${OUT}/Assets/${PLATFORM}/common/boot.bin"
cp "${ROOT}/ruby/main.rb" "${OUT}/Assets/${PLATFORM}/common/main.rb"
mkdir -p "${OUT}/Assets/${PLATFORM}/common/examples"
cp "${ROOT}"/ruby/examples/*.rb "${OUT}/Assets/${PLATFORM}/common/examples/"

ZIP="${ROOT}/dist/${CORE_NAME}.zip"
rm -f "${ZIP}"
(cd "${OUT}" && zip -q -r "${ZIP}" Cores Platforms Assets)
echo "wrote ${ZIP}"
find "${OUT}" -type f | sed "s|${OUT}/||" | sort
