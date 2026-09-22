#!/usr/bin/env bash
set -euo pipefail

root="$1"
outputs="$2"
source "$root/scripts/checks/helpers.sh"

main() {
	local workspace="$outputs/workspace-tasks"
	copy_render "$outputs/tauri-monorepo" "$workspace"
	local trace="$workspace/task-trace"
	local fake_bin="$workspace/.test-bin"
	add_projects "$workspace"
	fake_pnpm "$fake_bin"

	local build_projects
	build_projects="$(cd "$workspace" && node scripts/workspace-projects.mjs build)"
	if [[ "$build_projects" != $'apps/build-only\napps/workbench' ]]; then
		echo "build projects were not discovered in sorted order" >&2
		exit 1
	fi

	TRACE="$trace" PATH="$fake_bin:$PATH" task -d "$workspace" dev
	TRACE="$trace" PATH="$fake_bin:$PATH" task -d "$workspace" init
	TRACE="$trace" PATH="$fake_bin:$PATH" task -d "$workspace" check
	TRACE="$trace" PATH="$fake_bin:$PATH" task -d "$workspace" build
	TRACE="$trace" PATH="$fake_bin:$PATH" task -d "$workspace" deploy
	check_trace "$workspace" "$trace"
	check_broken_project "$workspace"
}

add_projects() {
	local workspace="$1"
	mkdir -p \
		"$workspace/apps/build-only" \
		"$workspace/packages/check-only" \
		"$workspace/packages/noop"
	cat >"$workspace/apps/workbench/Taskfile.yml" <<'EOF'
version: "3"
tasks:
  init:
    cmds: ['echo workbench-init >> "$TRACE"']
  check:
    cmds: ['echo workbench-check >> "$TRACE"']
  dev:
    cmds: ['echo workbench-dev >> "$TRACE"']
  build:
    cmds: ['echo workbench-build >> "$TRACE"']
  deploy:
    cmds: ['echo workbench-deploy >> "$TRACE"']
EOF
	cat >"$workspace/apps/build-only/Taskfile.yml" <<'EOF'
version: "3"
tasks:
  build:
    cmds: ['echo build-only-build >> "$TRACE"']
EOF
	cat >"$workspace/packages/check-only/Taskfile.yml" <<'EOF'
version: "3"
tasks:
  check:
    cmds: ['echo check-only-check >> "$TRACE"']
EOF
	cat >"$workspace/packages/noop/Taskfile.yml" <<'EOF'
version: "3"
tasks:
  noop:
    cmds: [echo noop]
EOF
}

fake_pnpm() {
	local fake_bin="$1"
	mkdir -p "$fake_bin"
	cat >"$fake_bin/pnpm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	chmod +x "$fake_bin/pnpm"
}

check_trace() {
	local workspace="$1"
	local trace="$2"
	cat >"$workspace/expected-task-trace" <<'EOF'
build-only-build
check-only-check
workbench-build
workbench-check
workbench-deploy
workbench-dev
workbench-init
EOF
	sort "$trace" >"$trace.sorted"
	diff "$workspace/expected-task-trace" "$trace.sorted"
}

check_broken_project() {
	local workspace="$1"
	mkdir -p "$workspace/packages/broken"
	printf 'not valid Task YAML\n' >"$workspace/packages/broken/Taskfile.yml"
	if (cd "$workspace" && node scripts/workspace-projects.mjs build >/dev/null 2>&1); then
		echo "workspace discovery should reject a broken child Taskfile" >&2
		exit 1
	fi
}

main "$@"
