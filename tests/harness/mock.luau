--!nonstrict
-- A small mock of the Roblox runtime, good enough to execute this project's server + client code in the plain Luau
-- CLI: Instances with class-member validation (unknown property names throw), data types, signals, a virtual-time
-- task scheduler, remotes wired server<->client in one process, a DataStore with UpdateAsync + failure injection.
-- It does NOT simulate physics, rendering or layout. See tests/README for what this can and cannot prove.
local db = require("./api_db")

local M = {}
M.errors = {} -- uncaught errors thrown inside spawned threads / signal handlers
M.stats = { voxelWrites = 0, instancesCreated = 0 }
M.clientEvents = {} -- player -> list of { remote, args } (everything the server sent)
M.kicks = {}
M.heightFn = function(x, z) return 0 end

-- ===== virtual time + scheduler =====
local now = 0
local timers = {}
local current = nil
local mainCo, mainError = nil, nil
local function runThread(co, ...)
	local prev = current
	current = co
	local ok, err = coroutine.resume(co, ...)
	current = prev
	if not ok then
		local tb = debug.traceback(co, tostring(err))
		if co == mainCo then
			mainError = tb
		else
			table.insert(M.errors, tb)
		end
	end
end
local function spawn(f, ...)
	if type(f) == "thread" then
		runThread(f, ...)
		return f
	end
	local co = coroutine.create(f)
	runThread(co, ...)
	return co
end
local task = {}
task.spawn = spawn
task.defer = spawn
function task.delay(t, f, ...)
	table.insert(timers, { t = now + (t or 0), f = f, args = table.pack(...) })
end
function task.wait(t)
	t = t or 0.03
	if current ~= nil then
		table.insert(timers, { t = now + t, co = coroutine.running() })
		coroutine.yield()
	else
		M.advance(t)
	end
	return t
end
function task.cancel() end
M.task = task

local signalsToStep = {}
function M.advance(dt)
	local target = now + dt
	while now < target - 1e-9 do
		local step = math.min(1 / 30, target - now)
		now += step
		-- due timers in time order
		table.sort(timers, function(a, b) return a.t < b.t end)
		local due = {}
		local rest = {}
		for _, tm in timers do
			if tm.t <= now + 1e-9 then table.insert(due, tm) else table.insert(rest, tm) end
		end
		timers = rest
		for _, tm in due do
			if tm.co then runThread(tm.co) else spawn(tm.f, table.unpack(tm.args, 1, tm.args.n)) end
		end
		for _, s in signalsToStep do
			s:Fire(step)
		end
	end
end
function M.now() return now end

-- Runs a test body as a scheduler thread so it can task.wait(); drives virtual time until it finishes.
function M.run(fn)
	local co = coroutine.create(fn)
	mainCo = co
	runThread(co)
	local guard = 0
	while coroutine.status(co) ~= "dead" and guard < 200000 do
		guard += 1
		M.advance(0.05)
	end
	if mainError then error(mainError, 0) end
	if coroutine.status(co) ~= "dead" then error("test body never finished (stuck waiting)") end
end

M.os = { clock = function() return now end, time = function() return 1700000000 + math.floor(now) end, date = os.date, difftime = os.difftime }

-- ===== signals =====
local Signal = {}
Signal.__index = Signal
local function newSignal()
	return setmetatable({ handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	local c = { fn = fn, Connected = true }
	c.Disconnect = function(self)
		self.Connected = false
	end
	table.insert(self.handlers, c)
	return c
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end
function Signal:Fire(...)
	local hs = self.handlers
	self.handlers = {}
	for _, c in hs do
		if c.Connected then
			table.insert(self.handlers, c)
			spawn(c.fn, ...)
		end
	end
	local w = self.waiting
	self.waiting = {}
	for _, co in w do
		spawn(co, ...)
	end
end
M.Signal = newSignal

-- ===== data types =====
local function typed(name, mt)
	mt.__index = mt.__index or mt
	mt._t = name
	return mt
end

local V3 = {}
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2) end
	if k == "Unit" then
		local m = math.sqrt(t.X ^ 2 + t.Y ^ 2 + t.Z ^ 2)
		if m == 0 then return t end
		return setmetatable({ X = t.X / m, Y = t.Y / m, Z = t.Z / m }, V3)
	end
	if k == "_t" then return "Vector3" end
	return V3[k]
end
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
V3.new = v3
V3.zero, V3.one = v3(0, 0, 0), v3(1, 1, 1)
V3.xAxis, V3.yAxis, V3.zAxis = v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return ("%g, %g, %g"):format(a.X, a.Y, a.Z) end
function V3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3.Lerp(a, b, t) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end

local V2 = {}
V2.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X ^ 2 + t.Y ^ 2) end
	if k == "_t" then return "Vector2" end
	return V2[k]
