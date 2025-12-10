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
local powerButtonAddress = readAddress("power_button_address.txt")
if not powerButtonAddress then
  error("power_button_address.txt not found. Please run setup.lua first.")
end

-- Read secondary power button address if it exists
local secondaryPowerButtonAddress = readAddress("secondary_power_button_address.txt")

-- Shutdown primary reactor
local reactor_chamber_signal = component.proxy(component.get(powerButtonAddress))
for side = 0, 5 do
  reactor_chamber_signal.setOutput(side, 0)
end

-- Shutdown secondary reactor if configured
if secondaryPowerButtonAddress then
  local secondary_reactor_signal = component.proxy(component.get(secondaryPowerButtonAddress))
  for side = 0, 5 do
    secondary_reactor_signal.setOutput(side, 0)
  end
end

print("AZ5 EMERGENCY SHUTDOWN INITIATED")
-- for i = 1, 5 do computer.beep(1000, 0.6) end
-- computer.beep(1300, 2)
for i = 1, 5 do computer.beep(500, 0.7) computer.beep(750, 0.6)  os.sleep(1) end
computer.beep(1300, 2)


