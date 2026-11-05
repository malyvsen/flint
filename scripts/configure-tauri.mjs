import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const [tauriDir, identifier, packageName] = process.argv.slice(2);
if (tauriDir === undefined || identifier === undefined || packageName === undefined) {
	throw new Error("usage: configure-tauri.mjs <tauri-dir> <identifier> <package-name>");
}

configureTauri(join(tauriDir, "tauri.conf.json"), identifier);
configureCargo(join(tauriDir, "Cargo.toml"), packageName);
configureMain(join(tauriDir, "src/main.rs"), packageName);
configureLogging(tauriDir, packageName);
configureLib(join(tauriDir, "src/lib.rs"));
configureCapabilities(join(tauriDir, "capabilities/default.json"));

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
		[/^name = "app"$/m, `name = "${packageName}"`],
		[/^name = "app_lib"$/m, `name = "${libName}"`],
		[/^rust-version = "[^"]*"\n/m, ""],
	].reduce((source, [from, to]) => replaceOnce(source, from, to), cargo);
	writeFileSync(path, ensureLoggingDependencies(configured));
}

function ensureLoggingDependencies(cargo) {
	const missing = [
		["log", 'log = "0.4"'],
		["tauri-plugin-log", 'tauri-plugin-log = "2"'],
	].filter(([name]) => !new RegExp(`^${name}\\s*=`, "m").test(cargo));
	if (missing.length === 0) {
		return cargo;
	}
	const added = missing.map(([, line]) => line).join("\n");
	return replaceOnce(
		cargo,
		/^\[dependencies\]\n/m,
		`[dependencies]\n${added}\n`,
	);
}

function configureMain(path, packageName) {
	const main = readFileSync(path, "utf8");
	writeFileSync(
		path,
		replaceOnce(main, "app_lib::run()", `${rustIdentifier(`${packageName}_lib`)}::run()`),
	);
}

function configureLogging(tauriDir, packageName) {
	const reference = readFileSync(
		new URL("./tauri/logging.rs", import.meta.url),
		"utf8",
	);
	const logFile = packageName;
	const logLevelEnv = `${packageName.replaceAll(/[^A-Za-z0-9]/g, "_").toUpperCase()}_LOG`;
	const configured = reference
		.replaceAll("__LOG_FILE_NAME__", logFile)
		.replaceAll("__LOG_LEVEL_ENV__", logLevelEnv);
	writeFileSync(join(tauriDir, "src/logging.rs"), configured);
}

function configureLib(path) {
	const lib = readFileSync(path, "utf8");
	const setup =
		/\.setup\(\|app\| \{\s*if cfg!\(debug_assertions\) \{\s*app\s*\.handle\(\)\s*\.plugin\(\s*tauri_plugin_log::Builder::default\(\)\s*\.level\(log::LevelFilter::Info\)\s*\.build\(\),?\s*\)\?;\s*\}\s*Ok\(\(\)\)\s*\}\)/;
	const configured = lib.replace(setup, ".plugin(logging::plugin())");
	if (configured === lib) {
		throw new Error("expected a generated log setup in src/lib.rs");
	}
	writeFileSync(path, `mod logging;\n\n${configured}`);
}

function configureCapabilities(path) {
	const capabilities = JSON.parse(readFileSync(path, "utf8"));
	if (!capabilities.permissions.includes("log:default")) {
		capabilities.permissions.push("log:default");
	}
	writeFileSync(path, `${JSON.stringify(capabilities, null, "\t")}\n`);
}

function rustIdentifier(value) {
	return value.replaceAll("-", "_");
}

function replaceOnce(source, from, to) {
	// NB: `from` must not contain capture groups; split() includes them in the result.
	if (source.split(from).length - 1 !== 1) {
		throw new Error(`expected exactly one ${from}`);
	}
	return source.replace(from, to);
}
