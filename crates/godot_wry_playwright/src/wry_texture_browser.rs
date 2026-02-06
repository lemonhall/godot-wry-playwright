use std::sync::mpsc;

use godot::classes::{INode, Node};
use godot::prelude::*;

#[cfg(windows)]
use godot_wry_playwright_core::protocol::Command;

#[derive(Debug, Clone)]
struct BrowserResponse {
  request_id: i64,
  ok: bool,
  result_json: String,
  error: String,
}

#[cfg_attr(not(windows), allow(dead_code))]
#[derive(Debug)]
enum BackendMessage {
  Response(BrowserResponse),
  FramePng(Vec<u8>),
}

#[cfg(windows)]
mod backend {
  use super::*;
  use std::cell::Cell;
  use std::collections::HashMap;
  use std::thread;
  use std::time::{Duration, Instant};

  use crate::pending::PendingRequests;

  use tao::event::{Event, StartCause};
  use tao::event_loop::{ControlFlow, EventLoopBuilder, EventLoopProxy};
  use tao::platform::windows::EventLoopBuilderExtWindows;
  use tao::platform::windows::WindowBuilderExtWindows;
  use tao::platform::windows::WindowExtWindows;
  use tao::window::WindowBuilder;

  use godot_wry_playwright_core::protocol::{automation_shim_js, build_dispatch_script, parse_ipc_envelope, Command};

  use webview2_com::Microsoft::Web::WebView2::Win32::*;
  use webview2_com::{
    take_pwstr, AddScriptToExecuteOnDocumentCreatedCompletedHandler, CapturePreviewCompletedHandler,
    CreateCoreWebView2ControllerCompletedHandler, CreateCoreWebView2EnvironmentCompletedHandler,
    ExecuteScriptCompletedHandler, NavigationCompletedEventHandler, WebMessageReceivedEventHandler,
  };
  use windows::core::{Error as WinError, HSTRING, PCWSTR};
  use windows::Win32::Foundation::{E_POINTER, HWND, RECT};
  use windows::Win32::System::Com::{CoInitializeEx, IStream, STATFLAG_NONAME, STREAM_SEEK_SET, COINIT_APARTMENTTHREADED};
  use windows::Win32::System::Com::StructuredStorage::CreateStreamOnHGlobal;
  use windows::Win32::UI::WindowsAndMessaging::{
    SetWindowPos, ShowWindow, SWP_ASYNCWINDOWPOS, SWP_NOACTIVATE, SWP_NOSIZE, SWP_NOZORDER, SW_SHOWNOACTIVATE,
  };

  #[derive(Debug, Clone)]
  pub(super) enum UserEvent {
    SetCaptureFps { fps: i32 },
    CaptureOnce,
    JsCommand { id: i64, cmd: Command, timeout_ms: u64 },
    Goto { id: i64, url: String, timeout_ms: u64 },
    Ipc(String),
    PageLoadFinished(String),
    Tick,
    Stop,
  }

  #[derive(Debug)]
  pub(super) struct Handle {
    pub proxy: EventLoopProxy<UserEvent>,
    pub rx: mpsc::Receiver<BackendMessage>,
    pub join: thread::JoinHandle<()>,
  }

  fn send_error(resp_tx: &mpsc::Sender<BackendMessage>, request_id: i64, error: impl ToString) {
    let _ = resp_tx.send(BackendMessage::Response(BrowserResponse {
      request_id,
      ok: false,
      result_json: "null".to_string(),
      error: error.to_string(),
    }));
  }

  fn add_script(webview: &ICoreWebView2, js: String) -> Result<(), WinError> {
    unsafe {
      let js = HSTRING::from(js);
      webview.AddScriptToExecuteOnDocumentCreated(
        &js,
        &AddScriptToExecuteOnDocumentCreatedCompletedHandler::create(Box::new(|err, _| err)),
      )?;
    }
    Ok(())
  }

