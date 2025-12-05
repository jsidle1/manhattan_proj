-- Function to turn the reactor_chamber component off

component = require("component")
shell = require("shell")
local computer = require('computer')

local powerButtonFile = io.open("power_button_address.txt", "r")
if not powerButtonFile then
  error("power_button_address.txt not found. Please run setup.lua first.")
end
local powerButtonAddress = powerButtonFile:read("*a"):match("^%s*(.-)%s*$")
powerButtonFile:close()

if not powerButtonAddress or powerButtonAddress == '' then
  error("POWER_BUTTON address not configured. Please run setup.lua first.")
end

reactor_chamber_signal = component.proxy(component.get(powerButtonAddress))

for side = 0, 5 do
  reactor_chamber_signal.setOutput(side, 0)
end

print("AZ5 EMERGENCY SHUTDOWN INITIATED")
-- for i = 1, 5 do computer.beep(1000, 0.6) end
-- computer.beep(1300, 2)
for i = 1, 5 do computer.beep(500, 0.7) computer.beep(750, 0.6)  os.sleep(1) end
computer.beep(1300, 2)


