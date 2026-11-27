#!/usr/bin/env node
/* Minimal, dependency-free MCP stdio server for ForeverAddon exportJson.
 * It never controls WoW: reads a JSON snapshot and returns text recommendations.
 */
"use strict";
const fs = require("fs");
const readline = require("readline");

const fileArgIndex = process.argv.indexOf("--file");
const file = fileArgIndex >= 0 ? process.argv[fileArgIndex + 1] : process.env.FA_EXPORT;
let snapshot = null;
try {
  snapshot = file ? JSON.parse(fs.readFileSync(file, "utf8")) : null;
} catch (error) {
  process.stderr.write("ForeverAddon export not loaded: " + error.message + "\n");
}

const TOOLS = [
  { name: "market_health", description: "Freshness, coverage and anomalies", inputSchema: { type: "object", properties: {} } },
  { name: "top_flips", description: "Flips ranked by profit/confidence", inputSchema: { type: "object", properties: { limit: { type: "number" } } } },
  { name: "craft_plan", description: "Craft/DE chains under a budget", inputSchema: { type: "object", properties: { budget: { type: "number" } } } },
  { name: "profession_advice", description: "Profession coverage and best chains", inputSchema: { type: "object", properties: {} } },
  { name: "farming_plan", description: "Farming zones/resources", inputSchema: { type: "object", properties: {} } },
  { name: "explain", description: "Explain formulas and assumptions", inputSchema: { type: "object", properties: { kind: { type: "string" } } } },
];

const EXPLAIN = {
  flip: "Profit = resale * 0.95 - buy. Confidence is a heuristic; verify volume and history.",
  craft: "Cost = sum of reagent medians. Profit = max(direct, DE) * 0.95 - cost; DE is estimated.",
  farm: "score = nodes * yield * price / (respawn + travel) * competition.",
  profession: "Ranking uses positive chains; coverage is shown separately.",
};

function text(value) {
  return { content: [{ type: "text", text: typeof value === "string" ? value : JSON.stringify(value, null, 2) }] };
}

function call(name, args) {
  if (!snapshot && name !== "explain") {
    return text("No export loaded. Run /fa export in game and pass --file with the JSON.");
  }
  if (name === "market_health") return text(snapshot.health || {});
  if (name === "top_flips") {
    const limit = Math.max(1, Math.min(100, Number(args && args.limit) || 10));
    return text((snapshot.flips || []).slice(0, limit));
  }
  if (name === "craft_plan") {
    const budget = Number(args && args.budget) || 100000;
    return text((snapshot.chains || []).filter((c) => (c.cost || 0) <= budget).slice(0, 20));
  }
  if (name === "profession_advice") return text((snapshot.professions || []).slice(0, 12));
  if (name === "farming_plan") return text((snapshot.farming || []).slice(0, 10));
  if (name === "explain") return text(EXPLAIN[(args && args.kind) || "flip"] || "No explanation available.");
  return text("Unknown tool: " + name);
}

function respond(id, result) {
  process.stdout.write(JSON.stringify({ jsonrpc: "2.0", id, result }) + "\n");
}

const rl = readline.createInterface({ input: process.stdin });
rl.on("line", (line) => {
  if (!line.trim()) return;
  let msg;
  try { msg = JSON.parse(line); } catch { return; }
  if (msg.method === "initialize") {
    respond(msg.id, {
      protocolVersion: "2024-11-05",
      capabilities: { tools: {} },
      serverInfo: { name: "forever-addon-advisor", version: "1.0.0" },
    });
  } else if (msg.method === "tools/list") {
    respond(msg.id, { tools: TOOLS });
  } else if (msg.method === "tools/call") {
    const params = msg.params || {};
    respond(msg.id, call(params.name, params.arguments || {}));
  } else if (msg.id !== undefined) {
    respond(msg.id, { content: [{ type: "text", text: "Unsupported method: " + msg.method }], isError: true });
  }
});