end
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.new = v2
V2.zero = v2(0, 0)
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b)
	if type(a) == "number" then return v2(a * b.X, a * b.Y) end
	if type(b) == "number" then return v2(a.X * b, a.Y * b) end
	return v2(a.X * b.X, a.Y * b.Y)
end

-- CFrame: position + 3x3 rotation (row-major r11..r33)
local CF = {}
local function cf(x, y, z, r) return setmetatable({ X = x, Y = y, Z = z, r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF) end
local function matmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
CF.__index = function(t, k)
	if k == "Position" then return v3(t.X, t.Y, t.Z) end
	if k == "LookVector" then return v3(-t.r[3], -t.r[6], -t.r[9]) end
	if k == "RightVector" then return v3(t.r[1], t.r[4], t.r[7]) end
	if k == "UpVector" then return v3(t.r[2], t.r[5], t.r[8]) end
	if k == "_t" then return "CFrame" end
	return CF[k]
end
function CF.new(a, b, c)
	if a == nil then return cf(0, 0, 0) end
	if type(a) == "number" then return cf(a, b, c) end
	if b ~= nil then return CF.lookAt(a, b) end
	return cf(a.X, a.Y, a.Z)
end
function CF.Angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(0, 0, 0, matmul(matmul(Rx, Ry), Rz))
end
CF.fromEulerAnglesXYZ = CF.Angles
function CF.lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then right = v3(1, 0, 0) end
	right = right.Unit
	local u = right:Cross(look)
	-- columns: right, up, -look
	return cf(at.X, at.Y, at.Z, { right.X, u.X, -look.X, right.Y, u.Y, -look.Y, right.Z, u.Z, -look.Z })
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return v3(a.X + a.r[1] * b.X + a.r[2] * b.Y + a.r[3] * b.Z, a.Y + a.r[4] * b.X + a.r[5] * b.Y + a.r[6] * b.Z, a.Z + a.r[7] * b.X + a.r[8] * b.Y + a.r[9] * b.Z)
	end
	local p = a * v3(b.X, b.Y, b.Z)
	return cf(p.X, p.Y, p.Z, matmul(a.r, b.r))
end
CF.__add = function(a, b) return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.r) end
CF.__sub = function(a, b) return cf(a.X - b.X, a.Y - b.Y, a.Z - b.Z, a.r) end
function CF.VectorToObjectSpace(a, v)
	local r = a.r
	return v3(r[1] * v.X + r[4] * v.Y + r[7] * v.Z, r[2] * v.X + r[5] * v.Y + r[8] * v.Z, r[3] * v.X + r[6] * v.Y + r[9] * v.Z)
end
function CF.GetComponents(a)
	local r = a.r
	return a.X, a.Y, a.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
function CF.Inverse(a)
	local r = a.r
	local rt = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	local x = -(rt[1] * a.X + rt[2] * a.Y + rt[3] * a.Z)
	local y = -(rt[4] * a.X + rt[5] * a.Y + rt[6] * a.Z)
	local z = -(rt[7] * a.X + rt[8] * a.Y + rt[9] * a.Z)
	return cf(x, y, z, rt)
end
function CF.PointToWorldSpace(a, v) return a * v end
function CF.ToWorldSpace(a, b) return a * b end
function CF.Lerp(a, b, t) return cf(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t, b.r) end
CF.identity = cf(0, 0, 0)

local C3 = {}
C3.__index = function(t, k)
	if k == "_t" then return "Color3" end
	return C3[k]
end
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end
C3.new = c3
C3.fromRGB = function(r, g, b) return c3(r / 255, g / 255, b / 255) end
C3.fromHSV = function(h, s, v) return c3(v, v, v) end
function C3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end

