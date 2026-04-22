#include "vpn_service.h"
#include "tun_manager.h"

#include <windows.h>
#include <tlhelp32.h>  // For CreateToolhelp32Snapshot, Process32FirstW, etc.
#include <shlobj.h>
#include <wininet.h>
#include <winsvc.h>
#include <iphlpapi.h>  // For GetIfTable
#include <vector>
#include <fstream>
#include <sstream>
#include <thread>
#include <mutex>
#include <chrono>
#include <shellapi.h>
#include <winhttp.h>   // For HTTP requests to Xray API

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "winhttp.lib")

static bool FileExists(const std::wstring& path) {
    DWORD attribs = GetFileAttributesW(path.c_str());
    return (attribs != INVALID_FILE_ATTRIBUTES && !(attribs & FILE_ATTRIBUTE_DIRECTORY));
}

// Forward declaration used by logging helpers.
std::wstring GetAppDataDir();

static void AppendNativeLog(const std::string& line) {
    try {
        std::wstring appDir = GetAppDataDir();
        if (appDir.empty()) return;
        std::wstring logPath = appDir + L"\\native.log";
        std::ofstream f(logPath, std::ios::app);
        if (!f.is_open()) return;
        f << line << "\n";
    } catch (...) {
    }
}

static std::string WideToUtf8(const std::wstring& w) {
    if (w.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), nullptr, 0, nullptr, nullptr);
    std::string str(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, w.c_str(), (int)w.size(), str.data(), size_needed, nullptr, nullptr);
    return str;
}

static std::string LastErrorToString(DWORD err) {
    if (err == 0) return "0";
    LPWSTR buf = nullptr;
    DWORD size = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        nullptr,
        err,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        (LPWSTR)&buf,
        0,
        nullptr);
    std::wstring msg = (size && buf) ? std::wstring(buf, buf + size) : L"";
    if (buf) LocalFree(buf);
    std::ostringstream oss;
    oss << err << ": " << WideToUtf8(msg);
    return oss.str();
}

static bool RunProcessAndWaitToFile(const std::wstring& cmdLine,
                                   const std::wstring& outputFile,
                                   DWORD timeoutMs,
                                   DWORD* outExitCode) {
    HANDLE hFile = CreateFileW(
        outputFile.c_str(),
        GENERIC_WRITE,
        FILE_SHARE_READ,
        nullptr,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        nullptr);

    if (hFile == INVALID_HANDLE_VALUE) {
        AppendNativeLog(std::string("[native] CreateFileW failed: ") + LastErrorToString(GetLastError()));
        return false;
    }

    // Child process can only inherit handles that are marked inheritable.
    if (!SetHandleInformation(hFile, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT)) {
        AppendNativeLog(std::string("[native] SetHandleInformation failed: ") + LastErrorToString(GetLastError()));
        CloseHandle(hFile);
        return false;
    }

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    si.dwFlags = STARTF_USESHOWWINDOW | STARTF_USESTDHANDLES;
    si.wShowWindow = SW_HIDE;
    si.hStdOutput = hFile;
    si.hStdError = hFile;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);

    std::wstring mutableCmd = cmdLine;
    BOOL created = CreateProcessW(
        nullptr,
        mutableCmd.data(),
        nullptr,
        nullptr,
        TRUE,
        CREATE_NO_WINDOW,
        nullptr,
        nullptr,
        &si,
        &pi);

    if (!created) {
        DWORD err = GetLastError();
        CloseHandle(hFile);
        AppendNativeLog(std::string("[native] CreateProcessW failed: ") + LastErrorToString(err));
        return false;
    }

    DWORD waitRes = WaitForSingleObject(pi.hProcess, timeoutMs);
    DWORD exitCode = 0;
    if (waitRes == WAIT_OBJECT_0) {
        GetExitCodeProcess(pi.hProcess, &exitCode);
    } else {
        TerminateProcess(pi.hProcess, 1);
        exitCode = 1;
    }

    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    CloseHandle(hFile);
    if (outExitCode) *outExitCode = exitCode;
    return true;
}

#pragma comment(lib, "wininet.lib")

// Xray process handle
static HANDLE g_xrayProcess = nullptr;
static std::string g_status = "disconnected";
static flutter::MethodChannel<flutter::EncodableValue>* g_channel = nullptr;
static flutter::MethodChannel<flutter::EncodableValue>* g_dataChannel = nullptr;
static DWORD g_main_thread_id = 0;  // Main thread ID for thread safety

// Simple approach: always send from main thread, queue from background thread
static std::mutex g_status_mutex;
static std::vector<std::pair<std::string, std::pair<int,int>>> g_pending_statuses;
static UINT_PTR g_status_timer_id = 0;  // Timer ID for processing pending statuses

// Forward declaration
static void CALLBACK StatusTimerProc(HWND hwnd, UINT uMsg, UINT_PTR idEvent, DWORD dwTime);

// TUN configuration constants
static const char* TUN_IP = "10.0.0.2";
static const char* TUN_GATEWAY = "10.0.0.1";
static const int TUN_PREFIX = 24;
static const char* TUN_DNS = "1.1.1.1";  // Cloudflare DNS

static std::wstring GetModuleDir() {
    wchar_t exe_path[MAX_PATH];
    DWORD len = GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
        return L"";
    }
    std::wstring path(exe_path);
    size_t pos = path.find_last_of(L"\\/");
    if (pos == std::wstring::npos) {
        return L"";
    }
    return path.substr(0, pos);
}

