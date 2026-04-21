#include "tun_manager.h"
#include <windows.h>
#include <netioapi.h>
#include <iphlpapi.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream>
#include <sstream>
#include <iomanip>
#include <shlobj.h>

static bool FileExists(const std::wstring& path) {
    DWORD attribs = GetFileAttributesW(path.c_str());
    return (attribs != INVALID_FILE_ATTRIBUTES && !(attribs & FILE_ATTRIBUTE_DIRECTORY));
}

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "ole32.lib")

TunManager* g_tunManager = nullptr;

// External function from vpn_service.cpp
extern bool ExecuteCommand(const std::wstring& cmd);

// Helper to convert IP string to bytes
bool StringToIPv4(const std::string& ip, BYTE* outBytes) {
    int parts[4];
    if (sscanf_s(ip.c_str(), "%d.%d.%d.%d", &parts[0], &parts[1], &parts[2], &parts[3]) == 4) {
        for (int i = 0; i < 4; i++) {
            if (parts[i] < 0 || parts[i] > 255) return false;
            outBytes[i] = (BYTE)parts[i];
        }
        return true;
    }
    return false;
}

TunManager::TunManager()
    : wintunDll_(nullptr), adapter_(nullptr), session_(nullptr),
      WintunCreateAdapter_(nullptr), WintunCloseAdapter_(nullptr),
      WintunStartSession_(nullptr), WintunEndSession_(nullptr),
      WintunGetReadWaitEvent_(nullptr), WintunReceivePacket_(nullptr),
      WintunReleaseReceivePacket_(nullptr), WintunAllocateSendPacket_(nullptr),
      WintunSendPacket_(nullptr), WintunGetRunningDriverVersion_(nullptr),
      interfaceIndex_(0) {
}

TunManager::~TunManager() {
    EndSession();
    CloseAdapter();
    UnloadWintunDll();
}

bool TunManager::LoadWintunDll() {
    // Get app data directory
    wchar_t path[MAX_PATH];
    if (!SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, 0, path))) {
        OutputDebugStringW(L"[TUN] Failed to get app data path\n");
        return false;
    }
    
    std::wstring dllPath = std::wstring(path) + L"\\VoyfyVPN\\wintun.dll";
    
    // Check if wintun.dll exists
    if (!FileExists(dllPath)) {
        OutputDebugStringW((L"[TUN] wintun.dll not found at: " + dllPath + L"\n").c_str());
        
        // Try same directory as exe
        dllPath = L"wintun.dll";
        if (!FileExists(dllPath)) {
            OutputDebugStringW(L"[TUN] wintun.dll not found in current directory either\n");
            return false;
        }
    }
    
    wintunDll_ = LoadLibraryW(dllPath.c_str());
    if (!wintunDll_) {
        DWORD err = GetLastError();
        OutputDebugStringW((L"[TUN] Failed to load wintun.dll, error: " + std::to_wstring(err) + L"\n").c_str());
        return false;
    }
    
    // Load functions
    WintunCreateAdapter_ = (WintunCreateAdapterFunc)GetProcAddress(wintunDll_, "WintunCreateAdapter");
    WintunCloseAdapter_ = (WintunCloseAdapterFunc)GetProcAddress(wintunDll_, "WintunCloseAdapter");
    WintunStartSession_ = (WintunStartSessionFunc)GetProcAddress(wintunDll_, "WintunStartSession");
    WintunEndSession_ = (WintunEndSessionFunc)GetProcAddress(wintunDll_, "WintunEndSession");
    WintunGetReadWaitEvent_ = (WintunGetReadWaitEventFunc)GetProcAddress(wintunDll_, "WintunGetReadWaitEvent");
    WintunReceivePacket_ = (WintunReceivePacketFunc)GetProcAddress(wintunDll_, "WintunReceivePacket");
    WintunReleaseReceivePacket_ = (WintunReleaseReceivePacketFunc)GetProcAddress(wintunDll_, "WintunReleaseReceivePacket");
    WintunAllocateSendPacket_ = (WintunAllocateSendPacketFunc)GetProcAddress(wintunDll_, "WintunAllocateSendPacket");
    WintunSendPacket_ = (WintunSendPacketFunc)GetProcAddress(wintunDll_, "WintunSendPacket");
    WintunGetRunningDriverVersion_ = (WintunGetRunningDriverVersionFunc)GetProcAddress(wintunDll_, "WintunGetRunningDriverVersion");
    
    if (!WintunCreateAdapter_ || !WintunCloseAdapter_ || !WintunStartSession_ ||
        !WintunEndSession_ || !WintunGetReadWaitEvent_ || !WintunReceivePacket_ ||
        !WintunReleaseReceivePacket_ || !WintunAllocateSendPacket_ || !WintunSendPacket_) {
        OutputDebugStringW(L"[TUN] Failed to load all required WinTun functions\n");
        UnloadWintunDll();
        return false;
    }
    
    // Log version
    DWORD version = WintunGetRunningDriverVersion_ ? WintunGetRunningDriverVersion_() : 0;
    OutputDebugStringW((L"[TUN] WinTun driver version: " + std::to_wstring(version) + L"\n").c_str());
    
    return true;
}

