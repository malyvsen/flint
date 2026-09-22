#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
outputs="$(mktemp -d)"
trap 'rm -rf "$outputs"' EXIT

main() {
	render python single-package
	render python monorepo
	render tauri single-package
	render tauri monorepo workbench
	render tauri single-package desktop null

	for check in \
		template-layout \
		configure-tauri \
		tauri-version \
		tauri-delivery \
		workspace-tasks; do
		bash "$root/scripts/checks/$check.sh" "$root" "$outputs"
	done
}

render() {
	local language="$1"
	local size="$2"
	local output_name="${4:-$language-$size}"
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
		"$outputs/$output_name"
	git -C "$outputs/$output_name" init -q
}

main "$@"
