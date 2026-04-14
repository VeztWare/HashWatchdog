--[[
    Owner: _vezt (! hamza)
    Idea: a way to snapshot and differentiate script hashes in a game, useful for detecting changes after updates for security monitoring.
    Credits:
        - chadhyatt (LuaEncode library)
        - Claude (UI design)
    ! You are allowed to use and modify this code, although giving credit is appreciated. Do not remove this comment.
]]

local Watchdog = {
    Hashes = {},
    StartingExclusions = {
        CorePackages = true,
        CoreGui = true,
        Chat = true
    },
    EndingExclusions = {
        Animate = true,
    },
    WildcardTokens = {
        { token = "[WTD_WILDCARD_NAME]",        getValue = function() return game:GetService("Players").LocalPlayer.Name end },
        { token = "[WTD_WILDCARD_DISPLAYNAME]", getValue = function() return game:GetService("Players").LocalPlayer.DisplayName end },
    },
    Beautifier = loadstring(game:HttpGet("https://raw.githubusercontent.com/chadhyatt/LuaEncode/refs/heads/master/src/LuaEncode.lua"))()
}

if not isfolder("Watchdog_Saves") then
    makefolder("Watchdog_Saves")
end

function Watchdog:NormalizePath(fullName)
    local segments = {}
    for seg in string.gmatch(fullName, "[^%.]+") do
        table.insert(segments, seg)
    end

    for i, seg in ipairs(segments) do
        for _, rule in ipairs(self.WildcardTokens) do
            if seg == rule.getValue() then
                segments[i] = rule.token
                break
            end
        end
    end

    return table.concat(segments, ".")
end

function Watchdog:DenormalizePath(normalizedName)
    local result = normalizedName
    for _, rule in ipairs(self.WildcardTokens) do
        local escapedToken = rule.token:gsub("[%[%]]", "%%%1")
        result = result:gsub(escapedToken, rule.getValue())
    end
    return result
end


function Watchdog:Sanitize(module)
    local fullName = module:GetFullName()
    local root = string.match(fullName, "^[^%.]+")

    if self.StartingExclusions[root] then
        return false
    end

    for segment in string.gmatch(fullName, "[^%.]+") do
        if self.EndingExclusions[segment] then
            return false
        end
    end

    return true
end

function Watchdog:SanitizeName(str)
    str = str:gsub("[^\x20-\x7E]", "")
    str = str:gsub("[%.%/%\\%:%*%?%\"%<%>%|]", "_")
    str = str:gsub("%s+", "_")
    str = str:gsub("[^%w_]", "")
    return str
end

function Watchdog:CheckValidBytecode(module)
    local suc, bytecode = pcall(function()
        return getscriptbytecode(module)
    end)
    if bytecode == nil then
        return ""
    end
    if bytecode ~= nil and #bytecode <= 1 then
        return ""
    end
    return "valid"
end

