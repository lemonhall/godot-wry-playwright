use godot::prelude::*;

pub mod pending;
mod wry_browser;

pub use wry_browser::WryBrowser;

struct GodotWryPlaywright;

#[gdextension]
unsafe impl ExtensionLibrary for GodotWryPlaywright {}
