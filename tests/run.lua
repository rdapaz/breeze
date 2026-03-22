#!/usr/bin/env lua
-- Breeze Test Runner
-- Usage: lua tests/run.lua
-- Discovers and runs all tests/test_*.lua files

------------------------------------------------------------------------
-- Resolve paths relative to this script's location
------------------------------------------------------------------------
local script_path = arg and arg[0] or "tests/run.lua"
local test_dir = script_path:match("^(.-)[/\\][^/\\]+$") or "tests"
local root_dir = test_dir:match("^(.-)[/\\][^/\\]+$") or "."

------------------------------------------------------------------------
-- Load the Breeze module
------------------------------------------------------------------------
package.path = root_dir .. "/?.lua;" .. package.path
Breeze = require("breeze")

------------------------------------------------------------------------
-- ANSI colors
------------------------------------------------------------------------
local GREEN  = "\27[32m"
local RED    = "\27[31m"
local YELLOW = "\27[33m"
local DIM    = "\27[2m"
local BOLD   = "\27[1m"
local RESET  = "\27[0m"

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local total_pass = 0
local total_fail = 0
local total_skip = 0
local failures = {}
local current_describe = nil

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function fmt_value(v)
  if type(v) == "string" then
    return string.format("%q", v)
  end
  return tostring(v)
end

local function fail_test(name, message)
  total_fail = total_fail + 1
  local full_name = current_describe and (current_describe .. " > " .. name) or name
  table.insert(failures, { name = full_name, message = message })
  io.write(RED .. "  FAIL " .. RESET .. name .. "\n")
  io.write(DIM .. "       " .. message .. RESET .. "\n")
end

local function pass_test(name)
  total_pass = total_pass + 1
  io.write(GREEN .. "  PASS " .. RESET .. name .. "\n")
end

------------------------------------------------------------------------
-- Test DSL (exposed as globals)
------------------------------------------------------------------------
function describe(name, fn)
  io.write("\n" .. BOLD .. name .. RESET .. "\n")
  local prev = current_describe
  current_describe = prev and (prev .. " > " .. name) or name
  fn()
  current_describe = prev
end

function it(name, fn)
  local ok, err = pcall(fn)
  if ok then
    pass_test(name)
  else
    fail_test(name, tostring(err))
  end
end

function assert_eq(actual, expected, msg)
  if actual ~= expected then
    local detail = "expected " .. fmt_value(expected) .. ", got " .. fmt_value(actual)
    error((msg and (msg .. ": ") or "") .. detail, 2)
  end
end

function assert_match(str, pattern, msg)
  if type(str) ~= "string" then
    error((msg and (msg .. ": ") or "") .. "expected string, got " .. type(str), 2)
  end
  if not str:match(pattern) then
    error((msg and (msg .. ": ") or "") ..
      fmt_value(str) .. " does not match pattern " .. fmt_value(pattern), 2)
  end
end

function assert_contains(str, substr, msg)
  if type(str) ~= "string" then
    error((msg and (msg .. ": ") or "") .. "expected string, got " .. type(str), 2)
  end
  if not str:find(substr, 1, true) then
    error((msg and (msg .. ": ") or "") ..
      fmt_value(str) .. " does not contain " .. fmt_value(substr), 2)
  end
end

function assert_error(fn, msg)
  local ok, err = pcall(fn)
  if ok then
    error((msg and (msg .. ": ") or "") .. "expected an error but none was raised", 2)
  end
  return err
end

function assert_truthy(val, msg)
  if not val then
    error((msg and (msg .. ": ") or "") ..
      "expected truthy value, got " .. fmt_value(val), 2)
  end
end

function assert_type(val, expected_type, msg)
  local actual_type = type(val)
  if actual_type ~= expected_type then
    error((msg and (msg .. ": ") or "") ..
      "expected type " .. fmt_value(expected_type) ..
      ", got " .. fmt_value(actual_type), 2)
  end
end

------------------------------------------------------------------------
-- Test file discovery
------------------------------------------------------------------------
local function discover_tests()
  local files = {}
  -- Try both Unix and Windows directory listing
  local sep = package.config:sub(1,1)  -- "/" or "\\"
  local cmd
  if sep == "\\" then
    cmd = 'dir /b "' .. test_dir .. '\\test_*.lua" 2>nul'
  else
    cmd = 'ls "' .. test_dir .. '"/test_*.lua 2>/dev/null'
  end
  local handle = io.popen(cmd)
  if handle then
    for line in handle:lines() do
      line = line:gsub("%s+$", "")  -- trim trailing whitespace/CR
      if line ~= "" then
        -- dir /b returns just filenames, ls returns full paths
        if not line:find(test_dir, 1, true) then
          line = test_dir .. sep .. line
        end
        files[#files + 1] = line
      end
    end
    handle:close()
  end
  table.sort(files)
  return files
end

------------------------------------------------------------------------
-- Main
------------------------------------------------------------------------
local function main()
  io.write(BOLD .. "Breeze Test Runner" .. RESET .. "\n")
  io.write(DIM .. string.rep("-", 50) .. RESET .. "\n")

  local files = discover_tests()

  if #files == 0 then
    io.write(YELLOW .. "No test files found (tests/test_*.lua)" .. RESET .. "\n")
    os.exit(0)
  end

  for _, file in ipairs(files) do
    io.write("\n" .. BOLD .. YELLOW .. ">> " .. file .. RESET .. "\n")
    local fn, err = loadfile(file)
    if not fn then
      total_fail = total_fail + 1
      table.insert(failures, { name = file, message = "Failed to load: " .. tostring(err) })
      io.write(RED .. "  ERROR " .. RESET .. "could not load file\n")
      io.write(DIM .. "       " .. tostring(err) .. RESET .. "\n")
    else
      local ok, run_err = pcall(fn)
      if not ok then
        total_fail = total_fail + 1
        table.insert(failures, { name = file, message = "Runtime error: " .. tostring(run_err) })
        io.write(RED .. "  ERROR " .. RESET .. "runtime error in file\n")
        io.write(DIM .. "       " .. tostring(run_err) .. RESET .. "\n")
      end
    end
  end

  -- Summary
  io.write("\n" .. string.rep("=", 50) .. "\n")
  local total = total_pass + total_fail
  io.write(string.format("Total: %d  ", total))
  io.write(GREEN .. string.format("Passed: %d  ", total_pass) .. RESET)
  if total_fail > 0 then
    io.write(RED .. string.format("Failed: %d", total_fail) .. RESET)
  else
    io.write(string.format("Failed: %d", total_fail))
  end
  io.write("\n")

  if #failures > 0 then
    io.write("\n" .. RED .. BOLD .. "Failures:" .. RESET .. "\n")
    for i, f in ipairs(failures) do
      io.write(RED .. "  " .. i .. ") " .. RESET .. f.name .. "\n")
      io.write(DIM .. "     " .. f.message .. RESET .. "\n")
    end
  end

  io.write("\n")
  if total_fail > 0 then
    io.write(RED .. BOLD .. "FAILED" .. RESET .. "\n")
    os.exit(1)
  else
    io.write(GREEN .. BOLD .. "ALL PASSED" .. RESET .. "\n")
    os.exit(0)
  end
end

main()
