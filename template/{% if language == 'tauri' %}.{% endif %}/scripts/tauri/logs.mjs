import { createReadStream, promises as fs } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const [identifier, fileName, ...extraArgs] = process.argv.slice(2);
if (
	identifier === undefined ||
	identifier === "" ||
	fileName === undefined ||
	fileName === "" ||
	extraArgs.length > 0
) {
	throw new Error("usage: logs.mjs <bundle-identifier> <file-name>");
}

await follow(resolveLogFile(identifier, fileName));

function resolveLogFile(identifier, fileName) {
	const file = `${fileName}.log`;
	if (process.platform === "darwin") {
		return join(homedir(), "Library", "Logs", identifier, file);
	}
	if (process.platform === "win32") {
		const localAppData = process.env.LOCALAPPDATA;
		if (localAppData === undefined || localAppData === "") {
			throw new Error("LOCALAPPDATA is not set");
		}
		return join(localAppData, identifier, "logs", file);
	}
	const dataHome =
		process.env.XDG_DATA_HOME ?? join(homedir(), ".local", "share");
	return join(dataHome, identifier, "logs", file);
}

async function follow(path) {
	let offset = 0;
	let waiting = false;
	for (;;) {
		try {
			const { size } = await fs.stat(path);
			if (size < offset) {
				offset = 0;
			}
			if (size > offset) {
				await dump(path, offset, size);
				offset = size;
			}
			waiting = false;
		} catch (error) {
			if (error?.code !== "ENOENT") {
				throw error;
			}
			if (!waiting) {
				process.stderr.write(`waiting for ${path}\n`);
				waiting = true;
			}
			offset = 0;
		}
		await sleep(250);
	}
}

function dump(path, start, end) {
	return new Promise((resolve, reject) => {
		const stream = createReadStream(path, { start, end: end - 1 });
		stream.on("error", reject);
		stream.on("end", resolve);
		stream.pipe(process.stdout, { end: false });
	});
}

function sleep(ms) {
	return new Promise((resolve) => setTimeout(resolve, ms));
}
