#ifndef MULTI_MOUSE_BACKEND_H
#define MULTI_MOUSE_BACKEND_H

#include <memory>

namespace godot {

class MultiMouseServer;

class MultiMouseBackend {
public:
    explicit MultiMouseBackend(MultiMouseServer *p_server) : server(p_server) {}
    virtual ~MultiMouseBackend() = default;

    virtual void start() {}
    virtual void stop() {}
    virtual void poll() {}

    virtual void set_target_window(void * /*hwnd*/) {}

protected:
    MultiMouseServer *server = nullptr;
};

std::unique_ptr<MultiMouseBackend> create_multi_mouse_backend(MultiMouseServer *server);

} // namespace godot

#endif // MULTI_MOUSE_BACKEND_H