  fn fit_width_script() -> &'static str {
    r#"
(() => {
  const applyTextureFitWidth = () => {
    const docEl = document.documentElement;
    const body = document.body;

    if (!docEl || !body) {
      return;
    }

    const clientWidth = Math.max(1, docEl.clientWidth || window.innerWidth || 1);
    const scrollWidth = Math.max(clientWidth, body.scrollWidth || 0, docEl.scrollWidth || 0);
    const fitScale = Math.min(1, clientWidth / scrollWidth);

    body.style.transformOrigin = 'top left';
    body.style.transform = `scale(${fitScale})`;
    body.style.width = `${100 / fitScale}%`;
    body.style.margin = '0';

    docEl.style.overflowX = 'hidden';
    body.style.overflowX = 'hidden';
  };

  if (!window.__gwry_texture_fit_width_bound__) {
    window.__gwry_texture_fit_width_bound__ = true;
    window.addEventListener('resize', () => applyTextureFitWidth(), { passive: true });
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => applyTextureFitWidth(), { once: true });
    }
  }

  applyTextureFitWidth();
})();
"#
  }

  fn url_from_webview(webview: &ICoreWebView2) -> Result<String, WinError> {
    let mut pwstr = windows::core::PWSTR::null();
    unsafe { webview.Source(&mut pwstr)? };
    Ok(take_pwstr(pwstr))
  }

  fn read_stream_to_vec(stream: &IStream) -> Result<Vec<u8>, WinError> {
    unsafe {
      let mut stat = windows::Win32::System::Com::STATSTG::default();
      stream.Stat(&mut stat, STATFLAG_NONAME)?;
      let size = stat.cbSize as usize;

      // reset to beginning
      let mut _new_pos: u64 = 0;
      stream.Seek(0, STREAM_SEEK_SET, Some(&mut _new_pos))?;

      let mut buf = vec![0u8; size];
      let mut read: u32 = 0;
      stream.Read(buf.as_mut_ptr() as *mut _, size as u32, Some(&mut read)).ok()?;
      buf.truncate(read as usize);
      Ok(buf)
    }
  }

  fn create_environment() -> Result<ICoreWebView2Environment, String> {
    let (tx, rx) = mpsc::channel::<Result<ICoreWebView2Environment, WinError>>();

    let options = webview2_com::CoreWebView2EnvironmentOptions::default();
    unsafe {
      CreateCoreWebView2EnvironmentWithOptions(
        PCWSTR::null(),
        &HSTRING::new(),
        &ICoreWebView2EnvironmentOptions::from(options),
        &CreateCoreWebView2EnvironmentCompletedHandler::create(Box::new(move |err, environment| {
          if let Err(e) = err {
            let _ = tx.send(Err(e.clone()));
            return Err(e);
          }
          let Some(environment) = environment else {
            let e = WinError::from(E_POINTER);
            let _ = tx.send(Err(e.clone()));
            return Err(e);
          };
          let _ = tx.send(Ok(environment));
          Ok(())
        })),
      )
      .map_err(|e| e.to_string())?;
    }

    webview2_com::wait_with_pump(rx)
      .map_err(|e| format!("webview2_wait_env_error: {e:?}"))?
      .map_err(|e| format!("webview2_env_error: {e:?}"))
  }

  fn create_controller(hwnd: HWND, env: &ICoreWebView2Environment) -> Result<ICoreWebView2Controller, String> {
    let (tx, rx) = mpsc::channel::<Result<ICoreWebView2Controller, WinError>>();
    let env = env.clone();

    let handler = CreateCoreWebView2ControllerCompletedHandler::create(Box::new(move |err, controller| {
      if let Err(e) = err {
        let _ = tx.send(Err(e.clone()));
        return Err(e);
      }
      let Some(controller) = controller else {
        let e = WinError::from(E_POINTER);
        let _ = tx.send(Err(e.clone()));
        return Err(e);
      };
      let _ = tx.send(Ok(controller));
      Ok(())
    }));

    unsafe { env.CreateCoreWebView2Controller(hwnd, &handler).map_err(|e| e.to_string())? };

    webview2_com::wait_with_pump(rx)
      .map_err(|e| format!("webview2_wait_controller_error: {e:?}"))?
      .map_err(|e| format!("webview2_controller_error: {e:?}"))
  }

  pub(super) fn spawn(width: i32, height: i32, fps: i32) -> Result<Handle, String> {
    let (msg_tx, msg_rx) = mpsc::channel::<BackendMessage>();
    let (proxy_tx, proxy_rx) = mpsc::channel::<EventLoopProxy<UserEvent>>();

    let join = thread::spawn(move || {
      let _ = unsafe { CoInitializeEx(None, COINIT_APARTMENTTHREADED) };

      let event_loop = EventLoopBuilder::<UserEvent>::with_user_event()
        .with_any_thread(true)
        .build();
      let proxy = event_loop.create_proxy();
      let _ = proxy_tx.send(proxy.clone());

      let start = Instant::now();
      let mut pending = PendingRequests::new();
      let mut pending_kind: HashMap<i64, &'static str> = Default::default();
      let mut goto_pending: Option<i64> = None;
      let mut capture_ready = false;

      let fps = fps.clamp(1, 30);
      let mut capture_interval = Duration::from_millis((1000 / fps) as u64);
      let mut next_capture_at = Instant::now() + capture_interval;
      let capture_in_flight = std::rc::Rc::new(Cell::new(false));

      let window = WindowBuilder::new()
        .with_title("godot-wry-playwright (texture hidden)")
        .with_visible(false)
        .with_decorations(false)
        .with_skip_taskbar(true)
        .with_inner_size(tao::dpi::LogicalSize::new(width.max(1), height.max(1)))
        .build(&event_loop)
        .expect("create hidden window");

      // Show the window off-screen without activating/focusing it.
      // WebView2 CapturePreview can be unreliable if the host window is truly hidden on some setups.
      unsafe {
        let _ = SetWindowPos(
          HWND(window.hwnd() as _),
          None,
          -32000,
          -32000,
          0,
          0,
          SWP_ASYNCWINDOWPOS | SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOSIZE,
        );
        let _ = ShowWindow(HWND(window.hwnd() as _), SW_SHOWNOACTIVATE);
      }
      let hwnd = HWND(window.hwnd() as _);

      let env = match create_environment() {
        Ok(env) => env,
        Err(e) => {
          send_error(&msg_tx, -1, e);
          return;
        }
      };
      let controller = match create_controller(hwnd, &env) {
        Ok(c) => c,
        Err(e) => {
          send_error(&msg_tx, -1, e);
          return;
        }
      };

      let webview = match unsafe { controller.CoreWebView2() } {
        Ok(wv) => wv,
        Err(e) => {
          send_error(&msg_tx, -1, format!("core_webview2_error: {e:?}"));
          return;
        }
      };

      unsafe {
        let rect = RECT {
          left: 0,
          top: 0,
          right: width.max(1),
          bottom: height.max(1),
        };
        let _ = controller.SetBounds(rect);
      }

      // IPC bridge + our automation shim.
      let _ = add_script(&webview, "Object.defineProperty(window, 'ipc', { value: Object.freeze({ postMessage: s=> window.chrome.webview.postMessage(s) }) });".to_string());
      let _ = add_script(&webview, automation_shim_js().to_string());
      let _ = add_script(&webview, fit_width_script().to_string());

      // A small ticker to drive timeouts + capture scheduling.
      let tick_proxy = proxy.clone();
      thread::spawn(move || loop {
        thread::sleep(Duration::from_millis(50));
        if tick_proxy.send_event(UserEvent::Tick).is_err() {
          break;
        }
      });

      // WebMessageReceived -> UserEvent::Ipc
      let proxy_ipc = proxy.clone();
      unsafe {
        let mut token = 0i64;
        let _ = webview.add_WebMessageReceived(
          &WebMessageReceivedEventHandler::create(Box::new(move |_, args| {
            let Some(args) = args else { return Ok(()) };
            let js = {
              let mut js = windows::core::PWSTR::null();
              args.TryGetWebMessageAsString(&mut js)?;
              take_pwstr(js)
            };
            let _ = proxy_ipc.send_event(UserEvent::Ipc(js));
            Ok(())
          })),
          &mut token,
        );
      }

      // NavigationCompleted -> PageLoadFinished(url)
      let proxy_nav = proxy.clone();
      unsafe {
        let mut token = 0i64;
        let _ = webview.add_NavigationCompleted(
          &NavigationCompletedEventHandler::create(Box::new(move |webview, _| {
            let Some(webview) = webview else { return Ok(()) };
            let url = url_from_webview(&webview)?;
            let _ = proxy_nav.send_event(UserEvent::PageLoadFinished(url));
            Ok(())
          })),
          &mut token,
        );
      }

      let _window = Some(window);
      let _controller = Some(controller);
      let webview = Some(webview);

      event_loop.run(move |event, _target, control_flow| {
        *control_flow = ControlFlow::Wait;

        match event {
          Event::NewEvents(StartCause::Init) => {}
          Event::UserEvent(UserEvent::Stop) => {
            *control_flow = ControlFlow::Exit;
          }
          Event::UserEvent(UserEvent::SetCaptureFps { fps }) => {
            let fps = fps.clamp(1, 30);
            capture_interval = Duration::from_millis((1000 / fps) as u64);
            next_capture_at = Instant::now() + capture_interval;
          }
          Event::UserEvent(UserEvent::CaptureOnce) => {
            next_capture_at = Instant::now();
          }
          Event::UserEvent(UserEvent::Goto { id, url, timeout_ms }) => {
            let Some(wv) = &webview else {
              pending.complete(id);
              pending_kind.remove(&id);
              send_error(&msg_tx, id, "webview_not_started");
              return;
            };

            capture_ready = false;

            let now_ms = start.elapsed().as_millis() as u64;
            pending.insert(id, now_ms, timeout_ms);
            pending_kind.insert(id, "goto");
            goto_pending = Some(id);

            unsafe {
              let url = HSTRING::from(url);
              if let Err(e) = wv.Navigate(&url) {
                pending.complete(id);
                pending_kind.remove(&id);
                goto_pending = None;
                send_error(&msg_tx, id, format!("navigate_error: {e:?}"));
              }
            }
          }
          Event::UserEvent(UserEvent::JsCommand { id, cmd, timeout_ms }) => {
            let Some(wv) = &webview else {
              pending.complete(id);
              pending_kind.remove(&id);
              send_error(&msg_tx, id, "webview_not_started");
              return;
            };

            let now_ms = start.elapsed().as_millis() as u64;
            pending.insert(id, now_ms, timeout_ms);
            pending_kind.insert(id, "js");

            let script = build_dispatch_script(&id.to_string(), cmd);
            unsafe {
              let script = HSTRING::from(script);
              if let Err(e) = wv.ExecuteScript(&script, &ExecuteScriptCompletedHandler::create(Box::new(|err, _| err))) {
                pending.complete(id);
                pending_kind.remove(&id);
                send_error(&msg_tx, id, format!("execute_script_error: {e:?}"));
              }
            }
          }
          Event::UserEvent(UserEvent::Ipc(body)) => match parse_ipc_envelope(&body) {
            Ok(envp) => {
              let id: i64 = envp.id.parse().unwrap_or(-1);
              let _had_pending = pending.complete(id);
              pending_kind.remove(&id);
              let result_json = envp.result.map(|v| v.to_string()).unwrap_or_else(|| "null".to_string());
              let error = envp.error.unwrap_or_default();
              let _ = msg_tx.send(BackendMessage::Response(BrowserResponse {
                request_id: id,
                ok: envp.ok,
                result_json,
                error,
              }));
            }
            Err(e) => {
              let _ = msg_tx.send(BackendMessage::Response(BrowserResponse {
                request_id: -1,
                ok: false,
                result_json: "null".to_string(),
                error: format!("ipc_parse_error: {e}"),
              }));
            }
          },
          Event::UserEvent(UserEvent::PageLoadFinished(url)) => {
            if let Some(id) = goto_pending.take() {
              capture_ready = true;
              next_capture_at = Instant::now();

              pending.complete(id);
              pending_kind.remove(&id);
              let result_json = serde_json::to_string(&url).unwrap_or_else(|_| "\"\"".to_string());
              let _ = msg_tx.send(BackendMessage::Response(BrowserResponse {
                request_id: id,
                ok: true,
                result_json,
                error: String::new(),
              }));
            }
          }
          Event::UserEvent(UserEvent::Tick) => {
            // Capture scheduling (simulated render).
            if capture_ready && Instant::now() >= next_capture_at && !capture_in_flight.get() {
              let Some(wv) = &webview else { return; };
              let Ok(stream) = (unsafe { CreateStreamOnHGlobal(Default::default(), true) }) else { return; };

              capture_in_flight.set(true);
              next_capture_at = Instant::now() + capture_interval;

              let msg_tx2 = msg_tx.clone();
              let inflight2 = capture_in_flight.clone();
              let stream2 = stream.clone();
              let handler = CapturePreviewCompletedHandler::create(Box::new(move |err| {
                inflight2.set(false);
                if let Err(e) = err {
                  send_error(&msg_tx2, -1, format!("capture_error: {e:?}"));
                  return Err(e);
                }
                match read_stream_to_vec(&stream2) {
                  Ok(bytes) => {
                    let _ = msg_tx2.send(BackendMessage::FramePng(bytes));
                  }
                  Err(e) => {
                    send_error(&msg_tx2, -1, format!("capture_read_error: {e:?}"));
                  }
                }
                Ok(())
              }));

              unsafe {
                if let Err(e) = wv.CapturePreview(COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG, &stream, &handler) {
                  capture_in_flight.set(false);
                  send_error(&msg_tx, -1, format!("capture_start_error: {e:?}"));
                }
              }
            }

            {
              let now_ms = start.elapsed().as_millis() as u64;
              for id in pending.expired(now_ms) {
                let kind = pending_kind.remove(&id).unwrap_or("cmd");
                if goto_pending == Some(id) {
                  goto_pending = None;
                }
                let _ = msg_tx.send(BackendMessage::Response(BrowserResponse {
                  request_id: id,
                  ok: false,
                  result_json: "null".to_string(),
                  error: format!("{kind}_timeout"),
                }));
              }
            }
          }
          _ => {}
        }
      });
    });

    let proxy = proxy_rx
      .recv_timeout(std::time::Duration::from_secs(5))
      .map_err(|_| "failed to receive event loop proxy from webview thread".to_string())?;

    Ok(Handle {
      proxy,
      rx: msg_rx,
      join,
    })
  }
}

