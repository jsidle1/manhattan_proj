-- Function to turn the reactor_chamber component off

component = require("component")
shell = require("shell")
local computer = require('computer')

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

-- Read primary power button address
-- Attempt to read a reactors list first (reactors.txt)
local function readReactorsList(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local list = {}
  for line in f:lines() do
    local cleaned = line:match("^%s*(.-)%s*$")
    if cleaned ~= "" then
      local taddr, paddr = cleaned:match('^(%S+)%s+(%S+)')
      if paddr then
        table.insert(list, paddr)
      else
        -- If only one token present, assume it's the power button
        table.insert(list, cleaned)
      end
    end
  end
  f:close()
  return #list > 0 and list or nil
end

local powerButtons = readReactorsList("reactors.txt")
if not powerButtons then
  error("Configuration file 'reactors.txt' not found. Please run setup.lua to configure reactors.")
end

-- Shutdown every configured power button
for i, addr in ipairs(powerButtons) do
  local ok, proxyOrErr = pcall(component.get, addr)
  if not ok or not proxyOrErr then
    print(string.format("Warning: power button address '%s' not found (reactor %d). Skipping.", tostring(addr), i))
  else
    local success, proxy = pcall(component.proxy, proxyOrErr)
    if success and proxy then
      for side = 0, 5 do
        proxy.setOutput(side, 0)
      end
      print(string.format("Shutdown signal sent to reactor %d (power button %s)", i, tostring(addr)))
    else
      print(string.format("Warning: could not proxy component %s for reactor %d", tostring(addr), i))
    end
  end
end

print("AZ5 EMERGENCY SHUTDOWN INITIATED")
-- for i = 1, 5 do computer.beep(1000, 0.6) end
-- computer.beep(1300, 2)
for i = 1, 5 do computer.beep(500, 0.7) computer.beep(750, 0.6)  os.sleep(1) end
computer.beep(1300, 2)


