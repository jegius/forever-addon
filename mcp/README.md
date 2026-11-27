# MCP advisor

Dependency-free MCP stdio server for a **safe** local advisor. It never controls WoW.

## Data flow

1. In game: `/fa export` → `ForeverAddonDB.exportJson` in SavedVariables.
2. Extract the JSON string into a file (SavedVariables is Lua, `exportJson` is a JSON string).
3. Run:

```bash
node mcp/server.js --file export.json
```

or set `FA_EXPORT=/path/export.json`.

## Tools

- `market_health` — freshness, coverage, anomalies.
- `top_flips` — profit/ROI/confidence.
- `craft_plan` — chains under a budget.
- `profession_advice` — coverage and best chains.
- `farming_plan` — zones/resources.
- `explain` — formula and assumptions.

All results are text/JSON. The server does not click, inject input, read pixels or bypass anti-cheat.
Always treat recommendations as estimates; verify volume, competition and scan age.

## Test

```bash
node mcp/test.js
```

The sample contract is in `tools.json`; `sample-export.json` is a test fixture.