void TunManager::UnloadWintunDll() {
    if (wintunDll_) {
        FreeLibrary(wintunDll_);
        wintunDll_ = nullptr;
    }
}

bool TunManager::Initialize() {
    return LoadWintunDll();
}

bool TunManager::CreateAdapter(const std::wstring& name) {
    if (!wintunDll_) {
        OutputDebugStringW(L"[TUN] WinTun not loaded\n");
        return false;
    }
    
    // Close existing adapter
    if (adapter_) {
        WintunCloseAdapter_(adapter_);
        adapter_ = nullptr;
    }
    
    adapterName_ = name;
    
    // Create adapter with unique GUID
    GUID adapterGuid;
    CoCreateGuid(&adapterGuid);
    
    adapter_ = WintunCreateAdapter_(adapterName_.c_str(), L"VoyfyVPN", &adapterGuid);
    if (!adapter_) {
        DWORD err = GetLastError();
        OutputDebugStringW((L"[TUN] Failed to create adapter, error: " + std::to_wstring(err) + L"\n").c_str());
        return false;
    }
    
    OutputDebugStringW((L"[TUN] Adapter created: " + adapterName_ + L"\n").c_str());
    
    // Get interface index
    GetInterfaceIndex();
    
    return true;
}

void TunManager::CloseAdapter() {
    if (adapter_ && WintunCloseAdapter_) {
        WintunCloseAdapter_(adapter_);
        adapter_ = nullptr;
    }
}

bool TunManager::StartSession() {
    if (!adapter_) {
        OutputDebugStringW(L"[TUN] No adapter to start session\n");
        return false;
    }
    
    session_ = WintunStartSession_(adapter_, 0x400000); // 4MB ring buffer
    if (!session_) {
        DWORD err = GetLastError();
        OutputDebugStringW((L"[TUN] Failed to start session, error: " + std::to_wstring(err) + L"\n").c_str());
        return false;
    }
    
    OutputDebugStringW(L"[TUN] Session started\n");
    return true;
}

void TunManager::EndSession() {
    if (session_ && WintunEndSession_) {
        WintunEndSession_(session_);
        session_ = nullptr;
    }
}

bool TunManager::GetInterfaceIndex() {
    if (adapterName_.empty()) return false;
    
    // Use netsh to get interface index
    // This is a simplified version - in production would use proper APIs
    MIB_IFTABLE* ifTable = nullptr;
    DWORD dwSize = 0;
    
    if (GetIfTable(ifTable, &dwSize, FALSE) == ERROR_INSUFFICIENT_BUFFER) {
        ifTable = (MIB_IFTABLE*)malloc(dwSize);
    }
    
    if (GetIfTable(ifTable, &dwSize, FALSE) == NO_ERROR) {
        for (DWORD i = 0; i < ifTable->dwNumEntries; i++) {
            MIB_IFROW& row = ifTable->table[i];
            char name[256];
            WideCharToMultiByte(CP_ACP, 0, (wchar_t*)row.wszName, -1, name, 256, nullptr, nullptr);
            
            std::wstring wname((wchar_t*)row.wszName);
            if (wname.find(adapterName_) != std::wstring::npos) {
                interfaceIndex_ = row.dwIndex;
                break;
            }
        }
    }
    
    if (ifTable) free(ifTable);
    
    // Alternative: use netsh to find interface name
    std::wstringstream ss;
    ss << L"interface ip show interface name=\"" << adapterName_ << L"\"";
    ExecuteNetsh(ss.str());
    
    return interfaceIndex_ != 0;
}

bool TunManager::ExecuteNetsh(const std::wstring& args) {
    std::wstring cmd = L"netsh " + args;
    return ExecuteCommand(cmd);
}

