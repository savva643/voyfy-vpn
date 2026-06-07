#include "vpn_service.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <glib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <cstring>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <thread>
#include <chrono>
#include <vector>

namespace voyfy {

namespace {

// Check if the Hysteria2 binary already has cap_net_admin capability
bool HasCapNetAdmin(const std::string& path) {
  std::string cmd = "getcap \"" + path + "\" 2>/dev/null | grep cap_net_admin > /dev/null";
  int ret = std::system(cmd.c_str());
  return ret == 0;
}

// Request root password via pkexec GUI dialog (like UAC on Windows)
// to grant cap_net_admin capability to the Hysteria2 binary.
// Returns true if user entered password and setcap succeeded.
bool GrantCapNetAdmin(const std::string& path) {
  std::string cmd = "pkexec setcap cap_net_admin=+ep \"" + path + "\"";
  int ret = std::system(cmd.c_str());
  return ret == 0;
}

// Check if a process with given PID is still alive
bool IsProcessAlive(GPid pid) {
  if (pid <= 0) return false;
  return kill(pid, 0) == 0;
}

}  // namespace

VpnService& VpnService::GetInstance() {
  static VpnService instance;
  return instance;
}

bool VpnService::Initialize(FlMethodChannel* channel) {
  channel_ = channel;
  return true;
}

bool VpnService::Connect(const std::string& config, const std::string& server_ip) {
  if (connected_) {
    Disconnect();
  }

  server_ip_ = server_ip;

  // Save Hysteria2 YAML config to temp file
  std::string config_path = GetConfigPath();
  std::ofstream config_file(config_path);
  if (!config_file.is_open()) {
    return false;
  }
  config_file << config;
  config_file.close();

  // Locate Hysteria2 binary
  std::string hysteria2_path = GetHysteria2Path();
  if (access(hysteria2_path.c_str(), X_OK) != 0) {
    return false;
  }

  // Ensure Hysteria2 has CAP_NET_ADMIN so it can create TUN without root.
  // If not, show a GUI password dialog (pkexec) — same UX as Windows UAC.
  if (!HasCapNetAdmin(hysteria2_path)) {
    if (!GrantCapNetAdmin(hysteria2_path)) {
      // User cancelled or password incorrect
      return false;
    }
  }

  // Start Hysteria2 (TUN created, but routes managed manually)
  if (!StartHysteria2(config_path)) {
    return false;
  }

  // Save current default route so we can restore it on disconnect
  SaveOriginalRoute();

  // Setup VPN routes via pkexec (redirect all traffic through TUN)
  if (!ConfigureRoutes(server_ip_)) {
    StopHysteria2();
    return false;
  }

  connected_ = true;
  if (status_callback_) {
    status_callback_("connected");
  }

  // Start data monitoring thread
  std::thread([this]() {
    while (connected_) {
      std::this_thread::sleep_for(std::chrono::seconds(1));
      // Update data usage from TUN interface stats
      GetDataUsage(bytes_received_, bytes_sent_);

      // Send data usage update via channel (must be on platform thread)
      if (channel_) {
        struct DataUsagePayload {
          FlMethodChannel* channel;
          int64_t received;
          int64_t sent;
        };
        auto* payload = new DataUsagePayload{channel_, bytes_received_, bytes_sent_};
        g_idle_add([](gpointer user_data) -> gboolean {
          auto* p = static_cast<DataUsagePayload*>(user_data);
          g_autoptr(FlValue) args = fl_value_new_map();
          fl_value_set_string_take(args, "bytesReceived", fl_value_new_int(p->received));
          fl_value_set_string_take(args, "bytesSent", fl_value_new_int(p->sent));
          fl_method_channel_invoke_method(p->channel, "onDataUsageUpdated", args, nullptr, nullptr, nullptr);
          delete p;
          return G_SOURCE_REMOVE;
        }, payload);
      }
    }
  }).detach();

  return true;
}

bool VpnService::Disconnect() {
  g_print("VPN C++: Disconnect() called, connected_=%d\n", connected_);

  if (status_callback_) {
    status_callback_("disconnecting");
  }

  StopHysteria2();
  RestoreRoutes();

  connected_ = false;

  if (status_callback_) {
    status_callback_("disconnected");
  }

  g_print("VPN C++: Disconnect() finished\n");
  return true;
}

bool VpnService::IsConnected() const {
  return connected_;
}

void VpnService::GetDataUsage(int64_t& received, int64_t& sent) {
  // Read from /sys/class/net/{tun_name}/statistics/
  if (!tun_name_.empty()) {
    std::string rx_path = "/sys/class/net/" + tun_name_ + "/statistics/rx_bytes";
    std::string tx_path = "/sys/class/net/" + tun_name_ + "/statistics/tx_bytes";

    std::ifstream rx_file(rx_path);
    std::ifstream tx_file(tx_path);

    if (rx_file.is_open()) {
      rx_file >> received;
      rx_file.close();
    }

    if (tx_file.is_open()) {
      tx_file >> sent;
      tx_file.close();
    }
  }
}

void VpnService::SetStatusCallback(std::function<void(const std::string&)> callback) {
  status_callback_ = callback;
}

bool VpnService::StartHysteria2(const std::string& config_path) {
  std::string hysteria2_path = GetHysteria2Path();

  // Check if Hysteria2 exists
  if (access(hysteria2_path.c_str(), X_OK) != 0) {
    return false;
  }

  GPid pid;
  gchar* argv[] = {
    const_cast<gchar*>(hysteria2_path.c_str()),
    const_cast<gchar*>("-c"),
    const_cast<gchar*>(config_path.c_str()),
    nullptr
  };

  GError* error = nullptr;
  gboolean spawned = g_spawn_async(
    nullptr,  // working directory
    argv,
    nullptr,  // envp
    G_SPAWN_DO_NOT_REAP_CHILD,
    nullptr,  // child setup
    nullptr,  // user data
    &pid,
    &error
  );

  if (!spawned) {
    if (error) {
      g_error_free(error);
    }
    return false;
  }

  hysteria2_pid_ = pid;

  // Give Hysteria2 a moment to start up and create the TUN device
  std::this_thread::sleep_for(std::chrono::seconds(3));

  // Verify the process actually survived (not crashed due to missing privileges)
  if (!IsProcessAlive(hysteria2_pid_)) {
    hysteria2_pid_ = 0;
    return false;
  }

  return true;
}

bool VpnService::StopHysteria2() {
  if (hysteria2_pid_ > 0) {
    // Send SIGTERM first
    kill(hysteria2_pid_, SIGTERM);

    // Wait up to 3 seconds for graceful shutdown
    bool terminated = false;
    for (int i = 0; i < 30; ++i) {
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
      int status = 0;
      pid_t result = waitpid(hysteria2_pid_, &status, WNOHANG);
      if (result == hysteria2_pid_) {
        terminated = true;
        break;
      }
    }

    // Force kill if still alive
    if (!terminated && kill(hysteria2_pid_, 0) == 0) {
      kill(hysteria2_pid_, SIGKILL);
      waitpid(hysteria2_pid_, nullptr, 0);
    }

    hysteria2_pid_ = 0;
  }

  // Fallback: also kill any stray hysteria2 processes
  std::system("pkill -f 'hysteria2 -c /tmp/voyfy_hysteria2.yaml' 2>/dev/null || true");
  return true;
}

bool VpnService::SaveOriginalRoute() {
  g_print("VPN C++: SaveOriginalRoute() called\n");
  FILE* pipe = popen("ip route show default", "r");
  if (!pipe) {
    g_print("VPN C++: popen failed\n");
    return false;
  }
  char buffer[256];
  if (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    original_route_ = buffer;
    original_route_.erase(original_route_.find_last_not_of("\n\r") + 1);
    g_print("VPN C++: Saved original route: %s\n", original_route_.c_str());

    // Parse gateway and dev
    size_t via_pos = original_route_.find("via ");
    size_t dev_pos = original_route_.find("dev ");
    if (via_pos != std::string::npos) {
      size_t start = via_pos + 4;
      size_t end = original_route_.find(' ', start);
      original_gateway_ = original_route_.substr(start, end - start);
    }
    if (dev_pos != std::string::npos) {
      size_t start = dev_pos + 4;
      size_t end = original_route_.find(' ', start);
      original_dev_ = original_route_.substr(start, end - start);
    }
    g_print("VPN C++: Parsed gateway=%s dev=%s\n", original_gateway_.c_str(), original_dev_.c_str());
  } else {
    g_print("VPN C++: No default route found\n");
  }
  pclose(pipe);
  return true;
}

bool VpnService::ConfigureRoutes(const std::string& server_ip) {
  g_print("VPN C++: ConfigureRoutes() called server_ip=%s\n", server_ip.c_str());

  std::string script;
  // 1. Host route to VPN server via original gateway (so Hysteria2 can reach server)
  if (!server_ip.empty() && !original_gateway_.empty() && !original_dev_.empty()) {
    script += "ip route add " + server_ip + " via " + original_gateway_ + " dev " + original_dev_ + " 2>/dev/null || true; ";
  }
  // 2. Assign IP to TUN
  script += "ip addr add 172.16.0.2/30 dev " + tun_name_ + " 2>/dev/null || true; ";
  // 3. Bring TUN up
  script += "ip link set " + tun_name_ + " up; ";
  // 4. Remove old default route
  script += "ip route del default 2>/dev/null || true; ";
  // 5. Add new default route through TUN
  script += "ip route add default dev " + tun_name_ + " metric 1";

  std::string cmd = "pkexec bash -c '" + script + "'";
  g_print("VPN C++: %s\n", cmd.c_str());
  int ret = std::system(cmd.c_str());
  g_print("VPN C++: pkexec returned %d\n", ret);

  // Verify state
  g_print("VPN C++: Current TUN state:\n");
  std::system("ip addr show hy2");
  g_print("VPN C++: Current default route:\n");
  std::system("ip route show default");

  return ret == 0;
}

bool VpnService::RestoreRoutes() {
  g_print("VPN C++: RestoreRoutes() called, original_route=%s\n", original_route_.c_str());

  std::string script;
  // 1. Remove VPN default route
  script += "ip route del default dev " + tun_name_ + " 2>/dev/null || true; ";
  // 2. Restore original default route
  if (!original_gateway_.empty() && !original_dev_.empty()) {
    script += "ip route add default via " + original_gateway_ + " dev " + original_dev_ + "; ";
    // 3. Remove host route to server
    if (!server_ip_.empty()) {
      script += "ip route del " + server_ip_ + " 2>/dev/null || true";
    }
  }

  std::string cmd = "pkexec bash -c '" + script + "'";
  g_print("VPN C++: %s\n", cmd.c_str());
  std::system(cmd.c_str());

  return true;
}

std::string VpnService::GetHysteria2Path() {
  // Try multiple possible locations for Hysteria2 binary
  const char* home = g_getenv("HOME");
  std::vector<std::string> possible_paths;

  // 1. Application support directory (where Dart Hysteria2Downloader saves it)
  //    path_provider uses g_get_user_data_dir() + app_id on Linux.
  //    Common locations: ~/.local/share/Voyfy/bin/hysteria2
  //                    ~/.local/share/com.keeppixel.voyfy/bin/hysteria2
  if (home) {
    possible_paths.push_back(std::string(home) + "/.local/share/Voyfy/bin/hysteria2");
    possible_paths.push_back(std::string(home) + "/.local/share/com.keeppixel.voyfy/bin/hysteria2");
  }

  // 2. Same directory as executable
  gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path) {
    gchar* dir = g_path_get_dirname(exe_path);
    g_free(exe_path);
    possible_paths.push_back(std::string(dir) + "/hysteria2");
    g_free(dir);
  }

