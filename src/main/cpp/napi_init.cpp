#include "napi/native_api.h"
#include <hilog/log.h>
#include <atomic>
#include <chrono>
#include <deque>
#include <mutex>
#include <string>

namespace {

constexpr char kSep = '\x1F';
constexpr size_t kMaxLines = 4000;

std::mutex g_mutex;
std::deque<std::string> g_buffer;
uint64_t g_total = 0;
uint64_t g_dropped = 0;
bool g_installed = false;
std::atomic<bool> g_enabled{true};
std::atomic<bool> g_captureAll{false};

uint64_t NowMs() {
    auto since = std::chrono::system_clock::now().time_since_epoch();
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(since).count());
}

void HilogCallback(const LogType type, const LogLevel level, const unsigned int domain, const char *tag,
                   const char *msg) {
    if (!g_enabled.load() || msg == nullptr) {
        return;
    }
    if (!g_captureAll.load() && type != LOG_APP) {
        return;
    }

    std::string line;
    line.reserve(160);
    line += std::to_string(NowMs());
    line += kSep;
    line += std::to_string(static_cast<int>(type));
    line += kSep;
    line += std::to_string(static_cast<int>(level));
    line += kSep;
    line += std::to_string(static_cast<unsigned int>(domain));
    line += kSep;
    line += (tag == nullptr ? "" : tag);
    line += kSep;
    line += msg;

    std::lock_guard<std::mutex> lock(g_mutex);
    g_total++;
    if (g_buffer.size() >= kMaxLines) {
        g_buffer.pop_front();
        g_dropped++;
    }
    g_buffer.push_back(std::move(line));
}

bool ReadBoolArg(napi_env env, napi_callback_info info, bool fallback) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        return fallback;
    }
    bool value = fallback;
    if (napi_get_value_bool(env, args[0], &value) != napi_ok) {
        return fallback;
    }
    return value;
}

napi_value Install(napi_env env, napi_callback_info info) {
    if (!g_installed) {
        OH_LOG_SetCallback(HilogCallback);
        g_installed = true;
    }
    napi_value result = nullptr;
    napi_get_boolean(env, g_installed, &result);
    return result;
}

napi_value SetEnabled(napi_env env, napi_callback_info info) {
    g_enabled.store(ReadBoolArg(env, info, true));
    napi_value result = nullptr;
    napi_get_boolean(env, g_enabled.load(), &result);
    return result;
}

// true: everything including system logs. false: only LOG_APP.
napi_value SetCaptureAll(napi_env env, napi_callback_info info) {
    g_captureAll.store(ReadBoolArg(env, info, false));
    napi_value result = nullptr;
    napi_get_boolean(env, g_captureAll.load(), &result);
    return result;
}

napi_value Drain(napi_env env, napi_callback_info info) {
    std::deque<std::string> local;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        local.swap(g_buffer);
    }

    napi_value array = nullptr;
    napi_create_array_with_length(env, local.size(), &array);
    uint32_t index = 0;
    for (const std::string &line : local) {
        napi_value item = nullptr;
        napi_create_string_utf8(env, line.c_str(), NAPI_AUTO_LENGTH, &item);
        napi_set_element(env, array, index, item);
        index++;
    }
    return array;
}

napi_value Stats(napi_env env, napi_callback_info info) {
    uint64_t total = 0;
    uint64_t dropped = 0;
    size_t pending = 0;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        total = g_total;
        dropped = g_dropped;
        pending = g_buffer.size();
    }

    napi_value array = nullptr;
    napi_create_array_with_length(env, 3, &array);
    napi_value v0 = nullptr;
    napi_value v1 = nullptr;
    napi_value v2 = nullptr;
    napi_create_double(env, static_cast<double>(total), &v0);
    napi_create_double(env, static_cast<double>(dropped), &v1);
    napi_create_double(env, static_cast<double>(pending), &v2);
    napi_set_element(env, array, 0, v0);
    napi_set_element(env, array, 1, v1);
    napi_set_element(env, array, 2, v2);
    return array;
}

} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"install", nullptr, Install, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setEnabled", nullptr, SetEnabled, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setCaptureAll", nullptr, SetCaptureAll, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"drain", nullptr, Drain, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stats", nullptr, Stats, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module debugPanelModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "portable_debug_panel",
    .nm_priv = ((void *)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterPortable_debug_panelModule(void) {
    napi_module_register(&debugPanelModule);
}
