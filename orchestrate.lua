local shell = require("shell")
local thread = require("thread")
local event = require("event")
local component = require("component")

local args, options = shell.parse(...)

-- Helper function to read address from file
local function readAddress(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local raw = f:read("*a")
  f:close()
  if not raw then
    return nil
  end
  local cleaned = raw:match("^%s*(.-)%s*$")
  if cleaned == "" then
    return nil
  end
  return cleaned
end

-- Check if secondary reactor is configured
-- Discover reactor configurations. Preference order:
-- 1) `reactors.txt` where each non-empty line is: <transposerAddr> <powerButtonAddr>
-- 2) fallback to primary files + legacy secondary files for backward compatibility
local reactors = {}
local function readReactorsList(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local list = {}
  for line in f:lines() do
    local cleaned = line:match("^%s*(.-)%s*$")
    if cleaned ~= "" then
      local taddr, paddr = cleaned:match('^(%S+)%s+(%S+)')
      if not taddr then taddr = cleaned end
      table.insert(list, {transposer = taddr, powerbutton = paddr})
    end
  end
  f:close()
  return #list > 0 and list or nil
end

local function validateReactors(list)
  local valid = {}
  for i, r in ipairs(list) do
    local t = r.transposer and r.transposer:match("^%s*(.-)%s*$")
    local p = r.powerbutton and r.powerbutton:match("^%s*(.-)%s*$")

    if not t or t == "" then
      print(string.format("[SKIP] Reactor %d: missing transposer address", i))
    elseif not p or p == "" then
      print(string.format("[SKIP] Reactor %d: missing power button address", i))
    else
      local ok_t = component.get(t)
      local ok_p = component.get(p)
      if not ok_t then
        print(string.format("[SKIP] Reactor %d: transposer address '%s' not found", i, tostring(t)))
      elseif not ok_p then
        print(string.format("[SKIP] Reactor %d: power button address '%s' not found", i, tostring(p)))
      else
        table.insert(valid, {transposer = t, powerbutton = p})
      end
    end
  end
  return valid
end

local listed = readReactorsList("reactors.txt")
if not listed then
  error("Configuration file 'reactors.txt' not found. Please run setup.lua to configure reactors.")
end
local valid = validateReactors(listed)
if #valid == 0 then
  error("No valid reactors found in 'reactors.txt'. Each line must be: <transposerAddr> <powerButtonAddr>")
end
reactors = valid

if #reactors > 0 then
  print(string.format("Found %d valid reactor(s) to start.", #reactors))
end

if #args > 0 and args[1] == "start" then
  print("Starting nuclearReactor.lua in background...")
  
  -- Create reactor threads for every configured reactor
  local reactor_threads = {}
  local reactor_logs = {}

  local function tail_print(path, maxLines)
    maxLines = maxLines or 80
    local f = io.open(path, "r")
    if not f then
      print("(no log at " .. tostring(path) .. ")")
      return
    end
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    local start = #lines - maxLines + 1
    if start < 1 then start = 1 end
    for i = start, #lines do print(lines[i]) end
  end

  if #reactors == 0 then
    -- No configuration found, start a single default reactor (old behavior)
    local log = "/home/reactor_1.log"
    reactor_logs[1] = log
    reactor_threads[1] = thread.create(function()
      os.execute(string.format("lua /home/nuclearReactor.lua > %s 2>&1", log))
    end)
    print("Starting default reactor; logs -> " .. log)
  else
    for i, cfg in ipairs(reactors) do
      local log = string.format("/home/reactor_%d.log", i)
      reactor_logs[i] = log
      print(string.format("Starting nuclearReactor.lua for reactor %d (log: %s)...", i, log))
      local cmd
      if cfg.transposer and cfg.powerbutton then
        cmd = string.format("lua /home/nuclearReactor.lua %s %s > %s 2>&1", cfg.transposer, cfg.powerbutton, log)
      elseif cfg.transposer then
        cmd = string.format("lua /home/nuclearReactor.lua %s > %s 2>&1", cfg.transposer, log)
      else
        cmd = string.format("lua /home/nuclearReactor.lua > %s 2>&1", log)
      end
      reactor_threads[i] = thread.create(function()
        os.execute(cmd)
      end)
      -- Stagger starts slightly to avoid contention
      os.sleep(0.2)
    end
  end
  
  local cleanup_thread = thread.create(function()
    event.pull("interrupted")
    print("Interrupt received - initiating AZ5 shutdown...")
  end)
  
  local input_thread = thread.create(function()
    print("Press Enter to stop the reactor...")
    io.read()
    print("User requested shutdown - initiating AZ5 shutdown...")
  end)
  
  local monitor_thread = thread.create(function()
    while true do
      -- If any reactor thread stops, trigger shutdown and show its log tail
      for i, rt in ipairs(reactor_threads) do
        if rt:status() ~= "running" then
          print(string.format("Reactor %d thread no longer running - initiating AZ5 shutdown...", i))
          local log = reactor_logs and reactor_logs[i]
          if log then
            print("--- Last lines of " .. log .. " ---")
            tail_print(log, 80)
            print("--- end log ---")
          end
          return
        end
      end
      os.sleep(0.5)
    end
  end)
  
  -- Wait for any thread to complete
  local finished_thread = thread.waitForAny({cleanup_thread, input_thread, monitor_thread})
  
  -- Kill all reactor threads and helpers
  for _, rt in ipairs(reactor_threads) do
    if rt and rt:status() == "running" then
      rt:kill()
    end
  end
  cleanup_thread:kill()
  input_thread:kill()
  monitor_thread:kill()
  
  -- Run AZ5 emergency shutdown
  os.execute("/home/az5.lua")
  
else
  os.execute("/home/az5.lua")
end