#!/usr/bin/env bash
set -euo pipefail

root="$1"
outputs="$2"
source "$root/scripts/checks/helpers.sh"

fixture="$outputs/configure-tauri/src-tauri"
mkdir -p "$fixture/src" "$fixture/capabilities"
cat >"$fixture/tauri.conf.json" <<'EOF'
{
	"identifier": "com.tauri.dev",
	"version": "0.1.0",
	"bundle": {}
}
EOF
cat >"$fixture/Cargo.toml" <<'EOF'
[package]
name = "app"
version = "0.1.0"
edition = "2024"
rust-version = "1.90"

[lib]
name = "app_lib"

[dependencies]
log = "0.4"
tauri-plugin-log = "2"
EOF
cat >"$fixture/capabilities/default.json" <<'EOF'
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "enables the default permissions",
  "windows": [
    "main"
  ],
  "permissions": [
    "core:default"
  ]
}
EOF
cat >"$fixture/src/lib.rs" <<'EOF'
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  tauri::Builder::default()
    .setup(|app| {
      if cfg!(debug_assertions) {
        app.handle().plugin(
          tauri_plugin_log::Builder::default()
            .level(log::LevelFilter::Info)
            .build(),
        )?;
      }
      Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while building tauri application");
}
EOF
printf 'fn main() { app_lib::run() }\n' >"$fixture/src/main.rs"

node "$root/scripts/configure-tauri.mjs" "$fixture" app.example.fixture fixture
expect_match "$outputs/configure-tauri" src-tauri/Cargo.toml '^name = "fixture"$'
expect_match "$outputs/configure-tauri" src-tauri/Cargo.toml '^name = "fixture_lib"$'
expect_match "$outputs/configure-tauri" src-tauri/Cargo.toml '^edition = "2024"$'
expect_match "$outputs/configure-tauri" src-tauri/Cargo.toml '^log = "0.4"$'
expect_match "$outputs/configure-tauri" src-tauri/Cargo.toml '^tauri-plugin-log = "2"$'
reject_match "$outputs/configure-tauri" src-tauri/Cargo.toml 'rust-version'
reject_match "$outputs/configure-tauri" src-tauri/tauri.conf.json '"version"'
reject_match "$outputs/configure-tauri" src-tauri/tauri.conf.json '"versionCode"'
expect_paths "$outputs/configure-tauri" src-tauri/src/logging.rs
expect_match "$outputs/configure-tauri" src-tauri/src/logging.rs 'tauri_plugin_log::Builder::new\(\)'
expect_match "$outputs/configure-tauri" src-tauri/src/logging.rs 'file_name: Some\("fixture"\.into\(\)\)'
expect_match "$outputs/configure-tauri" src-tauri/src/logging.rs '"FIXTURE_LOG"'
expect_match "$outputs/configure-tauri" src-tauri/src/lib.rs '^mod logging;$'
expect_match "$outputs/configure-tauri" src-tauri/src/lib.rs '\.plugin\(logging::plugin\(\)\)'
reject_match "$outputs/configure-tauri" src-tauri/src/lib.rs 'tauri_plugin_log::Builder'
expect_match "$outputs/configure-tauri" src-tauri/capabilities/default.json '"log:default"'
