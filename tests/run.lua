local tests = {
  "tests/test_price.lua",
  "tests/test_disenchant.lua",
  "tests/test_catalog.lua",
  "tests/test_db.lua",
  "tests/test_advisor.lua",
  "tests/test_farming.lua",
  "tests/test_load_all.lua",
  "tests/test_ui_smoke.lua",
}

for _, path in ipairs(tests) do
  local chunk = assert(loadfile(path))
  local ok, err = pcall(chunk)
  if not ok then
    io.stderr:write(string.format("FAIL %s: %s\n", path, tostring(err)))
    os.exit(1)
  end
end
print("all tests passed")
