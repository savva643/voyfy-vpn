#include "my_application.h"
#include "vpn_service.h"
#include <flutter_linux/flutter_linux.h>
#include <unistd.h>

static FlMethodChannel* vpn_channel = nullptr;
static FlMethodChannel* vpn_data_channel = nullptr;

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
    const gchar* method = fl_method_call_get_name(method_call);
    FlValue* args = fl_method_call_get_args(method_call);

    if (strcmp(method, "initialize") == 0) {
        voyfy::VpnService::GetInstance().Initialize(vpn_channel);
        fl_method_call_respond_success(method_call, fl_value_new_bool(TRUE), nullptr);
    }
    else if (strcmp(method, "connect") == 0) {
        FlValue* config_value = fl_value_lookup_string(args, "config");
        if (config_value) {
            const char* config = fl_value_get_string(config_value);
            bool result = voyfy::VpnService::GetInstance().Connect(config);
            fl_method_call_respond_success(method_call, fl_value_new_bool(result), nullptr);
        } else {
            fl_method_call_respond_error(method_call, "INVALID_ARGS", "Missing config", nullptr, nullptr);
        }
    }
    else if (strcmp(method, "disconnect") == 0) {
        bool result = voyfy::VpnService::GetInstance().Disconnect();
        fl_method_call_respond_success(method_call, fl_value_new_bool(result), nullptr);
    }
    else if (strcmp(method, "getStatus") == 0) {
        bool is_connected = voyfy::VpnService::GetInstance().IsConnected();
        const char* status = is_connected ? "connected" : "disconnected";
        fl_method_call_respond_success(method_call, fl_value_new_string(status), nullptr);
    }
    else if (strcmp(method, "ping") == 0) {
        fl_method_call_respond_success(method_call, fl_value_new_int(-1), nullptr);
    }
    else if (strcmp(method, "checkAndDownloadXray") == 0) {
        // Проверяем наличие xray в ожидаемых местах
        std::string xray_path = voyfy::VpnService::GetInstance().GetXrayPath();
        bool exists = !xray_path.empty() && access(xray_path.c_str(), X_OK) == 0;
        fl_method_call_respond_success(method_call, fl_value_new_bool(exists), nullptr);
    }
    else if (strcmp(method, "testConfig") == 0) {
        FlValue* config_value = fl_value_lookup_string(args, "config");
        if (config_value) {
            const char* config = fl_value_get_string(config_value);
            bool is_valid = config && strncmp(config, "vless://", 8) == 0;
            fl_method_call_respond_success(method_call, fl_value_new_bool(is_valid), nullptr);
        } else {
            fl_method_call_respond_success(method_call, fl_value_new_bool(false), nullptr);
        }
    }
    else {
        fl_method_call_respond_not_implemented(method_call, nullptr);
    }
}

static void register_plugins(FlPluginRegistry* registry) {
    FlPluginRegistrar* registrar = fl_plugin_registry_get_registrar_for_plugin(registry, "VpnService");
    FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);

    vpn_channel = fl_method_channel_new(messenger, "com.voyfy.vpn/linux",
                                        FL_METHOD_CODEC(fl_standard_method_codec_new()));
    fl_method_channel_set_method_call_handler(vpn_channel, method_call_cb,
                                              g_object_ref(registrar), g_object_unref);

    vpn_data_channel = fl_method_channel_new(messenger, "com.voyfy.vpn/linux_data",
                                             FL_METHOD_CODEC(fl_standard_method_codec_new()));
}

int main(int argc, char** argv) {
    g_autoptr(MyApplication) app = my_application_new();
    g_signal_connect(app, "register-plugins", G_CALLBACK(register_plugins), nullptr);
    return g_application_run(G_APPLICATION(app), argc, argv);
}