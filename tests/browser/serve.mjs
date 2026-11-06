// Minimal static server for the built documentation site (site/, from zensical build), used by the
// browser tests. Folder URLs serve their index.html, as GitHub Pages does.
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, normalize, resolve, sep } from "node:path";

const root = resolve(process.env.SITE_DIR || "site");
const port = Number(process.env.PORT || 8765);
const types = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".xml": "application/xml",
    ".txt": "text/plain; charset=utf-8"
};

createServer(async (req, res) => {
    let path;
    try {
        path = normalize(decodeURIComponent(new URL(req.url, "http://localhost").pathname)).replace(/^([/\\])+/, "");
    } catch {
        res.writeHead(400).end();
        return;
    }
    let file = join(root, path || "index.html");
    // inside the site folder only (a prefix check would let "site-other" through)
    if (file !== root && !file.startsWith(root + sep)) {
        res.writeHead(403).end();
        return;
    }
    try {
        if ((await stat(file)).isDirectory()) {
            file = join(file, "index.html");
        }
        const body = await readFile(file);
        res.writeHead(200, { "Content-Type": types[extname(file)] || "application/octet-stream" }).end(body);
    } catch {
        res.writeHead(404).end();
    }
}).listen(port, "127.0.0.1", () => console.log(`serving ${root} on http://127.0.0.1:${port}`));
