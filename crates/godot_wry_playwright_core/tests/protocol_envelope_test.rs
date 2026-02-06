use godot_wry_playwright_core::protocol::{build_dispatch_script, parse_ipc_envelope, Command};
use pretty_assertions::assert_eq;
use serde_json::json;

#[test]
fn parse_ipc_envelope_ok_with_result() {
  let s = r#"{"id":"1","ok":true,"result":{"title":"Example"},"error":null}"#;
  let env = parse_ipc_envelope(s).expect("should parse");
  assert_eq!(env.id, "1");
  assert_eq!(env.ok, true);
  assert_eq!(env.result, Some(json!({"title":"Example"})));
  assert_eq!(env.error, None);
}

#[test]
fn parse_ipc_envelope_err_with_message() {
  let s = r#"{"id":"99","ok":false,"result":null,"error":"timeout"}"#;
  let env = parse_ipc_envelope(s).expect("should parse");
  assert_eq!(env.id, "99");
  assert_eq!(env.ok, false);
  assert_eq!(env.result, None);
  assert_eq!(env.error, Some("timeout".to_string()));
}

#[test]
fn build_dispatch_script_includes_id_and_cmd() {
  let script = build_dispatch_script("abc", Command::Eval { js: "() => 1".into() });
  assert!(script.contains(r#""id":"abc""#), "script should include request id");
  assert!(script.contains(r#""cmd":"eval""#), "script should include command");
}

