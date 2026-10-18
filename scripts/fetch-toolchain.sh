#!/bin/sh
# Download the xPack RISC-V GCC (newlib, multilib) into .toolchain/.
# The SoC needs rv32imafdc / ilp32d; this build ships that multilib.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="15.2.0-1"
NAME="xpack-riscv-none-elf-gcc-${VERSION}"
DEST="${ROOT}/.toolchain"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)
    ARCHIVE="${NAME}-darwin-arm64.tar.gz"
    SHA256="6588e8351455fad8aca37551f0e5a5543f3346bfa9a837cf03cbd3bdd4989f8f"
    ;;
  *)
    echo "unsupported host: $(uname -s)-$(uname -m)" >&2
    exit 1
    ;;
esac

URL="https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v${VERSION}/${ARCHIVE}"

if [ -x "${DEST}/${NAME}/bin/riscv-none-elf-gcc" ]; then
  echo "toolchain already present: ${DEST}/${NAME}"
  exit 0
fi

mkdir -p "${DEST}"
cd "${DEST}"
if [ ! -f "${ARCHIVE}" ]; then
  echo "downloading ${URL}"
  curl -sSL -o "${ARCHIVE}" "${URL}"
fi
echo "${SHA256}  ${ARCHIVE}" | shasum -a 256 -c -
tar xzf "${ARCHIVE}"
echo "installed: ${DEST}/${NAME}"