#[cfg(not(windows))]
mod backend {
  use super::*;

  #[allow(dead_code)]
  #[derive(Debug)]
  pub(super) struct Handle {
    pub rx: mpsc::Receiver<BackendMessage>,
  }

  #[allow(dead_code)]
  #[allow(clippy::unnecessary_wraps)]
  pub(super) fn spawn() -> Result<Handle, String> {
    let (_tx, rx) = mpsc::channel::<BackendMessage>();
    Ok(Handle { rx })
  }

  #[allow(dead_code)]
  #[derive(Debug, Clone)]
  pub(super) enum UserEvent {
    _Noop,
  }
}

#[derive(GodotClass)]
#[class(base = Node)]
pub struct WryTextureBrowser {
  base: Base<Node>,
  next_request_id: i64,

  #[cfg(windows)]
  proxy: Option<tao::event_loop::EventLoopProxy<backend::UserEvent>>,
  #[cfg(windows)]
  join: Option<std::thread::JoinHandle<()>>,

  rx: Option<mpsc::Receiver<BackendMessage>>,
}

#[godot_api]
impl INode for WryTextureBrowser {
  fn init(base: Base<Node>) -> Self {
    Self {
      base,
      next_request_id: 0,
      #[cfg(windows)]
      proxy: None,
      #[cfg(windows)]
      join: None,
      rx: None,
    }
  }

