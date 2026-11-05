import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [tauriDir, identifier, packageName] = process.argv.slice(2);
if (tauriDir === undefined || identifier === undefined || packageName === undefined) {
	throw new Error("usage: configure-tauri.mjs <tauri-dir> <identifier> <package-name>");
}

configureTauri(join(tauriDir, "tauri.conf.json"), identifier);
configureCargo(join(tauriDir, "Cargo.toml"), packageName);
configureMain(join(tauriDir, "src/main.rs"), packageName);

function configureTauri(path, identifier) {
	const config = JSON.parse(readFileSync(path, "utf8"));
	config.identifier = identifier;
	delete config.version;
	writeFileSync(path, `${JSON.stringify(config, null, "\t")}\n`);
}

function configureCargo(path, packageName) {
	const cargo = readFileSync(path, "utf8");
	const libName = rustIdentifier(`${packageName}_lib`);
	const configured = [
		['name = "app"', `name = "${packageName}"`],
		['name = "app_lib"', `name = "${libName}"`],
		[/^rust-version = "[^"]*"\n/m, ""],
	].reduce((source, [from, to]) => replaceOnce(source, from, to), cargo);
	writeFileSync(path, configured);
}

function configureMain(path, packageName) {
	const main = readFileSync(path, "utf8");
	writeFileSync(
		path,
		replaceOnce(main, "app_lib::run()", `${rustIdentifier(`${packageName}_lib`)}::run()`),
	);
}

function rustIdentifier(value) {
	return value.replaceAll("-", "_");
}

function replaceOnce(source, from, to) {
	if (typeof from === "string") {
		const first = source.indexOf(from);
		if (first === -1 || source.indexOf(from, first + from.length) !== -1) {
			throw new Error(`expected exactly one ${JSON.stringify(from)}`);
		}
		return source.replace(from, to);
	}
	const matches = source.match(globalCopy(from)) ?? [];
	if (matches.length !== 1) {
		throw new Error(`expected exactly one ${from}`);
	}
	return source.replace(from, to);
}

function globalCopy(pattern) {
	const flags = pattern.flags.includes("g") ? pattern.flags : `${pattern.flags}g`;
	return new RegExp(pattern.source, flags);
}
