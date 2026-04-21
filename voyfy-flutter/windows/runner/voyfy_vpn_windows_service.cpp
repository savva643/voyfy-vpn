#include <windows.h>
#include <shlobj.h>
#include <iphlpapi.h>
#include <fstream>
#include <sstream>
#include <string>
#include <thread>
#include <chrono>
#include <algorithm>
#include <iterator>

#pragma comment(lib, "iphlpapi.lib")

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
static HANDLE g_xrayProcess = nullptr;

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

static bool WriteConfigFile(const std::string& configJson) {
    std::wstring dir = GetDataDir();
    if (dir.empty()) return false;
    
    // Replace user paths with SYSTEM paths in the config
    std::string modifiedConfig = configJson;
    
    // Convert wstring dir to string using WideCharToMultiByte
    int sizeNeeded = WideCharToMultiByte(CP_UTF8, 0, dir.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string systemDirStr(sizeNeeded - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, dir.c_str(), -1, &systemDirStr[0], sizeNeeded, nullptr, nullptr);
    
    // Replace backslashes with forward slashes for JSON
    std::replace(systemDirStr.begin(), systemDirStr.end(), '\\', '/');
    
    // Find and replace user-specific paths (e.g., C:/Users/Timur/AppData/Local/VoyfyVPN/access.log)
    size_t pos = 0;
    while ((pos = modifiedConfig.find("C:/Users/", pos)) != std::string::npos) {
        size_t voyfyPos = modifiedConfig.find("/VoyfyVPN/", pos);
        if (voyfyPos != std::string::npos) {
            // Find the end of the path (look for file suffix like /access.log or /error.log)
            size_t pathEnd = modifiedConfig.find("\"", voyfyPos);
            if (pathEnd != std::string::npos) {
                // Extract suffix after /VoyfyVPN/ (e.g., access.log or error.log)
                size_t suffixStart = voyfyPos + 10; // Length of "/VoyfyVPN/"
                std::string suffix = modifiedConfig.substr(suffixStart, pathEnd - suffixStart);
                std::string newPath = systemDirStr + "/" + suffix;
                modifiedConfig.replace(pos, pathEnd - pos, newPath);
            }
        }
        pos++;
    }
    
    std::ofstream file(dir + L"\\config.json", std::ios::binary);
    if (!file.is_open()) return false;
    file << modifiedConfig;
    file.close();
    return true;
}

static bool StopXray() {
    if (g_xrayProcess) {
        TerminateProcess(g_xrayProcess, 0);
        CloseHandle(g_xrayProcess);
        g_xrayProcess = nullptr;
    }
    return true;
}

// Parse server IP from config file
static std::string ParseServerIPFromFile() {
    std::wstring dir = GetDataDir();
    if (dir.empty()) return "";
    
    std::wstring configPath = dir + L"\\config.json";
    std::ifstream file(configPath);
    if (!file.is_open()) return "";
    
    std::string json((std::istreambuf_iterator<char>(file)),
                      std::istreambuf_iterator<char>());
    file.close();
    
    size_t addrPos = json.find("\"address\"");
    if (addrPos == std::string::npos) return "";
    
    size_t colonPos = json.find(":", addrPos);
    if (colonPos == std::string::npos) return "";
    
    size_t quoteStart = json.find("\"", colonPos);
    if (quoteStart == std::string::npos) return "";
    
    size_t quoteEnd = json.find("\"", quoteStart + 1);
    if (quoteEnd == std::string::npos) return "";
    
    return json.substr(quoteStart + 1, quoteEnd - quoteStart - 1);
}

// Add bypass route for VPN server IP using route command
static bool AddServerBypassRoute(const std::string& serverIP) {
    if (serverIP.empty()) {
        AppendServiceLog("[service] Server IP empty, cannot add bypass route");
        return false;
    }
    
    AppendServiceLog("[service] Adding bypass route for server: " + serverIP);
    
    // Use route.exe command which is more reliable
    std::string cmd = "route delete " + serverIP + " 2>nul";
    system(cmd.c_str());
    
    // Add host route /32 with gateway 192.168.1.1 and metric 1
    std::string addCmd = "route add " + serverIP + " mask 255.255.255.255 192.168.1.1 metric 1";
    int result = system(addCmd.c_str());
    
    if (result == 0) {
        AppendServiceLog("[service] Bypass route added successfully via route.exe");
        return true;
    } else {
        AppendServiceLog("[service] Failed to add bypass route, result: " + std::to_string(result));
        return false;
    }
}

// Disable Windows Firewall for all profiles
static bool DisableFirewall() {
    AppendServiceLog("[service] Disabling Windows Firewall...");
    int result = system("netsh advfirewall set allprofiles state off");
    if (result == 0) {
        AppendServiceLog("[service] Windows Firewall disabled successfully");
        return true;
    } else {
        AppendServiceLog("[service] Failed to disable firewall, result: " + std::to_string(result));
        return false;
    }
}

// Enable Windows Firewall for all profiles
static bool EnableFirewall() {
    AppendServiceLog("[service] Enabling Windows Firewall...");
    int result = system("netsh advfirewall set allprofiles state on");
    if (result == 0) {
        AppendServiceLog("[service] Windows Firewall enabled successfully");
        return true;
    } else {
        AppendServiceLog("[service] Failed to enable firewall, result: " + std::to_string(result));
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

static bool RunNetshCommand(const std::wstring& args) {
    std::wstring cmd = L"netsh " + args;
    
    STARTUPINFOW si = { sizeof(si) };
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi = {};
    
    BOOL created = CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE,
                                  CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT,
                                  nullptr, nullptr, &si, &pi);
    if (!created) {
        return false;
    }
    
    WaitForSingleObject(pi.hProcess, 5000);
    DWORD exitCode = 0;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    
    return exitCode == 0;
}

static bool ConfigureTunInterface() {
    // Wait for xray0 interface to appear
    DWORD ifIndex = 0;
    for (int i = 0; i < 60; i++) {
        Sleep(500);
        
        // Get interface index
        ULONG buflen = sizeof(IP_ADAPTER_INFO);
        PIP_ADAPTER_INFO pAdapterInfo = (PIP_ADAPTER_INFO)malloc(buflen);
        if (GetAdaptersInfo(pAdapterInfo, &buflen) == ERROR_BUFFER_OVERFLOW) {
            free(pAdapterInfo);
            pAdapterInfo = (PIP_ADAPTER_INFO)malloc(buflen);
        }
        
        if (GetAdaptersInfo(pAdapterInfo, &buflen) == NO_ERROR) {
            PIP_ADAPTER_INFO pAdapter = pAdapterInfo;
            while (pAdapter) {
                std::string desc(pAdapter->Description);
                if (desc.find("Xray") != std::string::npos || desc.find("Wintun") != std::string::npos) {
                    ifIndex = pAdapter->Index;
                    free(pAdapterInfo);
                    AppendServiceLog("[service] TUN interface found: idx=" + std::to_string(ifIndex));
                    goto found;
                }
                pAdapter = pAdapter->Next;
            }
        }
        free(pAdapterInfo);
    }
    AppendServiceLog("[service] TUN interface not detected after 30s");
    return false;
    
found:
    // Configure IP address using netsh
    Sleep(1000); // Wait for interface to be ready
    
    // Add IP address
    if (!RunNetshCommand(L"interface ip set address name=\"xray0\" source=static addr=10.0.0.2 mask=255.255.255.0 gateway=10.0.0.1")) {
        AppendServiceLog("[service] Failed to set IP address");
    } else {
        AppendServiceLog("[service] IP address configured");
    }
    
    // Add DNS
    RunNetshCommand(L"interface ip set dns name=\"xray0\" source=static addr=1.1.1.1");
    RunNetshCommand(L"interface ip add dns name=\"xray0\" addr=8.8.8.8 index=2");
    AppendServiceLog("[service] DNS configured");
    
    // Add default route with low metric
    // First delete existing default routes for this interface
    RunNetshCommand(L"interface ip delete route 0.0.0.0 interface=\"xray0\"");
    
    // Add new default route
    if (RunNetshCommand(L"interface ip add route 0.0.0.0/0 interface=\"xray0\" nexthop=10.0.0.1 metric=1")) {
        AppendServiceLog("[service] Default route added");
    } else {
        AppendServiceLog("[service] Failed to add default route");
    }
    
    return true;
}

static bool StartXray() {
    // xray.exe should be in the same directory as the service executable
    std::wstring moduleDir = GetModuleDir();
    std::wstring dataDir = GetDataDir();
    
    std::wstring xrayPath = moduleDir + L"\\xray.exe";
    std::wstring wintunPath = moduleDir + L"\\wintun.dll";
    std::wstring configPath = dataDir + L"\\config.json";

    AppendServiceLog("[service] Module dir: " + WStringToString(moduleDir));
    AppendServiceLog("[service] Data dir: " + WStringToString(dataDir));

    if (!FileExists(xrayPath)) {
        AppendServiceLog("[service] xray.exe not found in module directory");
        return false;
    }
    if (!FileExists(wintunPath)) {
        AppendServiceLog("[service] wintun.dll not found in module directory");
        return false;
    }
    if (!FileExists(configPath)) {
        AppendServiceLog("[service] config.json missing in data directory");
        return false;
    }
    AppendServiceLog("[service] All files found");

    // Add bypass route for VPN server before starting Xray
    std::string serverIP = ParseServerIPFromFile();
    if (!serverIP.empty()) {
        AppendServiceLog("[service] Server IP: " + serverIP);
        AddServerBypassRoute(serverIP);
    } else {
        AppendServiceLog("[service] Failed to parse server IP from config");
    }

    // Set working directory to module dir so xray can find wintun.dll
    std::wstring cmdLine = L"\"" + xrayPath + L"\" -config=\"" + configPath + L"\"";
    AppendServiceLog("[service] Command line: " + WStringToString(cmdLine));
    
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    
    BOOL created = CreateProcessW(
        nullptr, 
        cmdLine.data(), 
        nullptr, 
        nullptr, 
        FALSE,
        CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP,
        nullptr, 
        moduleDir.c_str(),  // Working directory = module dir (for wintun.dll)
        &si, 
        &pi);
        
    if (!created) {
        DWORD err = GetLastError();
        AppendServiceLog("[service] CreateProcessW failed: " + std::to_string(err));
        return false;
    }

    CloseHandle(pi.hThread);
    g_xrayProcess = pi.hProcess;
    AppendServiceLog("[service] Xray started successfully with PID: " + std::to_string(pi.dwProcessId));
    
    // Wait a bit and check if Xray is still running
    Sleep(1000);
    DWORD exitCode;
    if (GetExitCodeProcess(g_xrayProcess, &exitCode)) {
        if (exitCode != STILL_ACTIVE) {
            AppendServiceLog("[service] Xray exited with code: " + std::to_string(exitCode));
            return false;
        }
        AppendServiceLog("[service] Xray is running");
    }
    
    // Manually configure TUN interface (IP address and routes)
    if (!ConfigureTunInterface()) {
        AppendServiceLog("[service] Failed to configure TUN interface");
        // Continue anyway, Xray might have configured it
    }
    
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
        StopXray();
        EnableFirewall();  // Re-enable firewall on disconnect
        return "OK";
    }

    const std::string prefix = "CONNECT_JSON ";
    if (cmdLine.rfind(prefix, 0) == 0) {
        std::string json = cmdLine.substr(prefix.size());
        StopXray();
        
        // Write config first
        if (!WriteConfigFile(json)) {
            return "ERR write_config";
        }
        
        // Disable firewall before starting VPN
        DisableFirewall();
        
        // Now start Xray (it will parse server IP from the written config file)
        if (!StartXray()) {
            EnableFirewall();  // Re-enable firewall if Xray fails
            return "ERR start_xray";
        }
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

    StopXray();

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
