local fs = require("filesystem")
local shell = require('shell')
local internet = require('internet')
local json = require('json')

local args = {...}
local branch = args[1] or 'main'
local repo = args[2] or 'JosephKan3/manhattan_proj'

local function getFileList(repository, branchName)
    local url = string.format("https://api.github.com/repos/%s/contents/?ref=%s", repository, branchName)
    local handle = internet.request(url)
    if not handle then
        error("HTTP request failed")
    end

    local data = ""
    for chunk in handle do data = data .. chunk end
    return json.decode(data)
end

-- Delete all files from current directory to update them
print("\nClearing existing files...")
shell.execute("rm -r *")
print("Fetching files from repository...")

local files = getFileList(repo, branch)

for _, file in ipairs(files) do
    if file.type == "file" and file.name:match("%.lua$") then
        shell.execute(string.format(
            "wget -f https://raw.githubusercontent.com/%s/%s/%s",
            repo,
            branch,
            file.path
        ))
    end
end


-- Configure hardware addresses
local function setupConfig()
    print("\n=== Hardware Configuration ===")
    print("Please provide the hardware addresses for your system.")
    
    -- Primary reactor configuration
    print("\n--- PRIMARY REACTOR ---")
    io.write("Enter TRANSPOSER address: ")
    local transposerAddr = io.read()
    
    io.write("Enter POWER_BUTTON address: ")
    local powerButtonAddr = io.read()

    io.write("Enter POWER_REQUEST address (optional, press Enter to skip): ")
    local powerRequestAddr = io.read()
    if powerRequestAddr == "" then powerRequestAddr = nil end

    -- Secondary reactor configuration
    print("\n--- SECONDARY REACTOR (optional, press Enter to skip) ---")
    io.write("Enter secondary TRANSPOSER address (optional): ")
    local secondaryTransposerAddr = io.read()
    if secondaryTransposerAddr == "" then secondaryTransposerAddr = nil end
    
    io.write("Enter secondary POWER_BUTTON address (optional): ")
    local secondaryPowerButtonAddr = io.read()
    if secondaryPowerButtonAddr == "" then secondaryPowerButtonAddr = nil end

    -- Write primary transposer address
    local transposerFile = io.open("transposer_address.txt", "w")
    if transposerFile then
        transposerFile:write(transposerAddr)
        transposerFile:close()
    else
        print("ERROR: Could not write transposer_address.txt")
        return false
    end
    
    -- Write primary power button address
    local powerButtonFile = io.open("power_button_address.txt", "w")
    if powerButtonFile then
        powerButtonFile:write(powerButtonAddr)
        powerButtonFile:close()
    else
        print("ERROR: Could not write power_button_address.txt")
        return false
    end

    -- Write optional power request address
    if powerRequestAddr then
        local powerRequestFile = io.open("power_request_address.txt", "w")
        if powerRequestFile then
            powerRequestFile:write(powerRequestAddr)
            powerRequestFile:close()
        else
            print("ERROR: Could not write power_request_address.txt")
            return false
        end
    end

    -- Write secondary transposer address if provided
    if secondaryTransposerAddr then
        local secondaryTransposerFile = io.open("secondary_transposer_address.txt", "w")
        if secondaryTransposerFile then
            secondaryTransposerFile:write(secondaryTransposerAddr)
            secondaryTransposerFile:close()
        else
            print("ERROR: Could not write secondary_transposer_address.txt")
            return false
        end
    end

    -- Write secondary power button address if provided
    if secondaryPowerButtonAddr then
        local secondaryPowerButtonFile = io.open("secondary_power_button_address.txt", "w")
        if secondaryPowerButtonFile then
            secondaryPowerButtonFile:write(secondaryPowerButtonAddr)
            secondaryPowerButtonFile:close()
        else
            print("ERROR: Could not write secondary_power_button_address.txt")
            return false
        end
    end
    
    print("\nConfiguration saved.")
    return true
end

-- Check if config already exists
local transposerFile = io.open("transposer_address.txt", "r")
if transposerFile then
    transposerFile:close()
    io.write("\nConfig files already exist. Reconfigure? (y/n): ")
    local response = io.read()
    if response:lower() == "y" then
        setupConfig()
    end
else
    setupConfig()
end

-- Copy az5 to lib/az5.lua
shell.execute("cp az5.lua lib/az5.lua")

-- Add /home/orchestrate.lua to /home/.shrc to run on startup
local shrcPath = "/home/.shrc"
local shrcFile = io.open(shrcPath, "a")
if shrcFile then
    for line in io.lines(shrcPath) do
        if line:match("orchestrate.lua") then
            shrcFile:close()
            print("Setup complete.")
            return
        end
    end
    shrcFile:write("\n/home/orchestrate.lua\n")
    shrcFile:close()
else
    shrcFile = io.open(shrcPath, "w")
    shrcFile:write("/home/orchestrate.lua\n")
    shrcFile:close()
end
print("Setup complete.")

local files = getFileList(repo, branch)

for _, file in ipairs(files) do
    if file.type == "file" and file.name:match("%.lua$") then
        shell.execute(string.format(
            "wget -f https://raw.githubusercontent.com/%s/%s/%s",
            repo,
            branch,
            file.path
        ))
    end
end

-- Copy az5 to lib/az5.lua
shell.execute("cp az5.lua lib/az5.lua")

-- Add /home/orchestrate.lua to /home/.shrc to run on startup
local shrcPath = "/home/.shrc"
local shrcFile = io.open(shrcPath, "a")
if shrcFile then
    for line in io.lines(shrcPath) do
        if line:match("orchestrate.lua") then
            shrcFile:close()
            print("Setup complete.")
            return
        end
    end
    shrcFile:write("\n/home/orchestrate.lua\n")
    shrcFile:close()
else
    shrcFile = io.open(shrcPath, "w")
    shrcFile:write("/home/orchestrate.lua\n")
    shrcFile:close()
end
print("Setup complete.")