#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <intrin.h>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

// CPU Hardware instruction capabilities detected via CPUID
struct CpuFeatures {
  char vendor[13] = {0};
  char brand[49] = {0};
  bool sse = false;
  bool sse2 = false;
  bool sse3 = false;
  bool ssse3 = false;
  bool sse41 = false;
  bool sse42 = false;
  bool avx = false;
  bool avx2 = false;
  bool fma = false;
  bool f16c = false;
  bool bmi1 = false;
  bool bmi2 = false;
  bool popcnt = false;
  bool aes = false;
};

CpuFeatures DetectCpuFeatures() {
  CpuFeatures feat;
  int cpuInfo[4] = {0};

  // Vendor string (Function 0)
  __cpuid(cpuInfo, 0);
  int nIds = cpuInfo[0];
  *reinterpret_cast<int*>(feat.vendor) = cpuInfo[1];
  *reinterpret_cast<int*>(feat.vendor + 4) = cpuInfo[3];
  *reinterpret_cast<int*>(feat.vendor + 8) = cpuInfo[2];
  feat.vendor[12] = '\0';

  // Feature flags (Function 1)
  if (nIds >= 1) {
    __cpuid(cpuInfo, 1);
    int edx = cpuInfo[3];
    int ecx = cpuInfo[2];
    feat.sse    = (edx & (1 << 25)) != 0;
    feat.sse2   = (edx & (1 << 26)) != 0;
    feat.sse3   = (ecx & (1 << 0))  != 0;
    feat.ssse3  = (ecx & (1 << 9))  != 0;
    feat.sse41  = (ecx & (1 << 19)) != 0;
    feat.sse42  = (ecx & (1 << 20)) != 0;
    feat.popcnt = (ecx & (1 << 23)) != 0;
    feat.aes    = (ecx & (1 << 25)) != 0;
    feat.avx    = (ecx & (1 << 28)) != 0;
    feat.fma    = (ecx & (1 << 12)) != 0;
    feat.f16c   = (ecx & (1 << 29)) != 0;
  }

  // Extended features (Function 7)
  if (nIds >= 7) {
    __cpuidex(cpuInfo, 7, 0);
    int ebx = cpuInfo[1];
    feat.bmi1 = (ebx & (1 << 3)) != 0;
    feat.avx2 = (ebx & (1 << 5)) != 0;
    feat.bmi2 = (ebx & (1 << 8)) != 0;
  }

  // Brand string (Function 0x80000000 - 0x80000004)
  __cpuid(cpuInfo, 0x80000000);
  unsigned int nExIds = static_cast<unsigned int>(cpuInfo[0]);
  if (nExIds >= 0x80000004) {
    __cpuid(reinterpret_cast<int*>(feat.brand), 0x80000002);
    __cpuid(reinterpret_cast<int*>(feat.brand + 16), 0x80000003);
    __cpuid(reinterpret_cast<int*>(feat.brand + 32), 0x80000004);
    feat.brand[48] = '\0';
  }

  return feat;
}

