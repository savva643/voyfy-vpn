#include "tun_manager.h"

// Must define these BEFORE any includes
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600  // Windows Vista or later
#endif

// winsock2.h MUST be included BEFORE windows.h
#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>
#include <vector>
#include <sstream>
#include <filesystem>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")

TunManager* g_tunManager = nullptr;

// Helper to execute Windows command
static bool ExecCmd(const std::wstring& cmd) {
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    
    std::wstring fullCmd = L"cmd.exe /c " + cmd;
    
    BOOL result = CreateProcessW(nullptr, &fullCmd[0], nullptr, nullptr, FALSE,
                                 CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
    if (!result) {
        OutputDebugStringW((L"[TUN] Failed to execute: " + cmd + L"\n").c_str());
        return false;
    }
    
    WaitForSingleObject(pi.hProcess, 10000);
    DWORD exitCode;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    
    return exitCode == 0;
}

TunManager::TunManager() {}
TunManager::~TunManager() {
    CleanupRouting();
}

bool TunManager::SetupRouting(const std::string& vpnServerIP) {
    OutputDebugStringW(L"[TUN] SetupRouting started\n");
    
    // Wait for Xray to create TUN interface
    Sleep(2000);
    
    // Find the TUN interface
    if (!FindTunInterface()) {
        OutputDebugStringW(L"[TUN] Could not find TUN interface\n");
        // Continue anyway - Xray handles its own TUN
    }
    
    // Set DNS to Cloudflare (through TUN)
    SetInterfaceDNS(L"*", "1.1.1.1");
    
    // Exclude VPN server IP from VPN (to avoid routing loop)
    if (!vpnServerIP.empty()) {
        std::wstring wvpnIp(vpnServerIP.begin(), vpnServerIP.end());
        // Add route to VPN server through default gateway (not TUN)
        ExecCmd(L"route add " + wvpnIp + L" mask 255.255.255.255 0.0.0.0");
    }
    
    // Flush DNS cache
    FlushDNSCache();
    
    OutputDebugStringW(L"[TUN] Routing setup complete\n");
    return true;
}

void TunManager::CleanupRouting() {
    OutputDebugStringW(L"[TUN] CleanupRouting\n");
    
    // Remove custom routes we added
    for (const auto& route : addedRoutes_) {
        ExecCmd(L"route delete " + route);
    }
    addedRoutes_.clear();
    
    // Reset DNS
    SetInterfaceDNS(L"*", "dhcp");
    
    // Flush DNS
    FlushDNSCache();
}

std::wstring TunManager::GetTunInterfaceName() {
    return tunInterfaceName_;
}

bool TunManager::IsTunInterfacePresent() {
    return FindTunInterface();
}

bool TunManager::FindTunInterface() {
    // Xray creates interface named "VoyfyVPN" or similar
    // Try to find it by looking for interface with 10.x.x.x IP
    
    ULONG flags = GAA_FLAG_INCLUDE_PREFIX;
    ULONG family = AF_INET;
    ULONG bufferSize = 0;
    
    GetAdaptersAddresses(family, flags, nullptr, nullptr, &bufferSize);
    if (bufferSize == 0) return false;
    
    std::vector<BYTE> buffer(bufferSize);
    PIP_ADAPTER_ADDRESSES pAddresses = (PIP_ADAPTER_ADDRESSES)buffer.data();
    
    if (GetAdaptersAddresses(family, flags, nullptr, pAddresses, &bufferSize) != NO_ERROR) {
        return false;
    }
    
    for (PIP_ADAPTER_ADDRESSES pCurr = pAddresses; pCurr; pCurr = pCurr->Next) {
        // Check if this is TUN interface (usually has "TAP" or "TUN" in name, or 10.x IP)
        std::wstring friendlyName = pCurr->FriendlyName;
        
        for (PIP_ADAPTER_UNICAST_ADDRESS pUnicast = pCurr->FirstUnicastAddress; pUnicast; pUnicast = pUnicast->Next) {
            sockaddr_in* pAddr = (sockaddr_in*)pUnicast->Address.lpSockaddr;
            BYTE* ip = (BYTE*)&pAddr->sin_addr;
            
            // Check if IP starts with 10.0.0 (TUN subnet)
            if (ip[0] == 10 && ip[1] == 0 && ip[2] == 0) {
                tunInterfaceName_ = friendlyName;
                OutputDebugStringW((L"[TUN] Found TUN interface: " + friendlyName + L"\n").c_str());
                return true;
            }
        }
    }
    
    return false;
}

bool TunManager::AddRoute(const std::string& destination, int prefix, const std::string& gateway) {
    std::wstringstream ss;
    ss << L"route add ";
    ss << std::wstring(destination.begin(), destination.end());
    ss << L" mask ";
    
    // Calculate mask from prefix
    DWORD mask = 0;
    for (int i = 0; i < prefix; i++) {
        mask |= (0x80000000 >> i);
    }
    ss << ((mask >> 24) & 0xFF) << L"." << ((mask >> 16) & 0xFF) << L".";
    ss << ((mask >> 8) & 0xFF) << L"." << (mask & 0xFF);
    ss << L" " << std::wstring(gateway.begin(), gateway.end());
    
    if (ExecCmd(ss.str())) {
        addedRoutes_.push_back(std::wstring(destination.begin(), destination.end()));
        return true;
    }
    return false;
}

bool TunManager::DeleteRoute(const std::string& destination, int prefix, const std::string& gateway) {
    std::wstringstream ss;
    ss << L"route delete " << std::wstring(destination.begin(), destination.end());
    return ExecCmd(ss.str());
}

bool TunManager::ExecuteCommand(const std::wstring& cmd) {
    return ExecCmd(cmd);
}

bool TunManager::SetInterfaceMetric(const std::wstring& interfaceName, int metric) {
    std::wstringstream ss;
    ss << L"netsh interface ipv4 set interface \"" << interfaceName << L"\" metric=" << metric;
    return ExecCmd(ss.str());
}

bool TunManager::SetInterfaceDNS(const std::wstring& interfaceName, const std::string& dns) {
    std::wstringstream ss;
    if (dns == "dhcp") {
        ss << L"netsh interface ipv4 set dnsservers \"" << interfaceName << L"\" dhcp";
    } else {
        std::wstring wdns(dns.begin(), dns.end());
        ss << L"netsh interface ipv4 set dnsservers \"" << interfaceName << L"\" static " << wdns << L" primary";
    }
    return ExecCmd(ss.str());
}

// Global functions
bool InitializeTun() {
    if (!g_tunManager) {
        g_tunManager = new TunManager();
    }
    return true;
}

void CleanupTun() {
    if (g_tunManager) {
        delete g_tunManager;
        g_tunManager = nullptr;
    }
}

bool FlushDNSCache() {
    return ExecCmd(L"ipconfig /flushdns");
}

bool DisableIPv6Binding() {
    // Disable IPv6 binding to ensure IPv4 VPN works properly
    return ExecCmd(L"netsh interface ipv6 set privacy state=disabled");
}
