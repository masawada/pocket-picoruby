#!/bin/sh
# Cross-build libmruby.a for the Pocket with vendor/picoruby's rake.
# Needs CRuby 3.4+ (see .ruby-version) and the toolchain from
# scripts/fetch-toolchain.sh. Output:
#   vendor/picoruby/build/pocket-picoruby/lib/libmruby.a
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${ROOT}/firmware/build_config/pocket-picoruby.rb"

cd "${ROOT}/vendor/picoruby"
MRUBY_CONFIG="${CONFIG}" exec rake "$@"
