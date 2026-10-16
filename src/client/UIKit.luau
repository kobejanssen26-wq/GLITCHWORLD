-- Themed UI factory + helpers shared by every panel. All interfaces are real Roblox GUI objects.
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = {}

UIKit.theme = {
	bg = Color3.fromRGB(16, 12, 34),
	panel = Color3.fromRGB(28, 22, 58),
	panel2 = Color3.fromRGB(46, 38, 86),
	cyan = Color3.fromRGB(70, 240, 255),
	magenta = Color3.fromRGB(255, 70, 200),
	gold = Color3.fromRGB(255, 215, 90),
	good = Color3.fromRGB(110, 235, 140),
	bad = Color3.fromRGB(255, 96, 116),
	warn = Color3.fromRGB(255, 200, 80),
	text = Color3.fromRGB(244, 242, 255),
	dim = Color3.fromRGB(165, 158, 198),
	fontTitle = Enum.Font.FredokaOne,
	font = Enum.Font.GothamMedium,
	fontBold = Enum.Font.GothamBold,
}
local T = UIKit.theme

function UIKit.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UIKit.factor(): number
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(vp.X / 1100, vp.Y / 620), 0.85, 1.35)
end

function UIKit.px(n: number): number
	return math.max(11, math.floor(n * UIKit.factor() + 0.5))
end

function UIKit.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(r: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function UIKit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", { Color = color or T.panel2, Thickness = thickness or 1.5, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UIKit.pad(px: number): UIPadding
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	})
end

function UIKit.label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or T.text
	props.Font = props.Font or T.font
	props.TextSize = props.TextSize or UIKit.px(15)
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextWrapped = if props.TextWrapped == nil then true else props.TextWrapped
	return UIKit.new("TextLabel", props)
end

function UIKit.title(props: { [string]: any }): TextLabel
	props.Font = T.fontTitle
	return UIKit.label(props)
end

function UIKit.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	return UIKit.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical, Parent = parent,
	})
end

function UIKit.clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") and not c:IsA("UIGridLayout") and not c:IsA("UISizeConstraint") then
			c:Destroy()
		end
	end
end

function UIKit.scroll(props: { [string]: any }): ScrollingFrame
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = props.ScrollBarThickness or 5
	props.ScrollBarImageColor3 = T.magenta
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.CanvasSize = UDim2.new()
	props.ScrollingDirection = Enum.ScrollingDirection.Y
	return UIKit.new("ScrollingFrame", props)
end

UIKit.onClickSound = nil :: (() -> ())?

-- style: primary (cyan) | gold | ghost | danger | disabled
function UIKit.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local style = props.style or "primary"
	props.style = nil
	local base, fg
	if style == "primary" then
		base, fg = T.cyan, Color3.fromRGB(14, 10, 30)
	elseif style == "gold" then
		base, fg = T.gold, Color3.fromRGB(40, 24, 0)
	elseif style == "danger" then
		base, fg = T.bad, Color3.new(1, 1, 1)
	elseif style == "disabled" then
		base, fg = T.panel2, T.dim
	else
		base, fg = T.panel2, T.text
	end
	props.BackgroundColor3 = props.BackgroundColor3 or base
	props.TextColor3 = props.TextColor3 or fg
	props.Font = props.Font or T.fontBold
	props.TextSize = props.TextSize or UIKit.px(15)
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local b: TextButton = UIKit.new("TextButton", props, { UIKit.corner(10) })
	local normal = b.BackgroundColor3
	local hover = normal:Lerp(Color3.new(1, 1, 1), 0.2)
	local function tween(color: Color3)
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = color }):Play()
	end
	b.MouseEnter:Connect(function()
		if style ~= "disabled" then
			tween(hover)
		end
	end)
	b.MouseLeave:Connect(function()
		tween(normal)
	end)
	b.MouseButton1Down:Connect(function()
		if style ~= "disabled" then
			tween(normal:Lerp(Color3.new(0, 0, 0), 0.18))
		end
	end)
	b.MouseButton1Up:Connect(function()
		tween(normal)
	end)
	if onClick then
		b.Activated:Connect(function()
			if UIKit.onClickSound then
				UIKit.onClickSound()
			end
			onClick()
		end)
	end
	return b
end

function UIKit.bar(props: { [string]: any }, fillColor: Color3?)
	local root = UIKit.new("Frame", {
		BackgroundColor3 = T.bg, BorderSizePixel = 0, Size = props.Size or UDim2.new(1, 0, 0, 14), Position = props.Position,
		LayoutOrder = props.LayoutOrder, Parent = props.Parent,
	}, { UIKit.corner(6), UIKit.stroke(T.panel2, 1) })
	local fill = UIKit.new("Frame", { BackgroundColor3 = fillColor or T.cyan, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = root }, { UIKit.corner(6) })
	local text = UIKit.label({
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = props.TextSize or UIKit.px(12),
		Font = T.fontBold, Text = "", TextWrapped = false, ZIndex = 3, Parent = root,
	})
	local function set(fraction: number, label: string?, color: Color3?)
		TweenService:Create(fill, TweenInfo.new(0.18), { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }):Play()
		if label then
			text.Text = label
		end
		if color then
			fill.BackgroundColor3 = color
		end
	end
	return root, set
end

function UIKit.panel(gui: Instance, title: string, onClose: () -> ()): (Frame, Frame)
	local frame = UIKit.new("Frame", {
		Name = title, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = T.bg, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 10, Parent = gui,
	}, {
		UIKit.corner(16), UIKit.stroke(T.magenta, 2.5, 0.2),
		UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(880, 580), MinSize = Vector2.new(300, 220) }),
	})
	UIKit.title({ Size = UDim2.new(1, -70, 0, UIKit.px(40)), Position = UDim2.fromOffset(18, 4), Text = title, TextSize = UIKit.px(26), TextColor3 = T.cyan, Parent = frame, TextWrapped = false })
	UIKit.button({
		Size = UDim2.fromOffset(UIKit.px(36), UIKit.px(30)), Position = UDim2.new(1, -UIKit.px(36) - 12, 0, 8), Text = "X", style = "ghost", Parent = frame,
	}, onClose)
	local top = UIKit.px(46)
	local content = UIKit.new("Frame", { Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -top), BackgroundTransparency = 1, Parent = frame })
	return frame, content
end

function UIKit.fmt(n: number): string
	n = math.floor(n)
	if n >= 1e12 then
		return ("%.2fT"):format(n / 1e12)
	elseif n >= 1e9 then
		return ("%.2fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.2fM"):format(n / 1e6)
	elseif n >= 1e5 then
		return ("%.1fK"):format(n / 1e3)
	end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

function UIKit.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

return UIKit
