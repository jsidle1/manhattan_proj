-- Nuclear Reactor

local component = require('component')
local computer = require('computer')
local sides = require('sides')

--- @alias What { name: string, isDamaged: fun(stack):boolean }

--region SETUP
local SIDES = {
  INPUT                    = sides.west,
  OUTPUT                   = sides.east,
  NUCLEAR_REACTOR          = sides.bottom,
  NUCLEAR_REACTOR_POWER_BUTTON = sides.bottom,
}
local ADDRESSES = {
  TRANSPOSER = 'e589e3a5-a8fb-4895-ad80-ed19c7f9a78e',
  POWER_BUTTON   = '56ec984d-8790-41f2-8305-d1014789c889'
}
--- coolant cell
--- @type What
local C = {
  name      = 'gregtech:gt.360k_Helium_Coolantcell',
  isDamaged = function(stack)
    return stack.maxDamage - 5 <= stack.damage
  end
}
--- fuel rod
--- @type What
local F = {
  name      = 'gregtech:gt.rodUranium4',
  isDamaged = function(stack)
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
      if stack.name ~= preset.name then
        print("ERROR: Slot " .. slot .. " contains " .. stack.name .. " but should contain " .. preset.name)
        return false
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

function reactor:loop()
  self:ensure()
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