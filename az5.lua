-- Function to turn the reactor_chamber component off

component = require("component")
shell = require("shell")
local computer = require('computer')

reactor_chamber_signal = component.proxy(component.get("56ec984d-8790-41f2-8305-d1014789c889"))

for side = 0, 5 do
  reactor_chamber_signal.setOutput(side, 0)
end

print("AZ5 EMERGENCY SHUTDOWN INITIATED")
for i = 1, 5 do computer.beep(1000, 0.6) end
computer.beep(1300, 2)

