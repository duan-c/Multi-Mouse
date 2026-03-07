# Native extension scaffold

This directory contains the C++ pieces that expose raw multi-mouse events to
Godot via GDExtension. Nothing platform-specific exists yet—`MultiMouseServer`
currently exposes a stubbed device list and empty `poll()` method.

## Build steps (temporary)

1. Clone [`godot-cpp`](https://github.com/godotengine/godot-cpp) alongside this
   repository and generate its bindings for Godot 4.2:
   ```bash
   git clone https://github.com/godotengine/godot-cpp.git
   cd godot-cpp
   scons platform=windows target=template_debug vsproj=yes # example
   ```

2. Configure + build this project with CMake, pointing `GODOT_CPP_PATH` to that
   checkout:
   ```bash
   cmake -B build -S src -DGODOT_CPP_PATH=../godot-cpp
   cmake --build build --config Release
   ```

3. Copy the resulting library to `addons/multi_mouse/bin/<platform>/` and name
   it following Godot's convention (see `multi_mouse.gdextension`).

## Next steps

- Swap the placeholder device list with a real Raw Input backend on Windows.
- Implement a background thread that pushes events into a lock-free queue.
- Mirror the API on Linux via ManyMouse or libinput.
