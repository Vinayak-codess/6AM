#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  fullscreen_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "sixam/fullscreen",
          &flutter::StandardMethodCodec::GetInstance());
  fullscreen_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HandleFullscreenMethodCall(call, std::move(result));
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  fullscreen_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleFullscreenMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "isFullScreen") {
    result->Success(flutter::EncodableValue(is_fullscreen_));
    return;
  }
  if (call.method_name() == "setFullScreen") {
    const auto* arguments = call.arguments();
    const bool* fullscreen =
        arguments == nullptr ? nullptr : std::get_if<bool>(arguments);
    if (fullscreen == nullptr) {
      result->Error("bad_arguments", "setFullScreen expects a boolean.");
      return;
    }
    SetFullScreen(*fullscreen);
    result->Success();
    return;
  }
  result->NotImplemented();
}

void FlutterWindow::SetFullScreen(bool fullscreen) {
  if (fullscreen == is_fullscreen_) {
    return;
  }
  HWND window = GetHandle();
  if (fullscreen) {
    saved_placement_ = {};
    saved_placement_.length = sizeof(WINDOWPLACEMENT);
    if (!::GetWindowPlacement(window, &saved_placement_)) {
      return;
    }
    saved_style_ = ::GetWindowLongPtr(window, GWL_STYLE);

    MONITORINFO monitor_info = {};
    monitor_info.cbSize = sizeof(MONITORINFO);
    if (!::GetMonitorInfo(::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                          &monitor_info)) {
      return;
    }

    // Drop every non-client frame element so the window covers the whole
    // monitor with no visible border or title bar.
    ::SetWindowLongPtr(window, GWL_STYLE,
                       (saved_style_ | WS_POPUP) &
                           ~(WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
                             WS_MAXIMIZEBOX | WS_SYSMENU));
    ::SetWindowPos(
        window, nullptr, monitor_info.rcMonitor.left, monitor_info.rcMonitor.top,
        monitor_info.rcMonitor.right - monitor_info.rcMonitor.left,
        monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top,
        SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    is_fullscreen_ = true;
  } else {
    ::SetWindowLongPtr(window, GWL_STYLE, saved_style_);
    ::SetWindowPlacement(window, &saved_placement_);
    ::SetWindowPos(window, nullptr, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER |
                       SWP_FRAMECHANGED);
    is_fullscreen_ = false;
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
