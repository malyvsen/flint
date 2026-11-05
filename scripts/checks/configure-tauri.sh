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
edition = "2024"
rust-version = "1.90"

[lib]
name = "app_lib"
EOF
printf 'fn main() { app_lib::run() }\n' >"$fixture/src/main.rs"

node "$root/scripts/configure-tauri.mjs" "$fixture" app.example.fixture fixture
expect_match "$outputs/configure-tauri" src-tauri/Cargo.toml '^name = "fixture"$'
expect_match "$outputs/configure-tauri" src-tauri/Cargo.toml '^name = "fixture_lib"$'
expect_match "$outputs/configure-tauri" src-tauri/Cargo.toml '^edition = "2024"$'
reject_match "$outputs/configure-tauri" src-tauri/Cargo.toml 'rust-version'
reject_match "$outputs/configure-tauri" src-tauri/tauri.conf.json '"version"'
reject_match "$outputs/configure-tauri" src-tauri/tauri.conf.json '"versionCode"'
