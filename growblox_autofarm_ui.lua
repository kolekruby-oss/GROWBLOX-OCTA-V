-- Growblox Auto Farm + UI (Xeno)
-- Grid 5x5 di sekitar karakter: Place -> Break, auto collect drop.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Net = require(RS:WaitForChild("Shared"):WaitForChild("Net"))

local S = {
    Cycle = false, Collect = false, FastBreak = false,
    Mode = 1,                       -- 1 Place+Break, 2 Break, 3 Place
    PlaceDelay = 250, BreakDelay = 220, AfterBreak = 300, -- ms
    BlockId = 0,                    -- id item (isi manual)
    Range = 2,                      -- 2 = grid 5x5
}
local MODES = { "Place + Break", "Break saja", "Place saja" }
local stat = { place = 0, brk = 0, col = 0, action = "-" }

-- Posisi karakter: tangkap dari paket move milik game
local pos = { x = nil, y = nil }
local origMove = Net.move.send
Net.move.send = function(p, ...)
    if type(p) == "table" and p.x then pos.x, pos.y = p.x, p.y end
    return origMove(p, ...)
end

-- Auto collect drop
local seq = 40000
Net.dropAdded.listen(function(d)
    if not S.Collect then return end
    task.defer(function()
        seq = (seq + 1) % 65536
        Net.take.send({ seq = seq, uid = d.uid, want = math.clamp(d.n, 0, 65535) })
        stat.col += 1
    end)
end)

-- Loop farm
local function ms(n) task.wait(n / 1000) end
task.spawn(function()
    while true do
        task.wait(0.05)
        if not (S.Cycle and pos.x) then stat.action = "-"; continue end
        local cx, cy = math.floor(pos.x), math.floor(pos.y)
        local tiles = {}
        for dy = -S.Range, S.Range do
            for dx = -S.Range, S.Range do
                if not (dx == 0 and dy == 0) then
                    table.insert(tiles, { cx + dx, cy + dy })
                end
            end
        end
        if S.Mode ~= 2 and S.BlockId > 0 then
            stat.action = "Place"
            for _, t in ipairs(tiles) do
                if not S.Cycle then break end
                Net.tile.send({ layer = 1, x = t[1], y = t[2], id = S.BlockId, flip = false })
                stat.place += 1
                ms(S.PlaceDelay)
            end
        end
        if S.Mode ~= 3 then
            stat.action = "Break"
            for _, t in ipairs(tiles) do
                if not S.Cycle then break end
                local hits = S.FastBreak and 1 or 3
                for _ = 1, hits do
                    Net.act.send({ kind = 6, x = t[1] + 0.5, y = t[2] + 0.5 })
                    ms(S.BreakDelay)
                end
                stat.brk += 1
                ms(S.AfterBreak)
            end
        end
    end
end)

-- Anti AFK
local VU = game:GetService("VirtualUser")
Players.LocalPlayer.Idled:Connect(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end)

------------------------------------------------------------ UI
local BG, PANEL, ACC, TXT, SUB = Color3.fromRGB(22,22,26), Color3.fromRGB(32,32,38), Color3.fromRGB(230,190,90), Color3.new(1,1,1), Color3.fromRGB(150,150,160)
local gui = Instance.new("ScreenGui")
gui.Name = "GrowFarmUI"; gui.ResetOnSpawn = false
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local function corner(o, r) local c = Instance.new("UICorner", o); c.CornerRadius = UDim.new(0, r or 8) end
local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 420, 0, 400); main.Position = UDim2.new(0.5, -210, 0.5, -200)
main.BackgroundColor3 = BG; main.Active = true; main.Draggable = true; corner(main, 12)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -50, 0, 40); title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1; title.Text = "GROWFARM  |  Auto Farm"
title.TextColor3 = TXT; title.Font = Enum.Font.GothamBold; title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 30, 0, 30); close.Position = UDim2.new(1, -38, 0, 5)
close.Text = "X"; close.BackgroundColor3 = PANEL; close.TextColor3 = TXT; corner(close, 6)
close.MouseButton1Click:Connect(function() S.Cycle = false; S.Collect = false; gui:Destroy() end)

local statusLbl = Instance.new("TextLabel", main)
statusLbl.Size = UDim2.new(1, -28, 0, 56); statusLbl.Position = UDim2.new(0, 14, 0, 44)
statusLbl.BackgroundColor3 = PANEL; statusLbl.TextColor3 = SUB; statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 12; statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextYAlignment = Enum.TextYAlignment.Top; corner(statusLbl, 8)

