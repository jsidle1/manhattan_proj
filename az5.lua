-- Function to turn the reactor_chamber component off

component = require("component")
shell = require("shell")

reactor_chamber_signal = component.proxy(component.get("56ec984d-8790-41f2-8305-d1014789c889"))

for side = 0, 5 do
  reactor_chamber_signal.setOutput(side, 0)
end