  // 3. ~/bin/hysteria2
  if (home) {
    possible_paths.push_back(std::string(home) + "/bin/hysteria2");
  }

  // 4. System paths
  possible_paths.push_back("/usr/local/bin/hysteria2");
  possible_paths.push_back("/usr/bin/hysteria2");
  possible_paths.push_back("/opt/voyfy/hysteria2");

  // Find first existing hysteria2
  for (const auto& path : possible_paths) {
    if (access(path.c_str(), X_OK) == 0) {
      return path;
    }
  }

  // Return default if not found
  return possible_paths.empty() ? "" : possible_paths[0];
}

std::string VpnService::GetConfigPath() {
  return "/tmp/voyfy_hysteria2.yaml";
}

std::string VpnService::CheckDependencies() {
  struct DepCheck {
    const char* cmd;
    const char* pkg;
  };
  static const DepCheck deps[] = {
    {"which pkexec  >/dev/null 2>&1", "policykit-1 / polkit"},
    {"which setcap  >/dev/null 2>&1", "libcap2-bin / libcap"},
    {"which getcap  >/dev/null 2>&1", "libcap2-bin / libcap"},
    {"which ip      >/dev/null 2>&1", "iproute2"},
    {"which pkill   >/dev/null 2>&1", "procps / psmisc"},
  };

  std::vector<std::string> missing;
  for (const auto& d : deps) {
    if (std::system(d.cmd) != 0) {
      missing.emplace_back(d.pkg);
    }
  }

  if (missing.empty()) {
    return "";
  }
  std::string result = "Missing system utilities: ";
  for (size_t i = 0; i < missing.size(); ++i) {
    if (i > 0) result += ", ";
    result += missing[i];
  }
  return result;
}