void LogStartupProgress(const wchar_t* milestone) {
  SYSTEMTIME st;
  GetLocalTime(&st);
  FILE* f = nullptr;
  if (_wfopen_s(&f, L"quickbill_startup.log", L"a") == 0 && f) {
    fwprintf(f, L"[%04d-%02d-%02d %02d:%02d:%02d.%03d] %ls\n",
             st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds,
             milestone);
    fclose(f);
  }
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
    case 0xC0000005: exceptionDesc = L"ACCESS_VIOLATION (Memory access violation or driver crash)"; break;
    case 0xC00000FD: exceptionDesc = L"STACK_OVERFLOW"; break;
    case 0xC000001D: exceptionDesc = L"STATUS_ILLEGAL_INSTRUCTION (CPU attempted to execute an unsupported instruction)"; break;
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

  wchar_t logContent[4096];
  int written = swprintf_s(logContent, 4096,
    L"================================================================\n"
    L"QUICKBILL POS WINDOWS CRASH REPORT\n"
    L"Timestamp:          %04d-%02d-%02d %02d:%02d:%02d\n"
    L"================================================================\n"
    L"Exception Code:     0x%08X\n"
    L"Exception Meaning:  %ls\n"
    L"Faulting Module:    %ls\n"
    L"Fault Address:      0x%p\n"
    L"Total Physical RAM: %llu MB\n"
    L"Avail Physical RAM: %llu MB\n"
    L"Memory Load:        %u%%\n",
    st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond,
    code, exceptionDesc, moduleName, addr,
    memInfo.ullTotalPhys / (1024 * 1024),
    memInfo.ullAvailPhys / (1024 * 1024),
    memInfo.dwMemoryLoad);

  // Dump 64-bit register context if available
  if (pException->ContextRecord && written > 0 && written < 3500) {
    PCONTEXT ctx = pException->ContextRecord;
    swprintf_s(logContent + written, 4096 - written,
      L"\nCPU REGISTER STATE (x86-64):\n"
      L"RIP: 0x%016llX  RSP: 0x%016llX  RBP: 0x%016llX\n"
      L"RAX: 0x%016llX  RBX: 0x%016llX  RCX: 0x%016llX\n"
      L"RDX: 0x%016llX  RSI: 0x%016llX  RDI: 0x%016llX\n"
      L"R8:  0x%016llX  R9:  0x%016llX  R10: 0x%016llX\n"
      L"R11: 0x%016llX  R12: 0x%016llX  R13: 0x%016llX\n"
      L"R14: 0x%016llX  R15: 0x%016llX  EFLAGS: 0x%08X\n"
      L"================================================================\n\n",
      ctx->Rip, ctx->Rsp, ctx->Rbp,
      ctx->Rax, ctx->Rbx, ctx->Rcx,
      ctx->Rdx, ctx->Rsi, ctx->Rdi,
      ctx->R8,  ctx->R9,  ctx->R10,
      ctx->R11, ctx->R12, ctx->R13,
      ctx->R14, ctx->R15, ctx->EFlags);
  }

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
  if (code == 0xC000001D) {
    swprintf_s(msg, 1024,
      L"QuickBill POS encountered an Illegal Instruction exception (0xC000001D).\n\n"
      L"• Module: %ls\n"
      L"• Address: 0x%p\n\n"
      L"This occurs when code attempts to execute instructions not supported by your CPU.\n"
      L"QuickBill POS has logged diagnostics to 'quickbill_startup.log' and 'quickbill_crash.log'.\n\n"
      L"Please ensure you are running the universal baseline build.",
      moduleName, addr);
  } else {
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
  }

  ::MessageBoxW(nullptr, msg, L"QuickBill Crash Diagnostics", MB_ICONERROR | MB_OK);
  return EXCEPTION_EXECUTE_HANDLER;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  ::SetUnhandledExceptionFilter(QuickBillCrashFilter);

  // Initialize startup log and perform hardware capability audit
  CpuFeatures cpu = DetectCpuFeatures();
  FILE* startupLog = nullptr;
  if (_wfopen_s(&startupLog, L"quickbill_startup.log", L"w") == 0 && startupLog) {
    fwprintf(startupLog, L"=== QuickBill POS Windows Startup Diagnostics ===\n");
    fwprintf(startupLog, L"CPU Vendor:          %hs\n", cpu.vendor[0] ? cpu.vendor : "Unknown");
    fwprintf(startupLog, L"CPU Brand:           %hs\n", cpu.brand[0] ? cpu.brand : "Unknown");
    fwprintf(startupLog, L"Baseline x86-64:     SSE: %ls | SSE2: %ls | SSE3: %ls | SSSE3: %ls\n",
             cpu.sse ? L"YES" : L"NO", cpu.sse2 ? L"YES" : L"NO", cpu.sse3 ? L"YES" : L"NO", cpu.ssse3 ? L"YES" : L"NO");
    fwprintf(startupLog, L"Advanced Extensions: SSE4.1: %ls | SSE4.2: %ls | POPCNT: %ls | AES-NI: %ls\n",
             cpu.sse41 ? L"YES" : L"NO", cpu.sse42 ? L"YES" : L"NO", cpu.popcnt ? L"YES" : L"NO", cpu.aes ? L"YES" : L"NO");
    fwprintf(startupLog, L"Vector Extensions:   AVX: %ls | AVX2: %ls | FMA3: %ls | F16C: %ls | BMI1: %ls | BMI2: %ls\n",
             cpu.avx ? L"YES" : L"NO", cpu.avx2 ? L"YES" : L"NO", cpu.fma ? L"YES" : L"NO", cpu.f16c ? L"YES" : L"NO",
             cpu.bmi1 ? L"YES" : L"NO", cpu.bmi2 ? L"YES" : L"NO");
    fwprintf(startupLog, L"Compilation Target:  Universal Baseline x86-64 (SSE2 - Intel Core i5-2400 Sandy Bridge Compatible)\n");
    fwprintf(startupLog, L"----------------------------------------------------------------\n");
    fclose(startupLog);
  }

  LogStartupProgress(L"[Milestone 1] Native crash filter registered and CPU capabilities audited");

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

  LogStartupProgress(L"[Milestone 2] Working directory anchored to binary location");

  // Attach to parent console if running from CMD or PowerShell
  if (!::AttachConsole(ATTACH_PARENT_PROCESS)) {
    if (::IsDebuggerPresent()) {
      CreateAndAttachConsole();
    }
  }

  // Initialize COM, so that it is available for use in the library and/or plugins.
  HRESULT hr = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) {
    LogStartupProgress(L"[Warning] CoInitializeEx failed, falling back to basic threading");
  } else {
    LogStartupProgress(L"[Milestone 3] COM apartment initialized successfully");
  }

  try {
    flutter::DartProject project(L"data");

    std::vector<std::string> command_line_arguments =
        GetCommandLineArguments();

    project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

    LogStartupProgress(L"[Milestone 4] DartProject initialized with data directory");

    FlutterWindow window(project);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1280, 720);
    if (!window.Create(L"QuickBill POS — Retail Billing", origin, size)) {
      LogStartupProgress(L"[Error] Failed to create Win32 application window");
      ::MessageBox(nullptr,
        L"Failed to create application window.\n\nPlease check that your graphics drivers are up to date and that Microsoft Visual C++ 2015-2022 Redistributable (x64) is installed.",
        L"QuickBill Launch Error", MB_ICONERROR | MB_OK);
      return EXIT_FAILURE;
    }
    window.SetQuitOnClose(true);

    LogStartupProgress(L"[Milestone 5] Win32 Window created successfully. Entering message pump");

    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0)) {
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }

    LogStartupProgress(L"[Milestone 6] Win32 message pump finished normally. Shutting down");

    ::CoUninitialize();
    return EXIT_SUCCESS;
  } catch (const std::exception& e) {
    std::string err_msg = e.what();
    std::wstring w_err(err_msg.begin(), err_msg.end());
    LogStartupProgress(L"[Fatal C++ Exception] Caught unhandled std::exception");
    ::MessageBox(nullptr, w_err.c_str(), L"QuickBill Launch Error", MB_ICONERROR | MB_OK);
    return EXIT_FAILURE;
  } catch (...) {
    LogStartupProgress(L"[Fatal Unknown Exception] Caught unhandled non-std exception");
    ::MessageBox(nullptr,
      L"An unexpected error occurred while launching QuickBill POS.",
      L"QuickBill Launch Error", MB_ICONERROR | MB_OK);
    return EXIT_FAILURE;
  }
}