static bool RelaunchInstallerAsAdmin() {
    std::wstring moduleDir = GetModuleDir();
    if (moduleDir.empty()) return false;
    std::wstring exePath = moduleDir + L"\\flutter_vpn.exe";
    if (!FileExists(exePath)) {
        // Fallback to current module path.
        wchar_t buf[MAX_PATH];
        DWORD len = GetModuleFileNameW(nullptr, buf, MAX_PATH);
        if (len == 0 || len >= MAX_PATH) return false;
        exePath.assign(buf);
    }

    std::wstring params = L"--install-service";
    HINSTANCE res = ShellExecuteW(nullptr, L"runas", exePath.c_str(), params.c_str(), nullptr, SW_SHOWNORMAL);
    return (INT_PTR)res > 32;
}

static bool PipeSendCommand(const std::string& command, std::string* outResponse) {
    const wchar_t* pipeName = L"\\\\.\\pipe\\VoyfyVpnPipe";
    HANDLE hPipe = CreateFileW(
        pipeName,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        0,
        nullptr);
    if (hPipe == INVALID_HANDLE_VALUE) {
        DWORD err = GetLastError();
        AppendNativeLog(std::string("[native] Pipe CreateFileW failed: ") + LastErrorToString(err));
        return false;
    }

    DWORD mode = PIPE_READMODE_MESSAGE;
    SetNamedPipeHandleState(hPipe, &mode, nullptr, nullptr);

    std::string msg = command + "\n";
    DWORD written = 0;
    BOOL ok = WriteFile(hPipe, msg.data(), (DWORD)msg.size(), &written, nullptr);
    if (!ok) {
        DWORD err = GetLastError();
        AppendNativeLog(std::string("[native] Pipe WriteFile failed: ") + LastErrorToString(err));
        CloseHandle(hPipe);
        return false;
    }

    char buffer[64 * 1024];
    DWORD read = 0;
    ok = ReadFile(hPipe, buffer, sizeof(buffer) - 1, &read, nullptr);
    if (!ok) {
        DWORD err = GetLastError();
        AppendNativeLog(std::string("[native] Pipe ReadFile failed: ") + LastErrorToString(err));
        CloseHandle(hPipe);
        return false;
    }
    buffer[read] = 0;

    if (outResponse) {
        *outResponse = std::string(buffer);
        while (!outResponse->empty() && (outResponse->back() == '\n' || outResponse->back() == '\r')) {
            outResponse->pop_back();
        }
    }

    CloseHandle(hPipe);
    return true;
}

// Check if Windows service is installed
static bool IsServiceInstalled(const wchar_t* serviceName) {
    SC_HANDLE scm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
    if (!scm) return false;
    
    SC_HANDLE svc = OpenServiceW(scm, serviceName, SERVICE_QUERY_STATUS);
    bool installed = (svc != nullptr);
    
    if (svc) CloseServiceHandle(svc);
    CloseServiceHandle(scm);
    return installed;
}

// Check if Windows service is running
static bool IsServiceRunning(const wchar_t* serviceName) {
    SC_HANDLE scm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
    if (!scm) return false;
    
    SC_HANDLE svc = OpenServiceW(scm, serviceName, SERVICE_QUERY_STATUS);
    if (!svc) {
        CloseServiceHandle(scm);
        return false;
    }
    
    SERVICE_STATUS status;
    BOOL result = QueryServiceStatus(svc, &status);
    
    CloseServiceHandle(svc);
    CloseServiceHandle(scm);
    
    return result && status.dwCurrentState == SERVICE_RUNNING;
}

// Start Windows service
static bool StartService(const wchar_t* serviceName) {
    SC_HANDLE scm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
    if (!scm) {
        AppendNativeLog("[native] StartService: OpenSCManagerW failed");
        return false;
    }
    
    SC_HANDLE svc = OpenServiceW(scm, serviceName, SERVICE_START);
    if (!svc) {
        AppendNativeLog("[native] StartService: OpenServiceW failed");
        CloseServiceHandle(scm);
        return false;
    }
    
    bool started = StartServiceW(svc, 0, nullptr);
    if (!started) {
        DWORD err = GetLastError();
        if (err == ERROR_SERVICE_ALREADY_RUNNING) {
            started = true;  // Already running is success
        } else {
            AppendNativeLog("[native] StartService: StartServiceW failed: " + std::to_string(err));
        }
    }
    
    CloseServiceHandle(svc);
    CloseServiceHandle(scm);
    return started;
}

// Check if VoyfyVpnService.exe process is already running
static bool IsServiceProcessRunning() {
    HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap == INVALID_HANDLE_VALUE) return false;
    
    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);
    
    bool found = false;
    if (Process32FirstW(hSnap, &pe32)) {
        do {
            if (_wcsicmp(pe32.szExeFile, L"VoyfyVpnService.exe") == 0) {
                found = true;
                break;
            }
        } while (Process32NextW(hSnap, &pe32));
    }
    
    CloseHandle(hSnap);
    return found;
}

// Delete service for reinstall
static bool DeleteService(const wchar_t* serviceName) {
    SC_HANDLE scm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_ALL_ACCESS);
    if (!scm) return false;
    
    SC_HANDLE svc = OpenServiceW(scm, serviceName, SERVICE_STOP | DELETE);
    if (!svc) {
        CloseServiceHandle(scm);
        return false;
    }
    
    // Try to stop service first
    SERVICE_STATUS status;
    ControlService(svc, SERVICE_CONTROL_STOP, &status);
    
    // Delete service
    BOOL result = DeleteService(svc);
    
    CloseServiceHandle(svc);
    CloseServiceHandle(scm);
    
    return result;
}