function Watchdog:SaveHashes()
    self.Hashes = {}
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("ModuleScript") or v:IsA("LocalScript") or (v:IsA("Script") and #self:CheckValidBytecode(v) > 1) then
            if not self:Sanitize(v) then continue end
            local normalized = self:NormalizePath(v:GetFullName())
            self.Hashes[normalized] = getscripthash(v)
        end
    end
    writefile(
        "Watchdog_Saves/" .. game.PlaceId .. "_Hash_[" .. os.date("%d_%m_%Y(%H_%M_%S)") .. "].txt",
        "return " .. self.Beautifier(self.Hashes, { Prettify = true, FunctionsReturnRaw = true })
    )
end

function Watchdog:CheckChanges(file)
    if #listfiles("Watchdog_Saves") == 0 then
        warn("No hash file found. Run SaveHashes first.")
        return
    end

    
    local rawOldData = loadstring(readfile(file))()
    local oldData = {}
    for path, hash in pairs(rawOldData) do
        oldData[self:DenormalizePath(path)] = hash
    end

    local newData = {}
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("ModuleScript") or v:IsA("LocalScript") or (v:IsA("Script") and #self:CheckValidBytecode(v) > 1) then
            if not self:Sanitize(v) then continue end
            local key = self:DenormalizePath(self:NormalizePath(v:GetFullName()))
            newData[key] = getscripthash(v)
        end
    end

    return oldData, newData
end


local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PlayerGui        = game:WaitForChild("CoreGui")

local C = {
    BG       = Color3.fromHex("#0d0f14"),
    Panel    = Color3.fromHex("#13161e"),
    Border   = Color3.fromHex("#1e2130"),
    Accent   = Color3.fromHex("#4f8ef7"),
    Add      = Color3.fromHex("#3dd68c"),
    Remove   = Color3.fromHex("#f75f5f"),
    Change   = Color3.fromHex("#f7b73d"),
    Text     = Color3.fromHex("#d4daf0"),
    Subtext  = Color3.fromHex("#5a6080"),
    Button   = Color3.fromHex("#1c2030"),
    ButtonHov= Color3.fromHex("#252a3a"),
    Header   = Color3.fromHex("#0a0c10"),
}

local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

local function corner(radius, parent)
    return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(color, thickness, parent)
    return make("UIStroke", { Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local ScreenGui = make("ScreenGui", {
    Name = "WatchdogUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

local Main = make("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 440, 0, 540),
    Position = UDim2.new(0.5, -220, 0.5, -270),
    BackgroundColor3 = C.BG,
    BorderSizePixel = 0,
}, ScreenGui)
corner(10, Main)
stroke(C.Border, 1.5, Main)

local Shadow = make("Frame", {
    Name = "Shadow",
    Size = UDim2.new(1, 20, 1, 20),
    Position = UDim2.new(0, -10, 0, 8),
    BackgroundColor3 = Color3.fromHex("#000000"),
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    ZIndex = 0,
}, Main)
corner(14, Shadow)

local TitleBar = make("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = C.Header,
    BorderSizePixel = 0,
}, Main)
corner(10, TitleBar)

make("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 1, -10),
    BackgroundColor3 = C.Header,
    BorderSizePixel = 0,
}, TitleBar)

make("Frame", {
    Size = UDim2.new(0, 3, 0, 22),
    Position = UDim2.new(0, 12, 0.5, -11),
    BackgroundColor3 = C.Accent,
    BorderSizePixel = 0,
}, TitleBar)
corner(2, TitleBar:FindFirstChild("Frame"))

make("TextLabel", {
    Size = UDim2.new(1, -80, 1, 0),
    Position = UDim2.new(0, 22, 0, 0),
    BackgroundTransparency = 1,
    Text = "WATCHDOG",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = C.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TitleBar)

make("TextLabel", {
    Size = UDim2.new(0, 60, 1, 0),
    Position = UDim2.new(1, -70, 0, 0),
    BackgroundTransparency = 1,
    Text = "v1.0",
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = C.Subtext,
    TextXAlignment = Enum.TextXAlignment.Right,
}, TitleBar)

local CloseBtn = make("TextButton", {
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -36, 0.5, -14),
    BackgroundColor3 = Color3.fromHex("#2a1820"),
    Text = "❌",
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = C.Remove,
    BorderSizePixel = 0,
}, TitleBar)
corner(6, CloseBtn)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local Body = make("Frame", {
    Name = "Body",
    Size = UDim2.new(1, -24, 1, -54),
    Position = UDim2.new(0, 12, 0, 48),
    BackgroundTransparency = 1,
}, Main)

local function sectionLabel(text, yOffset, parent)
    return make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.new(0, 0, 0, yOffset),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = C.Subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

sectionLabel("SNAPSHOT", 0, Body)

local SaveBtn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 38),
    Position = UDim2.new(0, 0, 0, 20),
    BackgroundColor3 = C.Button,
    Text = "",
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, Body)
corner(8, SaveBtn)
stroke(C.Border, 1, SaveBtn)

make("TextLabel", {
    Size = UDim2.new(1, -14, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "💾  Save Current Hashes",
    Font = Enum.Font.GothamMedium,
    TextSize = 13,
    TextColor3 = C.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, SaveBtn)

local SaveStatus = make("TextLabel", {
    Size = UDim2.new(0, 100, 1, 0),
    Position = UDim2.new(1, -110, 0, 0),
    BackgroundTransparency = 1,
    Text = "",
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = C.Add,
    TextXAlignment = Enum.TextXAlignment.Right,
}, SaveBtn)

sectionLabel("SELECT HASH FILE", 72, Body)

local FileRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    Position = UDim2.new(0, 0, 0, 92),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
}, Body)
corner(8, FileRow)
stroke(C.Border, 1, FileRow)

local FileDropdown = make("TextButton", {
    Size = UDim2.new(1, -100, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    Text = "  No file selected",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = C.Subtext,
    TextXAlignment = Enum.TextXAlignment.Left,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, FileRow)

local RefreshBtn = make("TextButton", {
    Size = UDim2.new(0, 90, 0, 28),
    Position = UDim2.new(1, -96, 0.5, -14),
    BackgroundColor3 = Color3.fromHex("#1a2035"),
    Text = "🔄  Refresh",
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    TextColor3 = C.Accent,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, FileRow)
corner(6, RefreshBtn)

local DropList = make("Frame", {
    Name = "DropList",
    Size = UDim2.new(1, 0, 0, 0),
    Position = UDim2.new(0, 0, 0, 134),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 50,
    Visible = false,
}, Body)
corner(8, DropList)
stroke(C.Border, 1, DropList)

local DropScroll = make("ScrollingFrame", {
    Size = UDim2.new(1, -4, 1, -4),
    Position = UDim2.new(0, 2, 0, 2),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 51,
}, DropList)

make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2),
}, DropScroll)

local selectedFile = nil
local dropOpen = false

local function closeDropdown()
    dropOpen = false
    TweenService:Create(DropList, TweenInfo.new(0.15), { Size = UDim2.new(1, 0, 0, 0) }):Play()
    task.delay(0.16, function() DropList.Visible = false end)
end

local function populateDropdown()
    for _, c in pairs(DropScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local files = listfiles("Watchdog_Saves")
    if #files == 0 then
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            Text = "No saved files found",
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = C.Subtext,
            ZIndex = 52,
        }, DropScroll)
        DropScroll.CanvasSize = UDim2.new(0, 0, 0, 34)
        return
    end
    local totalH = 0
    for _, f in ipairs(files) do
        local name = string.match(f, "([^/\\]+)$") or f
        local btn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = C.Button,
            Text = "  " .. name,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = C.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 52,
        }, DropScroll)
        corner(5, btn)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = C.ButtonHov }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = C.Button }):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            selectedFile = f
            FileDropdown.Text = "  " .. name
            FileDropdown.TextColor3 = C.Text
            closeDropdown()
        end)
        totalH = totalH + 34
    end
    DropScroll.CanvasSize = UDim2.new(0, 0, 0, totalH)