  fn process(&mut self, _delta: f64) {
    let mut drained: Vec<BackendMessage> = Vec::new();
    if let Some(rx) = &self.rx {
      while let Ok(msg) = rx.try_recv() {
        drained.push(msg);
      }
    }

    for msg in drained {
      match msg {
        BackendMessage::Response(resp) => {
          let args = [
            StringName::from("completed").to_variant(),
            resp.request_id.to_variant(),
            resp.ok.to_variant(),
            resp.result_json.to_variant(),
            resp.error.to_variant(),
          ];
          self.base_mut().call_deferred("emit_signal", &args);
        }
        BackendMessage::FramePng(bytes) => {
          let mut pba = PackedByteArray::new();
          pba.resize(bytes.len());
          // SAFETY: Godot PackedByteArray stores raw bytes; we copy from Vec.
          pba.as_mut_slice().copy_from_slice(&bytes);
          let args = [
            StringName::from("frame_png").to_variant(),
            pba.to_variant(),
          ];
          self.base_mut().call_deferred("emit_signal", &args);
        }
      }
    }
  }

  fn exit_tree(&mut self) {
    self.stop();
  }
}

#[godot_api]
impl WryTextureBrowser {
  #[signal]
  fn completed(request_id: i64, ok: bool, result_json: String, error: String);