local list = Instance.new("ScrollingFrame", main)
list.Size = UDim2.new(1, -28, 1, -118); list.Position = UDim2.new(0, 14, 0, 106)
list.BackgroundTransparency = 1; list.ScrollBarThickness = 3; list.BorderSizePixel = 0
list.CanvasSize = UDim2.new(0, 0, 0, 0); list.AutomaticCanvasSize = Enum.AutomaticSize.Y
local lay = Instance.new("UIListLayout", list); lay.Padding = UDim.new(0, 6)

local function row(name, desc)
    local f = Instance.new("Frame", list)
    f.Size = UDim2.new(1, -6, 0, 46); f.BackgroundColor3 = PANEL; corner(f, 8)
    local a = Instance.new("TextLabel", f)
    a.Size = UDim2.new(1, -110, 0, 22); a.Position = UDim2.new(0, 10, 0, 4); a.BackgroundTransparency = 1
    a.Text = name; a.TextColor3 = TXT; a.Font = Enum.Font.GothamSemibold; a.TextSize = 13
    a.TextXAlignment = Enum.TextXAlignment.Left
    local b = Instance.new("TextLabel", f)
    b.Size = UDim2.new(1, -110, 0, 16); b.Position = UDim2.new(0, 10, 0, 25); b.BackgroundTransparency = 1
    b.Text = desc; b.TextColor3 = SUB; b.Font = Enum.Font.Gotham; b.TextSize = 11
    b.TextXAlignment = Enum.TextXAlignment.Left
    return f
end

local function toggle(name, desc, key)
    local f = row(name, desc)
    local t = Instance.new("TextButton", f)
    t.Size = UDim2.new(0, 46, 0, 24); t.Position = UDim2.new(1, -58, 0.5, -12); t.Text = ""; corner(t, 12)
    local function paint() t.BackgroundColor3 = S[key] and ACC or Color3.fromRGB(60,60,68) end
    paint()
    t.MouseButton1Click:Connect(function() S[key] = not S[key]; paint() end)
end

local function input(name, desc, key, isNum)
    local f = row(name, desc)
    local tb = Instance.new("TextBox", f)
    tb.Size = UDim2.new(0, 70, 0, 26); tb.Position = UDim2.new(1, -82, 0.5, -13)
    tb.BackgroundColor3 = BG; tb.TextColor3 = TXT; tb.Text = tostring(S[key]); corner(tb, 6)
    tb.FocusLost:Connect(function()
        local n = tonumber(tb.Text)
        if n then S[key] = n else tb.Text = tostring(S[key]) end
    end)
end

toggle("Siklus", "Place + Break grid 5x5 di sekitar karakter", "Cycle")
toggle("Auto Collect", "Ambil drop otomatis", "Collect")
toggle("Break Cepat", "1 pukulan per tile, tanpa jeda ekstra", "FastBreak")

local mf = row("Mode", "Klik untuk ganti mode")
local mb = Instance.new("TextButton", mf)
mb.Size = UDim2.new(0, 96, 0, 26); mb.Position = UDim2.new(1, -108, 0.5, -13)
mb.BackgroundColor3 = BG; mb.TextColor3 = ACC; mb.TextSize = 11; mb.Text = MODES[S.Mode]; corner(mb, 6)
mb.MouseButton1Click:Connect(function() S.Mode = S.Mode % 3 + 1; mb.Text = MODES[S.Mode] end)

input("Block ID", "ID item untuk di-place (angka)", "BlockId")
input("Speed Place (ms)", "Jeda setelah tiap place", "PlaceDelay")
input("Speed Break (ms)", "Jeda tiap pukulan", "BreakDelay")
input("Jeda setelah hancur (ms)", "Sebelum lanjut ke tile berikutnya", "AfterBreak")

task.spawn(function()
    while gui.Parent do
        statusLbl.Text = ("  Status : %s\n  Posisi : %s\n  Place/Break/Collect : %d / %d / %d"):format(
            S.Cycle and "BERJALAN" or "BERHENTI",
            pos.x and ("%.1f, %.1f"):format(pos.x, pos.y) or "belum terdeteksi (gerak sedikit)",
            stat.place, stat.brk, stat.col)
        task.wait(0.3)
    end
end)
