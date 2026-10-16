-- Runtime part construction helpers (server). Everything is anchored; decorative parts are not queryable.
local Mk = {}

local function col(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end
Mk.color = col

function Mk.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: { number }, material: string?, o: any?): Part
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = o.collide == true
	p.CanTouch = o.touch == true
	p.CanQuery = o.collide == true
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = col(color)
	p.Material = Enum.Material[material or "SmoothPlastic"]
	p.Transparency = o.tr or 0
	if o.shape then
		p.Shape = Enum.PartType[o.shape]
	end
	if o.spin then
		p:SetAttribute("Spin", o.spin)
	end
	if o.bob then
		p:SetAttribute("Bob", o.bob)
	end
	p.Parent = parent
	return p
end

-- vertical cylinder (Roblox cylinders run along X)
function Mk.cyl(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: { number }, material: string?, o: any?): Part
	return Mk.part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, (function()
		local t = table.clone(o or {})
		t.shape = "Cylinder"
		return t
	end)())
end

function Mk.ball(parent: Instance, name: string, d: number, cf: CFrame, color: { number }, material: string?, o: any?): Part
	local t = table.clone(o or {})
	t.shape = "Ball"
	return Mk.part(parent, name, Vector3.new(d, d, d), cf, color, material, t)
end

function Mk.label(adornee: BasePart, text: string, offsetY: number, color: { number }?, size: UDim2?, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = size or UDim2.fromOffset(220, 44)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance or 160
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = col(color or { 255, 255, 255 })
	l.TextStrokeTransparency = 0.4
	l.Parent = gui
	gui.Parent = adornee
	return gui
end

function Mk.light(parent: Instance, color: { number }, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = col(color)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

return Mk
