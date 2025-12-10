local shell = require("shell")
local thread = require("thread")
local event = require("event")

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
local secondaryTransposer = readAddress("secondary_transposer_address.txt")
local secondaryPowerButton = readAddress("secondary_power_button_address.txt")
local hasSecondaryReactor = secondaryTransposer and secondaryPowerButton

if #args > 0 and args[1] == "start" then
  print("Starting nuclearReactor.lua in background...")
  
  -- Create primary reactor thread
  local reactor_thread = thread.create(function()
    os.execute("/home/nuclearReactor.lua")
  end)
  
  -- Create secondary reactor thread if configured
  local secondary_reactor_thread = nil
  if hasSecondaryReactor then
    print("Starting secondary nuclearReactor.lua in background...")
    secondary_reactor_thread = thread.create(function()
      -- Pass addresses as command-line arguments to the reactor script
      local cmd = string.format("/home/nuclearReactor.lua %s %s", secondaryTransposer, secondaryPowerButton)
      os.execute(cmd)
    end)
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
      if reactor_thread:status() ~= "running" then
        print("Reactor thread no longer running - initiating AZ5 shutdown...")
        break
      end
      if secondary_reactor_thread and secondary_reactor_thread:status() ~= "running" then
        print("Secondary reactor thread no longer running - initiating AZ5 shutdown...")
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
  if secondary_reactor_thread and secondary_reactor_thread:status() == "running" then
    secondary_reactor_thread:kill()
  end
  cleanup_thread:kill()
  input_thread:kill()
  monitor_thread:kill()
  
  -- Run AZ5 emergency shutdown
  os.execute("/home/az5.lua")
  
else
  os.execute("/home/az5.lua")
end