local UD = {}
UD.__index = function(t, k) if k == "_t" then return "UDim" end return UD[k] end
UD.new = function(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD) end
local UD2 = {}
UD2.__index = function(t, k) if k == "_t" then return "UDim2" end return UD2[k] end
local function ud2(xs, xo, ys, yo) return setmetatable({ X = UD.new(xs, xo), Y = UD.new(ys, yo) }, UD2) end
UD2.new = function(a, b, c, d)
	if getmetatable(a) == UD then return ud2(a.Scale, a.Offset, b.Scale, b.Offset) end
	return ud2(a or 0, b or 0, c or 0, d or 0)
end
UD2.fromScale = function(x, y) return ud2(x, 0, y, 0) end
UD2.fromOffset = function(x, y) return ud2(0, x, 0, y) end

local function simple(name, ctor)
	local mt = {}
	mt.__index = function(t, k) if k == "_t" then return name end return mt[k] end
	return { new = function(...) return setmetatable(ctor(...), mt) end, mt = mt }
end
local NR = simple("NumberRange", function(a, b) return { Min = a, Max = b or a } end)
local NSK = simple("NumberSequenceKeypoint", function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end)
local NS = simple("NumberSequence", function(a, b)
	if type(a) == "table" then return { Keypoints = a } end
	return { Keypoints = { NSK.new(0, a), NSK.new(1, b or a) } }
end)
local CSK = simple("ColorSequenceKeypoint", function(t, c) return { Time = t, Value = c } end)
local CS = simple("ColorSequence", function(a, b)
	if getmetatable(a) == nil and type(a) == "table" and a[1] then return { Keypoints = a } end
	return { Keypoints = { CSK.new(0, a), CSK.new(1, b or a) } }
end)
local TI = simple("TweenInfo", function(time, style, dir, rep, rev, delay) return { Time = time or 1 } end)
local R3 = simple("Region3", function(a, b) return { Min = a, Max = b } end)
function R3.mt.ExpandToGrid(self, res) return self end
local RP = simple("RaycastParams", function() return { FilterDescendantsInstances = {}, FilterType = nil } end)
local Rnd = {}
Rnd.new = function(seed)
	local s = ((seed or 0) % 2147483646) + 1
	local self = {}
	function self:NextNumber(a, b)
		s = (s * 48271) % 2147483647
		local r = s / 2147483647
		if a then return a + r * ((b or 0) - a) end
		return r
	end
	function self:NextInteger(a, b)
		return a + math.floor(self:NextNumber() * (b - a + 1))
	end
	return self
end

-- Enum: Enum.Material.Neon -> { _enum = "Material", Name = "Neon" }; compared by identity per (enum, name)
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		local e = enumCache[enumName]
		if not e then
			e = setmetatable({}, {
				__index = function(t, itemName)
					local item = { _enum = enumName, Name = itemName, Value = 0, _t = "EnumItem" }
					rawset(t, itemName, item)
					return item
				end,
			})
			enumCache[enumName] = e
		end
		return e
	end,
})

-- ===== Instances =====
local data = setmetatable({}, { __mode = "k" })
local methods = {}
local classMethods = {}

local function isA(class, target)
	local c = class
	while c do
		if c == target then return true end
		local d = db[c]
		c = d and d.extends
	end
	return false
end

local function findMember(class, kind, name)
	local c = class
	while c do
		local d = db[c]
		if not d then return nil end
		local v = d[kind][name]
		if v then return v end
		c = d.extends
	end
	return nil
end

local defaults = {
	number = 0, boolean = false, string = "",
}
local trueDefaults = { Visible = true, Enabled = true }
local function defaultFor(typ, key)
	if typ == "boolean" and trueDefaults[key] then return true end
	if defaults[typ] ~= nil then return defaults[typ] end
	if typ == "Vector3" then return v3(0, 0, 0) end
	if typ == "Vector2" then return v2(0, 0) end
	if typ == "CFrame" then return CF.identity end
	if typ == "Color3" then return c3(1, 1, 1) end
	if typ == "UDim2" then return ud2(0, 0, 0, 0) end
	if typ == "UDim" then return UD.new(0, 0) end
	return nil
end