static FlMethodChannel* g_vpn_channel = nullptr;
static FlMethodChannel* g_vpn_data_channel = nullptr;

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                          gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "initialize") == 0) {
    VpnService::GetInstance().Initialize(g_vpn_channel);
    fl_method_call_respond_success(method_call, fl_value_new_bool(TRUE), nullptr);
  } else if (strcmp(method, "connect") == 0) {
    FlValue* config_value = fl_value_lookup_string(args, "config");
    FlValue* server_ip_value = fl_value_lookup_string(args, "serverIp");
    if (config_value) {
      const char* config = fl_value_get_string(config_value);
      const char* server_ip = server_ip_value ? fl_value_get_string(server_ip_value) : "";
      bool result = VpnService::GetInstance().Connect(config, server_ip);
      fl_method_call_respond_success(method_call, fl_value_new_bool(result), nullptr);
    } else {
      fl_method_call_respond_error(method_call, "INVALID_ARGS", "Missing config", nullptr, nullptr);
    }
  } else if (strcmp(method, "disconnect") == 0) {
    g_print("VPN C++: method_call_cb disconnect\n");
    bool result = VpnService::GetInstance().Disconnect();
    fl_method_call_respond_success(method_call, fl_value_new_bool(result), nullptr);
  } else if (strcmp(method, "getStatus") == 0) {
    bool is_connected = VpnService::GetInstance().IsConnected();
    const char* status = is_connected ? "connected" : "disconnected";
    fl_method_call_respond_success(method_call, fl_value_new_string(status), nullptr);
  } else if (strcmp(method, "ping") == 0) {
    fl_method_call_respond_success(method_call, fl_value_new_int(-1), nullptr);
  } else if (strcmp(method, "checkAndDownloadXray") == 0) {
    std::string hysteria2_path = VpnService::GetInstance().GetHysteria2Path();
    bool exists = !hysteria2_path.empty() && access(hysteria2_path.c_str(), X_OK) == 0;
    fl_method_call_respond_success(method_call, fl_value_new_bool(exists), nullptr);
  } else if (strcmp(method, "checkDependencies") == 0) {
    std::string missing = VpnService::GetInstance().CheckDependencies();
    if (missing.empty()) {
      fl_method_call_respond_success(method_call, fl_value_new_string(""), nullptr);
    } else {
      fl_method_call_respond_success(method_call, fl_value_new_string(missing.c_str()), nullptr);
    }
  } else if (strcmp(method, "testConfig") == 0) {
    FlValue* config_value = fl_value_lookup_string(args, "config");
    if (config_value) {
      const char* config = fl_value_get_string(config_value);
      bool is_valid = config && strlen(config) > 0;
      fl_method_call_respond_success(method_call, fl_value_new_bool(is_valid), nullptr);
    } else {
      fl_method_call_respond_success(method_call, fl_value_new_bool(false), nullptr);
    }
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

void SetupVpnMethodChannels(FlBinaryMessenger* messenger) {
  g_vpn_channel = fl_method_channel_new(
      messenger, "com.voyfy.vpn/linux",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(g_vpn_channel, method_call_cb,
                                           nullptr, nullptr);

  g_vpn_data_channel = fl_method_channel_new(
      messenger, "com.voyfy.vpn/linux_data",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
}

}  // namespace voyfy
