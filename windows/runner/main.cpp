#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {
// Shared by all installed copies in the current Windows session.
constexpr wchar_t kInstanceMutex[] = L"Local\\MisakaFetch.SingleInstance";
constexpr wchar_t kWindowClass[] = L"MISAKAFETCH_RUNNER_WIN32_WINDOW";

class SingleInstance {
 public:
  SingleInstance() : mutex_(::CreateMutexW(nullptr, FALSE, kInstanceMutex)) {}
  ~SingleInstance() {
    if (owned_) ::ReleaseMutex(mutex_);
    if (mutex_) ::CloseHandle(mutex_);
  }

  bool AcquireOrActivate() {
    if (!mutex_) {
      ::MessageBoxW(nullptr, L"无法检查应用运行状态，请稍后重试。",
                    L"MisakaFetch", MB_OK | MB_ICONERROR);
      return false;
    }
    // Concurrent launches can arrive before the first window has been shown.
    for (int attempt = 0; attempt < 200; ++attempt) {
      const DWORD state = ::WaitForSingleObject(mutex_, 0);
      if (state == WAIT_OBJECT_0 || state == WAIT_ABANDONED) {
        owned_ = true;
        return true;
      }
      if (state != WAIT_TIMEOUT) return false;
      HWND existing = ::FindWindowW(kWindowClass, L"MisakaFetch");
      if (existing && ::IsWindowVisible(existing)) {
        if (::IsIconic(existing)) ::ShowWindowAsync(existing, SW_RESTORE);
        ::SetForegroundWindow(existing);
        return false;
      }
      ::Sleep(50);
    }
    // An unresponsive first instance must never lead to a second window.
    return false;
  }

 private:
  HANDLE mutex_ = nullptr;
  bool owned_ = false;
};
}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  SingleInstance single_instance;
  if (!single_instance.AcquireOrActivate()) return EXIT_SUCCESS;

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
  if (!window.Create(L"MisakaFetch", origin, size)) {
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
