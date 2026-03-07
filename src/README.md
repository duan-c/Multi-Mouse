# Native extension scaffold

This directory contains the C++ pieces that expose raw multi-mouse events to
Godot via GDExtension. Platform backends will live under `platform/` (Windows
Raw Input first, then Linux libinput/ManyMouse). For now the server publishes
placeholder devices plus strongly-typed `InputEventMultiMouse*` classes.

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

- Flesh out the Windows Raw Input backend and pipe real motion/button events.
- Implement a background thread that pushes events into a lock-free queue.
- Mirror the API on Linux via ManyMouse or libinput.
