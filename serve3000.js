const http = require("http");
const fs = require("fs");
const path = require("path");

const root = process.cwd();
const port = 3000;

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8"
};

function safePath(urlPath) {
  const raw = decodeURIComponent((urlPath || "/").split("?")[0].split("#")[0]);
  const normalized = raw === "/" ? "/openclaw2.html" : raw;
  const abs = path.resolve(root, "." + normalized);
  if (!abs.startsWith(root)) return null;
  return abs;
}

const server = http.createServer((req, res) => {
  const abs = safePath(req.url);
  if (!abs) {
    res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Bad request");
    return;
  }
  fs.stat(abs, (err, stat) => {
    if (err || !stat.isFile()) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found");
      return;
    }
    const ext = path.extname(abs).toLowerCase();
    res.writeHead(200, { "Content-Type": mime[ext] || "application/octet-stream" });
    fs.createReadStream(abs).pipe(res);
  });
});

server.listen(port, () => {
  console.log(`Static server running: http://localhost:${port}/openclaw2.html`);
});
