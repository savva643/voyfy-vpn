#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <shellapi.h>
#include <winsvc.h>
#include <shlobj.h>
#include <fstream>
#include <sstream>

#include "flutter_window.h"
#include "utils.h"

static void InstallerLog(const std::string& msg) {
    try {
        wchar_t path[MAX_PATH];
        if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_COMMON_APPDATA, nullptr, 0, path))) {
            std::wstring dir = path;
            dir += L"\\VoyfyVPN";
            CreateDirectoryW(dir.c_str(), nullptr);
            std::ofstream f(dir + L"\\installer.log", std::ios::app);
            if (f.is_open()) {
                f << msg << "\n";
            }
        }
    } catch (...) {}
}

static std::string LastErrorToString(DWORD err) {
    if (err == 0) return "0";
    LPWSTR buf = nullptr;
    FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                   nullptr, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPWSTR)&buf, 0, nullptr);
    std::wstring msg = buf ? std::wstring(buf) : L"";
    if (buf) LocalFree(buf);
    char narrow[512];
    WideCharToMultiByte(CP_UTF8, 0, msg.c_str(), -1, narrow, sizeof(narrow), nullptr, nullptr);
    std::ostringstream oss;
    oss << err << ": " << narrow;
    return oss.str();
}

static bool IsRunningAsAdmin() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
    return false;
  }
  TOKEN_ELEVATION elevation;
  DWORD size = sizeof(elevation);
  bool is_elevated = false;
  if (GetTokenInformation(token, TokenElevation, &elevation, sizeof(elevation),
                          &size)) {
    is_elevated = elevation.TokenIsElevated != 0;
  }
  CloseHandle(token);
  return is_elevated;
}

static bool RelaunchAsAdminIfNeeded() {
  if (IsRunningAsAdmin()) {
    return false;
  }

  wchar_t exe_path[MAX_PATH];
  DWORD len = GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    return false;
  }

  // Preserve original arguments.
  // CommandLineToArgvW returns argv[0] = exe name, so we skip it.
  int argc = 0;
  wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  std::wstring params;
  if (argv) {
    for (int i = 1; i < argc; i++) {
      if (!params.empty()) {
        params += L" ";
      }
      params += L"\"";
      params += argv[i];
      params += L"\"";
    }
    LocalFree(argv);
  }

  HINSTANCE result = ShellExecuteW(nullptr, L"runas", exe_path,
                                  params.empty() ? nullptr : params.c_str(),
                                  nullptr, SW_SHOWNORMAL);
  if ((INT_PTR)result <= 32) {
    return false;
  }

  // Successfully launched elevated instance; exit this one.
  ExitProcess(0);
  return true;
}

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

static bool CopyFileIfExists(const std::wstring& src, const std::wstring& dst) {
  // Use Windows API instead of std::filesystem (C++17 not available)
  DWORD attribs = GetFileAttributesW(src.c_str());
  if (attribs == INVALID_FILE_ATTRIBUTES) {
    return false; // Source doesn't exist
  }
  // Copy with overwrite
  return CopyFileW(src.c_str(), dst.c_str(), FALSE) != 0;
}

static std::string WStringToString(const std::wstring& wstr) {
  if (wstr.empty()) return "";
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
  std::string str(size_needed - 1, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &str[0], size_needed, nullptr, nullptr);
  return str;
}

