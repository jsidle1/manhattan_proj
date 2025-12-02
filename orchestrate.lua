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
  
  local input_thread = thread.create(function()
    print("Press Enter to stop the reactor...")
    io.read()
    print("User requested shutdown - initiating AZ5 shutdown...")
  end)
  
  local monitor_thread = thread.create(function()
    while true do
      if reactor_thread:status() ~= "running" then
        print("Reactor thread no longer running - initiating AZ5 shutdown...")
        break
      end
      os.sleep(0.5)
    end
  end)
  
  -- Wait for any thread to complete
  local finished_thread = thread.waitForAny({cleanup_thread, input_thread, monitor_thread})
  
  -- Kill all other threads
  if reactor_thread:status() == "running" then
    reactor_thread:kill()
  end
  cleanup_thread:kill()
  input_thread:kill()
  monitor_thread:kill()
  
  -- Run AZ5 emergency shutdown
  os.execute("/home/az5.lua")
  
else
  os.execute("/home/az5.lua")
end