// Check if installed service path matches current executable path
static bool IsServicePathCorrect(const wchar_t* serviceName) {
    SC_HANDLE scm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
    if (!scm) return false;
    
    SC_HANDLE svc = OpenServiceW(scm, serviceName, SERVICE_QUERY_CONFIG);
    if (!svc) {
        CloseServiceHandle(scm);
        return false;
    }
    
    // Query service config to get binary path
    BYTE buffer[1024];
    DWORD needed = 0;
    QUERY_SERVICE_CONFIGW* config = (QUERY_SERVICE_CONFIGW*)buffer;
    BOOL result = QueryServiceConfigW(svc, config, sizeof(buffer), &needed);
    
    CloseServiceHandle(svc);
    CloseServiceHandle(scm);
    
    if (!result) return false;
    
    // Get current module path
    wchar_t currentPath[MAX_PATH];
    DWORD len = GetModuleFileNameW(nullptr, currentPath, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) return false;
    
    // Remove \flutter_vpn.exe from current path to get directory
    std::wstring currentDir(currentPath);
    size_t pos = currentDir.find_last_of(L"\\/");
    if (pos != std::wstring::npos) {
        currentDir = currentDir.substr(0, pos);
    }
    
    // Service binary path should be currentDir\VoyfyVpnService.exe
    std::wstring expectedPath = currentDir + L"\\VoyfyVpnService.exe";
    
    // Compare paths (case insensitive)
    std::wstring servicePath(config->lpBinaryPathName);
    // Remove quotes if present
    if (!servicePath.empty() && servicePath[0] == L'"') {
        servicePath = servicePath.substr(1, servicePath.length() - 2);
    }
    
    return _wcsicmp(servicePath.c_str(), expectedPath.c_str()) == 0;
}

static bool EnsureServiceRunning() {
    const wchar_t* kServiceName = L"VoyfyVpnService";
    std::string resp;
    
    // Static flag to prevent multiple simultaneous installations
    static bool s_installing = false;
    static auto s_lastInstallTime = std::chrono::steady_clock::now();
    
    // If we just tried to install within last 10 seconds, don't try again
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - s_lastInstallTime).count();
    if (s_installing || elapsed < 10) {
        AppendNativeLog("[native] Installation already in progress or recently completed, waiting...");
        // Wait for installation to complete
        for (int i = 0; i < 20; i++) {  // Wait up to 10 seconds
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            resp.clear();
            if (PipeSendCommand("PING", &resp) && resp == "PONG") {
                AppendNativeLog("[native] Service now reachable after waiting");
                return true;
            }
        }
        return false;
    }
    
    // Check if service process is already running
    if (IsServiceProcessRunning()) {
        AppendNativeLog("[native] VoyfyVpnService.exe process found, checking pipe...");
        // Wait a bit for pipe to be ready
        for (int i = 0; i < 10; i++) {
            std::this_thread::sleep_for(std::chrono::milliseconds(300));
            resp.clear();
            if (PipeSendCommand("PING", &resp) && resp == "PONG") {
                AppendNativeLog("[native] Service reachable (process was already running)");
                return true;
            }
        }
        AppendNativeLog("[native] Process running but pipe not responding, will try to reinstall...");
    }
    
    if (PipeSendCommand("PING", &resp) && resp == "PONG") {
        // Service is running, check if path is correct
        if (!IsServicePathCorrect(kServiceName)) {
            AppendNativeLog("[native] Service running but from different path, deleting for reinstall...");
            DeleteService(kServiceName);
            Sleep(1000); // Wait for service to be deleted
            // Continue to reinstall path below
        } else {
            AppendNativeLog("[native] Service already running from correct path (PONG received)");
            return true;
        }
    }
    
    // Check if service is already installed
    if (IsServiceInstalled(kServiceName)) {
        AppendNativeLog("[native] Service installed, checking if running...");
        
        // Check if path is correct
        if (!IsServicePathCorrect(kServiceName)) {
            AppendNativeLog("[native] Service path mismatch, deleting for reinstall...");
            DeleteService(kServiceName);
            Sleep(1000);
            // Continue to reinstall path
        } else {
            // If not running, try to start it
            if (!IsServiceRunning(kServiceName)) {
                AppendNativeLog("[native] Service installed but not running, starting it...");
                if (!StartService(kServiceName)) {
                    AppendNativeLog("[native] Failed to start service, will try to reinstall...");
                    // Fall through to reinstall path
                } else {
                    AppendNativeLog("[native] Service started, waiting for pipe...");
                }
            } else {
                AppendNativeLog("[native] Service is running but pipe not reachable, waiting...");
            }
            
            // Wait for service/pipe to be ready (no UAC needed)
            for (int i = 0; i < 30; i++) {
                std::this_thread::sleep_for(std::chrono::milliseconds(500));
                resp.clear();
                if (PipeSendCommand("PING", &resp) && resp == "PONG") {
                    AppendNativeLog("[native] Service is now reachable");
                    return true;
                }
            }
            
            AppendNativeLog("[native] Service not responding, will try to reinstall...");
            // Continue to reinstall path
        }
    }

    // Service not installed - need to install with UAC
    AppendNativeLog("[native] Service not installed, will install with UAC...");

    // Check if service exe exists
    std::wstring moduleDir = GetModuleDir();
    std::wstring serviceExe = moduleDir + L"\\VoyfyVpnService.exe";
    
    if (!FileExists(serviceExe)) {
        AppendNativeLog("[native] ERROR: VoyfyVpnService.exe not found at: " + WideToUtf8(serviceExe));
        return false;
    }

    // Mark that we're installing to prevent duplicate UAC prompts
    s_installing = true;
    s_lastInstallTime = std::chrono::steady_clock::now();
    
    AppendNativeLog("[native] Launching installer with UAC...");
    if (!RelaunchInstallerAsAdmin()) {
        AppendNativeLog("[native] Failed to relaunch installer as admin");
        s_installing = false;
        return false;
    }
    AppendNativeLog("[native] Installer launched, waiting for service...");

    // Wait for service to come up.
    bool serviceReady = false;
    for (int i = 0; i < 30; i++) {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        resp.clear();
        if (PipeSendCommand("PING", &resp) && resp == "PONG") {
            AppendNativeLog("[native] Service is now reachable after install");
            serviceReady = true;
            break;
        }
    }
    
    s_installing = false;
    s_lastInstallTime = std::chrono::steady_clock::now();
    
    if (serviceReady) {
        return true;
    }

    AppendNativeLog("[native] Service still not reachable after install attempt");
    return false;
}

