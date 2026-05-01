#include "vpn_service.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <glib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/if_tun.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <cstring>
#include <fstream>
#include <sstream>
#include <thread>
#include <chrono>

namespace voyfy {

VpnService& VpnService::GetInstance() {
  static VpnService instance;
  return instance;
}

bool VpnService::Initialize(FlMethodChannel* channel) {
  channel_ = channel;
  return true;
}

bool VpnService::Connect(const std::string& config) {
  if (connected_) {
    Disconnect();
  }

  // Save config to temp file
  std::string config_path = GetConfigPath();
  std::ofstream config_file(config_path);
  if (!config_file.is_open()) {
    return false;
  }
  config_file << config;
  config_file.close();

  // Setup TUN device
  if (!SetupTunDevice()) {
    return false;
  }

  // Configure routes
  if (!ConfigureRoutes()) {
    RestoreRoutes();
    StopXray();
    return false;
  }

  // Start Xray
  if (!StartXray(config_path)) {
    RestoreRoutes();
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
      
      // Send data usage update via channel
      if (channel_) {
        g_autoptr(FlValue) args = fl_value_new_map();
        fl_value_set_string_take(args, "bytesReceived", fl_value_new_int(bytes_received_));
        fl_value_set_string_take(args, "bytesSent", fl_value_new_int(bytes_sent_));
        fl_method_channel_invoke_method(channel_, "onDataUsageUpdated", args, nullptr, nullptr, nullptr);
      }
    }
  }).detach();

  return true;
}

bool VpnService::Disconnect() {
  if (!connected_) {
    return true;
  }

  if (status_callback_) {
    status_callback_("disconnecting");
  }

  RestoreRoutes();
  StopXray();
  
  if (tun_fd_ >= 0) {
    close(tun_fd_);
    tun_fd_ = -1;
  }

  connected_ = false;
  
  if (status_callback_) {
    status_callback_("disconnected");
  }

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

bool VpnService::StartXray(const std::string& config_path) {
  std::string xray_path = GetXrayPath();
  
  // Check if xray exists
  if (access(xray_path.c_str(), X_OK) != 0) {
    return false;
  }

  GPid pid;
  gchar* argv[] = {
    const_cast<gchar*>(xray_path.c_str()),
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

  xray_pid_ = pid;
  return true;
}

bool VpnService::StopXray() {
  if (xray_pid_ > 0) {
    kill(xray_pid_, SIGTERM);
    waitpid(xray_pid_, nullptr, 0);
    xray_pid_ = 0;
  }
  return true;
}

bool VpnService::SetupTunDevice() {
  // Create TUN device
  tun_fd_ = open("/dev/net/tun", O_RDWR);
  if (tun_fd_ < 0) {
    return false;
  }

  struct ifreq ifr;
  memset(&ifr, 0, sizeof(ifr));
  ifr.ifr_flags = IFF_TUN | IFF_NO_PI;
  strncpy(ifr.ifr_name, "tun_voyfy", IFNAMSIZ);

  if (ioctl(tun_fd_, TUNSETIFF, &ifr) < 0) {
    close(tun_fd_);
    tun_fd_ = -1;
    return false;
  }

  tun_name_ = ifr.ifr_name;

  // Configure TUN interface
  std::string cmd = "ip link set " + tun_name_ + " up";
  system(cmd.c_str());
  
  cmd = "ip addr add 10.0.0.2/24 dev " + tun_name_;
  system(cmd.c_str());

  return true;
}

bool VpnService::ConfigureRoutes() {
  // Add default route through TUN
  std::string cmd = "ip route add default dev " + tun_name_ + " metric 100";
  int ret = system(cmd.c_str());
  return ret == 0;
}

bool VpnService::RestoreRoutes() {
  // Remove TUN routes
  if (!tun_name_.empty()) {
    std::string cmd = "ip route del default dev " + tun_name_ + " 2>/dev/null || true";
    system(cmd.c_str());
  }
  return true;
}

std::string VpnService::GetXrayPath() {
  // Get executable directory
  gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (!exe_path) {
    return "";
  }
  
  gchar* dir = g_path_get_dirname(exe_path);
  g_free(exe_path);
  
  std::string xray_path = std::string(dir) + "/xray";
  g_free(dir);
  
  return xray_path;
}

std::string VpnService::GetConfigPath() {
  return "/tmp/voyfy_config.json";
}

}  // namespace voyfy
