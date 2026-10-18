#!/bin/sh
# Download the openfpga-litex release package into .cache/ and extract the
# prebuilt bitstream. The bitstream is not in the git repo, only in releases.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE="0.1.0"
ARCHIVE="agg23.RISCV_${RELEASE}-2023-12-03.zip"
SHA256="e2918d320ec5f64777cd390bb2a689bb064355442fd19fcef8f90924f2cec0fa"
URL="https://github.com/agg23/openfpga-litex/releases/download/${RELEASE}/${ARCHIVE}"
DEST="${ROOT}/.cache/openfpga-litex-${RELEASE}"

if [ -f "${DEST}/Cores/agg23.RISCV/riscv.rev" ]; then
  echo "bitstream already present: ${DEST}"
  exit 0
fi

mkdir -p "${ROOT}/.cache"
cd "${ROOT}/.cache"
if [ ! -f "${ARCHIVE}" ]; then
  echo "downloading ${URL}"
  curl -sSL -o "${ARCHIVE}" "${URL}"
fi
echo "${SHA256}  ${ARCHIVE}" | shasum -a 256 -c -
rm -rf "${DEST}"
mkdir -p "${DEST}"
unzip -q "${ARCHIVE}" -d "${DEST}"
echo "extracted: ${DEST}"
