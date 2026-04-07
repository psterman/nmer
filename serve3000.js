const http = require("http");
const fs = require("fs");
const path = require("path");

const root = process.cwd();
const port = 3000;
const niumaHistoryDir = path.join(root, "Data", "niuma-chat");
const niumaHistoryFile = path.join(niumaHistoryDir, "history.json");

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

function sendJson(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body));
}

function readNiumaHistory(cb) {
  fs.readFile(niumaHistoryFile, "utf8", (err, text) => {
    if (err) {
      if (err.code === "ENOENT") {
        cb(null, { version: 1, sessions: {}, updatedAt: null });
        return;
      }
      cb(err);
      return;
    }
    try {
      const parsed = JSON.parse(text);
      if (!parsed || typeof parsed !== "object") throw new Error("Invalid history payload");
      cb(null, parsed);
    } catch (parseErr) {
      cb(parseErr);
    }
  });
}

function writeNiumaHistory(payload, cb) {
  const normalized = payload && typeof payload === "object" ? payload : {};
  const doc = {
    version: 1,
    sessions: normalized.sessions && typeof normalized.sessions === "object" ? normalized.sessions : {},
    updatedAt: new Date().toISOString()
  };
  fs.mkdir(niumaHistoryDir, { recursive: true }, (mkErr) => {
    if (mkErr) {
      cb(mkErr);
      return;
    }
    fs.writeFile(niumaHistoryFile, JSON.stringify(doc, null, 2), "utf8", cb);
  });
}

function parseJsonBody(req, cb) {
  let raw = "";
  req.on("data", (chunk) => {
    raw += String(chunk);
    if (raw.length > 2 * 1024 * 1024) {
      cb(new Error("Body too large"));
      req.destroy();
    }
  });
  req.on("end", () => {
    if (!raw.trim()) {
      cb(null, {});
      return;
    }
    try {
      cb(null, JSON.parse(raw));
    } catch (err) {
      cb(err);
    }
  });
  req.on("error", cb);
}

const server = http.createServer((req, res) => {
  const reqPath = decodeURIComponent((req.url || "/").split("?")[0].split("#")[0]);
  if (reqPath === "/api/niuma/history") {
    if (req.method === "GET") {
      readNiumaHistory((err, data) => {
        if (err) {
          sendJson(res, 500, { ok: false, error: err.message || String(err) });
          return;
        }
        sendJson(res, 200, { ok: true, data });
      });
      return;
    }
    if (req.method === "POST") {
      parseJsonBody(req, (bodyErr, body) => {
        if (bodyErr) {
          sendJson(res, 400, { ok: false, error: "Invalid JSON body" });
          return;
        }
        const payload = body && typeof body === "object" && body.data && typeof body.data === "object"
          ? body.data
          : body;
        writeNiumaHistory(payload, (writeErr) => {
          if (writeErr) {
            sendJson(res, 500, { ok: false, error: writeErr.message || String(writeErr) });
            return;
          }
          sendJson(res, 200, { ok: true, path: niumaHistoryFile });
        });
      });
      return;
    }
    sendJson(res, 405, { ok: false, error: "Method not allowed" });
    return;
  }

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
