#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
outputs="$(mktemp -d)"
trap 'rm -rf "$outputs"' EXIT

main() {
	render python single-package
	expect python-single-package Taskfile.yml taskfiles/python.yml
	reject python-single-package package.json apps libs taskfiles/rust.yml

	render python monorepo
	expect python-monorepo Taskfile.yml apps/.gitkeep libs/.gitkeep taskfiles/python.yml
	reject python-monorepo package.json pnpm-workspace.yaml taskfiles/rust.yml

	render tauri single-package
	expect tauri-single-package package.json src/App.tsx taskfiles/rust.yml taskfiles/typescript.yml
	reject tauri-single-package apps libs taskfiles/python.yml Cargo.toml pnpm-workspace.yaml
	reject_match tauri-single-package package.json '"(packageManager|dependencies|devDependencies)"'
	expect_match tauri-single-package biome.json 'schemas/latest/schema.json'

	render tauri monorepo workbench
	expect tauri-monorepo package.json pnpm-workspace.yaml Cargo.toml apps/workbench/package.json packages/.gitkeep
	reject tauri-monorepo apps/desktop libs taskfiles/python.yml src
	reject_match tauri-monorepo package.json '"(packageManager|dependencies|devDependencies)"'
	reject_match tauri-monorepo apps/workbench/package.json '"(packageManager|dependencies|devDependencies)"'
	expect_match tauri-monorepo pnpm-workspace.yaml '^catalog: \{\}$'
}

render() {
	local language="$1"
	local size="$2"
	local data=(
		--data "language=$language"
		--data "repo_size=$size"
	)
	if [[ "$language" == tauri ]]; then
		local app_slug="${3:-desktop}"
		data+=(
			--data "app_slug=$app_slug"
			--data "app_identifier=app.example.$app_slug"
		)
	fi
	uv run copier copy \
		--trust \
		--skip-tasks \
		--defaults \
		"${data[@]}" \
		--vcs-ref=HEAD \
		-q \
		"$root" \
		"$outputs/$language-$size"
}

expect() {
	local output="$1"
	shift
	for path in "$@"; do
		if [[ ! -e "$outputs/$output/$path" ]]; then
			echo "$output should contain $path" >&2
			exit 1
		fi
	done
}

reject() {
	local output="$1"
	shift
	for path in "$@"; do
		if [[ -e "$outputs/$output/$path" ]]; then
			echo "$output should not contain $path" >&2
			exit 1
		fi
	done
}

expect_match() {
	local output="$1"
	local path="$2"
	local pattern="$3"
	if ! grep -Eq "$pattern" "$outputs/$output/$path"; then
		echo "$output/$path should match $pattern" >&2
		exit 1
	fi
}

reject_match() {
	local output="$1"
	local path="$2"
	local pattern="$3"
	if grep -Eq "$pattern" "$outputs/$output/$path"; then
		echo "$output/$path should not match $pattern" >&2
		exit 1
	fi
}

main "$@"
