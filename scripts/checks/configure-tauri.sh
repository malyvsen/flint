#!/usr/bin/env bash
set -euo pipefail

root="$1"
outputs="$2"
source "$root/scripts/checks/helpers.sh"

fixture="$outputs/configure-tauri/src-tauri"
mkdir -p "$fixture/src"
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
edition = "2021"
rust-version = "1.77.2"

[lib]
name = "app_lib"
EOF
printf 'fn main() { app_lib::run() }\n' >"$fixture/src/main.rs"

node "$root/scripts/configure-tauri.mjs" "$fixture" app.example.fixture fixture
reject_match "$outputs/configure-tauri" src-tauri/tauri.conf.json '"version"'
reject_match "$outputs/configure-tauri" src-tauri/tauri.conf.json '"versionCode"'
