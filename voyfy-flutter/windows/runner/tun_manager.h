#pragma once

#include <string>
#include <vector>

// Simple Windows routing/DNS manager for Xray TUN
// Xray creates its own TUN interface, we just configure Windows routing

class TunManager {
public:
    TunManager();
    ~TunManager();

    // Setup VPN routing - call after Xray starts
    bool SetupRouting(const std::string& vpnServerIP);
    
    // Cleanup all routes and settings
    void CleanupRouting();
    
    // Get TUN interface name (Xray creates "VoyfyVPN" or similar)
    std::wstring GetTunInterfaceName();
    
    // Check if Xray TUN interface exists
    bool IsTunInterfacePresent();

private:
    std::wstring tunInterfaceName_;
    std::vector<std::wstring> addedRoutes_;
    
    // Find TUN interface by name pattern
    bool FindTunInterface();
    
    // Route helpers
    bool AddRoute(const std::string& destination, int prefix, const std::string& gateway);
    bool DeleteRoute(const std::string& destination, int prefix, const std::string& gateway);
    
    // Execute Windows command
    bool ExecuteCommand(const std::wstring& cmd);
    
    // netsh helpers
    bool SetInterfaceMetric(const std::wstring& interfaceName, int metric);
    bool SetInterfaceDNS(const std::wstring& interfaceName, const std::string& dns);
};

// Global instance
extern TunManager* g_tunManager;

// Initialize and cleanup
bool InitializeTun();
void CleanupTun();

// Helper functions
bool FlushDNSCache();
bool DisableIPv6Binding();
