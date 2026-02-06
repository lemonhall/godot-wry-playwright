use serde::{Deserialize, Serialize};
use serde_json::Value;
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct IpcEnvelope {
  pub id: String,
  pub ok: bool,
  #[serde(default)]
  pub result: Option<Value>,
  #[serde(default)]
  pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
pub enum Command {
  Eval { js: String },
  Click { selector: String },
  Fill { selector: String, text: String },
  Text { selector: String },
  Attr { selector: String, name: String },
  WaitForSelector { selector: String, timeout_ms: u64 },
}

#[derive(Error, Debug)]
pub enum ProtocolError {
  #[error("invalid ipc envelope json: {0}")]
  InvalidJson(String),
  #[error("failed to serialize dispatch request: {0}")]
  Serialize(String),
}

pub fn parse_ipc_envelope(s: &str) -> Result<IpcEnvelope, ProtocolError> {
  serde_json::from_str::<IpcEnvelope>(s).map_err(|e| ProtocolError::InvalidJson(e.to_string()))
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
struct DispatchRequest {
  id: String,
  #[serde(flatten)]
  cmd: Command,
}

pub fn build_dispatch_script(id: &str, cmd: Command) -> String {
  let req = DispatchRequest {
    id: id.to_string(),
    cmd,
  };
  let req_json = match serde_json::to_string(&req) {
    Ok(s) => s,
    Err(e) => {
      // Keep it non-panicking in production; emit a best-effort error envelope.
      let fallback = IpcEnvelope {
        id: id.to_string(),
        ok: false,
        result: None,
        error: Some(ProtocolError::Serialize(e.to_string()).to_string()),
      };
      let fallback_json =
        serde_json::to_string(&fallback).unwrap_or_else(|_| "{\"ok\":false}".to_string());
      return format!("window.ipc && window.ipc.postMessage({fallback_json:?});");
    }
  };

  format!("window.__gwry && window.__gwry.dispatch({req_json});")
}

pub fn automation_shim_js() -> &'static str {
  r#"
(function () {
  if (window.__gwry && window.__gwry.__installed) return;

  function postMessage(obj) {
    try {
      if (window.ipc && typeof window.ipc.postMessage === "function") {
        window.ipc.postMessage(JSON.stringify(obj));
      }
    } catch (_) {}
  }

  function sendOk(id, result) {
    postMessage({ id: String(id), ok: true, result: result ?? null, error: null });
  }

  function sendErr(id, error) {
    postMessage({ id: String(id), ok: false, result: null, error: String(error) });
  }

  function qs(selector) {
    return document.querySelector(selector);
  }

  function waitForSelector(selector, timeoutMs) {
    return new Promise(function (resolve, reject) {
      var el = qs(selector);
      if (el) return resolve(true);

      var done = false;
      var timeout = setTimeout(function () {
        if (done) return;
        done = true;
        try { obs.disconnect(); } catch (_) {}
        reject(new Error("timeout"));
      }, Math.max(0, Number(timeoutMs || 0)));

      var obs = new MutationObserver(function () {
        var el2 = qs(selector);
        if (el2 && !done) {
          done = true;
          clearTimeout(timeout);
          try { obs.disconnect(); } catch (_) {}
          resolve(true);
        }
      });
      obs.observe(document.documentElement || document, { childList: true, subtree: true });
    });
  }

  async function dispatch(msg) {
    var id = msg && msg.id;
    var cmd = msg && msg.cmd;
    try {
      if (!id) throw new Error("missing_id");
      if (!cmd) throw new Error("missing_cmd");

      switch (cmd) {
        case "eval": {
          var f = (0, eval)(msg.js);
          var value = (typeof f === "function") ? f() : f;
          var result = await Promise.resolve(value);
          sendOk(id, result);
          return;
        }
        case "click": {
          var el = qs(msg.selector);
          if (!el) throw new Error("not_found");
          el.click();
          sendOk(id, true);
          return;
        }
        case "fill": {
          var el2 = qs(msg.selector);
          if (!el2) throw new Error("not_found");
          el2.value = String(msg.text ?? "");
          el2.dispatchEvent(new Event("input", { bubbles: true }));
          el2.dispatchEvent(new Event("change", { bubbles: true }));
          sendOk(id, true);
          return;
        }
        case "text": {
          var el3 = qs(msg.selector);
          if (!el3) throw new Error("not_found");
          sendOk(id, el3.textContent ?? "");
          return;
        }
        case "attr": {
          var el4 = qs(msg.selector);
          if (!el4) throw new Error("not_found");
          sendOk(id, el4.getAttribute(String(msg.name)));
          return;
        }
        case "wait_for_selector": {
          await waitForSelector(msg.selector, msg.timeout_ms);
          sendOk(id, true);
          return;
        }
        default:
          throw new Error("unsupported_cmd:" + String(cmd));
      }
    } catch (e) {
      sendErr(id || "unknown", e && e.message ? e.message : e);
    }
  }

  window.__gwry = {
    __installed: true,
    dispatch: dispatch,
  };
})();
"#
}
