#include "multi_mouse_backend.h"

#include "multi_mouse_server.h"

#include <memory>

namespace godot {

class StubBackend : public MultiMouseBackend {
public:
    using MultiMouseBackend::MultiMouseBackend;

    void start() override {
        if (!server) {
            return;
        }
        MultiMouseDeviceInfo info;
        info.name = "Placeholder Mouse";
        info.system_id = "stub";
        info.transport = "none";
        server->register_device(info);
    }
};

std::unique_ptr<MultiMouseBackend> create_multi_mouse_backend(MultiMouseServer *server) {
    return std::make_unique<StubBackend>(server);
}

} // namespace godot
