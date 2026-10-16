-- Serialises the baker's records to an .rbxmx model. Property names follow Roblox's XML format; `Material`/`shape`
-- are written as numeric enum tokens. Output is produced in chunks via emit() so it never builds one giant string.
local Serialize = {}

local MATERIAL = {
	Plastic = 256, SmoothPlastic = 272, Neon = 288, Wood = 512, WoodPlanks = 528, Marble = 784, Basalt = 788, Slate = 800,
	CrackedLava = 804, Concrete = 816, Limestone = 820, Granite = 832, Pavement = 836, Brick = 848, Pebble = 864,
	Cobblestone = 880, Rock = 896, Sandstone = 912, CorrodedMetal = 1040, DiamondPlate = 1056, Foil = 1072, Metal = 1088,
	Grass = 1280, LeafyGrass = 1284, Sand = 1296, Fabric = 1312, Snow = 1328, Mud = 1344, Ground = 1360, Asphalt = 1376,
	Salt = 1392, Ice = 1536, Glacier = 1552, Glass = 1568, ForceField = 1584,
}
Serialize.MATERIAL = MATERIAL
local SHAPE = { Ball = 0, Block = 1, Cylinder = 2 }

local function esc(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function f(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local s = ("%.4f"):format(n)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	if s == "-0" or s == "" then
		return "0"
	end
	return s
end

local ref = 0

local function writeNode(node, emit, depth)
	ref += 1
	if node.c == "Folder" then
		emit(('<Item class="Folder" referent="RBX%d"><Properties><string name="Name">%s</string></Properties>'):format(ref, esc(node.n)))
		for _, k in node.kids do
			writeNode(k, emit, depth + 1)
		end
		emit("</Item>")
		return
	end
	local mat = MATERIAL[node.mat]
	assert(mat, "unknown material " .. tostring(node.mat))
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = node.cf:GetComponents()
	local col = node.col
	local rgb = (math.floor(col[1] + 0.5) * 65536) + (math.floor(col[2] + 0.5) * 256) + math.floor(col[3] + 0.5)
	local parts = {
		('<Item class="Part" referent="RBX%d"><Properties><string name="Name">%s</string>'):format(ref, esc(node.n)),
		"<bool name=\"Anchored\">true</bool>",
		("<bool name=\"CanCollide\">%s</bool>"):format(node.collide and "true" or "false"),
		("<bool name=\"CanTouch\">%s</bool>"):format(node.touch and "true" or "false"),
		("<bool name=\"CanQuery\">%s</bool>"):format(node.query and "true" or "false"),
		"<bool name=\"CastShadow\">false</bool>",
		("<Color3uint8 name=\"Color3uint8\">%d</Color3uint8>"):format(4278190080 + rgb),
		("<token name=\"Material\">%d</token>"):format(mat),
		("<token name=\"shape\">%d</token>"):format(SHAPE[node.shape]),
		("<Vector3 name=\"size\"><X>%s</X><Y>%s</Y><Z>%s</Z></Vector3>"):format(f(node.s[1]), f(node.s[2]), f(node.s[3])),
		("<CoordinateFrame name=\"CFrame\"><X>%s</X><Y>%s</Y><Z>%s</Z><R00>%s</R00><R01>%s</R01><R02>%s</R02><R10>%s</R10><R11>%s</R11><R12>%s</R12><R20>%s</R20><R21>%s</R21><R22>%s</R22></CoordinateFrame>"):format(f(x), f(y), f(z), f(r00), f(r01), f(r02), f(r10), f(r11), f(r12), f(r20), f(r21), f(r22)),
	}
	if node.tr and node.tr > 0 then
		table.insert(parts, ("<float name=\"Transparency\">%s</float>"):format(f(node.tr)))
	end
	if node.ref and node.ref > 0 then
		table.insert(parts, ("<float name=\"Reflectance\">%s</float>"):format(f(node.ref)))
	end
	table.insert(parts, "</Properties></Item>")
	emit(table.concat(parts))
end

function Serialize.write(root, emit: (string) -> ())
	ref = 0
	emit('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')
	writeNode(root, emit, 0)
	emit("</roblox>")
end

return Serialize