static bool InstallAndStartService() {
  InstallerLog("=== InstallAndStartService started ===");
  
  const wchar_t* kServiceName = L"VoyfyVpnService";
  std::wstring moduleDir = GetModuleDir();
  if (moduleDir.empty()) {
    InstallerLog("ERROR: GetModuleDir() returned empty");
    return false;
  }
  InstallerLog("Module dir: " + WStringToString(moduleDir));

  std::wstring serviceExePath = moduleDir + L"\\VoyfyVpnService.exe";
  std::wstring binPath = L"\"" + serviceExePath + L"\"";
  
  // Check if service exe exists
  DWORD attribs = GetFileAttributesW(serviceExePath.c_str());
  if (attribs == INVALID_FILE_ATTRIBUTES) {
    InstallerLog("ERROR: VoyfyVpnService.exe not found at: " + WStringToString(serviceExePath));
    return false;
  }
  InstallerLog("VoyfyVpnService.exe found");

  // Copy xray.exe and wintun.dll to service directory (from assets)
  std::wstring xraySrc = moduleDir + L"\\data\\flutter_assets\\assets\\xray\\xray.exe";
  std::wstring wintunSrc = moduleDir + L"\\data\\flutter_assets\\assets\\xray\\wintun.dll";
  
  bool copiedXray = CopyFileIfExists(xraySrc, moduleDir + L"\\xray.exe");
  bool copiedWintun = CopyFileIfExists(wintunSrc, moduleDir + L"\\wintun.dll");
  InstallerLog("Copied xray.exe: " + std::string(copiedXray ? "yes" : "no"));
  InstallerLog("Copied wintun.dll: " + std::string(copiedWintun ? "yes" : "no"));

  InstallerLog("Opening SC Manager...");
  SC_HANDLE scm = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_ALL_ACCESS);
  if (!scm) {
    DWORD err = GetLastError();
    InstallerLog("ERROR: OpenSCManagerW failed: " + LastErrorToString(err));
    return false;
  }
  InstallerLog("SC Manager opened successfully");

  InstallerLog("Opening service...");
  SC_HANDLE svc = OpenServiceW(scm, kServiceName, SERVICE_ALL_ACCESS);
  if (!svc) {
    DWORD err = GetLastError();
    InstallerLog("OpenServiceW failed (expected if not exists): " + LastErrorToString(err));
    if (err == ERROR_SERVICE_DOES_NOT_EXIST) {
      InstallerLog("Creating new service...");
      svc = CreateServiceW(
          scm,
          kServiceName,
          L"Voyfy VPN Service",
          SERVICE_ALL_ACCESS,
          SERVICE_WIN32_OWN_PROCESS,
          SERVICE_DEMAND_START,
          SERVICE_ERROR_NORMAL,
          binPath.c_str(),
          nullptr,
          nullptr,
          nullptr,
          nullptr,
          nullptr);
      if (!svc) {
        DWORD err2 = GetLastError();
        InstallerLog("ERROR: CreateServiceW failed: " + LastErrorToString(err2));
        CloseServiceHandle(scm);
        return false;
      }
      InstallerLog("Service created successfully");
    } else {
      InstallerLog("ERROR: OpenServiceW failed with unexpected error");
      CloseServiceHandle(scm);
      return false;
    }
  } else {
    InstallerLog("Service already exists");
  }

  InstallerLog("Starting service...");
  if (!StartServiceW(svc, 0, nullptr)) {
    DWORD err = GetLastError();
    if (err == ERROR_SERVICE_ALREADY_RUNNING) {
      InstallerLog("Service already running");
    } else {
      InstallerLog("ERROR: StartServiceW failed: " + LastErrorToString(err));
      CloseServiceHandle(svc);
      CloseServiceHandle(scm);
      return false;
    }
  } else {
    InstallerLog("Service started successfully");
  }

  CloseServiceHandle(svc);
  CloseServiceHandle(scm);
  InstallerLog("=== InstallAndStartService completed successfully ===");
  return true;
}

static bool HasArg(const wchar_t* cmdLine, const wchar_t* arg) {
  if (!cmdLine || !arg) return false;
  return wcsstr(cmdLine, arg) != nullptr;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // One-time installer entrypoint: run elevated and install/start service.
  if (HasArg(::GetCommandLineW(), L"--install-service")) {
    if (!IsRunningAsAdmin()) {
      RelaunchAsAdminIfNeeded();
      return EXIT_SUCCESS;
    }
    bool ok = InstallAndStartService();
    return ok ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  // Do NOT auto-elevate for GUI - only elevate when explicitly requested
  // via --install-service flag

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.CreateAndShow(L"VoyFy", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
