#ifndef VPN_SERVICE_H_
#define VPN_SERVICE_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <string>
#include <memory>

namespace voyfy {

class VpnService {
 public:
  static VpnService& GetInstance();
  
  // Initialize the VPN service and MethodChannel
  bool Initialize(FlMethodChannel* channel);
  
  // Connect to VPN with Xray config
  bool Connect(const std::string& config);
  
  // Disconnect from VPN
  bool Disconnect();
  
  // Check if connected
  bool IsConnected() const;
  
  // Get current data usage
  void GetDataUsage(int64_t& received, int64_t& sent);
  
  // Set status callback
  void SetStatusCallback(std::function<void(const std::string&)> callback);

 private:
  VpnService() = default;
  ~VpnService() = default;
  VpnService(const VpnService&) = delete;
  VpnService& operator=(const VpnService&) = delete;
  
  bool StartXray(const std::string& config);
  bool StopXray();
  bool SetupTunDevice();
  bool ConfigureRoutes();
  bool RestoreRoutes();
  
  std::string GetXrayPath();
  std::string GetConfigPath();
  
  FlMethodChannel* channel_ = nullptr;
  std::function<void(const std::string&)> status_callback_;
  
  bool connected_ = false;
  int64_t bytes_received_ = 0;
  int64_t bytes_sent_ = 0;
  
  GPid xray_pid_ = 0;
  int tun_fd_ = -1;
  std::string tun_name_;
};

}  // namespace voyfy

#endif  // VPN_SERVICE_H_
