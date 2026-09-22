#!/usr/bin/env bash
set -euo pipefail

root="$1"
outputs="$2"
source "$root/scripts/checks/helpers.sh"

main() {
	local single="$outputs/delivery-single"
	copy_render "$outputs/tauri-single-package" "$single"
	prepare_app "$single"
	check_build "$single" "$single" tauri-single-package

	local mono="$outputs/delivery-monorepo"
	copy_render "$outputs/tauri-monorepo" "$mono"
	prepare_app "$mono/apps/workbench"
	CARGO_TARGET_DIR="$mono/custom-target" \
		check_build "$mono" "$mono/apps/workbench" workbench

	check_installer "$outputs/tauri-single-package/scripts/tauri/install-macos.mjs"
}

prepare_app() {
	local app="$1"
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
	cargo generate-lockfile --manifest-path "$app/src-tauri/Cargo.toml" >/dev/null
}

check_build() {
	local workspace="$1"
	local app="$2"
	local artifact_name="$3"
	local fake_bin="$workspace/.test-bin"
	mkdir -p "$fake_bin"
	cat >"$fake_bin/pnpm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
target="$(cargo metadata --format-version 1 --locked --no-deps --manifest-path src-tauri/Cargo.toml |
	node -e "let input = ''; process.stdin.on('data', chunk => input += chunk).on('end', () => process.stdout.write(JSON.parse(input).target_directory))")"
mkdir -p "$target/release/bundle/test"
printf 'distributable\n' >"$target/release/bundle/test/app"
EOF
	chmod +x "$fake_bin/pnpm"

	PATH="$fake_bin:$PATH" task -d "$app" build
	expect_paths "$workspace/release/$artifact_name" test/app
}

check_installer() {
	local installer="$1"
	local fixture="$outputs/installer"
	local artifact="$fixture/release/desktop"
	local applications="$fixture/Applications"
	local fake_bin="$fixture/bin"
	mkdir -p \
		"$artifact/macos/Desktop.app" \
		"$applications" \
		"$fake_bin"
	printf 'new\n' >"$artifact/macos/Desktop.app/new"
	cat >"$fake_bin/ditto" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cp -R "$1" "$2"
EOF
	chmod +x "$fake_bin/ditto"

	PATH="$fake_bin:$PATH" node "$installer" "$artifact" "$applications"
	expect_paths "$applications/Desktop.app" new
}

main "$@"