  #[signal]
  fn frame_png(png_bytes: PackedByteArray);

  #[func]
  fn start_texture(&mut self, width: i32, height: i32, fps: i32) -> bool {
    #[cfg(windows)]
    {
      if self.proxy.is_some() {
        self.set_capture_fps(fps);
        return true;
      }

      match backend::spawn(width, height, fps) {
        Ok(handle) => {
          self.proxy = Some(handle.proxy);
          self.rx = Some(handle.rx);
          self.join = Some(handle.join);
          true
        }
        Err(e) => {
          let args = [
            StringName::from("completed").to_variant(),
            (-1_i64).to_variant(),
            false.to_variant(),
            "null".to_variant(),
            e.to_variant(),
          ];
          self.base_mut().call_deferred("emit_signal", &args);
          false
        }
      }
    }

    #[cfg(not(windows))]
    {
      let _ = (width, height, fps);
      false
    }
  }

  #[func]
  fn set_capture_fps(&mut self, fps: i32) {
    #[cfg(windows)]
    if let Some(proxy) = &self.proxy {
      let _ = proxy.send_event(backend::UserEvent::SetCaptureFps { fps });
    }

    #[cfg(not(windows))]
    let _ = fps;
  }

  #[func]
  fn capture_once(&mut self) {
    #[cfg(windows)]
    if let Some(proxy) = &self.proxy {
      let _ = proxy.send_event(backend::UserEvent::CaptureOnce);
    }
  }

