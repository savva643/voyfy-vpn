#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601  // Windows 7
#endif

#include <winsock2.h>
#include <windows.h>
#include <tlhelp32.h>
#include <iphlpapi.h>
#include <shlobj.h>
#include <winhttp.h>
#include <wininet.h>
#include <fstream>
#include <sstream>
#include <string>
#include <thread>
#include <chrono>
#include <atomic>
#include <algorithm>
#include <iterator>
#include <vector>

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "wininet.lib")

static bool FileExists(const std::wstring& path) {
    DWORD attribs = GetFileAttributesW(path.c_str());
    return (attribs != INVALID_FILE_ATTRIBUTES && !(attribs & FILE_ATTRIBUTE_DIRECTORY));
}

// Create security descriptor allowing Everyone access to named pipe
static SECURITY_ATTRIBUTES* CreatePipeSecurityAttributes() {
    static SECURITY_ATTRIBUTES sa = {};
    static SECURITY_DESCRIPTOR sd = {};
    static ACL acl = {};
    static char aclBuffer[256] = {};

    // Initialize security descriptor
    if (!InitializeSecurityDescriptor(&sd, SECURITY_DESCRIPTOR_REVISION)) {
        return nullptr;
    }

    // Create a DACL that allows Everyone to access
    DWORD cbAcl = sizeof(ACL) + sizeof(ACCESS_ALLOWED_ACE) + GetSidLengthRequired(1);
    if (cbAcl > sizeof(aclBuffer)) {
        return nullptr;
    }

    PACL pAcl = (PACL)aclBuffer;
    if (!InitializeAcl(pAcl, cbAcl, ACL_REVISION)) {
        return nullptr;
    }

    // Add access allowed ACE for Everyone (SID: S-1-1-0)
    BYTE everyoneSid[12] = { 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0 };  // SID for Everyone (S-1-1-0)
    if (!AddAccessAllowedAce(pAcl, ACL_REVISION, GENERIC_READ | GENERIC_WRITE, (PSID)&everyoneSid)) {
        return nullptr;
    }

    // Set DACL to security descriptor
    if (!SetSecurityDescriptorDacl(&sd, TRUE, pAcl, FALSE)) {
        return nullptr;
    }

    // Set up SECURITY_ATTRIBUTES
    sa.nLength = sizeof(SECURITY_ATTRIBUTES);
    sa.lpSecurityDescriptor = &sd;
    sa.bInheritHandle = FALSE;

    return &sa;
}

static SERVICE_STATUS g_serviceStatus = {};
static SERVICE_STATUS_HANDLE g_statusHandle = nullptr;
static HANDLE g_stopEvent = nullptr;
static HANDLE g_hysteria2Process = nullptr;

static std::string WStringToString(const std::wstring& wstr);

static std::wstring GetModuleDir() {
    wchar_t path[MAX_PATH];
    DWORD len = GetModuleFileNameW(nullptr, path, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) return L"";
    std::wstring fullPath(path);
    size_t pos = fullPath.find_last_of(L"\\/");
    if (pos == std::wstring::npos) return L"";
    return fullPath.substr(0, pos);
}

static std::wstring GetDataDir() {
    // Use Public AppData so all users can access it without admin rights
    // C:\Users\Public is accessible to everyone
    std::wstring dataPath = L"C:\\Users\\Public\\VoyfyVPN";
    CreateDirectoryW(L"C:\\Users\\Public", nullptr);
    CreateDirectoryW(dataPath.c_str(), nullptr);
    return dataPath;
}

static void AppendServiceLog(const std::string& line) {
    try {
        std::wstring dir = GetDataDir();
        if (dir.empty()) return;
        std::ofstream f(dir + L"\\service.log", std::ios::app);
        if (!f.is_open()) return;
        f << line << "\n";
    } catch (...) {
    }
}

