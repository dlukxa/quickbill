#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

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

  FILE* f = nullptr;
  if (fopen_s(&f, "quickbill_crash.log", "w") == 0 && f) {
    fwprintf(f, L"Crash Exception: 0x%08X\nAddress: %p\nModule: %ls\n", code, addr, moduleName);
    fclose(f);
  }

  wchar_t msg[1024];
  swprintf_s(msg, 1024,
    L"QuickBill POS encountered an unexpected system error.\n\n"
    L"Exception Code: 0x%08X\n"
    L"Faulting Module: %ls\n\n"
    L"To resolve this issue:\n"
    L"1. Double-click and install 'vc_redist.x64.exe' in the QuickBill folder.\n"
    L"2. Update or reinstall your Intel Graphics display drivers.\n"
    L"3. Run QuickBill as Administrator.",
    code, moduleName);

  ::MessageBoxW(nullptr, msg, L"QuickBill Crash Diagnostics", MB_ICONERROR | MB_OK);
  return EXCEPTION_EXECUTE_HANDLER;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  ::SetUnhandledExceptionFilter(QuickBillCrashFilter);

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