end

FileDropdown.MouseButton1Click:Connect(function()
    if dropOpen then
        closeDropdown()
    else
        populateDropdown()
        dropOpen = true
        DropList.Visible = true
        local itemCount = math.min(#listfiles("Watchdog_Saves"), 4)
        local targetH = math.max(itemCount, 1) * 34 + 4
        TweenService:Create(DropList, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {
            Size = UDim2.new(1, 0, 0, targetH)
        }):Play()
    end
end)

RefreshBtn.MouseButton1Click:Connect(function()
    populateDropdown()
    dropOpen = true
    DropList.Visible = true
    local itemCount = math.min(#listfiles("Watchdog_Saves"), 4)
    local targetH = math.max(itemCount, 1) * 34 + 4
    TweenService:Create(DropList, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {
        Size = UDim2.new(1, 0, 0, targetH)
    }):Play()
end)

local CheckBtn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 38),
    Position = UDim2.new(0, 0, 0, 144),
    BackgroundColor3 = Color3.fromHex("#0f1e38"),
    Text = "",
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, Body)
corner(8, CheckBtn)
stroke(C.Accent, 1, CheckBtn)

make("TextLabel", {
    Size = UDim2.new(1, -14, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "🔃  Run Diff Against Selected File",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextColor3 = C.Accent,
    TextXAlignment = Enum.TextXAlignment.Left,
}, CheckBtn)

sectionLabel("RESULTS", 196, Body)

local StatsRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    Position = UDim2.new(0, 0, 0, 214),
    BackgroundTransparency = 1,
}, Body)

local function statBadge(color, label, xPos)
    local badge = make("Frame", {
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(0, xPos, 0, 0),
        BackgroundColor3 = color:Lerp(C.BG, 0.82),
        BorderSizePixel = 0,
    }, StatsRow)
    corner(6, badge)
    stroke(color:Lerp(C.BG, 0.4), 1, badge)
    local txt = make("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = label .. ": 0",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = color,
    }, badge)
    return txt
end

local AddCount    = statBadge(C.Add,    "  ＋ Added",   0)
local RemoveCount = statBadge(C.Remove, "  － Removed", 126)
local ChangeCount = statBadge(C.Change, "  ！ Changed", 252)

local ResultScroll = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 220),
    Position = UDim2.new(0, 0, 0, 248),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.Accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, Body)
corner(8, ResultScroll)
stroke(C.Border, 1, ResultScroll)

make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2),
}, ResultScroll)
make("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, ResultScroll)

local EmptyLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
    Text = "Run a diff to see changes here",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = C.Subtext,
}, ResultScroll)

local function clearResults()
    for _, c in pairs(ResultScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    EmptyLabel.Visible = true
    AddCount.Text    = "  ＋ Added: 0"
    RemoveCount.Text = "  － Removed: 0"
    ChangeCount.Text = "  ！ Changed: 0"
    ResultScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
end

local function clipToast(row, color)
    local toast = make("TextLabel", {
        Size = UDim2.new(0, 64, 0, 20),
        Position = UDim2.new(1, -70, 0.5, -10),
        BackgroundColor3 = color:Lerp(Color3.fromHex("#000000"), 0.5),
        BackgroundTransparency = 0.3,
        Text = "Copied!",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = color,
        BorderSizePixel = 0,
        ZIndex = row.ZIndex + 2,
    }, row)
    corner(4, toast)
    task.delay(1, function()
        TweenService:Create(toast, TweenInfo.new(0.3), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
        }):Play()
        task.delay(0.35, function() toast:Destroy() end)
    end)