  #[func]
  fn stop(&mut self) {
    #[cfg(windows)]
    {
      if let Some(proxy) = self.proxy.take() {
        let _ = proxy.send_event(backend::UserEvent::Stop);
      }
      if let Some(join) = self.join.take() {
        let _ = join.join();
      }
      self.rx = None;
    }
  }

  fn next_id(&mut self) -> i64 {
    self.next_request_id += 1;
    self.next_request_id
  }

  #[func]
  fn goto(&mut self, url: GString, timeout_ms: i64) -> i64 {
    #[cfg(not(windows))]
    let _ = (&url, timeout_ms);

    let id = self.next_id();
    #[cfg(windows)]
    if let Some(proxy) = &self.proxy {
      let _ = proxy.send_event(backend::UserEvent::Goto {
        id,
        url: url.to_string(),
        timeout_ms: timeout_ms.max(0) as u64,
      });
    }
    id
  }

  #[func]
  fn eval(&mut self, js: GString, timeout_ms: i64) -> i64 {
    #[cfg(not(windows))]
    let _ = (&js, timeout_ms);

    let id = self.next_id();
    #[cfg(windows)]
    if let Some(proxy) = &self.proxy {
      let _ = proxy.send_event(backend::UserEvent::JsCommand {
        id,
        cmd: Command::Eval { js: js.to_string() },
        timeout_ms: timeout_ms.max(0) as u64,
      });
    }
    id
  }
}
