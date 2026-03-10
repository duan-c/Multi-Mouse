#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=${TARGET:-template_debug}
ARCH=${ARCH:-x86_64}
BUILD_DIR="$ROOT_DIR/build/linux_${TARGET}"
GODOT_CPP_DIR="$ROOT_DIR/extern/godot-cpp"

if [[ ! -d "$GODOT_CPP_DIR" ]]; then
  echo "godot-cpp submodule is missing. Run 'git submodule update --init --recursive'." >&2
  exit 1
fi

pushd "$GODOT_CPP_DIR" >/dev/null
scons platform=linux target=$TARGET bits=64 generate_bindings=yes -j"$(nproc)"
popd >/dev/null

LIB_PATH="$GODOT_CPP_DIR/bin/libgodot-cpp.linux.${TARGET}.${ARCH}.a"
if [[ ! -f "$LIB_PATH" ]]; then
  echo "Expected library $LIB_PATH not found. Check the scons build output." >&2
  exit 1
fi

if [[ "$TARGET" == "template_debug" ]]; then
  BUILD_TYPE="Debug"
else
  BUILD_TYPE="Release"
fi

cmake -B "$BUILD_DIR" -S "$ROOT_DIR/src" \
  -DGODOT_CPP_PATH="$GODOT_CPP_DIR" \
  -DGODOT_CPP_LIB="$LIB_PATH" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
cmake --build "$BUILD_DIR"

OUTPUT_LIB="$BUILD_DIR/libmulti_mouse.so"
TARGET_DIR="$ROOT_DIR/addons/multi_mouse/bin/linux"
mkdir -p "$TARGET_DIR"
cp "$OUTPUT_LIB" "$TARGET_DIR/libmulti_mouse.linux.${TARGET}.${ARCH}.so"

echo "Built native library -> $TARGET_DIR/libmulti_mouse.linux.${TARGET}.${ARCH}.so"