local instMT = {}
local function typeOk(typ, v, class, key)
	if typ == "number" then return type(v) == "number" and v == v end
	if typ == "boolean" then return type(v) == "boolean" end
	if typ == "string" then return type(v) == "string" end
	if typ == "Vector3" or typ == "Vector2" or typ == "CFrame" or typ == "Color3" or typ == "UDim2" or typ == "UDim" or typ == "NumberSequence" or typ == "ColorSequence" or typ == "NumberRange" then
		return type(v) == "table" and v._t == typ
	end
	if typ:sub(1, 4) == "Enum" and #typ > 4 then
		return type(v) == "table" and v._enum == typ:sub(5)
	end
	return true
end

local function descendants(inst, out)
	for _, c in data[inst].children do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

local function setParent(inst, parent)
	local d = data[inst]
	if d.parent then
		local sibs = data[d.parent].children
		local i = table.find(sibs, inst)
		if i then table.remove(sibs, i) end
	end
	d.parent = parent
	if parent then
		table.insert(data[parent].children, inst)
		local pd = data[parent]
		if pd.signals.ChildAdded then pd.signals.ChildAdded:Fire(inst) end
		local p = parent
		while p do
			local s = data[p].signals.DescendantAdded
			if s then s:Fire(inst) end
			p = data[p].parent
		end
	end
	if d.signals.AncestryChanged then d.signals.AncestryChanged:Fire(inst, parent) end
end

local function getSignal(inst, name)
	local d = data[inst]
	local s = d.signals[name]
	if not s then
		s = newSignal()
		d.signals[name] = s
	end
	return s
end

local function create(class, name)
	local def = db[class]
	if not def then
		error(("Unable to create an Instance of type %q"):format(class), 3)
	end
	M.stats.instancesCreated += 1
	local inst = setmetatable({}, instMT)
	data[inst] = { class = class, name = name or class, parent = nil, children = {}, props = {}, attrs = {}, signals = {}, attrSignals = {}, propSignals = {} }
	if isA(class, "BasePart") then
		data[inst].props.Size = v3(4, 1, 2)
		data[inst].props.CFrame = CF.identity
	end
	return inst
end
M.create = create

instMT.__index = function(inst, k)
	local d = data[inst]
	if k == "Name" then return d.name end
	if k == "Parent" then return d.parent end
	if k == "ClassName" then return d.class end
	local m = classMethods[d.class] and classMethods[d.class][k]
	if not m then
		-- walk class chain for class specific methods
		local c = db[d.class]
		local cn = d.class
		while cn and not m do
			m = classMethods[cn] and classMethods[cn][k]
			local dd = db[cn]
			cn = dd and dd.extends
		end
	end
	if m then return m end
	if methods[k] then return methods[k] end
	if d.props[k] ~= nil then return d.props[k] end
	-- computed members
	if k == "Position" and isA(d.class, "BasePart") then
		local c = d.props.CFrame
		return v3(c.X, c.Y, c.Z)
	end
	if findMember(d.class, "events", k) or k == "Changed" or k == "ChildAdded" or k == "DescendantAdded" or k == "AncestryChanged" or k == "Destroying" or k == "ChildRemoved" then
		return getSignal(inst, k)
	end
	for _, c in d.children do
		if data[c].name == k then return c end
	end
	local typ = findMember(d.class, "props", k)
	if typ then
		return defaultFor(typ, k)
	end
	if findMember(d.class, "methods", k) then
		return function() end -- declared in the API but not modelled: harmless no-op
	end
	error(("%s is not a valid member of %s"):format(tostring(k), d.class), 2)
end

instMT.__newindex = function(inst, k, v)
	local d = data[inst]
	if k == "Name" then
		d.name = v
		return
	end
	if k == "Parent" then
		if v ~= nil and (type(v) ~= "table" or not data[v]) then
			error("Parent must be an Instance or nil", 2)
		end
		setParent(inst, v)
		return
	end
	if k == "ClassName" then error("ClassName is read-only", 2) end
	local typ = findMember(d.class, "props", k)
	if not typ then
		-- scripts may assign signals' handlers like OnServerInvoke
		if k == "OnServerInvoke" or k == "OnClientInvoke" then
			d.props[k] = v
			return
		end
		error(("%q is not a valid property of %s"):format(tostring(k), d.class), 2)
	end
	if v ~= nil and not typeOk(typ, v, d.class, k) then
		error(("bad value for %s.%s (expected %s, got %s)"):format(d.class, k, typ, typeof(v)), 2)
	end
	d.props[k] = v
	if k == "Position" and isA(d.class, "BasePart") then
		d.props.CFrame = cf(v.X, v.Y, v.Z, d.props.CFrame.r)
	end
	local s = d.propSignals[k]
	if s then s:Fire() end
