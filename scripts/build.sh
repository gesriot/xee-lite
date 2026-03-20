#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_DIR="/Library/Developer/CommandLineTools/SDKs"
SDK_PATH="$SDK_DIR/MacOSX.sdk"

if [[ -d "$SDK_DIR/MacOSX15.4.sdk" ]]; then
  SDK_PATH="$SDK_DIR/MacOSX15.4.sdk"
elif [[ -d "$SDK_DIR/MacOSX15.sdk" ]]; then
  SDK_PATH="$SDK_DIR/MacOSX15.sdk"
fi

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/swiftpm-module-cache"
export SDKROOT="$SDK_PATH"

cd "$ROOT_DIR"
swift build
