-- Menu manager: exactly one full panel is open at a time.
local Menus = {}

local panels: { [string]: { frame: Frame, onOpen: (() -> ())? } } = {}
local current: string? = nil

function Menus.register(name: string, frame: Frame, onOpen: (() -> ())?)
	panels[name] = { frame = frame, onOpen = onOpen }
end

function Menus.close()
	if current then
		panels[current].frame.Visible = false
		current = nil
	end
end

function Menus.open(name: string)
	local p = panels[name]
	if not p then
		return
	end
	Menus.close()
	current = name
	if p.onOpen then
		p.onOpen()
	end
	p.frame.Visible = true
end

function Menus.toggle(name: string)
	if current == name then
		Menus.close()
	else
		Menus.open(name)
	end
end

function Menus.current(): string?
	return current
end

return Menus
