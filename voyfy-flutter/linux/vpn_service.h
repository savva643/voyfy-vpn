#ifndef VPN_SERVICE_H_
#define VPN_SERVICE_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <string>
#include <memory>
#include <functional>

namespace voyfy {

class VpnService {
 public:
  static VpnService& GetInstance();

  // Initialize the VPN service and MethodChannel
  bool Initialize(FlMethodChannel* channel);

  // Connect to VPN with Hysteria2 YAML config
  bool Connect(const std::string& config);

  // Disconnect from VPN
  bool Disconnect();

  // Check if connected
  bool IsConnected() const;

  // Get current data usage from TUN interface stats
  void GetDataUsage(int64_t& received, int64_t& sent);

  // Set status callback
  void SetStatusCallback(std::function<void(const std::string&)> callback);

  // Get path to Hysteria2 binary (public for main.cc)
  std::string GetHysteria2Path();

  // Check that all required system tools are present.
  // Returns empty string if everything OK, otherwise a human-readable
  // comma-separated list of missing packages/utilities.
  std::string CheckDependencies();

 private:
  VpnService() = default;
  ~VpnService() = default;
  VpnService(const VpnService&) = delete;
  VpnService& operator=(const VpnService&) = delete;

  bool StartHysteria2(const std::string& config_path);
  bool StopHysteria2();
  bool RestoreRoutes();

  std::string GetConfigPath();

  FlMethodChannel* channel_ = nullptr;
  std::function<void(const std::string&)> status_callback_;

  bool connected_ = false;
  int64_t bytes_received_ = 0;
  int64_t bytes_sent_ = 0;

  GPid hysteria2_pid_ = 0;
  std::string tun_name_ = "hy2";
};

// Setup VPN MethodChannels on the given messenger.
// Call this after fl_register_plugins() in my_application.cc.
void SetupVpnMethodChannels(FlBinaryMessenger* messenger);

}  // namespace voyfy

#endif  // VPN_SERVICE_H_
