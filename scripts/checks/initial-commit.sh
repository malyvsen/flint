#!/usr/bin/env bash
set -euo pipefail

root="$1"
outputs="$2"

expected="chore: initialize with flint"

main() {
	check_task
	for name in python-single-package python-monorepo tauri-single-package tauri-monorepo null; do
		check_render "$outputs/$name"
	done
}

check_task() {
	if grep -Fq -- '--no-verify' "$root/copier.yml"; then
		echo "copier.yml should not contain --no-verify" >&2
		exit 1
	fi
	local last_command_line
	last_command_line="$(grep -n -- '- command:' "$root/copier.yml" | tail -1 | cut -d: -f1)"
	if ! tail -n "+$last_command_line" "$root/copier.yml" | grep -Fq "$expected"; then
		echo "last _tasks entry should contain $expected" >&2
		exit 1
	fi
}

check_render() {
	local directory="$1"
	git -C "$directory" config user.name "Flint Check"
	git -C "$directory" config user.email "flint-check@example.com"
	git -C "$directory" add -A
	# Skip verification here for speed; the real copier task still verifies.
	git -C "$directory" commit --no-verify -q -m "$expected"
	local message
	message="$(git -C "$directory" log --format=%s -n 1)"
	if [[ "$message" != "$expected" ]]; then
		echo "$directory commit message should be $expected, was $message" >&2
		exit 1
	fi
	if ! git -C "$directory" rev-parse --verify HEAD >/dev/null; then
		echo "$directory should have a verified HEAD" >&2
		exit 1
	fi
	if [[ -n "$(git -C "$directory" status --porcelain)" ]]; then
		echo "$directory should have a clean status after commit" >&2
		exit 1
	fi
}

main "$@"
