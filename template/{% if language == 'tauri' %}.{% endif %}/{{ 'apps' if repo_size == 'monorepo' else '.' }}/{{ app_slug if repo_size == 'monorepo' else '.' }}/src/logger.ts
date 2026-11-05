import {
	attachConsole,
	debug,
	error,
	info,
	trace,
	warn,
} from "@tauri-apps/plugin-log";

type ConsoleMethod = "log" | "debug" | "info" | "warn" | "error";

// Mirror console output into the Rust log while keeping devtools output.
// Plugin rejections are swallowed so importing this module is safe outside Tauri.
export function initLogging(): void {
	attachConsole().catch(() => {});
	// The plugin has no `log` level, so `console.log` maps to `trace`.
	mirror("log", trace);
	mirror("debug", debug);
	mirror("info", info);
	mirror("warn", warn);
	mirror("error", error);
	if (typeof window !== "undefined") {
		// Report uncaught failures through the mirrored console so they reach the log.
		window.addEventListener("error", (event) => {
			console.error(event.error ?? event.message);
		});
		window.addEventListener("unhandledrejection", (event) => {
			console.error(event.reason);
		});
	}
}

function mirror(
	method: ConsoleMethod,
	logger: (message: string) => Promise<void>,
): void {
	const original = console[method].bind(console);
	console[method] = (...args: unknown[]) => {
		original(...args);
		logger(formatArgs(args)).catch(() => {});
	};
}

function formatArgs(args: unknown[]): string {
	return args.map(formatValue).join(" ");
}

function formatValue(value: unknown): string {
	if (typeof value === "string") {
		return value;
	}
	if (value instanceof Error) {
		return value.stack ?? value.message;
	}
	try {
		return JSON.stringify(value) ?? String(value);
	} catch {
		return String(value);
	}
}
