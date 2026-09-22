#!/usr/bin/env bash
set -euo pipefail

root="$1"
outputs="$2"
source "$root/scripts/checks/helpers.sh"

main() {
	local single="$outputs/version-single"
	copy_render "$outputs/tauri-single-package" "$single"
	prepare_app "$single" desktop
	check_bump "$single" desktop

	local mono="$outputs/version-monorepo"
	copy_render "$outputs/tauri-monorepo" "$mono"
	add_sibling "$mono"
	prepare_app "$mono/apps/workbench" android
	check_bump "$mono/apps/workbench" android
	expect_match "$mono" Cargo.lock '^version = "9.9.9"$'
	expect_match "$mono/apps/sibling" src-tauri/Cargo.toml '^version = "9.9.9"$'
}

prepare_app() {
	local app="$1"
	local platform="$2"
	mkdir -p "$app/src-tauri/src"
	cat >"$app/src-tauri/Cargo.toml" <<'EOF'
[package]
name = "fixture"
version = "0.1.0"
edition = "2024"

[lib]
path = "src/lib.rs"
EOF
	printf '\n' >"$app/src-tauri/src/lib.rs"
	if [[ "$platform" == android ]]; then
		cat >"$app/src-tauri/tauri.conf.json" <<'EOF'
{"bundle":{"android":{"versionCode":1}}}
EOF
	else
		cat >"$app/src-tauri/tauri.conf.json" <<'EOF'
{"bundle":{}}
EOF
	fi
	cargo generate-lockfile --manifest-path "$app/src-tauri/Cargo.toml" >/dev/null
}

add_sibling() {
	local workspace="$1"
	local app="$workspace/apps/sibling"
	mkdir -p "$app/src-tauri/src"
	cat >"$app/src-tauri/Cargo.toml" <<'EOF'
[package]
name = "sibling"
version = "9.9.9"

[lib]
path = "src/lib.rs"
EOF
	printf '\n' >"$app/src-tauri/src/lib.rs"
	sed -i.bak \
		's#members = \[#members = ["apps/sibling/src-tauri", #' \
		"$workspace/Cargo.toml"
	rm "$workspace/Cargo.toml.bak"
}

check_bump() {
	local app="$1"
	local platform="$2"
	task -d "$app" bump -- patch
	expect_match "$app" src-tauri/Cargo.toml '^version = "0.1.1"$'
	reject_match "$app" package.json '"version"'
	reject_match "$app" src-tauri/tauri.conf.json '"version"'
	if [[ "$platform" == android ]]; then
		expect_match "$app" src-tauri/tauri.conf.json '"versionCode":2'
	else
		reject_match "$app" src-tauri/tauri.conf.json '"versionCode"'
	fi

	local workspace
	workspace="$(cargo_metadata_field "$app/src-tauri/Cargo.toml" workspace_root)"
	expect_match "$workspace" Cargo.lock '^version = "0.1.1"$'
}

main "$@"
