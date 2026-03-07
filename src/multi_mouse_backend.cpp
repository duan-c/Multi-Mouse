#include "multi_mouse_backend.h"

#include "multi_mouse_server.h"

#ifdef _WIN32
#include "platform/windows/multi_mouse_backend_windows.h"
#endif

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
        info.name = String("Placeholder Mouse");
        info.system_id = String("stub");
        info.transport = String("none");
        server->register_device(info);
    }
};

std::unique_ptr<MultiMouseBackend> create_multi_mouse_backend(MultiMouseServer *server) {
#ifdef _WIN32
    return std::make_unique<MultiMouseBackendWindows>(server);
#else
    return std::make_unique<StubBackend>(server);
#endif
}

} // namespace godot