end
instMT.__tostring = function(inst) return data[inst].name end

function methods.GetChildren(inst) return table.clone(data[inst].children) end
function methods.GetDescendants(inst) return descendants(inst, {}) end
function methods.IsA(inst, c) return isA(data[inst].class, c) end
function methods.Destroy(inst)
	local d = data[inst]
	if d.signals.Destroying then d.signals.Destroying:Fire() end
	setParent(inst, nil)
	for _, c in table.clone(d.children) do
		methods.Destroy(c)
	end
	d.destroyed = true
end
function methods.ClearAllChildren(inst)
	for _, c in table.clone(data[inst].children) do methods.Destroy(c) end
end
function methods.FindFirstChild(inst, name, recursive)
	for _, c in data[inst].children do
		if data[c].name == name then return c end
	end
	if recursive then
		for _, c in data[inst].children do
			local r = methods.FindFirstChild(c, name, true)
			if r then return r end
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(inst, class)
	for _, c in data[inst].children do
		if data[c].class == class then return c end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(inst, class)
	for _, c in data[inst].children do
		if isA(data[c].class, class) then return c end
	end
	return nil
end
function methods.FindFirstAncestor(inst, name)
	local p = data[inst].parent
	while p do
		if data[p].name == name then return p end
		p = data[p].parent
	end
	return nil
end
function methods.FindFirstAncestorOfClass(inst, class)
	local p = data[inst].parent
	while p do
		if data[p].class == class then return p end
		p = data[p].parent
	end
	return nil
end
function methods.IsDescendantOf(inst, anc)
	local p = data[inst].parent
	while p do
		if p == anc then return true end
		p = data[p].parent
	end
	return false
end
function methods.WaitForChild(inst, name, timeout)
	local c = methods.FindFirstChild(inst, name)
	if c then return c end
	-- in a test everything is created before use: a missing child is a real wiring bug
	error(("WaitForChild: %q is not a child of %s (would hang in Studio)"):format(name, data[inst].name), 2)
end
function methods.GetFullName(inst)
	local parts = {}
	local c = inst
	while c do
		table.insert(parts, 1, data[c].name)
		c = data[c].parent
	end
	return table.concat(parts, ".")
end
function methods.SetAttribute(inst, k, v)
	local d = data[inst]
	d.attrs[k] = v
	local s = d.attrSignals[k]
	if s then s:Fire() end
end
function methods.GetAttribute(inst, k) return data[inst].attrs[k] end
function methods.GetAttributes(inst) return table.clone(data[inst].attrs) end
function methods.GetAttributeChangedSignal(inst, k)
	local d = data[inst]
	if not d.attrSignals[k] then d.attrSignals[k] = newSignal() end
	return d.attrSignals[k]
end
function methods.GetPropertyChangedSignal(inst, k)
	local d = data[inst]
	if not d.propSignals[k] then d.propSignals[k] = newSignal() end
	return d.propSignals[k]
end
function methods.Clone(inst)
	local d = data[inst]
	local c = create(d.class, d.name)
	for k, v in d.props do data[c].props[k] = v end
	for k, v in d.attrs do data[c].attrs[k] = v end
	for _, ch in d.children do methods.Clone(ch).Parent = c end
	return c
end

local Instance = { new = function(class, parent)
	local inst = create(class)
	if parent then inst.Parent = parent end
	return inst
end }

-- model / part helpers
local function pivotOf(model)
	local pp = data[model].props.PrimaryPart
	if pp then return data[pp].props.CFrame end
	return data[model].pivot or CF.identity
