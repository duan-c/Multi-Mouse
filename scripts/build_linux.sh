#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/linux"
GODOT_CPP_DIR="$ROOT_DIR/extern/godot-cpp"
TARGET=${TARGET:-template_debug}
ARCH=${ARCH:-x86_64}

if [[ ! -d "$GODOT_CPP_DIR" ]]; then
  echo "godot-cpp submodule is missing. Run 'git submodule update --init --recursive'." >&2
  exit 1
fi

pushd "$GODOT_CPP_DIR" >/dev/null
scons platform=linux target=$TARGET bits=64 -j"$(nproc)"
popd >/dev/null

LIB_PATH="$GODOT_CPP_DIR/bin/libgodot-cpp.linux.${TARGET}.${ARCH}.a"
if [[ ! -f "$LIB_PATH" ]]; then
  echo "Expected library $LIB_PATH not found. Check the scons build output." >&2
  exit 1
fi

cmake -B "$BUILD_DIR" -S "$ROOT_DIR/src" \
  -DGODOT_CPP_PATH="$GODOT_CPP_DIR" \
  -DGODOT_CPP_LIB="$LIB_PATH"
cmake --build "$BUILD_DIR" --config Release

echo "Built native library. Copyit from $BUILD_DIR/libmulti_mouse.so to addons/multi_mouse/bin/linux/."
