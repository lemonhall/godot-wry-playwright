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

#[cfg(windows)]
mod backend {
  use super::*;
  use std::collections::HashMap;
  use std::thread;
  use std::time::{Duration, Instant};

  use tao::event::{Event, StartCause};
  use tao::event_loop::{ControlFlow, EventLoopBuilder, EventLoopProxy};
  use tao::platform::windows::EventLoopBuilderExtWindows;
  use tao::window::WindowBuilder;
  use wry::{http::Request, PageLoadEvent, WebView, WebViewBuilder};

  use crate::pending::PendingRequests;
  use godot_wry_playwright_core::protocol::{
    automation_shim_js, build_dispatch_script, parse_ipc_envelope, Command,
  };

  #[derive(Debug, Clone)]
  pub(super) enum UserEvent {
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
    pub rx: mpsc::Receiver<BrowserResponse>,
    pub join: thread::JoinHandle<()>,
  }

  pub(super) fn spawn() -> Result<Handle, String> {
    let (resp_tx, resp_rx) = mpsc::channel::<BrowserResponse>();
    let (proxy_tx, proxy_rx) = mpsc::channel::<EventLoopProxy<UserEvent>>();

    let join = thread::spawn(move || {
      let event_loop = EventLoopBuilder::<UserEvent>::with_user_event()
        .with_any_thread(true)
        .build();
      let proxy = event_loop.create_proxy();
      let _ = proxy_tx.send(proxy.clone());

      let window = WindowBuilder::new()
        .with_title("godot-wry-playwright (hidden)")
        .with_visible(false)
        .build(&event_loop)
        .expect("create hidden window");

      let proxy_ipc = proxy.clone();
      let ipc_handler = move |req: Request<String>| {
        let body = req.body().to_string();
        let _ = proxy_ipc.send_event(UserEvent::Ipc(body));
      };

      let proxy_load = proxy.clone();
      let page_load_handler = move |event: PageLoadEvent, url: String| {
        if matches!(event, PageLoadEvent::Finished) {
          let _ = proxy_load.send_event(UserEvent::PageLoadFinished(url));
        }
      };

      let mut webview: WebView = WebViewBuilder::new()
        .with_initialization_script(automation_shim_js())
        .with_ipc_handler(ipc_handler)
        .with_on_page_load_handler(page_load_handler)
        .build(&window)
        .expect("build webview");

      let start = Instant::now();
      let mut pending = PendingRequests::new();
      let mut pending_kind: HashMap<i64, &'static str> = Default::default();
      let mut goto_pending: Option<i64> = None;

      // A small ticker to drive timeouts even when the window is hidden.
      let tick_proxy = proxy.clone();
      thread::spawn(move || loop {
        thread::sleep(Duration::from_millis(50));
        if tick_proxy.send_event(UserEvent::Tick).is_err() {
          break;
        }
      });

      event_loop.run(move |event, _target, control_flow| {
        *control_flow = ControlFlow::Wait;

        match event {
          Event::NewEvents(StartCause::Init) => {}
          Event::UserEvent(UserEvent::Stop) => {
            *control_flow = ControlFlow::Exit;
          }
          Event::UserEvent(UserEvent::Goto { id, url, timeout_ms }) => {
            let now_ms = start.elapsed().as_millis() as u64;
            pending.insert(id, now_ms, timeout_ms);
            pending_kind.insert(id, "goto");
            goto_pending = Some(id);

            if let Err(e) = webview.load_url(&url) {
              pending.complete(id);
              pending_kind.remove(&id);
              goto_pending = None;
              let _ = resp_tx.send(BrowserResponse {
                request_id: id,
                ok: false,
                result_json: "null".to_string(),
                error: e.to_string(),
              });
            }
          }
          Event::UserEvent(UserEvent::JsCommand { id, cmd, timeout_ms }) => {
            let now_ms = start.elapsed().as_millis() as u64;
            pending.insert(id, now_ms, timeout_ms);
            pending_kind.insert(id, "js");

            let script = build_dispatch_script(&id.to_string(), cmd);
            if let Err(e) = webview.evaluate_script(&script) {
              pending.complete(id);
              pending_kind.remove(&id);
              let _ = resp_tx.send(BrowserResponse {
                request_id: id,
                ok: false,
                result_json: "null".to_string(),
                error: e.to_string(),
              });
            }
          }
          Event::UserEvent(UserEvent::Ipc(body)) => match parse_ipc_envelope(&body) {
            Ok(env) => {
              let id: i64 = env.id.parse().unwrap_or(-1);
              let _had_pending = pending.complete(id);
              pending_kind.remove(&id);

              let result_json = env.result.map(|v| v.to_string()).unwrap_or_else(|| "null".to_string());
              let error = env.error.unwrap_or_default();
              let _ = resp_tx.send(BrowserResponse {
                request_id: id,
                ok: env.ok,
                result_json,
                error,
              });
            }
            Err(e) => {
              let _ = resp_tx.send(BrowserResponse {
                request_id: -1,
                ok: false,
                result_json: "null".to_string(),
                error: format!("ipc_parse_error: {e}"),
              });
            }
          },
          Event::UserEvent(UserEvent::PageLoadFinished(url)) => {
            if let Some(id) = goto_pending.take() {
              pending.complete(id);
              pending_kind.remove(&id);
              let result_json = serde_json::to_string(&url).unwrap_or_else(|_| "\"\"".to_string());
              let _ = resp_tx.send(BrowserResponse {
                request_id: id,
                ok: true,
                result_json,
                error: String::new(),
              });
            }
          }
          Event::UserEvent(UserEvent::Tick) => {
            let now_ms = start.elapsed().as_millis() as u64;
            for id in pending.expired(now_ms) {
              let kind = pending_kind.remove(&id).unwrap_or("cmd");
              if goto_pending == Some(id) {
                goto_pending = None;
              }
              let _ = resp_tx.send(BrowserResponse {
                request_id: id,
                ok: false,
                result_json: "null".to_string(),
                error: format!("{kind}_timeout"),
              });
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
      rx: resp_rx,
      join,
    })
  }
}

#[cfg(not(windows))]
mod backend {
  use super::*;

  #[derive(Debug)]
  pub(super) struct Handle {
    pub rx: mpsc::Receiver<BrowserResponse>,
  }

  pub(super) fn spawn() -> Result<Handle, String> {
    let (_tx, rx) = mpsc::channel::<BrowserResponse>();
    Ok(Handle { rx })
  }
}

#[derive(GodotClass)]
#[class(base = Node)]
pub struct WryBrowser {
  base: Base<Node>,

  next_request_id: i64,

  #[cfg(windows)]
  proxy: Option<tao::event_loop::EventLoopProxy<backend::UserEvent>>,

  #[cfg(windows)]
  join: Option<std::thread::JoinHandle<()>>,

  rx: Option<mpsc::Receiver<BrowserResponse>>,
}

#[godot_api]
impl INode for WryBrowser {
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
    let Some(rx) = &self.rx else { return };

    while let Ok(resp) = rx.try_recv() {
      let mut base = self.base.to_gd();
      base.emit_signal(
        "completed",
        &[
          resp.request_id.to_variant(),
          resp.ok.to_variant(),
          resp.result_json.to_variant(),
          resp.error.to_variant(),
        ],
      );
    }
  }

  fn exit_tree(&mut self) {
    self.stop();
  }
}

#[godot_api]
impl WryBrowser {
  #[signal]
  fn completed(request_id: i64, ok: bool, result_json: String, error: String);

  #[func]
  fn start(&mut self) -> bool {
    #[cfg(windows)]
    {
      if self.proxy.is_some() {
        return true;
      }

      match backend::spawn() {
        Ok(handle) => {
          self.proxy = Some(handle.proxy);
          self.rx = Some(handle.rx);
          self.join = Some(handle.join);
          true
        }
        Err(e) => {
          let mut base = self.base.to_gd();
          base.emit_signal(
            "completed",
            &[
              (-1_i64).to_variant(),
              false.to_variant(),
              "null".to_variant(),
              e.to_variant(),
            ],
          );
          false
        }
      }
    }

    #[cfg(not(windows))]
    {
      let _ = backend::spawn().map(|h| self.rx = Some(h.rx));
      false
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
      return id;
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
      return id;
    }
    id
  }

  #[func]
  fn click(&mut self, selector: GString, timeout_ms: i64) -> i64 {
    #[cfg(not(windows))]
    let _ = (&selector, timeout_ms);

    let id = self.next_id();
    #[cfg(windows)]
    if let Some(proxy) = &self.proxy {
      let _ = proxy.send_event(backend::UserEvent::JsCommand {
        id,
        cmd: Command::Click {
          selector: selector.to_string(),
        },
        timeout_ms: timeout_ms.max(0) as u64,
      });
      return id;
    }
    id
  }

  #[func]
  fn fill(&mut self, selector: GString, text: GString, timeout_ms: i64) -> i64 {
    #[cfg(not(windows))]
    let _ = (&selector, &text, timeout_ms);

    let id = self.next_id();
    #[cfg(windows)]
    if let Some(proxy) = &self.proxy {
      let _ = proxy.send_event(backend::UserEvent::JsCommand {
        id,
        cmd: Command::Fill {
          selector: selector.to_string(),
          text: text.to_string(),
        },
        timeout_ms: timeout_ms.max(0) as u64,
      });
      return id;
    }
    id
  }

  #[func]
  fn wait_for_selector(&mut self, selector: GString, timeout_ms: i64) -> i64 {
    #[cfg(not(windows))]
    let _ = (&selector, timeout_ms);

    let id = self.next_id();
    #[cfg(windows)]
    if let Some(proxy) = &self.proxy {
      let _ = proxy.send_event(backend::UserEvent::JsCommand {
        id,
        cmd: Command::WaitForSelector {
          selector: selector.to_string(),
          timeout_ms: timeout_ms.max(0) as u64,
        },
        timeout_ms: timeout_ms.max(0) as u64,
      });
      return id;
    }
    id
  }
}
