expect_paths() {
	local directory="$1"
	shift
	for path in "$@"; do
		if [[ ! -e "$directory/$path" ]]; then
			echo "$directory should contain $path" >&2
			exit 1
		fi
	done
}

reject_paths() {
	local directory="$1"
	shift
	for path in "$@"; do
		if [[ -e "$directory/$path" ]]; then
			echo "$directory should not contain $path" >&2
			exit 1
		fi
	done
}

expect_match() {
	local directory="$1"
	local path="$2"
	local pattern="$3"
	if ! grep -Eq "$pattern" "$directory/$path"; then
		echo "$directory/$path should match $pattern" >&2
		exit 1
	fi
}

reject_match() {
	local directory="$1"
	local path="$2"
	local pattern="$3"
	if grep -Eq "$pattern" "$directory/$path"; then
		echo "$directory/$path should not match $pattern" >&2
		exit 1
	fi
}

expect_task() {
	local directory="$1"
	local task_name="$2"
	if ! task -d "$directory" -n "$task_name" >/dev/null 2>&1; then
		echo "$directory should define task $task_name" >&2
		exit 1
	fi
}

reject_task() {
	local directory="$1"
	local task_name="$2"
	if task -d "$directory" -n "$task_name" >/dev/null 2>&1; then
		echo "$directory should not define task $task_name" >&2
		exit 1
	fi
}

copy_render() {
	local source="$1"
	local destination="$2"
	rm -rf "$destination"
	cp -R "$source" "$destination"
}

cargo_metadata_field() {
	local manifest="$1"
	local field="$2"
	cargo metadata --format-version 1 --locked --no-deps --manifest-path "$manifest" |
		node -e "let input = ''; process.stdin.on('data', chunk => input += chunk).on('end', () => process.stdout.write(JSON.parse(input)[process.argv[1]]))" "$field"
}
