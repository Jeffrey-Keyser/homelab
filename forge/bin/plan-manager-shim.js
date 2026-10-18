#!/usr/bin/env node
// forge-local stand-in for openclaw-bridge on 127.0.0.1:3099.
// - /plan-manager/* is served HERE with the bridge's own handler (wake-inbox + plan-manager.sh must run on the host that owns ~/dev-inbox).
// - everything else is proxied to the real bridge on prod beelink (Telegram notify, /decisions/notify, /live-orchestration, ...).
const BRIDGE = process.env.BRIDGE_SRC || "/home/jkeyser/openclaw-bridge";
const UPSTREAM = new URL(process.env.UPSTREAM_BRIDGE_URL || "http://100.99.136.81:3099");
const PORT = Number(process.env.PORT || 3099);
const http = require("http");
const express = require(`${BRIDGE}/node_modules/express`);
const bodyParser = require(`${BRIDGE}/node_modules/body-parser`);
const planManager = require(`${BRIDGE}/src/handlers/plan-manager`);
const app = express();
app.get("/health", (_req, res) => res.json({ status: "ok", service: "plan-manager-shim", host: "forge", upstream: UPSTREAM.href }));
// parse JSON only for local routes; proxied routes get the raw stream
app.use("/plan-manager", bodyParser.json({ limit: "2mb" }));
planManager.mount(app);
app.use((req, res) => {
  const opts = { host: UPSTREAM.hostname, port: UPSTREAM.port, path: req.originalUrl, method: req.method,
    headers: { ...req.headers, host: `${UPSTREAM.hostname}:${UPSTREAM.port}`, "x-forwarded-by": "plan-manager-shim/forge" } };
  const up = http.request(opts, (ur) => { res.writeHead(ur.statusCode, ur.headers); ur.pipe(res); });
  up.on("error", (e) => { if (!res.headersSent) res.status(502).json({ error: "upstream bridge unreachable", detail: e.message }); });
  req.pipe(up);
});
planManager.init().catch((e) => console.error("[plan-manager] init failed:", e.message));
app.listen(PORT, "127.0.0.1", () => console.log(`plan-manager-shim listening on 127.0.0.1:${PORT}, proxying to ${UPSTREAM.href}`));
