# MCP advisor contract

This folder defines the **tool contract** for an external local MCP/LLM advisor. The addon itself
never performs HTTP requests and contains no API keys.

1. In game: `/fa export` → `ForeverAddonDB.exportJson`.
2. Read the JSON from SavedVariables.
3. Expose the tools from `tools.json` in your local MCP server.
4. Prompt the model with the export and the guardrails. It must return text, not game actions.

No tool here clicks, moves the character, reads pixels, injects input or bypasses anti-cheat.