end
classMethods.Model = {
	PivotTo = function(model, target)
		local old = pivotOf(model)
		local delta = target * old:Inverse()
		for _, d in descendants(model, {}) do
			if isA(data[d].class, "BasePart") then
				data[d].props.CFrame = delta * data[d].props.CFrame
			end
		end
		if not data[model].props.PrimaryPart then data[model].pivot = target end
	end,
	GetPivot = function(model) return pivotOf(model) end,
	ScaleTo = function() end,
	GetExtentsSize = function() return v3(4, 4, 4) end,
}
classMethods.PVInstance = classMethods.Model

-- remotes: server <-> client in one process
classMethods.RemoteEvent = {
	FireClient = function(ev, player, ...)
		local list = M.clientEvents[player]
		if not list then list = {}; M.clientEvents[player] = list end
		table.insert(list, { remote = data[ev].name, args = table.pack(...) })
		if M.deliverToClient and player == M.localPlayer then
			getSignal(ev, "OnClientEvent"):Fire(...)
		end
	end,
	FireAllClients = function(ev, ...)
		getSignal(ev, "OnClientEvent"):Fire(...)
	end,
	FireServer = function(ev, ...)
		getSignal(ev, "OnServerEvent"):Fire(M.localPlayer, ...)
	end,
}
classMethods.RemoteFunction = {
	InvokeServer = function(rf, ...)
		local h = data[rf].props.OnServerInvoke
		assert(h, "no OnServerInvoke handler for " .. data[rf].name)
		return h(M.localPlayer, ...)
	end,
}
M.invokeAs = function(rf, player, ...)
	return data[rf].props.OnServerInvoke(player, ...)
end
M.fireServerAs = function(ev, player, ...)
	getSignal(ev, "OnServerEvent"):Fire(player, ...)
end

-- ===== services =====
local services = {}
local game = create("DataModel", "game")
local function service(class, name)
	local s = create(class, name or class)
	s.Parent = game
	services[name or class] = s
	return s
end
local Workspace = service("Workspace")
local Terrain = create("Terrain", "Terrain")
Terrain.Parent = Workspace
local camera = create("Camera", "Camera")
camera.Parent = Workspace
camera.ViewportSize = v2(1280, 720)
Workspace.CurrentCamera = camera
local ReplicatedStorage = service("ReplicatedStorage")
local ServerScriptService = service("ServerScriptService")
local StarterPlayer = service("StarterPlayer")
local StarterPlayerScripts = create("StarterPlayerScripts", "StarterPlayerScripts")
StarterPlayerScripts.Parent = StarterPlayer
local Lighting = service("Lighting")
local Players = service("Players")
local RunService = service("RunService")
local SoundService = service("SoundService")
local TweenService = service("TweenService")
local Debris = service("Debris")
local UserInputService = service("UserInputService")
local DataStoreService = service("DataStoreService")
service("StarterGui")