static bool WriteHysteria2Config(const std::string& configYaml) {
    std::wstring dir = GetDataDir();
    if (dir.empty()) {
        AppendServiceLog("[service] ERROR: GetDataDir returned empty");
        return false;
    }
    
    AppendServiceLog("[service] Data dir: " + WStringToString(dir));
    
    // Create directory if it doesn't exist
    if (!CreateDirectoryW(dir.c_str(), NULL)) {
        DWORD err = GetLastError();
        if (err != ERROR_ALREADY_EXISTS) {
            AppendServiceLog("[service] ERROR: Cannot create directory: " + std::to_string(err));
            return false;
        }
        AppendServiceLog("[service] Directory already exists");
    } else {
        AppendServiceLog("[service] Directory created");
    }
    
    std::wstring configPath = dir + L"\\config.yaml";
    AppendServiceLog("[service] Opening: " + WStringToString(configPath));
    
    std::ofstream file(configPath, std::ios::binary | std::ios::trunc);
    if (!file.is_open()) {
        AppendServiceLog("[service] ERROR: Cannot open config.yaml for writing");
        return false;
    }
    
    file << configYaml;
    file.flush();
    bool success = !file.fail();
    file.close();
    
    if (success) {
        AppendServiceLog("[service] Hysteria2 config written successfully: " + WStringToString(configPath));
    } else {
        AppendServiceLog("[service] ERROR: Failed to write config.yaml");
    }
    
    return success;
}

static bool SetSystemProxy(bool enable);
static bool ConfigureTunRoutes();

static bool StopHysteria2() {
    // Disable system proxy first
    SetSystemProxy(false);
    
    AppendServiceLog("[service] Stopping Hysteria2...");
    
    if (g_hysteria2Process) {
        TerminateProcess(g_hysteria2Process, 0);
        WaitForSingleObject(g_hysteria2Process, 3000);
        CloseHandle(g_hysteria2Process);
        g_hysteria2Process = nullptr;
    }
    
    // Kill any remaining hysteria2.exe processes
    HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32 pe;
        pe.dwSize = sizeof(pe);
        if (Process32First(hSnap, &pe)) {
            do {
                if (_wcsicmp(pe.szExeFile, L"hysteria2.exe") == 0) {
                    HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
                    if (hProcess) {
                        TerminateProcess(hProcess, 0);
                        CloseHandle(hProcess);
                    }
                }
            } while (Process32Next(hSnap, &pe));
        }
        CloseHandle(hSnap);
    }
    
    // Restore DNS to DHCP
    AppendServiceLog("[service] Restoring DNS settings");
    system("netsh interface ip set dns \"Wi-Fi\" dhcp >nul 2>&1");
    system("netsh interface ip set dns \"Ethernet\" dhcp >nul 2>&1");
    
    AppendServiceLog("[service] Hysteria2 stopped");
    return true;
}


// Open firewall ports for VPN (1080, 10085, 8444, 53)
static bool OpenFirewallPorts() {
    AppendServiceLog("[service] Opening firewall ports for VPN...");
    
    // Delete existing rule first to avoid duplicates
    system("netsh advfirewall firewall delete rule name=\"Xray VPN\"");
    
    // Add inbound rule for TCP ports
    int result_in = system("netsh advfirewall firewall add rule name=\"Xray VPN\" dir=in action=allow protocol=tcp localport=1080,10085,8444");
    // Add inbound rule for UDP (DNS)
    int result_in_udp = system("netsh advfirewall firewall add rule name=\"Xray VPN UDP\" dir=in action=allow protocol=udp localport=53,1080");
    // Add outbound rule for TCP ports
    int result_out = system("netsh advfirewall firewall add rule name=\"Xray VPN Out\" dir=out action=allow protocol=tcp localport=1080,10085,8444");
    // Add outbound rule for UDP
    int result_out_udp = system("netsh advfirewall firewall add rule name=\"Xray VPN Out UDP\" dir=out action=allow protocol=udp localport=53,1080");
    
    if (result_in == 0 && result_in_udp == 0 && result_out == 0 && result_out_udp == 0) {
        AppendServiceLog("[service] Firewall ports opened successfully");
        return true;
    } else {
        AppendServiceLog("[service] Failed to open some firewall ports");
        return false;
    }
}