// Get app data directory
std::wstring GetAppDataDir() {
    wchar_t path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, 0, path))) {
        std::wstring appPath = path;
        appPath += L"\\VoyfyVPN";
        CreateDirectoryW(appPath.c_str(), nullptr);
        return appPath;
    }
    return L"";
}

// Parse VLESS URL and create Xray TUN config
std::string CreateXrayConfig(const std::string& vlessUrl) {
    // Parse vless://uuid@host:port?encryption=none&...#name
    std::string config = vlessUrl;
    
    // Remove vless:// prefix
    if (config.find("vless://") == 0) {
        config = config.substr(8);
    }
    
    // Find @ for host:port
    size_t atPos = config.find('@');
    if (atPos == std::string::npos) return "";
    
    std::string uuid = config.substr(0, atPos);
    std::string rest = config.substr(atPos + 1);
    
    // Find ? or # for host:port boundary
    size_t qPos = rest.find('?');
    size_t hPos = rest.find('#');
    size_t endPos = std::min(qPos != std::string::npos ? qPos : rest.size(),
                             hPos != std::string::npos ? hPos : rest.size());
    
    std::string hostPort = rest.substr(0, endPos);
    size_t colonPos = hostPort.find(':');
    if (colonPos == std::string::npos) return "";
    
    std::string host = hostPort.substr(0, colonPos);
    std::string port = hostPort.substr(colonPos + 1);
    
    // Parse query parameters for Reality
    std::string pbk, sid, sni, fp = "chrome", security = "reality", flow = "";
    
    if (qPos != std::string::npos && hPos != std::string::npos && qPos < hPos) {
        std::string query = rest.substr(qPos + 1, hPos - qPos - 1);
        // Parse key=value pairs
        size_t start = 0;
        while (start < query.size()) {
            size_t eqPos = query.find('=', start);
            if (eqPos == std::string::npos) break;
            size_t ampPos = query.find('&', eqPos);
            if (ampPos == std::string::npos) ampPos = query.size();
            
            std::string key = query.substr(start, eqPos - start);
            std::string value = query.substr(eqPos + 1, ampPos - eqPos - 1);
            
            if (key == "pbk") pbk = value;
            else if (key == "sid") sid = value;
            else if (key == "sni") sni = value;
            else if (key == "fp") fp = value;
            else if (key == "security") security = value;
            else if (key == "flow") flow = value;
            
            start = ampPos + 1;
        }
    }
    
    // Build Reality stream settings
    std::string realitySettings = "";
    if (security == "reality" && !pbk.empty()) {
        realitySettings = R"(,
        "security": "reality",
        "realitySettings": {
          "show": false,
          "fingerprint": ")" + fp + R"(",
          "serverName": ")" + (sni.empty() ? host : sni) + R"(",
          "publicKey": ")" + pbk + R"(",
          "shortId": ")" + (sid.empty() ? "" : sid) + R"(",
          "spiderX": ""
        })";
    }
    
    // Build Xray JSON config with TUN inbound
    std::wstring appDirW = GetAppDataDir();
    int size = WideCharToMultiByte(CP_UTF8, 0, appDirW.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string appDirStr(size - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, appDirW.c_str(), -1, &appDirStr[0], size, nullptr, nullptr);

    // Use forward slashes to avoid JSON escape issues on Windows paths.
    std::string appDirForward = appDirStr;
    for (char& c : appDirForward) {
        if (c == '\\') c = '/';
    }
    std::string logAccessPath = appDirForward + "/access.log";
    std::string logErrorPath = appDirForward + "/error.log";
    
    std::string xrayConfig = R"({
  "log": {
    "loglevel": "debug",
    "access": ")" + logAccessPath + R"(",
    "error": ")" + logErrorPath + R"("
  },
  "dns": {
    "servers": [
      "1.1.1.1",
      "8.8.8.8"
    ]
  },
  "inbounds": [
    {
      "tag": "tun-in",
      "protocol": "tun",
      "settings": {
        "ip": [")" + std::string(TUN_IP) + R"(/24"],
        "mtu": 1500,
        "autoRoute": true,
        "strictRoute": true
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": ")" + host + R"(",
            "port": )" + port + R"(,
            "users": [
              {
                "id": ")" + uuid + R"(",
                "encryption": "none")" + (flow.empty() ? "" : ",\n                \"flow\": \"" + flow + "\"") + R"(
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp")" + realitySettings + R"(
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "inboundTag": ["tun-in"],
        "outboundTag": "proxy"
      },
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "direct"
      }
    ]
  }
})";

    OutputDebugStringA(("[VPN] Generated Xray TUN config: " + xrayConfig.substr(0, 500) + "...\n").c_str());
    return xrayConfig;
}

