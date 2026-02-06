use godot_wry_playwright_core::protocol::automation_shim_js;

#[test]
fn automation_shim_defines_dispatch_and_ipc() {
  let js = automation_shim_js();
  assert!(js.contains("window.__gwry"), "shim should define window.__gwry");
  assert!(js.contains("dispatch"), "shim should define dispatch");
  assert!(
    js.contains("window.ipc") && js.contains("postMessage"),
    "shim should use window.ipc.postMessage"
  );
  assert!(js.contains("MutationObserver"), "shim should support DOM waits");
}

