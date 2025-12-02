-- If start is given as arg, run nuclearReactor.lua in a separate process with interrupt handling.
-- Monitors thread status and handles soft interrupts (^C) to trigger AZ5 emergency shutdown.
local shell = require("shell")
local thread = require("thread")
local event = require("event")

local args, options = shell.parse(...)

if #args > 0 and args[1] == "start" then
  print("Starting nuclearReactor.lua in background...")
  local reactor_thread = thread.create(os.execute, "/home/nuclearReactor.lua")
  
  local cleanup_thread = thread.create(function()
    event.pull("interrupted")
    print("Interrupt received - initiating AZ5 shutdown...")
  end)
  
  local monitor_thread = thread.create(function()
    while true do
      if reactor_thread:status() ~= "running" then
        print("Reactor thread no longer running - initiating AZ5 shutdown...")
        break
      end
      os.sleep(0.5) -- Check every 500ms
    end
  end)
  
  -- Wait for either cleanup or monitor to trigger shutdown
  local finished_thread = thread.waitForAny({cleanup_thread, monitor_thread})
  
  -- Kill reactor thread if still running
  if reactor_thread:status() == "running" then
    reactor_thread:kill()
  end
  
  -- Run AZ5 emergency shutdown
  os.execute("/home/az5.lua")
  
else
  os.execute("/home/az5.lua")
end