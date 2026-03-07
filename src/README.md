# Native extension scaffold

This directory contains the C++ pieces that expose raw multi-mouse events to
Godot via GDExtension. Platform backends will live under `platform/` (Windows
Raw Input first, then Linux libinput/ManyMouse). For now the server publishes
placeholder devices and emits stock `InputEventMouseMotion/Button` objects with
metadata tags identifying each device.

## Build steps (Linux example)

1. Ensure the `godot-cpp` submodule is present and built:
   ```bash
   git submodule update --init --recursive
   cd extern/godot-cpp
   scons platform=linux target=template_debug bits=64 -j$(nproc)
   ```

2. Configure + build the extension with CMake, pointing at the headers and the
   freshly-built static library:
   ```bash
   cmake -B build/linux -S src \
     -DGODOT_CPP_PATH=../extern/godot-cpp \
     -DGODOT_CPP_LIB=../extern/godot-cpp/bin/libgodot-cpp.linux.template_debug.x86_64.a
   cmake --build build/linux --config Release
   ```

3. Copy/rename the produced shared library into `addons/multi_mouse/bin/...`
   so Godot can load it (see `addons/multi_mouse/bin/multi_mouse.gdextension`).

The helper script `scripts/build_linux.sh` automates the steps above.

## Next steps

- ✅ Windows Raw Input backend thread + event queue (needs on-device testing).
- Mirror the API on Linux via ManyMouse or libinput.
- Add hotplug filtering, device-friendly names, and diagnostics APIs.