// Close firewall ports for VPN
static bool CloseFirewallPorts() {
    AppendServiceLog("[service] Closing firewall ports for VPN...");
    
    int result1 = system("netsh advfirewall firewall delete rule name=\"Xray VPN\"");
    int result2 = system("netsh advfirewall firewall delete rule name=\"Xray VPN UDP\"");
    int result3 = system("netsh advfirewall firewall delete rule name=\"Xray VPN Out\"");
    int result4 = system("netsh advfirewall firewall delete rule name=\"Xray VPN Out UDP\"");
    
    if (result1 == 0 || result2 == 0 || result3 == 0 || result4 == 0) {
        AppendServiceLog("[service] Firewall ports closed successfully");
        return true;
    } else {
        AppendServiceLog("[service] Failed to close some firewall ports (may not exist)");
        return false;
    }
}

static std::string WStringToString(const std::wstring& wstr) {
    if (wstr.empty()) return "";
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string str(size_needed - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &str[0], size_needed, nullptr, nullptr);
    return str;
}

static bool SetSystemProxy(bool enable) {
    HKEY hKey;
    LONG result = RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings", 
                                 0, KEY_WRITE, &hKey);
    if (result != ERROR_SUCCESS) {
        AppendServiceLog("[service] Failed to open registry key for proxy");
        return false;
    }
    
    DWORD proxyEnable = enable ? 1 : 0;
    RegSetValueExW(hKey, L"ProxyEnable", 0, REG_DWORD, (BYTE*)&proxyEnable, sizeof(proxyEnable));
    
    if (enable) {
        std::wstring proxyServer = L"127.0.0.1:8080";
        RegSetValueExW(hKey, L"ProxyServer", 0, REG_SZ, (BYTE*)proxyServer.c_str(), 
                        static_cast<DWORD>((proxyServer.length() + 1) * sizeof(wchar_t)));
        AppendServiceLog("[service] System proxy enabled: 127.0.0.1:8080");
    } else {
        RegDeleteValueW(hKey, L"ProxyServer");
        AppendServiceLog("[service] System proxy disabled");
    }
    
    RegCloseKey(hKey);
    
    // Notify system of proxy change
    InternetSetOptionW(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0);
    InternetSetOptionW(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);
    
    return true;
}

static bool ConfigureTunRoutes() {
    // Wait for Hysteria2 TUN interface to appear
    DWORD ifIndex = 0;
    bool found = false;
    
    for (int i = 0; i < 30; i++) { // Wait up to 15 seconds
        Sleep(500);
        
        // Get adapter list using GetAdaptersAddresses (Unicode friendly names)
        ULONG bufLen = 0;
        DWORD dwRetVal = GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr, nullptr, &bufLen);
        if (dwRetVal != ERROR_BUFFER_OVERFLOW) continue;
        
        std::vector<BYTE> buffer(bufLen);
        PIP_ADAPTER_ADDRESSES pAddrs = reinterpret_cast<PIP_ADAPTER_ADDRESSES>(buffer.data());
        
        if (GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr, pAddrs, &bufLen) == NO_ERROR) {
            PIP_ADAPTER_ADDRESSES pCurr = pAddrs;
            while (pCurr) {
                std::wstring friendlyName(pCurr->FriendlyName);
                std::wstring desc(pCurr->Description);
                if (friendlyName.find(L"Hysteria2") != std::wstring::npos || 
                    friendlyName.find(L"Wintun") != std::wstring::npos ||
                    desc.find(L"Wintun") != std::wstring::npos) {
                    ifIndex = pCurr->IfIndex;
                    found = true;
                    AppendServiceLog("[service] TUN interface found: idx=" + std::to_string(ifIndex) + " name=" + WStringToString(friendlyName));
                    break;
                }
                pCurr = pCurr->Next;
            }
        }
        if (found) break;
    }
    
    if (!found) {
        AppendServiceLog("[service] TUN interface not detected after 15s");
        return false;
    }
    
    // Configure default route through TUN with low metric
    Sleep(1000); // Wait for interface to be ready
    
    // Add default route with metric 1 (highest priority)
    std::wstring cmd = L"route add 0.0.0.0 mask 0.0.0.0 10.0.0.1 metric 1 if " + std::to_wstring(ifIndex);
    
    STARTUPINFOW si = { sizeof(si) };
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi = {};
    
    BOOL created = CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE,
                                  CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
    if (created) {
        WaitForSingleObject(pi.hProcess, 5000);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        AppendServiceLog("[service] Default route added via TUN");
    } else {
        AppendServiceLog("[service] Failed to add default route");
    }
    
    // Set DNS to use through TUN
    cmd = L"netsh interface ip set dns name=\"Hysteria2\" static 1.1.1.1";
    created = CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE,
                              CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
    if (created) {
        WaitForSingleObject(pi.hProcess, 3000);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        AppendServiceLog("[service] DNS configured on TUN");
    }
    
    return true;
}