bool TunManager::ConfigureInterface(const std::string& ip, int prefixLength, const std::string& gateway) {
    if (adapterName_.empty()) {
        OutputDebugStringW(L"[TUN] No adapter name\n");
        return false;
    }
    
    // Convert IP strings to wide
    std::wstring wip(ip.begin(), ip.end());
    std::wstring wgateway(gateway.begin(), gateway.end());
    
    // Set IP address
    std::wstringstream ss;
    ss << L"interface ip set address name=\"" << adapterName_ 
       << L"\" static " << wip << L" " << prefixLength;
    
    if (!ExecuteNetsh(ss.str())) {
        OutputDebugStringW(L"[TUN] Failed to set IP address\n");
        return false;
    }
    
    // Set gateway if provided
    if (!gateway.empty()) {
        ss.str(L"");
        ss << L"interface ip add address name=\"" << adapterName_ 
           << L"\" gateway=" << wgateway << L" gwmetric=1";
        ExecuteNetsh(ss.str());
    }
    
    OutputDebugStringW((L"[TUN] Interface configured: " + wip + L"/" + std::to_wstring(prefixLength) + L"\n").c_str());
    return true;
}

bool TunManager::AddRoute(const std::string& destination, int prefix, const std::string& gateway) {
    if (adapterName_.empty()) return false;
    
    std::wstring wdest(destination.begin(), destination.end());
    std::wstring wgateway(gateway.begin(), gateway.end());
    
    // Delete existing route first
    std::wstringstream ss;
    ss << L"interface ip delete route " << wdest << L"/" << prefix 
       << L" \"" << adapterName_ << L"\" " << wgateway;
    ExecuteNetsh(ss.str()); // Ignore failure
    
    // Add route
    ss.str(L"");
    ss << L"interface ip add route " << wdest << L"/" << prefix 
       << L" \"" << adapterName_ << L"\" " << wgateway << L" metric=1";
    
    if (!ExecuteNetsh(ss.str())) {
        OutputDebugStringW((L"[TUN] Failed to add route to " + wdest + L"\n").c_str());
        return false;
    }
    
    return true;
}

bool TunManager::SetDNS(const std::string& dns) {
    if (adapterName_.empty()) return false;
    
    std::wstring wdns(dns.begin(), dns.end());
    
    // Set primary DNS
    std::wstringstream ss;
    ss << L"interface ip set dns name=\"" << adapterName_ 
       << L"\" static " << wdns << L" primary";
    
    if (!ExecuteNetsh(ss.str())) {
        OutputDebugStringW(L"[TUN] Failed to set DNS\n");
        return false;
    }
    
    return true;
}

bool TunManager::SetMetric(int metric) {
    if (adapterName_.empty()) return false;
    
    std::wstringstream ss;
    ss << L"interface ip set interface name=\"" << adapterName_ 
       << L"\" metric=" << metric;
    
    return ExecuteNetsh(ss.str());
}

bool TunManager::ReadPacket(BYTE* buffer, DWORD* size) {
    if (!session_) return false;
    return WintunReceivePacket_(session_, buffer, size);
}

bool TunManager::WritePacket(const BYTE* data, DWORD size) {
    if (!session_) return false;
    
    BYTE* packet = WintunAllocateSendPacket_(session_, size);
    if (!packet) return false;
    
    memcpy(packet, data, size);
    WintunSendPacket_(session_, packet);
    return true;
}

// Global functions
bool InitializeTun() {
    if (!g_tunManager) {
        g_tunManager = new TunManager();
    }
    return g_tunManager->Initialize();
}

void CleanupTun() {
    if (g_tunManager) {
        delete g_tunManager;
        g_tunManager = nullptr;
    }
}

bool FlushDNSCache() {
    return ExecuteCommand(L"ipconfig /flushdns");
}

bool EnableIPForwarding() {
    // Enable IP forwarding via registry
    HKEY hKey;
    DWORD value = 1;
    
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, 
        L"SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters",
        0, KEY_WRITE, &hKey) == ERROR_SUCCESS) {
        RegSetValueExW(hKey, L"IPEnableRouter", 0, REG_DWORD, 
                       (BYTE*)&value, sizeof(value));
        RegCloseKey(hKey);
    }
    
    return true;
}

bool SetInterfaceMetric(const std::wstring& interfaceName, int metric) {
    std::wstringstream ss;
    ss << L"interface ip set interface name=\"" << interfaceName 
       << L"\" metric=" << metric;
    return ExecuteNetsh(ss.str());
}
