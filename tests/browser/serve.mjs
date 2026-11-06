// Minimal static server for the built documentation site (output/site), used by the browser tests.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";

const root = resolve(process.env.SITE_DIR || "output/site");
const port = Number(process.env.PORT || 8765);
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".txt": "text/plain; charset=utf-8" };

createServer(async (req, res) => {
    const path = normalize(decodeURIComponent(new URL(req.url, "http://localhost").pathname)).replace(/^([/\\])+/, "");
    const file = join(root, path || "index.html");
    if (!file.startsWith(root)) {
        res.writeHead(403).end();
        return;
    }
    try {
        const body = await readFile(file);
        res.writeHead(200, { "Content-Type": types[extname(file)] || "application/octet-stream" }).end(body);
    } catch {
        res.writeHead(404).end();
    }
}).listen(port, "127.0.0.1", () => console.log(`serving ${root} on http://127.0.0.1:${port}`));