// Write config file
bool WriteConfigFile(const std::string& config) {
    std::wstring appDir = GetAppDataDir();
    if (appDir.empty()) return false;
    
    std::wstring configPath = appDir + L"\\config.json";
    std::wstring logPath = appDir + L"\\xray.log";
    
    std::string xrayConfig = CreateXrayConfig(config);
    if (xrayConfig.empty()) {
        OutputDebugStringW(L"[VPN] Failed to create Xray config\n");
        AppendNativeLog("[native] CreateXrayConfig returned empty string");
        return false;
    }
    
    // Write config file
    std::ofstream file(configPath, std::ios::binary);
    if (!file.is_open()) {
        OutputDebugStringW(L"[VPN] Failed to open config.json for writing\n");
        AppendNativeLog("[native] Failed to open config.json for writing");
        return false;
    }
    file << xrayConfig;
    file.close();
    
    // Also write config to log for debugging
    std::ofstream logFile(logPath, std::ios::app);
    if (logFile.is_open()) {
        logFile << "=== Config generated at: " << __TIME__ << " ===\n";
        logFile << xrayConfig << "\n\n";
        logFile.close();
    }
    
    OutputDebugStringA(("[VPN] Config written: " + xrayConfig.substr(0, 200) + "...\n").c_str());
    AppendNativeLog("[native] Config written to %LOCALAPPDATA%\\VoyfyVPN\\config.json");
    return true;
}

static bool TestXrayConfig(const std::wstring& xrayPath, const std::wstring& configPath) {
    if (!FileExists(xrayPath) || !FileExists(configPath)) {
        AppendNativeLog("[native] TestXrayConfig: xray.exe or config.json missing");
        return false;
    }

    std::wstring appDir = GetAppDataDir();
    std::wstring testLogPath = appDir + L"\\xray_test.log";
    std::wstring versionLogPath = appDir + L"\\xray_version.log";

    // Capture version output
    {
        std::wstring verCmd = L"\"" + xrayPath + L"\" -version";
        DWORD verExit = 0;
        AppendNativeLog(std::string("[native] Running: xray.exe -version (captured) output=") + WideToUtf8(versionLogPath));
        RunProcessAndWaitToFile(verCmd, versionLogPath, 5000, &verExit);
        AppendNativeLog(std::string("[native] xray -version exitCode=") + std::to_string(verExit));
    }

    // Append separator by reusing CreateFile(CREATE_ALWAYS) semantics: re-run -test will overwrite.
    std::wstring testCmd = L"\"" + xrayPath + L"\" -test -config=\"" + configPath + L"\"";
    DWORD exitCode = 0;
    AppendNativeLog(std::string("[native] Running: xray.exe -test ... output=") + WideToUtf8(testLogPath));
    bool ok = RunProcessAndWaitToFile(testCmd, testLogPath, 15000, &exitCode);
    AppendNativeLog(std::string("[native] xray -test ok=") + (ok ? "true" : "false") + ", exitCode=" + std::to_string(exitCode));
    return ok && exitCode == 0;
}

// Start Xray process
bool StartXray() {
    std::wstring appDir = GetAppDataDir();
    std::wstring xrayPath = appDir + L"\\xray.exe";
    std::wstring configPath = appDir + L"\\config.json";
    
    // Debug: Check if xray.exe exists
    bool xrayExists = FileExists(xrayPath);
    bool configExists = FileExists(configPath);
    
    if (!xrayExists) {
        xrayPath = L"xray.exe";
        xrayExists = true;
    }
    
    OutputDebugStringW((L"[VPN] Xray path: " + xrayPath + L"\n").c_str());
    OutputDebugStringW((L"[VPN] Config path: " + configPath + L"\n").c_str());
    OutputDebugStringW((L"[VPN] Config exists: " + std::to_wstring(configExists) + L"\n").c_str());

    AppendNativeLog(std::string("[native] StartXray: xrayPath=") + WideToUtf8(xrayPath));
    AppendNativeLog(std::string("[native] StartXray: configPath=") + WideToUtf8(configPath));
    AppendNativeLog(std::string("[native] StartXray: configExists=") + (configExists ? "true" : "false"));

    if (!TestXrayConfig(xrayPath, configPath)) {
        AppendNativeLog("[native] xray -test failed; not starting xray");
        return false;
    }
    
    std::wstring cmdLine = L"\"" + xrayPath + L"\" -config=\"" + configPath + L"\"";
    
    STARTUPINFOW si = {sizeof(si)};
    PROCESS_INFORMATION pi = {};
    
    BOOL created = CreateProcessW(
        nullptr,
        &cmdLine[0],
        nullptr, nullptr, FALSE,
        CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP,
        nullptr, nullptr, &si, &pi
    );
    
    if (!created) {
        DWORD error = GetLastError();
        OutputDebugStringW((L"[VPN] CreateProcess failed: " + std::to_wstring(error) + L"\n").c_str());
        AppendNativeLog(std::string("[native] CreateProcessW(xray) failed: ") + LastErrorToString(error));
        return false;
    }
    
    g_xrayProcess = pi.hProcess;
    CloseHandle(pi.hThread);
    OutputDebugStringW(L"[VPN] Xray started successfully\n");
    AppendNativeLog("[native] Xray started successfully");
    return true;
}