static bool StartHysteria2() {
    // hysteria2.exe is downloaded to data dir by Hysteria2Downloader
    std::wstring moduleDir = GetModuleDir();
    std::wstring dataDir = GetDataDir();
    
    // Look for hysteria2.exe in dataDir
    std::wstring hysteria2Path = dataDir + L"\\hysteria2.exe";
    std::wstring configPath = dataDir + L"\\config.yaml";

    AppendServiceLog("[service] Module dir: " + WStringToString(moduleDir));
    AppendServiceLog("[service] Data dir: " + WStringToString(dataDir));
    AppendServiceLog("[service] Looking for hysteria2.exe at: " + WStringToString(hysteria2Path));

    if (!FileExists(hysteria2Path)) {
        AppendServiceLog("[service] hysteria2.exe not found in data directory");
        return false;
    }
    if (!FileExists(configPath)) {
        AppendServiceLog("[service] config.yaml missing in data directory");
        return false;
    }
    
    // Check for wintun.dll (required for TUN mode)
    std::wstring wintunPath = dataDir + L"\\wintun.dll";
    if (FileExists(wintunPath)) {
        WIN32_FILE_ATTRIBUTE_DATA fad;
        if (GetFileAttributesExW(wintunPath.c_str(), GetFileExInfoStandard, &fad)) {
            LARGE_INTEGER size;
            size.HighPart = fad.nFileSizeHigh;
            size.LowPart = fad.nFileSizeLow;
            AppendServiceLog("[service] wintun.dll found: " + std::to_string(size.QuadPart) + " bytes");
        }
    } else {
        AppendServiceLog("[service] wintun.dll NOT found in data directory, TUN will not work");
    }
    
    AppendServiceLog("[service] All files found");

    // Redirect stdout/stderr to log file for diagnostics
    std::wstring logPath = dataDir + L"\\hysteria2.log";
    SECURITY_ATTRIBUTES sa = { sizeof(sa), nullptr, TRUE };
    HANDLE hLogFile = CreateFileW(logPath.c_str(), GENERIC_WRITE, FILE_SHARE_READ, &sa, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);

    // Hysteria2 command line - client mode with config
    std::wstring cmdLine = L"\"" + hysteria2Path + L"\" client -c \"" + configPath + L"\"";
    AppendServiceLog("[service] Command line: " + WStringToString(cmdLine));
    
    STARTUPINFOW si = { sizeof(si) };
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = hLogFile;
    si.hStdError = hLogFile;
    PROCESS_INFORMATION pi = {};
    
    BOOL created = CreateProcessW(
        nullptr, 
        cmdLine.data(), 
        nullptr, 
        nullptr, 
        TRUE,  // Inherit handles
        CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP,
        nullptr, 
        dataDir.c_str(),  // Working directory = data dir (where wintun.dll is)
        &si, 
        &pi);
    
    if (hLogFile != INVALID_HANDLE_VALUE) {
        CloseHandle(hLogFile);
    }
        
    if (!created) {
        DWORD err = GetLastError();
        AppendServiceLog("[service] CreateProcessW failed: " + std::to_string(err));
        return false;
    }

    CloseHandle(pi.hThread);
    g_hysteria2Process = pi.hProcess;
    AppendServiceLog("[service] Hysteria2 started successfully with PID: " + std::to_string(pi.dwProcessId));
    
    // Wait a bit and check if Hysteria2 is still running
    Sleep(2000);
    DWORD exitCode;
    if (GetExitCodeProcess(g_hysteria2Process, &exitCode)) {
        if (exitCode != STILL_ACTIVE) {
            AppendServiceLog("[service] Hysteria2 exited immediately with code: " + std::to_string(exitCode));
            // Read hysteria2.log for error details
            std::ifstream logFile(WStringToString(dataDir) + "\\hysteria2.log");
            if (logFile.is_open()) {
                std::string line;
                while (std::getline(logFile, line)) {
                    AppendServiceLog("[hysteria2] " + line);
                }
            }
            return false;
        }
        AppendServiceLog("[service] Hysteria2 is running");
    }
    
    // Hysteria2 works as SOCKS5/HTTP proxy and TUN interface
    AppendServiceLog("[service] Hysteria2 proxy mode active (SOCKS5: 127.0.0.1:1080, HTTP: 127.0.0.1:8080)");
    
    // Enable system proxy to redirect traffic through HTTP proxy
    SetSystemProxy(true);
    
    // Configure TUN routes for full VPN tunneling
    ConfigureTunRoutes();
    
    return true;
}

