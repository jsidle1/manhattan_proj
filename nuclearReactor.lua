-- Nuclear Reactor

local component = require('component')
local computer = require('computer')
local sides = require('sides')

--- @alias What { name: string, isDamaged: fun(stack):boolean }

--region SETUP
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

local transposerAddr = readAddress("transposer_address.txt")
if not transposerAddr then
  error("transposer_address.txt not found. Please run setup.lua first.")
end

local powerButtonAddr = readAddress("power_button_address.txt")
if not powerButtonAddr then
  error("power_button_address.txt not found. Please run setup.lua first.")
end

-- Optional power request
local powerRequestAddr = readAddress("power_request_address.txt")

local SIDES = {
  INPUT                         = sides.south,
  OUTPUT                        = sides.north,
  NUCLEAR_REACTOR               = sides.top,
  NUCLEAR_REACTOR_POWER_BUTTON  = sides.top,
}
local ADDRESSES = {
  TRANSPOSER     = transposerAddr,
  POWER_BUTTON   = powerButtonAddr,
  POWER_REQUEST  = powerRequestAddr
}

local coolant_name        = 'gregtech:gt.360k_Helium_Coolantcell'
local fuel_name           = 'gregtech:gt.rodUranium4'
local fuel_depleted_name  = 'gregtech:gt.depletedRodUranium4'

--- coolant cell
--- @type What
local C = {
  name      = coolant_name,
  isDamaged = function(stack)
    return stack.maxDamage - 5 <= stack.damage
  end
}
--- fuel rod
--- @type What
local F = {
  name      = fuel_name,
  isDamaged = function(stack)
    -- Consider depleted rods as damaged
    if stack.name == fuel_depleted_name then
      return true
    end
    return stack.damage == stack.maxDamage
  end
}
--- empty
--- @type What
local E = {
  name      = '',
  isDamaged = function(_)
    return false
  end
}
--- @type What[]
local LAYOUT = {
  C, F, F, F, C, F, F, C, F,
  F, F, C, F, F, F, F, C, F,
  C, F, F, F, F, C, F, F, F,
  F, F, F, C, F, F, F, F, C,
  F, C, F, F, F, F, C, F, F,
  F, C, F, F, C, F, F, F, C,
}
--endregion SETUP

local nuclearPowerButton = component.proxy(component.get(ADDRESSES.POWER_BUTTON))
local transposer = component.proxy(component.get(ADDRESSES.TRANSPOSER))

-- Optional proxy
local power_request = nil
if ADDRESSES.POWER_REQUEST then
  local addr = component.get(ADDRESSES.POWER_REQUEST)
  if addr then
    power_request = component.proxy(addr)
  end
end

local reactor = {
  started         = false,
  inventorySize   = 0,
  --- @type number[]
  damagedSlots    = {},
}

--- @return boolean
function reactor:initializationCheck()
  self.inventorySize = transposer.getInventorySize(SIDES.NUCLEAR_REACTOR)
  print("Inventory size: " .. self.inventorySize .. ", Expected: " .. #LAYOUT)
  if self.inventorySize ~= #LAYOUT then
    print("ERROR: Inventory size mismatch!")
    return false
  end
  for slot = 1, self.inventorySize do
    local preset = LAYOUT[slot]
    local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
    print("Slot " .. slot .. ": Expected=" .. (preset.name or "empty") .. ", Got=" .. (stack and stack.name or "empty"))
    if preset.name == '' and stack ~= nil then
      print("ERROR: Slot " .. slot .. " should be empty but contains " .. stack.name)
      return false
    end
    if preset.name ~= '' then
      if stack == nil then
        print("ERROR: Slot " .. slot .. " is empty but should contain " .. preset.name)
        return false
      end
      -- For fuel rods, accept both normal and depleted
      if preset == F then
        if stack.name ~= fuel_name and stack.name ~= fuel_depleted_name then
          print("ERROR: Slot " .. slot .. " contains " .. stack.name .. " but should contain " .. F.name .. " or " .. F.depleted_name)
          return false
        end
      else
        if stack.name ~= preset.name then
          print("ERROR: Slot " .. slot .. " contains " .. stack.name .. " but should contain " .. preset.name)
          return false
        end
      end
    end
  end
  print("Initialization check passed!")
  return true
end

function reactor:start()
  if not self.started then
    nuclearPowerButton.setOutput(SIDES.NUCLEAR_REACTOR_POWER_BUTTON, 15)
    self.started = true
  end
end

function reactor:stop()
  if self.started then
    nuclearPowerButton.setOutput(SIDES.NUCLEAR_REACTOR_POWER_BUTTON, 0)
    self.started = false
  end
end

--- @param what What
--- @return number slot
function reactor:findInput(what)
  while true do
    local found = nil
    local slot = 1
    local stacksIterator = transposer.getAllStacks(SIDES.INPUT)
    for stack in stacksIterator do
      if stack.name == what then
        found = slot
      end
      slot = slot + 1
    end
    if found then
      return found
    end
    os.sleep(5)
  end
end

function reactor:discharge()
  for _, slot in ipairs(self.damagedSlots) do
    while transposer.getSlotStackSize(SIDES.NUCLEAR_REACTOR, slot) ~= 0 do
      -- output is blocked, waiting
      if transposer.transferItem(SIDES.NUCLEAR_REACTOR, SIDES.OUTPUT, 1, slot) == 0 then
        print("Output is blocked, waiting to discharge slot " .. slot .. "...")
        os.sleep(5)
      end
    end
  end
end

function reactor:load()
  while #self.damagedSlots > 0 do
    local slot = self.damagedSlots[1]
    local what = LAYOUT[slot]
    local inputSlot = self:findInput(what.name)
    transposer.transferItem(SIDES.INPUT, SIDES.NUCLEAR_REACTOR, 1, inputSlot, slot)
    table.remove(self.damagedSlots, 1)
  end
end

--- @return boolean
function reactor:hasDamaged()
  for slot = 1, self.inventorySize do
    local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
    if stack and LAYOUT[slot].isDamaged(stack) then
      return true
    end
  end
  return false
end

function reactor:ensure()
  if not self:hasDamaged() then
    return
  end

  self:stop()
  os.sleep(1)

  for slot = 1, self.inventorySize do
    local stack = transposer.getStackInSlot(SIDES.NUCLEAR_REACTOR, slot)
    if stack and LAYOUT[slot].isDamaged(stack) then
      table.insert(self.damagedSlots, slot)
    end
  end

  self:discharge()
  self:load()
end

-- Skip if power_request unavailable
function reactor:wait_for_power_request()
  if not power_request then
    return
  end

  while true do
    local inputs = power_request.getInput()
    local triggered = false

    for i = 0, #inputs - 1 do
      if inputs[i] == 15 then
        triggered = true
        break
      end
    end

    if triggered then
      break
    end
    self:stop()

    os.sleep(1)
  end
end

function reactor:loop()
  self:wait_for_power_request()
  self:ensure()
  computer.beep(50, 0.1)
  if not self.started then
    self:start()
  end
end

function reactor:run()
  self:stop()
  print("[RUN] Starting initialization check...")
  if not self:initializationCheck() then
    print("[RUN] FATAL: Initialization failed!")
    for _ = 1, 3 do
      computer.beep('.')
      os.sleep(1)
    end
    return
  end
  print("[RUN] Initialization successful! Starting reactor loop...")
  while true do
    self:loop()
    os.sleep(0.25)
  end
end

function start()
  reactor:run()
end

start()