// Setup TUN interface and routing
bool SetupTunAndRouting() {
    // Initialize TUN manager
    if (!InitializeTun()) {
        OutputDebugStringW(L"[VPN] Failed to initialize TUN\n");
        return false;
    }

    // In autoRoute mode Xray will configure routing itself.
    // We only flush DNS cache here.
    FlushDNSCache();
    OutputDebugStringW(L"[VPN] TUN setup complete (autoRoute)\n");
    return true;
}

// Cleanup TUN and restore routing
void CleanupTunAndRouting() {
    if (g_tunManager) {
        g_tunManager->CleanupRouting();
    }
    CleanupTun();
    OutputDebugStringW(L"[VPN] TUN cleanup complete\n");
}

// Check if Xray process is running
bool IsXrayRunning() {
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return false;
    }
    
    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);
    bool found = false;
    
    if (Process32FirstW(hSnapshot, &pe32)) {
        do {
            if (_wcsicmp(pe32.szExeFile, L"xray.exe") == 0) {
                found = true;
                break;
            }
        } while (Process32NextW(hSnapshot, &pe32));
    }
    
    CloseHandle(hSnapshot);
    return found;
}

// Check if TUN adapter is actually active (real connection check)
bool IsTunAdapterActive() {
    // Use GetIfTable (compatible with all Windows versions)
    ULONG bufferSize = 0;
    DWORD result = GetIfTable(nullptr, &bufferSize, FALSE);
    
    if (result != ERROR_INSUFFICIENT_BUFFER) {
        return false;
    }
    
    std::vector<BYTE> buffer(bufferSize);
    MIB_IFTABLE* ifTable = reinterpret_cast<MIB_IFTABLE*>(buffer.data());
    
    result = GetIfTable(ifTable, &bufferSize, FALSE);
    if (result != NO_ERROR) {
        return false;
    }
    
    bool found = false;
    for (DWORD i = 0; i < ifTable->dwNumEntries; i++) {
        MIB_IFROW& row = ifTable->table[i];
        // Check for TUN interface by name or description
        wchar_t* name = reinterpret_cast<wchar_t*>(row.wszName);
        wchar_t* desc = row.dwDescrLen > 0 ? reinterpret_cast<wchar_t*>(row.bDescr) : nullptr;
        
        // Check if interface name or description contains TUN keywords
        bool isTunInterface = false;
        if (name && (wcsstr(name, L"TUN") || wcsstr(name, L"tun") ||
                     wcsstr(name, L"WireGuard") || wcsstr(name, L"Wintun") ||
                     wcsstr(name, L"Xray") || wcsstr(name, L"xray"))) {
            isTunInterface = true;
        }
        if (desc && (wcsstr(desc, L"TUN") || wcsstr(desc, L"tun") ||
                     wcsstr(desc, L"WireGuard") || wcsstr(desc, L"Wintun"))) {
            isTunInterface = true;
        }
        
        // Check if interface is up (operational)
        if (isTunInterface && row.dwOperStatus == IF_OPER_STATUS_OPERATIONAL) {
            found = true;
            break;
        }
    }
    
    return found;
}