static std::string HandleCommand(const std::string& cmdLine) {
    // Protocol:
    // PING\n
    // DISCONNECT\n
    // CONNECT_JSON <json>\n
    if (cmdLine == "PING") {
        return "PONG";
    }
    if (cmdLine == "DISCONNECT") {
        StopHysteria2();
        CloseFirewallPorts();  // Close firewall ports on disconnect
        return "OK";
    }

    const std::string prefix = "CONNECT_JSON ";
    if (cmdLine.rfind(prefix, 0) == 0) {
        std::string yaml = cmdLine.substr(prefix.size());
        AppendServiceLog("[service] CONNECT_JSON received (YAML), config length: " + std::to_string(yaml.length()));
        
        StopHysteria2();
        AppendServiceLog("[service] Hysteria2 stopped (if was running)");
        
        // Write YAML config first
        AppendServiceLog("[service] Writing Hysteria2 config file...");
        if (!WriteHysteria2Config(yaml)) {
            AppendServiceLog("[service] ERROR: WriteHysteria2Config failed");
            return "ERR write_config";
        }
        AppendServiceLog("[service] Hysteria2 config file written successfully");
        
        // Open firewall ports before starting VPN
        AppendServiceLog("[service] Opening firewall ports...");
        OpenFirewallPorts();
        AppendServiceLog("[service] Firewall ports opened");
        
        // Now start Hysteria2
        AppendServiceLog("[service] Starting Hysteria2...");
        if (!StartHysteria2()) {
            AppendServiceLog("[service] ERROR: StartHysteria2 failed");
            CloseFirewallPorts();  // Close ports if Hysteria2 fails
            return "ERR start_hysteria2";
        }
        
        AppendServiceLog("[service] Hysteria2 started successfully, returning OK");
        return "OK";
    }

    return "ERR unknown_command";
}