classMethods.Players_ = nil
classMethods.Camera = {
	ViewportPointToRay = function(cam, x, y)
		local c = data[cam].props.CFrame or CF.identity
		return { Origin = c.Position, Direction = c.LookVector }
	end,
}
classMethods.Workspace = {
	GetServerTimeNow = function() return 1700000000 + now end,
	Raycast = function(ws, origin, dir, params)
		local h = M.heightFn(origin.X, origin.Z)
		if origin.Y >= h and origin.Y + dir.Y <= h then
			return { Position = v3(origin.X, h, origin.Z), Normal = v3(0, 1, 0), Instance = Terrain, Material = Enum.Material.Grass }
		end
		return nil
	end,
}
M.terrain = { clears = 0, colors = {}, cellsWritten = 0 }
classMethods.Terrain = {
	Clear = function() M.terrain.clears += 1 end,
	WriteVoxels = function(t, region, res, materials, occupancies)
		M.stats.voxelWrites += 1
		local size = region.Max - region.Min
		local nx, ny, nz = size.X / res, size.Y / res, size.Z / res
		assert(nx == math.floor(nx) and ny == math.floor(ny) and nz == math.floor(nz), "region not grid aligned")
		assert(#materials == nx and #occupancies == nx, "x dimension mismatch " .. #materials .. " vs " .. nx)
		for xi = 1, nx do
			assert(#materials[xi] == ny and #occupancies[xi] == ny, "y dimension mismatch")
			for yi = 1, ny do
				assert(#materials[xi][yi] == nz and #occupancies[xi][yi] == nz, "z dimension mismatch")
				for zi = 1, nz do
					local o = occupancies[xi][yi][zi]
					assert(type(o) == "number" and o >= 0 and o <= 1, "occupancy out of range " .. tostring(o))
					assert(type(materials[xi][yi][zi]) == "table" and materials[xi][yi][zi]._enum == "Material", "bad material")
				end
			end
		end
		M.terrain.cellsWritten += nx * ny * nz
	end,
	SetMaterialColor = function(t, mat, color) M.terrain.colors[mat.Name] = color end,
}
classMethods.RunService = {
	IsStudio = function() return true end,
	IsServer = function() return true end,
	IsClient = function() return true end,
	IsRunning = function() return true end,
}
for _, name in { "Heartbeat", "RenderStepped", "Stepped", "PreSimulation", "PostSimulation" } do
	local s = getSignal(RunService, name)
	table.insert(signalsToStep, s)
end
classMethods.Players = {
	GetPlayers = function() return table.clone(M.playerList) end,
	GetPlayerFromCharacter = function(_, char)
		for _, p in M.playerList do
			if data[p].props.Character == char and char ~= nil then return p end
		end
		return nil
	end,
}
M.playerList = {}
classMethods.TweenService = {
	Create = function(_, inst, info, goals)
		for k, v in goals do
			if not findMember(data[inst].class, "props", k) then
				error(("TweenService: %s has no property %q"):format(data[inst].class, k), 2)
			end
		end
		local tween = { Completed = newSignal(), PlaybackState = nil }
		function tween:Play()
			for k, v in goals do
				data[inst].props[k] = v
			end
			task.delay(info.Time, function() self.Completed:Fire() end)
		end
		function tween:Cancel() end
		return tween
	end,
}
classMethods.Debris = {
	AddItem = function(_, inst, t)
		task.delay(t, function()
			if data[inst] and not data[inst].destroyed then methods.Destroy(inst) end
		end)
	end,
}
classMethods.UserInputService = {
	GetMouseLocation = function() return v2(640, 360) end,
}
UserInputService.MouseEnabled = true
UserInputService.KeyboardEnabled = true

-- DataStore with UpdateAsync semantics, deep copies and failure injection
M.datastore = { data = {}, failNext = 0, calls = 0, callsByKey = {}, writes = 0, offlineError = nil, log = {} }
local function deepcopy(v)
	if type(v) ~= "table" then return v end
	local o = {}
	for k, x in v do o[k] = deepcopy(x) end
	return o
end
M.deepcopy = deepcopy
local storeObj = { }
function storeObj:UpdateAsync(key, fn)
	M.datastore.calls += 1
	M.datastore.callsByKey[key] = (M.datastore.callsByKey[key] or 0) + 1
	if M.datastore.offlineError then error(M.datastore.offlineError) end
	if M.datastore.failNext > 0 then
		M.datastore.failNext -= 1
		error("503: DataStore request was throttled")
	end
	local old = deepcopy(M.datastore.data[key])
	local new = fn(old)
	if new == nil then return old end
	M.datastore.data[key] = deepcopy(new)
	M.datastore.writes += 1
	return deepcopy(new)
end
function storeObj:GetAsync(key) return deepcopy(M.datastore.data[key]) end
classMethods.DataStoreService = { GetDataStore = function() return storeObj end }

-- game
game.JobId = "job-A"
M.bindToClose = {}
classMethods.DataModel = {
	IsLoaded = function() return true end,
	GetService = function(g, name)
		local s = services[name]
		if not s then error("unknown service " .. tostring(name), 2) end
		return s
	end,
	BindToClose = function(g, fn) table.insert(M.bindToClose, fn) end,
}

-- Players: create + join
function M.newPlayer(name, userId)
	local p = create("Player", name)
	data[p].props.UserId = userId
	data[p].props.Name = name
	p.Parent = Players
	table.insert(M.playerList, p)
	local mt = data[p]
	classMethods.Player = classMethods.Player or {}
	return p
end
classMethods.Player = {
	LoadCharacterAsync = function(p)
		local old = data[p].props.Character
		if old then methods.Destroy(old) end
		local char = create("Model", data[p].name)
		local hum = create("Humanoid", "Humanoid")
		hum.Parent = char
		hum.Health = 100
		hum.MaxHealth = 100
		local hrp = create("Part", "HumanoidRootPart")
		hrp.Parent = char
		hrp.CFrame = CF.new(0, 5, 0)
		char.PrimaryPart = hrp
		char.Parent = Workspace
		data[p].props.Character = char
		getSignal(p, "CharacterAdded"):Fire(char)
	end,
	Kick = function(p, msg) table.insert(M.kicks, { player = p, message = msg }) end,
}
function M.leave(p)
	getSignal(Players, "PlayerRemoving"):Fire(p)
	local i = table.find(M.playerList, p)
	if i then table.remove(M.playerList, i) end
	setParent(p, nil)
end
function M.joinAsServer(p)
	getSignal(Players, "PlayerAdded"):Fire(p)
	-- CharacterAutoLoads: Roblox spawns the character right after PlayerAdded
	task.delay(0.2, function()
		if data[p] and data[p].parent then classMethods.Player.LoadCharacterAsync(p) end
	end)
end
function M.setLocalPlayer(p)
	M.localPlayer = p
	data[Players].props.LocalPlayer = p
	if not methods.FindFirstChild(p, "PlayerGui") then
		local pg = create("PlayerGui", "PlayerGui")
		pg.Parent = p
	end
end
function M.teleport(p, x, y, z)
	local char = data[p].props.Character
	local hrp = methods.FindFirstChild(char, "HumanoidRootPart")
	hrp.CFrame = CF.new(x, y, z)
end

-- ===== module tree + require =====
local files = {}
function M.registerFile(path, class)
	-- path like "shared/Config" -> instance under the right root
	local parts = string.split(path, "/")
	local root
	if parts[1] == "shared" then
		root = methods.FindFirstChild(ReplicatedStorage, "Shared") or (function() local f = create("Folder", "Shared"); f.Parent = ReplicatedStorage; return f end)()
	elseif parts[1] == "bake" then
		root = methods.FindFirstChild(ServerScriptService, "Bake") or (function() local f = create("Folder", "Bake"); f.Parent = ServerScriptService; return f end)()
	elseif parts[1] == "server" then
		root = methods.FindFirstChild(ServerScriptService, "Server") or (function() local f = create("Folder", "Server"); f.Parent = ServerScriptService; return f end)()
	else
		root = methods.FindFirstChild(StarterPlayerScripts, "Client") or (function() local f = create("Folder", "Client"); f.Parent = StarterPlayerScripts; return f end)()
	end
	local cur = root
	for i = 2, #parts - 1 do
		local nxt = methods.FindFirstChild(cur, parts[i])
		if not nxt then
			nxt = create("Folder", parts[i])
			nxt.Parent = cur
		end
		cur = nxt
	end
	local name = parts[#parts]
	local inst = create(class, name)
	inst.Parent = cur
	files[inst] = path
	return inst
end
function M.scriptFor(path)
	for inst, p in files do
		if p == path then return inst end
	end
	error("unregistered script " .. path)
end
function M.require(inst)
	local path = files[inst]
	if not path then
		error("require: not a registered ModuleScript: " .. tostring(inst), 2)
	end
	return require("./" .. path)
end

M.G = {
	game = game, workspace = Workspace, Instance = Instance, Enum = Enum, Vector3 = V3, Vector2 = V2, CFrame = CF, Color3 = C3,
	UDim = UD, UDim2 = UD2, NumberRange = NR, NumberSequence = NS, NumberSequenceKeypoint = NSK, ColorSequence = CS,
	ColorSequenceKeypoint = CSK, TweenInfo = TI, Region3 = R3, Random = Rnd, RaycastParams = RP, task = task, os = M.os,
	typeof = function(v)
		if type(v) == "table" then
			if data[v] then return "Instance" end
			local t = v._t
			if t then return t end
		end
		return type(v)
	end,
	warn = function(...)
		M.warnings = M.warnings or {}
		local parts = {}
		for _, v in table.pack(...) do table.insert(parts, tostring(v)) end
		table.insert(M.warnings, table.concat(parts, " "))
	end,
}
M.game = game
M.services = services
M.data = data
M.methods = methods
M.getSignal = getSignal
M.isA = isA
M.v3, M.cf = v3, cf

return M
