#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <intrin.h>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

// Check if current CPU hardware supports AVX2 instructions (introduced in Intel Haswell 2013)
bool IsCpuAvx2Supported() {
  int cpuInfo[4] = {0};
  __cpuid(cpuInfo, 0);
  if (cpuInfo[0] < 7) return false;
  __cpuidex(cpuInfo, 7, 0);
  return (cpuInfo[1] & (1 << 5)) != 0; // EBX bit 5 = AVX2
}

// Windows crash handler to capture hardware, driver, or runtime faults
LONG WINAPI QuickBillCrashFilter(EXCEPTION_POINTERS* pException) {
  if (!pException || !pException->ExceptionRecord) return EXCEPTION_CONTINUE_SEARCH;
  DWORD code = pException->ExceptionRecord->ExceptionCode;
  PVOID addr = pException->ExceptionRecord->ExceptionAddress;

  HMODULE hModule = NULL;
  wchar_t moduleName[MAX_PATH] = L"Unknown Module";
  if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         (LPCWSTR)addr, &hModule)) {
    GetModuleFileNameW(hModule, moduleName, MAX_PATH);
  }

  const wchar_t* exceptionDesc = L"General Exception";
  switch (code) {
    case 0xC0000005: exceptionDesc = L"ACCESS_VIOLATION (GPU Driver fault, shader error, or memory access violation)"; break;
    case 0xC00000FD: exceptionDesc = L"STACK_OVERFLOW"; break;
    case 0xC000001D: exceptionDesc = L"ILLEGAL_INSTRUCTION (Unsupported CPU instruction)"; break;
    case 0xC0000135: exceptionDesc = L"DLL_NOT_FOUND (Missing Microsoft Visual C++ Runtime or required DLL)"; break;
    case 0xC0000139: exceptionDesc = L"ENTRYPOINT_NOT_FOUND (Mismatched DLL version)"; break;
    case 0x887A0005: exceptionDesc = L"DXGI_ERROR_DEVICE_REMOVED (DirectX graphics driver crashed / GPU reset)"; break;
    case 0x887A0006: exceptionDesc = L"DXGI_ERROR_DEVICE_HUNG (Graphics driver stopped responding)"; break;
    case 0xE06D7363: exceptionDesc = L"C++ Exception (Unhandled C++ throw)"; break;
  }

  SYSTEMTIME st;
  GetLocalTime(&st);

  MEMORYSTATUSEX memInfo;
  memInfo.dwLength = sizeof(MEMORYSTATUSEX);
  GlobalMemoryStatusEx(&memInfo);

  wchar_t logContent[2048];
  swprintf_s(logContent, 2048,
    L"================================================================\n"
    L"QUICKBILL POS WINDOWS CRASH REPORT\n"
    L"Timestamp: %04d-%02d-%02d %02d:%02d:%02d\n"
    L"================================================================\n"
    L"Exception Code:    0x%08X\n"
    L"Exception Meaning: %ls\n"
    L"Faulting Module:   %ls\n"
    L"Fault Address:     0x%p\n"
    L"Total Physical RAM: %llu MB\n"
    L"Avail Physical RAM: %llu MB\n"
    L"Memory Load:       %u%%\n"
    L"================================================================\n\n",
    st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond,
    code, exceptionDesc, moduleName, addr,
    memInfo.ullTotalPhys / (1024 * 1024),
    memInfo.ullAvailPhys / (1024 * 1024),
    memInfo.dwMemoryLoad);

  // Write log to current folder
  FILE* f = nullptr;
  if (_wfopen_s(&f, L"quickbill_crash.log", L"a") == 0 && f) {
    fwprintf(f, L"%ls", logContent);
    fclose(f);
  }

  // Also write to %LOCALAPPDATA%\QuickBill\quickbill_crash.log
  wchar_t* localAppData = nullptr;
  size_t len = 0;
  if (_wdupenv_s(&localAppData, &len, L"LOCALAPPDATA") == 0 && localAppData) {
    wchar_t appDataLogPath[MAX_PATH];
    swprintf_s(appDataLogPath, MAX_PATH, L"%ls\\QuickBill", localAppData);
    CreateDirectoryW(appDataLogPath, NULL);
    swprintf_s(appDataLogPath, MAX_PATH, L"%ls\\QuickBill\\quickbill_crash.log", localAppData);
    if (_wfopen_s(&f, appDataLogPath, L"a") == 0 && f) {
      fwprintf(f, L"%ls", logContent);
      fclose(f);
    }
    free(localAppData);
  }

  wchar_t msg[1024];
  swprintf_s(msg, 1024,
    L"QuickBill POS encountered an unexpected system error.\n\n"
    L"• Exception: 0x%08X\n"
    L"• Type: %ls\n"
    L"• Faulting Module: %ls\n\n"
    L"A detailed crash report has been saved to:\n"
    L"quickbill_crash.log\n\n"
    L"Recommended Fixes:\n"
    L"1. Install 'vc_redist.x64.exe' in the QuickBill folder.\n"
    L"2. Update or reinstall your Intel Display Drivers.\n"
    L"3. Run QuickBill as Administrator.",
    code, exceptionDesc, moduleName);

  ::MessageBoxW(nullptr, msg, L"QuickBill Crash Diagnostics", MB_ICONERROR | MB_OK);
  return EXCEPTION_EXECUTE_HANDLER;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  ::SetUnhandledExceptionFilter(QuickBillCrashFilter);

  // Diagnostic log for hardware & CPU instruction set compatibility
  bool hasAvx2 = IsCpuAvx2Supported();
  FILE* startupLog = nullptr;
  if (_wfopen_s(&startupLog, L"quickbill_startup.log", L"w") == 0 && startupLog) {
    fwprintf(startupLog, L"=== QuickBill POS Windows Startup Diagnostics ===\n");
    fwprintf(startupLog, L"CPU Architecture: %ls\n", hasAvx2 ? L"AVX2 Supported (Modern Architecture)" : L"Intel Sandy Bridge / Legacy x86-64 (AVX2-Free Safe Mode)");
    fwprintf(startupLog, L"Instruction Target: /arch:AVX (Compatible with Intel Core i5-2400 and above)\n");
    fclose(startupLog);
  }

  // Ensure current working directory is the folder where the executable lives
  // so relative paths (e.g. "data" and bundled DLLs) always resolve correctly,
  // regardless of how or from where the shortcut/app was launched.
  wchar_t exe_path[MAX_PATH];
  if (GetModuleFileNameW(nullptr, exe_path, MAX_PATH) > 0) {
    std::wstring exe_str(exe_path);
    size_t last_slash = exe_str.find_last_of(L"\\/");
    if (last_slash != std::wstring::npos) {
      SetCurrentDirectoryW(exe_str.substr(0, last_slash).c_str());
    }
  }

  // Attach to parent console if running from CMD or PowerShell
  if (!::AttachConsole(ATTACH_PARENT_PROCESS)) {
    if (::IsDebuggerPresent()) {
      CreateAndAttachConsole();
    }
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  try {
    flutter::DartProject project(L"data");

    std::vector<std::string> command_line_arguments =
        GetCommandLineArguments();

    project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

    FlutterWindow window(project);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1280, 720);
    if (!window.Create(L"QuickBill POS — Retail Billing", origin, size)) {
      ::MessageBox(nullptr,
        L"Failed to create application window.\n\nPlease check that your graphics drivers are up to date and that Microsoft Visual C++ 2015-2022 Redistributable (x64) is installed.",
        L"QuickBill Launch Error", MB_ICONERROR | MB_OK);
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
  } catch (const std::exception& e) {
    std::string err_msg = e.what();
    std::wstring w_err(err_msg.begin(), err_msg.end());
    ::MessageBox(nullptr, w_err.c_str(), L"QuickBill Launch Error", MB_ICONERROR | MB_OK);
    return EXIT_FAILURE;
  } catch (...) {
    ::MessageBox(nullptr,
      L"An unexpected error occurred while launching QuickBill POS.",
      L"QuickBill Launch Error", MB_ICONERROR | MB_OK);
    return EXIT_FAILURE;
  }
}
