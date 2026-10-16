-- Analytic layout check (no renderer): resolves Scale/Offset sizes and anchors for the HUD and panels at many
-- viewport sizes and reports overlaps, off-screen elements and text that cannot fit its box (estimated glyph widths).
-- This is a heuristic, not a screenshot: it proves "nothing obviously collides", not "it looks good".
local M = __M
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Bake = require(game.ServerScriptService.Bake.Bake)
local Instantiate = require(game.ServerScriptService.Bake.Instantiate)
local fails, warnings = 0, 0
local function check(c, msg) if not c then fails += 1; print("FAIL: " .. msg) end end

Instantiate.build((Bake.build()), workspace)
task.spawn(require(game.ServerScriptService.Server.Main))
M.advance(3)
local Server = game.ServerScriptService.Server
local Sessions = require(Server.Sessions)
local P = M.newPlayer("Eve", 4004)
M.setLocalPlayer(P)
M.deliverToClient = true
local Client = game.StarterPlayer.StarterPlayerScripts.Client
task.spawn(require(Client.Main))
M.advance(1)
M.joinAsServer(P)
M.advance(4)
local S = Sessions.get(P)
-- a rich profile: the widest / longest content the UI will ever show
for _, it in Config.Items do S.profile.items[it.id] = true end
for f = 1, 12 do S.profile.floors[tostring(f)] = true end
S.profile.reached, S.profile.checkpoint = 12, 12
S.profile.cash, S.profile.crowns, S.profile.overdrive = 987654321, 98, 12
for _, p in Config.Perks do S.profile.perks[p.id] = true end
require(Server.ProgressService).commit(S)
M.advance(2)

local UIS = game:GetService("UserInputService")
local Menus = require(Client.Menus)
local function rebuild(w, h, touch)
	workspace.CurrentCamera.ViewportSize = Vector2.new(w, h)
	UIS.TouchEnabled = touch
	UIS.KeyboardEnabled = not touch
	local old = P.PlayerGui:FindFirstChild("NeonforgeUI")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "NeonforgeUI"
	gui.Parent = P.PlayerGui
	require(Client.Hud).build(gui)
	require(Client.Feedback).init(gui)
	local toast = require(Client.Feedback).toast
	require(Client.ShopPanel).create(gui, toast)
	require(Client.TowerPanel).create(gui, toast)
	require(Client.StylePanel).create(gui)
	require(Client.SettingsPanel).create(gui)
	return gui
end

-- ===== mini layout engine =====
local function isEnum(v, name) return type(v) == "table" and v.Name == name end
local function childrenOfClass(o, class)
	local out = {}
	for _, c in o:GetChildren() do if c:IsA(class) then table.insert(out, c) end end
	return out
end
local function size(o, pw, ph, vw, vh)
	local s = o.Size
	local w, h = s.X.Scale * pw + s.X.Offset, s.Y.Scale * ph + s.Y.Offset
	local c = o:FindFirstChildOfClass("UISizeConstraint")
	if c then
		w = math.clamp(w, c.MinSize.X, c.MaxSize.X)
		h = math.clamp(h, c.MinSize.Y, c.MaxSize.Y)
	end
	if isEnum(o.AutomaticSize, "Y") then
		local list = o:FindFirstChildOfClass("UIListLayout")
		local total, n = 0, 0
		for _, ch in o:GetChildren() do
			if ch:IsA("GuiObject") then
				local _, chh = size(ch, w, h, vw, vh)
				total += chh
				n += 1
			end
		end
		h = total + (if list then list.Padding.Offset * math.max(0, n - 1) else 0)
	end
	return w, h
end
-- absolute rect of an object whose ancestors are all absolutely positioned (else nil position)
local function rectOf(o, vw, vh)
	local parent = o.Parent
	local px, py, pw, ph
	if parent:IsA("ScreenGui") then
		px, py, pw, ph = 0, 0, vw, vh
	elseif parent:IsA("GuiObject") then
		local r = rectOf(parent, vw, vh)
		if not r then return nil end
		px, py, pw, ph = r.x, r.y, r.w, r.h
	else
		return nil
	end
	for _, sib in parent:GetChildren() do
		if sib:IsA("UIListLayout") or sib:IsA("UIGridLayout") then return nil end -- position decided by the layout
	end
	local w, h = size(o, pw, ph, vw, vh)
	local pos, a = o.Position, o.AnchorPoint
	return { x = px + pos.X.Scale * pw + pos.X.Offset - a.X * w, y = py + pos.Y.Scale * ph + pos.Y.Offset - a.Y * h, w = w, h = h }
end
local function visible(o)
	local c = o
	while c and c:IsA("GuiObject") do
		if not c.Visible then return false end
		c = c.Parent
	end
	return true
end
local function absSize(o, vw, vh)
	local chain = {}
	local c = o
	while c and c:IsA("GuiObject") do table.insert(chain, 1, c); c = c.Parent end
	local w, h = vw, vh
	for _, node in chain do w, h = size(node, w, h, vw, vh) end
	return w, h
end
local function overlap(a, b)
	return a.x < b.x + b.w - 0.5 and b.x < a.x + a.w - 0.5 and a.y < b.y + b.h - 0.5 and b.y < a.y + a.h - 0.5
end

