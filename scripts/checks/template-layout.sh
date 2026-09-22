#!/usr/bin/env bash
set -euo pipefail

root="$1"
outputs="$2"
source "$root/scripts/checks/helpers.sh"

python_single="$outputs/python-single-package"
expect_paths "$python_single" Taskfile.yml taskfiles/python.yml
reject_paths "$python_single" package.json apps libs taskfiles/rust.yml
expect_match "$python_single" Taskfile.yml '^  fix:$'

python_mono="$outputs/python-monorepo"
expect_paths "$python_mono" Taskfile.yml apps/.gitkeep libs/.gitkeep taskfiles/python.yml
reject_paths "$python_mono" package.json pnpm-workspace.yaml taskfiles/rust.yml
expect_match "$python_mono" Taskfile.yml '^  fix:$'

tauri_single="$outputs/tauri-single-package"
expect_paths "$tauri_single" \
	package.json \
	scripts/tauri/build.mjs \
	scripts/tauri/bump.mjs \
	scripts/tauri/install-macos.mjs \
	src/App.tsx \
	taskfiles/rust.yml \
	taskfiles/tauri.yml \
	taskfiles/typescript.yml
reject_paths "$tauri_single" \
	Cargo.toml \
	apps \
	libs \
	pnpm-workspace.yaml \
	scripts/workspace-projects.mjs \
	taskfiles/python.yml
generated_package_fields='"(packageManager|version|dependencies|devDependencies)"'
reject_match "$tauri_single" package.json "$generated_package_fields"
expect_match "$tauri_single" biome.json 'schemas/latest/schema.json'
expect_task "$tauri_single" build
expect_task "$tauri_single" bump
expect_task "$tauri_single" deploy

null_named="$outputs/null"
expect_match "$null_named" Taskfile.yml '^      ARTIFACT_NAME: "null"$'
expect_task "$null_named" build

tauri_mono="$outputs/tauri-monorepo"
expect_paths "$tauri_mono" \
	Cargo.toml \
	Taskfile.yml \
	apps/workbench/Taskfile.yml \
	apps/workbench/package.json \
	package.json \
	packages/.gitkeep \
	pnpm-workspace.yaml \
	scripts/tauri/build.mjs \
	scripts/tauri/bump.mjs \
	scripts/tauri/install-macos.mjs \
	scripts/workspace-projects.mjs \
	taskfiles/tauri.yml
reject_paths "$tauri_mono" apps/desktop libs src taskfiles/python.yml
reject_match "$tauri_mono" package.json "$generated_package_fields"
reject_match "$tauri_mono/apps/workbench" package.json "$generated_package_fields"
expect_match "$tauri_mono" pnpm-workspace.yaml '^catalog: \{\}$'
expect_match "$tauri_mono" Taskfile.yml '^  DEFAULT_PROJECT: apps/workbench$'
expect_task "$tauri_mono" build
expect_task "$tauri_mono" deploy
reject_task "$tauri_mono" bump
expect_task "$tauri_mono/apps/workbench" build
expect_task "$tauri_mono/apps/workbench" bump
expect_task "$tauri_mono/apps/workbench" deploy