static void PipeServerThread() {
    const wchar_t* pipeName = L"\\\\.\\pipe\\VoyfyVpnPipe";

    while (WaitForSingleObject(g_stopEvent, 0) == WAIT_TIMEOUT) {
        HANDLE hPipe = CreateNamedPipeW(
            pipeName,
            PIPE_ACCESS_DUPLEX,
            PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
            1,
            64 * 1024,
            64 * 1024,
            0,
            CreatePipeSecurityAttributes());

        if (hPipe == INVALID_HANDLE_VALUE) {
            AppendServiceLog("[service] CreateNamedPipeW failed");
            std::this_thread::sleep_for(std::chrono::seconds(1));
            continue;
        }

        BOOL connected = ConnectNamedPipe(hPipe, nullptr) ? TRUE : (GetLastError() == ERROR_PIPE_CONNECTED);
        if (!connected) {
            CloseHandle(hPipe);
            continue;
        }

        char buffer[64 * 1024];
        DWORD read = 0;
        BOOL ok = ReadFile(hPipe, buffer, sizeof(buffer) - 1, &read, nullptr);
        if (!ok || read == 0) {
            DisconnectNamedPipe(hPipe);
            CloseHandle(hPipe);
            continue;
        }
        buffer[read] = 0;

        std::string cmd(buffer);
        while (!cmd.empty() && (cmd.back() == '\n' || cmd.back() == '\r')) cmd.pop_back();
        
        AppendServiceLog("[service] Received command: " + cmd);

        std::string resp;
        try {
            resp = HandleCommand(cmd);
        } catch (...) {
            resp = "ERR exception";
            AppendServiceLog("[service] Exception in HandleCommand");
        }
        AppendServiceLog("[service] Response: " + resp);
        resp += "\n";
        DWORD written = 0;
        WriteFile(hPipe, resp.data(), (DWORD)resp.size(), &written, nullptr);

        FlushFileBuffers(hPipe);
        DisconnectNamedPipe(hPipe);
        CloseHandle(hPipe);
    }
}

static void SetServiceStatusState(DWORD state, DWORD win32ExitCode = NO_ERROR, DWORD waitHint = 0) {
    g_serviceStatus.dwCurrentState = state;
    g_serviceStatus.dwWin32ExitCode = win32ExitCode;
    g_serviceStatus.dwWaitHint = waitHint;
    SetServiceStatus(g_statusHandle, &g_serviceStatus);
}

static void WINAPI ServiceCtrlHandler(DWORD ctrl) {
    if (ctrl == SERVICE_CONTROL_STOP) {
        SetServiceStatusState(SERVICE_STOP_PENDING, NO_ERROR, 3000);
        SetEvent(g_stopEvent);
    }
}

static void WINAPI ServiceMain(DWORD /*argc*/, LPWSTR* /*argv*/) {
    g_statusHandle = RegisterServiceCtrlHandlerW(L"VoyfyVpnService", ServiceCtrlHandler);
    if (!g_statusHandle) return;

    g_serviceStatus.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    g_serviceStatus.dwControlsAccepted = SERVICE_ACCEPT_STOP;

    g_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!g_stopEvent) {
        SetServiceStatusState(SERVICE_STOPPED, GetLastError());
        return;
    }

    AppendServiceLog("[service] ServiceMain started");
    SetServiceStatusState(SERVICE_RUNNING);

    std::thread server(PipeServerThread);

    WaitForSingleObject(g_stopEvent, INFINITE);

    StopHysteria2();

    if (server.joinable()) server.join();

    SetServiceStatusState(SERVICE_STOPPED);
}

int APIENTRY wWinMain(_In_ HINSTANCE /*instance*/, _In_opt_ HINSTANCE /*prev*/,
                      _In_ LPWSTR /*cmd_line*/, _In_ int /*show_command*/) {
    SERVICE_TABLE_ENTRYW serviceTable[] = {
        { const_cast<LPWSTR>(L"VoyfyVpnService"), ServiceMain },
        { nullptr, nullptr }
    };

    if (!StartServiceCtrlDispatcherW(serviceTable)) {
        return (int)GetLastError();
    }

    return 0;
}