end

local SORT_GROUP = { add = 1, change = 2, remove = 3 }

local function addResult(kind, color, path, groupIndex)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = color:Lerp(C.Panel, 0.88),
        BorderSizePixel = 0,
        LayoutOrder = SORT_GROUP[kind] * 100000 + groupIndex,
    }, ResultScroll)
    corner(5, row)
    stroke(color:Lerp(C.Panel, 0.5), 1, row)

    local symbol = kind == "add" and "[+]" or kind == "change" and "[!]" or "[-]"

    make("TextLabel", {
        Size = UDim2.new(0, 22, 1, 0),
        Position = UDim2.new(0, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = symbol,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = color,
    }, row)

    make("TextLabel", {
        Size = UDim2.new(1, -34, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        BackgroundTransparency = 1,
        Text = path,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = C.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)

    local clickArea = make("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        BorderSizePixel = 0,
        ZIndex = row.ZIndex + 1,
    }, row)
    clickArea.MouseButton1Click:Connect(function()
        setclipboard(path)
        clipToast(row, color)
    end)

    return row
end


SaveBtn.MouseEnter:Connect(function()
    TweenService:Create(SaveBtn, TweenInfo.new(0.12), { BackgroundColor3 = C.ButtonHov }):Play()
end)
SaveBtn.MouseLeave:Connect(function()
    TweenService:Create(SaveBtn, TweenInfo.new(0.12), { BackgroundColor3 = C.Button }):Play()
end)
SaveBtn.MouseButton1Click:Connect(function()
    SaveStatus.Text = "Saving..."
    SaveStatus.TextColor3 = C.Subtext
    task.spawn(function()
        Watchdog:SaveHashes()
        SaveStatus.Text = "✅ Saved"
        SaveStatus.TextColor3 = C.Add
        task.delay(2.5, function() SaveStatus.Text = "" end)
    end)
end)

CheckBtn.MouseEnter:Connect(function()
    TweenService:Create(CheckBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromHex("#152845") }):Play()
end)
CheckBtn.MouseLeave:Connect(function()
    TweenService:Create(CheckBtn, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromHex("#0f1e38") }):Play()
end)

CheckBtn.MouseButton1Click:Connect(function()
    if not selectedFile then
        local s = stroke(C.Remove, 1.5, FileRow)
        task.delay(1.2, function() s:Destroy(); stroke(C.Border, 1, FileRow) end)
        return
    end
    clearResults()
    EmptyLabel.Visible = false

    task.spawn(function()
        local oldData, newData
        local ok, err = pcall(function()
            oldData, newData = Watchdog:CheckChanges(selectedFile)
        end)
        if not ok or not oldData or not newData then
            local row = make("Frame", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = C.Remove:Lerp(C.Panel, 0.88),
                BorderSizePixel = 0,
            }, ResultScroll)
            corner(5, row)
            make("TextLabel", {
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = ok and "No hash data found. Save hashes first." or tostring(err),
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = C.Remove,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)
            ResultScroll.CanvasSize = UDim2.new(0, 0, 0, 42)
            return
        end

        local buckets = { add = {}, change = {}, remove = {} }

        for path, hash in pairs(newData) do
            if not oldData[path] then
                table.insert(buckets.add, path)
            elseif oldData[path] ~= hash then
                table.insert(buckets.change, path)
            end
        end
        for path in pairs(oldData) do
            if not newData[path] then
                table.insert(buckets.remove, path)
            end
        end

        table.sort(buckets.add)
        table.sort(buckets.change)
        table.sort(buckets.remove)

        local totalH = 0
        for i, path in ipairs(buckets.add)    do addResult("add",    C.Add,    path, i) totalH += 32 end
        for i, path in ipairs(buckets.change) do addResult("change", C.Change, path, i) totalH += 32 end
        for i, path in ipairs(buckets.remove) do addResult("remove", C.Remove, path, i) totalH += 32 end

        if totalH == 0 then
            EmptyLabel.Visible = true
            EmptyLabel.Text = "No changes detected ✅"
            EmptyLabel.TextColor3 = C.Add
        end

        ResultScroll.CanvasSize = UDim2.new(0, 0, 0, totalH + 12)
        AddCount.Text    = "  ＋ Added: "   .. #buckets.add
        RemoveCount.Text = "  － Removed: " .. #buckets.remove
        ChangeCount.Text = "  ！ Changed: " .. #buckets.change
    end)
end)


do
    local dragging, dragStart, startPos

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = Main.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end


Main.BackgroundTransparency = 1
Main:TweenPosition(
    UDim2.new(0.5, -220, 0.5, -270),
    Enum.EasingDirection.Out,
    Enum.EasingStyle.Quart,
    0.35, true
)
TweenService:Create(Main, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
