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
print("Clearing existing files...")
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

-- Copy az5 to lib/az5.lua
shell.execute("cp az5.lua lib/az5.lua")
print("Setup complete.")