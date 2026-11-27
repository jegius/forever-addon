"use strict";
const { spawn } = require("child_process");
const path = require("path");

const child = spawn(process.execPath, [path.join(__dirname, "server.js"), "--file", path.join(__dirname, "sample-export.json")], {
  stdio: ["pipe", "pipe", "inherit"],
});
let out = "";
child.stdout.on("data", (chunk) => { out += chunk; });
child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize" }) + "\n");
child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: 2, method: "tools/list" }) + "\n");
child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "market_health", arguments: {} } }) + "\n");
child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "fa_sales", arguments: {} } }) + "\n");
child.stdin.end();
child.on("close", (code) => {
  if (code !== 0) process.exit(code || 1);
  const lines = out.trim().split(/\n+/).map((line) => JSON.parse(line));
  if (lines[0].result.serverInfo.name !== "forever-addon-advisor") throw new Error("initialize failed");
  if (!lines[1].result.tools.some((tool) => tool.name === "top_flips")) throw new Error("tools/list failed");
  if (!lines[2].result.content[0].text.includes("items")) throw new Error("tool call failed");
  if (lines[3].result.isError) throw new Error("fa_sales failed");
  console.log("mcp tests OK");
});
