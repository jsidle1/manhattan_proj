local fs = require("filesystem")
local shell = require('shell')
local internet = require('internet')
local json = require('json')

local args = {...}
local branch = args[1] or 'main'
local repo = args[2] or 'jsidle1/manhattan_proj'

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
    
    io.write("How many reactors do you want to configure? (1): ")
    local n = tonumber(io.read()) or 1

    io.write("Enter POWER_REQUEST address (optional, press Enter to skip): ")
    local powerRequestAddr = io.read()
    if powerRequestAddr == "" then powerRequestAddr = nil end

    local reactors = {}
    for i = 1, n do
        print(string.format("\n--- REACTOR %d ---", i))
        io.write("Enter TRANSPOSER address: ")
        local t = io.read()
        io.write("Enter POWER_BUTTON address: ")
        local p = io.read()
        table.insert(reactors, {t = t, p = p})
    end

    -- Write reactors list file (one reactor per line: <transposer> <powerbutton>)
    local rf = io.open("reactors.txt", "w")
    if rf then
        for _, r in ipairs(reactors) do
            rf:write((r.t or "") .. " " .. (r.p or "") .. "\n")
        end
        rf:close()
    else
        print("ERROR: Could not write reactors.txt")
        return false
    end

    -- Note: we only use 'reactors.txt' now. Legacy single-address files are not written anymore.
    local first = reactors[1]

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

    print("\nConfiguration saved.")
    return true
end

local reactorsFile = io.open("reactors.txt", "r")
if reactorsFile then
    reactorsFile:close()
    io.write("\nConfig file 'reactors.txt' already exists. Reconfigure? (y/n): ")
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