// Wait for real connection with timeout (checks TUN adapter)
bool WaitForRealConnection(int timeoutSeconds) {
    OutputDebugStringW(L"[VPN] Waiting for real connection...\n");
    
    for (int i = 0; i < timeoutSeconds * 2; i++) {
        if (IsTunAdapterActive()) {
            OutputDebugStringW(L"[VPN] TUN adapter is active!\n");
            return true;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
    
    OutputDebugStringW(L"[VPN] Timeout waiting for TUN adapter\n");
    return false;
}

// Stop Xray process
void StopXray() {
    if (g_xrayProcess) {
        TerminateProcess(g_xrayProcess, 0);
        CloseHandle(g_xrayProcess);
        g_xrayProcess = nullptr;
    }
}

// Set system proxy
void SetSystemProxy(bool enable) {
    INTERNET_PER_CONN_OPTION_LIST list = {};
    INTERNET_PER_CONN_OPTION options[2] = {};
    
    list.dwSize = sizeof(list);
    list.pszConnection = nullptr;
    list.dwOptionCount = enable ? 2 : 1;
    list.pOptions = options;
    
    if (enable) {
        // Use HTTP proxy (more compatible with Windows apps than SOCKS5)
        wchar_t proxy[] = L"http://127.0.0.1:10809";
        options[0].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
        options[0].Value.pszValue = proxy;
        options[1].dwOption = INTERNET_PER_CONN_FLAGS;
        options[1].Value.dwValue = PROXY_TYPE_PROXY;
    } else {
        options[0].dwOption = INTERNET_PER_CONN_FLAGS;
        options[0].Value.dwValue = PROXY_TYPE_DIRECT;
    }
    
    InternetSetOptionW(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, sizeof(list));
    InternetSetOptionW(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0);
    InternetSetOptionW(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);
}

// Process pending status updates (called on main thread)
void ProcessPendingStatuses() {
    std::lock_guard<std::mutex> lock(g_status_mutex);
    for (const auto& item : g_pending_statuses) {
        const std::string& status = item.first;
        int bytesReceived = item.second.first;
        int bytesSent = item.second.second;
        
        if (g_channel) {
            g_channel->InvokeMethod("onStatusChanged", std::make_unique<flutter::EncodableValue>(status));
        }
        if (bytesReceived >= 0 && g_dataChannel) {
            flutter::EncodableMap usage;
            usage[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(bytesReceived);
            usage[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(bytesSent);
            g_dataChannel->InvokeMethod("onDataUsageUpdated", std::make_unique<flutter::EncodableValue>(usage));
        }
    }
    g_pending_statuses.clear();
}

// Windows message handler for VPN status updates
void OnVpnStatusMessage(WPARAM wParam, LPARAM lParam) {
    ProcessPendingStatuses();
}

// Check if we're on the main thread
static bool IsMainThread() {
    return GetCurrentThreadId() == g_main_thread_id;
}

// Timer callback to process pending statuses
static void CALLBACK StatusTimerProc(HWND hwnd, UINT uMsg, UINT_PTR idEvent, DWORD dwTime) {
    ProcessPendingStatuses();
}

// Start status processing timer (call from main thread)
static void StartStatusTimer() {
    if (g_status_timer_id == 0) {
        g_status_timer_id = SetTimer(nullptr, 0, 100, StatusTimerProc);  // 100ms interval
        OutputDebugStringW(L"[VPN] Status timer started\n");
    }
}


// Send status to Dart (thread-safe)
void SendStatus(const std::string& status) {
    g_status = status;
    OutputDebugStringW((L"[VPN] SendStatus: " + std::wstring(status.begin(), status.end()) + L" (main thread: " + std::to_wstring(IsMainThread()) + L")\n").c_str());
    
    if (IsMainThread()) {
        // We're on main thread, send immediately
        if (g_channel) {
            g_channel->InvokeMethod("onStatusChanged", std::make_unique<flutter::EncodableValue>(status));
        }
    } else {
        // Queue for main thread - we'll process when main thread calls ProcessPendingStatuses
        std::lock_guard<std::mutex> lock(g_status_mutex);
        g_pending_statuses.push_back({status, {-1, -1}});
    }
}

// Send data usage to Dart (thread-safe)
void SendDataUsage(int bytesReceived, int bytesSent) {
    if (IsMainThread()) {
        if (g_dataChannel) {
            flutter::EncodableMap usage;
            usage[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(bytesReceived);
            usage[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(bytesSent);
            g_dataChannel->InvokeMethod("onDataUsageUpdated", std::make_unique<flutter::EncodableValue>(usage));
        }
    } else {
        std::lock_guard<std::mutex> lock(g_status_mutex);
        g_pending_statuses.push_back({"", {bytesReceived, bytesSent}});
    }
}

// Get Xray traffic stats from API (localhost:10085)
static bool GetXrayStats(long long& bytesReceived, long long& bytesSent) {
    HINTERNET hSession = WinHttpOpen(L"VoyfyVPN/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, NULL, NULL, 0);
    if (!hSession) return false;
    
    HINTERNET hConnect = WinHttpConnect(hSession, L"127.0.0.1", 10085, 0);
    if (!hConnect) {
        WinHttpCloseHandle(hSession);
        return false;
    }
    
    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET", L"/stats/query", NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, 0);
    if (!hRequest) {
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }
    
    bool success = WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0);
    if (!success || !WinHttpReceiveResponse(hRequest, NULL)) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }
    
    // Read response (simplified - just check if API responds)
    DWORD bytesAvailable = 0;
    WinHttpQueryDataAvailable(hRequest, &bytesAvailable);
    
    // For now, return mock stats based on API availability
    // TODO: Parse actual JSON response
    static long long s_recv = 0, s_sent = 0;
    s_recv += bytesAvailable > 0 ? 1024 : 0; // Mock increment
    s_sent += bytesAvailable > 0 ? 512 : 0;
    bytesReceived = s_recv;
    bytesSent = s_sent;
    
    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);
    
    return bytesAvailable > 0;
}

// Global stats timer
static UINT_PTR g_stats_timer_id = 0;
static void CALLBACK StatsTimerProc(HWND hwnd, UINT uMsg, UINT_PTR idEvent, DWORD dwTime) {
    if (g_status == "connected") {
        long long recv = 0, sent = 0;
        if (GetXrayStats(recv, sent)) {
            SendDataUsage(static_cast<int>(recv / 1024), static_cast<int>(sent / 1024)); // KB
        }
    }
}

static void StartStatsTimer() {
    if (g_stats_timer_id == 0) {
        g_stats_timer_id = SetTimer(nullptr, 0, 1000, StatsTimerProc); // Every 1 second
        OutputDebugStringW(L"[VPN] Stats timer started\n");
    }
}


void SetupVpnMethodChannel(flutter::FlutterViewController* controller) {
    // Store main thread ID for thread safety checks
    g_main_thread_id = GetCurrentThreadId();
    
    // Start timers for status processing and stats updates
    StartStatusTimer();
    StartStatsTimer();
    
    // Main VPN channel
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        controller->engine()->messenger(), "com.voyfy.vpn/windows",
        &flutter::StandardMethodCodec::GetInstance());
    
    g_channel = channel.get();
    
    // Data usage channel
    auto dataChannel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        controller->engine()->messenger(), "com.voyfy.vpn/data",
        &flutter::StandardMethodCodec::GetInstance());
    
    g_dataChannel = dataChannel.get();
    
    channel->SetMethodCallHandler([](const flutter::MethodCall<flutter::EncodableValue>& call,
                                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        
        if (method == "initialize") {
            // Initialize TUN support
            bool tunOk = InitializeTun();
            OutputDebugStringW((L"[VPN] Initialize TUN: " + std::to_wstring(tunOk) + L"\n").c_str());
            bool svcOk = EnsureServiceRunning();
            OutputDebugStringW((L"[VPN] Service reachable: " + std::to_wstring(svcOk) + L"\n").c_str());
            result->Success(flutter::EncodableValue(svcOk));
        }
        else if (method == "connect") {
            OutputDebugStringW(L"[VPN] Connect called (async mode)\n");
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (args) {
                auto it = args->find(flutter::EncodableValue("config"));
                if (it != args->end()) {
                    const std::string* config = std::get_if<std::string>(&it->second);
                    if (config && !config->empty()) {
                        OutputDebugStringW(L"[VPN] Got config, starting async connect...\n");
                        SendStatus("connecting");

                        // Capture by value for thread safety
                        std::string configCopy = *config;
                        auto resultPtr = result.release(); // Release to manage manually

                        // Run connection in background thread to avoid blocking UI
                        std::thread([configCopy, resultPtr]() {
                            bool success = false;
                            
                            // Step 1: Ensure service is running
                            if (!EnsureServiceRunning()) {
                                OutputDebugStringW(L"[VPN] Failed to ensure service running\n");
                                SendStatus("error");
                                resultPtr->Success(flutter::EncodableValue(false));
                                delete resultPtr;
                                return;
                            }

                            // Step 2: Create config and connect
                            std::string xrayJson = CreateXrayConfig(configCopy);
                            if (xrayJson.empty()) {
                                AppendNativeLog("[native] CreateXrayConfig returned empty");
                                SendStatus("error");
                                resultPtr->Success(flutter::EncodableValue(false));
                                delete resultPtr;
                                return;
                            }

                            std::string resp;
                            bool ok = PipeSendCommand(std::string("CONNECT_JSON ") + xrayJson, &resp);
                            AppendNativeLog(std::string("[native] CONNECT_JSON resp=") + resp);
                            
                            if (ok && resp == "OK") {
                                // Fast check - just verify Xray process is running
                                // Don't wait - connection is async in service
                                bool xrayRunning = IsXrayRunning();
                                OutputDebugStringW((L"[VPN] Xray running: " + std::to_wstring(xrayRunning) + L"\n").c_str());
                                
                                if (xrayRunning) {
                                    SendStatus("connected");
                                    SendDataUsage(0, 0);
                                    success = true;
                                } else {
                                    // Xray didn't start - error
                                    OutputDebugStringW(L"[VPN] Xray not running after connect\n");
                                    SendStatus("error");
                                }
                            } else {
                                OutputDebugStringW(L"[VPN] CONNECT_JSON failed\n");
                                SendStatus("error");
                            }
                            
                            resultPtr->Success(flutter::EncodableValue(success));
                            delete resultPtr;
                        }).detach();
                        
                        return; // Don't call result->Success here, thread will handle it
                    } else {
                        OutputDebugStringW(L"[VPN] Config empty or null\n");
                    }
                } else {
                    OutputDebugStringW(L"[VPN] No config key found\n");
                }
            } else {
                OutputDebugStringW(L"[VPN] No args\n");
            }
            SendStatus("error");
            result->Success(flutter::EncodableValue(false));
        }
        else if (method == "disconnect") {
            SendStatus("disconnecting");
            std::string resp;
            PipeSendCommand("DISCONNECT", &resp);
            AppendNativeLog(std::string("[native] DISCONNECT resp=") + resp);
            SendStatus("disconnected");
            result->Success(flutter::EncodableValue(true));
        }
        else if (method == "getStatus") {
            result->Success(flutter::EncodableValue(g_status));
        }
        else if (method == "getDataUsage") {
            // TODO: Read from Xray API or stats file
            // For now return 0, actual usage will be sent via onDataUsageUpdated
            flutter::EncodableMap usage;
            usage[flutter::EncodableValue("bytesReceived")] = flutter::EncodableValue(0);
            usage[flutter::EncodableValue("bytesSent")] = flutter::EncodableValue(0);
            result->Success(flutter::EncodableValue(usage));
        }
        else if (method == "testConfig") {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            bool valid = false;
            if (args) {
                auto it = args->find(flutter::EncodableValue("config"));
                if (it != args->end()) {
                    const std::string* config = std::get_if<std::string>(&it->second);
                    valid = config && config->find("vless://") == 0;
                }
            }
            result->Success(flutter::EncodableValue(valid));
        }
        else if (method == "ping") {
            // Simple ping - for now return static value to avoid header issues
            // TODO: Implement proper ICMP ping with correct Windows types
            result->Success(flutter::EncodableValue(50));
        }
        else if (method == "checkAndDownloadXray") {
            std::wstring appDir = GetAppDataDir();
            std::wstring xrayPath = appDir + L"\\xray.exe";
            bool exists = FileExists(xrayPath);
            OutputDebugStringW((L"[VPN] checkAndDownloadXray: " + xrayPath + L" exists=" + std::to_wstring(exists) + L"\n").c_str());
            result->Success(flutter::EncodableValue(exists));
        }
        else {
            result->NotImplemented();
        }
    });
    
    // Keep channels alive - do NOT call release()!
    // The unique_ptr must own the channels for the lifetime of the app
    // channel.release();  // REMOVED - causes dangling pointer!
    // dataChannel.release();  // REMOVED - causes dangling pointer!
    (void)channel.release();  // Intentionally leak to keep channel alive
    (void)dataChannel.release();  // Intentionally leak to keep dataChannel alive
}