local viewports = {
	{ 667, 375, true, "iPhone SE landscape" }, { 800, 360, true, "small phone landscape" }, { 844, 390, true, "phone landscape" },
	{ 1024, 768, true, "tablet" }, { 1280, 720, false, "desktop 720p" }, { 1920, 1080, false, "desktop 1080p" }, { 2560, 1440, false, "desktop 1440p" },
}
local CHAR_W = 0.54
local function textFit(root, label, vw, vh)
	local problems = 0
	for _, o in root:GetDescendants() do
		if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) and o.Text ~= "" then
			local w, h = absSize(o, vw, vh)
			if w > 0 and h > 0 then
				local ts = o.TextSize
				local cw = ts * (if o.Font.Name == "FredokaOne" or o.Font.Name == "GothamBold" or o.Font.Name == "GothamBlack" then 0.6 else CHAR_W)
				local lines = 0
				local maxLine = 0
				for line in (o.Text .. "\n"):gmatch("(.-)\n") do
					local lw = #line * cw
					maxLine = math.max(maxLine, lw)
					lines += if o.TextWrapped then math.max(1, math.ceil(lw / math.max(1, w - 4))) else 1
				end
				local needH = lines * ts * 1.15
				if not o.TextWrapped and maxLine > w * 1.12 then
					problems += 1
					print(("  [%s] text too wide: %q needs ~%d px, box %d px"):format(label, o.Text:sub(1, 40), maxLine, w))
				elseif o.TextWrapped and needH > h * 1.15 + 2 and not (o.Parent and o.Parent:IsA("ScrollingFrame")) then
					problems += 1
					print(("  [%s] wrapped text overflows: %q needs ~%d px tall, box %d px"):format(label, o.Text:sub(1, 40), needH, h))
				end
			end
		end
	end
	return problems
end

for _, vp in viewports do
	local w, h, touch, name = vp[1], vp[2], vp[3], vp[4]
	local gui = rebuild(w, h, touch)
	M.advance(0.5)
	local label = ("%dx%d %s"):format(w, h, name)
	-- HUD element rects
	local rects = {}
	local function add(label2, obj)
		if obj and visible(obj) then
			local r = rectOf(obj, w, h)
			if r then r.name = label2; table.insert(rects, r) end
		end
	end
	add("StatsCard", gui:FindFirstChild("StatsCard"))
	add("FloorCard", gui:FindFirstChild("FloorCard"))
	add("TitleCard", gui:FindFirstChild("TitleCard"))
	add("MenuColumn", gui:FindFirstChild("MenuColumn"))
	add("MenuBar", gui:FindFirstChild("MenuBar"))
	add("TravelButton", gui:FindFirstChild("TravelButton"))
	if touch then
		table.insert(rects, { x = w - 120, y = h - 120, w = 110, h = 110, name = "[Roblox jump button]" })
		table.insert(rects, { x = 10, y = h - 190, w = 170, h = 170, name = "[Roblox thumbstick]" })
	end
	-- toasts (3 stacked) under the objective card
	local toasts = gui:FindFirstChild("Toasts")
	if toasts then
		local tw = toasts.Size.X.Offset
		local th = 3 * (34 + 4)
		table.insert(rects, { x = w / 2 - tw / 2, y = h + toasts.Position.Y.Offset - th, w = tw, h = th, name = "Toasts(3)" })
	end
	local problems = 0
	for i, r in rects do
		if r.x < -0.5 or r.y < -0.5 or r.x + r.w > w + 0.5 or r.y + r.h > h + 0.5 then
			problems += 1; print(("  [%s] %s is off-screen: x=%d y=%d w=%d h=%d"):format(label, r.name, r.x, r.y, r.w, r.h))
		end
		for j = i + 1, #rects do
			if overlap(r, rects[j]) then
				problems += 1; print(("  [%s] %s overlaps %s"):format(label, r.name, rects[j].name))
			end
		end
	end
	problems += textFit(gui, label .. " HUD", w, h)
	-- every panel (and every tab of it): fits the screen, and its texts fit
	local tabsOf = {}
	for _, menu in { "shop", "tower", "style", "settings" } do
		for _, tabName in (tabsOf[menu] or { false }) do
			Menus.open(menu)
			M.advance(0.2)
			local panel
			for _, c in gui:GetChildren() do if c:IsA("Frame") and c.Visible and c.Size.X.Scale == 0.94 then panel = c end end
			if panel and tabName then
				for _, b in panel:GetDescendants() do
					if b:IsA("TextButton") and b.Text == tabName then M.getSignal(b, "Activated"):Fire() end
				end
				M.advance(0.2)
			end
			local what = menu .. (if tabName then "/" .. tabName else "")
			if panel then
				local r = rectOf(panel, w, h)
				if r.x < 0 or r.y < 0 or r.x + r.w > w or r.y + r.h > h then problems += 1; print(("  [%s] panel %s off-screen"):format(label, what)) end
				if r.w < 300 or r.h < 220 then problems += 1; print(("  [%s] panel %s too small %dx%d"):format(label, what, r.w, r.h)) end
				problems += textFit(panel, label .. " " .. what, w, h)
				for _, o in panel:GetDescendants() do
					if o:IsA("GuiObject") and visible(o) and not o:FindFirstAncestorOfClass("ScrollingFrame") then
						local rr = rectOf(o, w, h)
						if rr and (rr.x < r.x - 1 or rr.y < r.y - 1 or rr.x + rr.w > r.x + r.w + 1 or rr.y + rr.h > r.y + r.h + 1) then
							problems += 1
							print(("  [%s] %s: %s (%s) sticks out of the panel"):format(label, what, o.Name, o.ClassName))
						end
					end
				end
			else
				problems += 1; print(("  [%s] panel %s did not open"):format(label, what))
			end
		end
	end
	Menus.close()
	print(("%-34s %s"):format(label, if problems == 0 then "ok" else problems .. " layout problem(s)"))
	warnings += problems
end
check(warnings == 0, warnings .. " layout problems")
print(fails == 0 and "layout_test: PASS" or ("layout_test: " .. fails .. " FAILURES"))
if #M.errors > 0 then print("script errors:\n" .. table.concat(M.errors, "\n")); fails += 1 end
if fails > 0 then error("failed") end
