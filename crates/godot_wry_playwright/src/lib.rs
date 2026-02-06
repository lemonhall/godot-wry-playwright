use godot::prelude::*;

pub mod pending;
mod wry_browser;
mod wry_texture_browser;

pub use wry_browser::WryBrowser;
pub use wry_texture_browser::WryTextureBrowser;

struct GodotWryPlaywright;

#[gdextension]
unsafe impl ExtensionLibrary for GodotWryPlaywright {}
