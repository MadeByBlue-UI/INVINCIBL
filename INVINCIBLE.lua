local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local CONFIG = {
	MainLogo = "rbxassetid://108648429085459",
	LogoShrink = 0.75,

	Header = "Get INVINCIBLE Script",
	HeaderFont = Enum.Font.GothamBold,
	HeaderSize = 30,
	Tracking = 3,

	InfoLink = "",
	IconImage = "rbxassetid://108648429085459",
	ButtonText = "Continue",
	CopiedText = "Welcome to INVINCIBLE",
	ButtonFont = Enum.Font.GothamBold,
	LabelFont = Enum.Font.GothamMedium,

	AutoClose = false,
	Duration = 9,
	Speed = 1.45,
	WaitForLoad = false,
	Sound = "",
	ShatterSound = "",
	ClickSound = "",
	Quality = "Auto",

	Grid = 90,
	MaxTiles = 420,

	HudCorners = true,
	Footer = "I N V I N C I B L E Ftap Script",

	Theme = {
		BgTop = Color3.fromRGB(3, 3, 3),
		BgMid = Color3.fromRGB(13, 13, 13),
		BgBottom = Color3.fromRGB(2, 2, 2),
		AccentA = Color3.fromRGB(125, 125, 125),
		AccentB = Color3.fromRGB(88, 88, 88),
		AccentC = Color3.fromRGB(175, 175, 175),
	},

	SnowFar = 80,
	SnowMid = 44,
	SnowNear = 12,
	Bokeh = 7,
	Crystals = 24,
	Rays = 24,
	Burst = 30,
}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

ReplicatedFirst:RemoveDefaultLoadingScreen()

local Q = Enum.EasingStyle
local OUT, IN, INOUT = Enum.EasingDirection.Out, Enum.EasingDirection.In, Enum.EasingDirection.InOut

local savedCore = {}
local coreHidden = false

local function hideCoreGui()
	for _, t in ipairs(Enum.CoreGuiType:GetEnumItems()) do
		if t ~= Enum.CoreGuiType.All then
			local ok, state = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, t)
			if ok then
				savedCore[t] = state
			end
		end
	end
	coreHidden = true
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
end

local function restoreCoreGui()
	if not coreHidden then
		return
	end
	coreHidden = false
	if next(savedCore) == nil then
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
		return
	end
	for t, state in pairs(savedCore) do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, state)
	end
	table.clear(savedCore)
end

local gui, conn, skipConn
local finished = false
local prevMouseIcon

local function cleanup()
	if finished then
		return
	end
	finished = true
	if conn then
		conn:Disconnect()
	end
	if skipConn then
		skipConn:Disconnect()
	end
	pcall(RunService.UnbindFromRenderStep, RunService, "InvincibleIntroMouse")
	if prevMouseIcon ~= nil then
		UserInputService.MouseIconEnabled = prevMouseIcon
	end
	if gui then
		gui:Destroy()
	end
	restoreCoreGui()
end

if CONFIG.AutoClose then
	task.delay(CONFIG.Duration + 15, cleanup)
end

local function downloadBytes(url)
	local req = request or http_request or (syn and syn.request) or (http and http.request)
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and type(res) == "table" and type(res.Body) == "string" and #res.Body > 8 then
			if res.StatusCode == nil or res.StatusCode == 200 then
				return res.Body
			end
		end
	end
	local ok, res = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(res) == "string" and #res > 8 then
		return res
	end
	return nil
end

local function fetchRemoteImage(url)
	local gca = getcustomasset or getsynasset
	if not (gca and writefile) then
		return nil
	end
	local function enc(str)
		return (str:gsub("[^%w%-_%.~]", function(c)
			return string.format("%%%02X", string.byte(c))
		end))
	end
	local bare = enc((url:gsub("^https?://", "")))
	local candidates = {}
	candidates[#candidates + 1] = "https://wsrv.nl/?output=png&url=" .. bare
	candidates[#candidates + 1] = "https://images.weserv.nl/?output=png&url=" .. bare
	candidates[#candidates + 1] = url
	for _, u in ipairs(candidates) do
		local body = downloadBytes(u)
		if body then
			local isPng = body:sub(2, 4) == "PNG"
			local isJpg = body:byte(1) == 0xFF and body:byte(2) == 0xD8
			if isPng or isJpg then
				local file = "invincible_icon." .. (isJpg and "jpg" or "png")
				if pcall(writefile, file, body) then
					local ok, asset = pcall(gca, file)
					if ok and asset then
						return asset
					end
				end
			end
		end
	end
	return nil
end

local function main()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	while not camera do
		task.wait()
		camera = workspace.CurrentCamera
	end
	do
		local tries = 0
		while camera.ViewportSize.X < 100 and tries < 60 do
			task.wait()
			tries += 1
		end
	end

	local old = playerGui:FindFirstChild("InvincibleIntro")
	if old then
		old:Destroy()
	end

	hideCoreGui()

	local rng = Random.new()
	local vp = camera.ViewportSize
	local cx, cy = vp.X / 2, vp.Y / 2
	local maxD = math.sqrt(cx * cx + cy * cy)
	local function computeS(v)
		return math.clamp(math.min(v.Y / 1000, v.X / 640), 0.42, 1.5)
	end
	local S = computeS(vp)
	local function U(n)
		return math.floor(n * S + 0.5)
	end

	local lowEnd = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if CONFIG.Quality == "Low" then
		lowEnd = true
	end
	local density = lowEnd and 0.6 or 1
	local hasMouse = UserInputService.MouseEnabled

	local function lerp(a, b, t)
		return a + (b - a) * t
	end
	local function clamp01(x)
		return math.clamp(x, 0, 1)
	end

	local function new(className, props, children)
		local inst = Instance.new(className)
		local parent
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
		if children then
			for _, child in ipairs(children) do
				child.Parent = inst
			end
		end
		inst.Parent = parent
		return inst
	end

	local function round(r)
		return new("UICorner", { CornerRadius = r or UDim.new(1, 0) })
	end

	local function gradient(keys, rotation)
		local seq = {}
		for i, k in ipairs(keys) do
			seq[i] = NumberSequenceKeypoint.new(k[1], k[2])
		end
		return new("UIGradient", { Transparency = NumberSequence.new(seq), Rotation = rotation or 0 })
	end

	local function destroyer(inst)
		return function()
			inst:Destroy()
		end
	end

	local anims = {}
	local function at(t0, dur, style, dir, fn, done)
		anims[#anims + 1] = { t0 = t0, dur = dur, style = style, dir = dir, fn = fn, done = done }
	end

	local T_BURST, T_HILLS, T_LOGO = 0.2, 0.45, 0.55
	local T_SHATTER = 1.9
	local T_SHRINK = 1.6
	local T_TITLE = 3.0
	local T_ICON = T_TITLE + 0.9
	local T_BTN = T_ICON + 0.5
	local LS = CONFIG.LogoShrink
	local L_Y = -130

	gui = new("ScreenGui", {
		Name = "InvincibleIntro",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 999999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	prevMouseIcon = UserInputService.MouseIconEnabled
	UserInputService.MouseIconEnabled = true
	new("TextButton", {
		Name = "MouseUnlock",
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		Parent = gui,
	})
	RunService:BindToRenderStep("InvincibleIntroMouse", Enum.RenderPriority.Last.Value, function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)

	local root = new("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
		Parent = gui,
	})

	local function layer(name, z, parent)
		return new("Frame", {
			Name = name,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = z,
			Parent = parent or root,
		})
	end

	new("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = root,
	}, {
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, CONFIG.Theme.BgTop),
				ColorSequenceKeypoint.new(0.55, CONFIG.Theme.BgMid),
				ColorSequenceKeypoint.new(1, CONFIG.Theme.BgBottom),
			}),
			Rotation = 90,
		}),
	})

	local bgLayer = new("Frame", {
		Name = "Atmosphere",
		Size = UDim2.fromScale(1.14, 1.14),
		Position = UDim2.fromScale(-0.07, -0.07),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
	local tileLayer = layer("Tiles", 3)
	local lightLayer = layer("Light", 4)
	local fogLayer = layer("Fog", 5)
	local snowBack = layer("SnowBack", 6)
	local hillLayer = layer("Hills", 7)
	local edgeLayer = layer("Edges", 8)
	local content = layer("Content", 9)
	local snowFront = layer("SnowFront", 10)
	local overlay = layer("Overlay", 11)

	local hillFar = layer("Far", 1, hillLayer)
	local hillMid = layer("Mid", 2, hillLayer)
	local hillNear = layer("Near", 3, hillLayer)

	local G = math.max(48, U(CONFIG.Grid))
	G = math.max(G, math.floor(math.sqrt(vp.X * vp.Y / (CONFIG.MaxTiles * (lowEnd and 0.65 or 1)))))
	local cols = math.ceil(vp.X / G) + 2
	local rows = math.ceil(vp.Y / G) + 2
	local ox = cx - cols * G / 2
	local oy = cy - rows * G / 2

	local SHATTER_WAVE = 1.3
	local shatterSpan = 0
	local tiles = {}
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local tcx, tcy = ox + c * G + G / 2, oy + r * G + G / 2
			local dx, dy = tcx - cx, tcy - cy
			local d = math.sqrt(dx * dx + dy * dy)
			local checker = (r + c) % 2 == 0
			local rest = 0.9 + math.min(d / maxD, 1) * 0.07 - (checker and 0.03 or 0)
			local tl = {
				frame = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(tcx, tcy),
					Size = UDim2.fromOffset(G - 2, G - 2),
					BackgroundColor3 = BLACK,
					BorderSizePixel = 0,
					Parent = tileLayer,
				}),
				d = d,
				rest = rest,
				cur = 1,
				x = tcx,
				y = tcy,
				delay = d / maxD * SHATTER_WAVE + rng:NextNumber(0, 0.24),
				dur = rng:NextNumber(1.0, 1.4),
				fall = rng:NextNumber(40, 120) * S,
				drift = rng:NextNumber(-12, 12) * S,
				spin = rng:NextNumber(-25, 25),
				state = 0,
			}
			shatterSpan = math.max(shatterSpan, tl.delay + tl.dur)
			tiles[#tiles + 1] = tl
		end
	end

	local band = maxD * 0.2
	at(T_BURST, 1.2, Q.Quart, OUT, function(e)
		local R = e * (maxD + band) * 1.05
		for i = 1, #tiles do
			local tl = tiles[i]
			local v
			if tl.d > R + band * 0.25 then
				v = 1
			else
				local inten = clamp01(1 - math.abs(tl.d - R) / band)
				v = lerp(tl.rest, 0.35, inten * inten)
			end
			if v ~= tl.cur then
				tl.cur = v
				local g = 1 - v
				tl.frame.BackgroundColor3 = Color3.new(g, g, g)
			end
		end
	end)

	at(T_SHATTER, shatterSpan, Q.Linear, OUT, function(e)
		local tt = e * shatterSpan
		for i = 1, #tiles do
			local tl = tiles[i]
			if tl.state < 2 then
				local p = (tt - tl.delay) / tl.dur
				if p > 0 then
					if p >= 1 then
						tl.state = 2
						tl.frame.Visible = false
					else
						tl.state = 1
						local fr = tl.frame
						local k = p * p * (3 - 2 * p)
						local sz = (G - 2) * (1 - 0.22 * k)
						fr.Position = UDim2.fromOffset(tl.x + tl.drift * k, tl.y + tl.fall * k)
						fr.Size = UDim2.fromOffset(sz, sz)
						fr.Rotation = tl.spin * k
						fr.BackgroundTransparency = k
					end
				end
			end
		end
	end, function()
		tileLayer:Destroy()
		table.clear(tiles)
	end)

	local bands = {}
	local bloomScale
	do
		local TH = CONFIG.Theme

		local horizon = new("Frame", {
			Name = "Horizon",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.55),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = bgLayer,
		}, {
			new("UIGradient", {
				Color = ColorSequence.new(TH.AccentB, TH.AccentA),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.55, 0.965),
					NumberSequenceKeypoint.new(1, 0.84),
				}),
				Rotation = 90,
			}),
		})
		at(T_SHATTER + 0.3, 2.6, Q.Sine, OUT, function(e)
			horizon.BackgroundTransparency = 1 - e
		end)

		local bandDefs = {
			{ a = TH.AccentA, b = TH.AccentB, rot = 28, speed = 0.11, amp = 0.32, phase = 0.0, peak = 0.82, width = 0.30 },
			{ a = TH.AccentB, b = TH.AccentC, rot = -34, speed = 0.08, amp = 0.38, phase = 2.1, peak = 0.88, width = 0.26 },
			{ a = TH.AccentC, b = TH.AccentA, rot = 62, speed = 0.06, amp = 0.30, phase = 4.2, peak = 0.90, width = 0.34 },
		}
		for i = 1, lowEnd and 2 or #bandDefs do
			local d = bandDefs[i]
			local w, pk = d.width, d.peak
			local grad = new("UIGradient", {
				Color = ColorSequence.new(d.a, d.b),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5 - w, 1),
					NumberSequenceKeypoint.new(0.5 - w * 0.5, lerp(1, pk, 0.4)),
					NumberSequenceKeypoint.new(0.5, pk),
					NumberSequenceKeypoint.new(0.5 + w * 0.5, lerp(1, pk, 0.4)),
					NumberSequenceKeypoint.new(0.5 + w, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = d.rot,
			})
			local fr = new("Frame", {
				Name = "Aurora" .. i,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 1 + i,
				Parent = bgLayer,
			}, { grad })
			bands[i] = { grad = grad, rot = d.rot, speed = d.speed, amp = d.amp, phase = d.phase }
			at(T_SHATTER + 0.2 + 0.3 * i, 2.6, Q.Sine, OUT, function(e)
				fr.BackgroundTransparency = 1 - e
			end)
		end

		local bloom = new("Frame", {
			Name = "Bloom",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = bgLayer,
		})
		bloomScale = new("UIScale", { Scale = 0.15, Parent = bloom })
		local LAYERS, STEP = 16, 0.024
		local circles = {}
		for k = 1, LAYERS do
			local ratio = k / LAYERS
			local d = maxD * 2.3 * ratio ^ 1.35
			circles[k] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(),
				Size = UDim2.fromOffset(d, d),
				BackgroundColor3 = TH.AccentA:Lerp(WHITE, (1 - ratio) * 0.3),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = bloom,
			}, { round() })
		end
		at(T_SHATTER + 0.1, 2.6, Q.Sine, OUT, function(e)
			bloomScale.Scale = lerp(0.15, 1, e)
			local a = 1 - e * STEP
			for k = 1, LAYERS do
				circles[k].BackgroundTransparency = a
			end
		end)
	end

	do
		for i = 1, 5 do
			local g = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = lightLayer,
			}, { round() })
			at(T_BURST, 1.3, Q.Sine, OUT, function(e)
				local s = lerp(40, U(240 + i * 190), e)
				g.Size = UDim2.fromOffset(s, s)
				g.BackgroundTransparency = lerp(0.6 + i * 0.07, 0.94 + i * 0.012, e)
			end, destroyer(g))
		end

		local rayCount = math.floor(CONFIG.Rays * (lowEnd and 0.7 or 1))
		for i = 1, rayCount do
			local long = i % 2 == 0
			local len = maxD * (long and rng:NextNumber(0.9, 1.1) or rng:NextNumber(0.35, 0.7))
			local thick = long and math.max(2, U(3)) or 1
			local a0 = long and 0.1 or 0.45
			local ray = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(0, thick),
				Rotation = (i - 1) * (360 / rayCount) + rng:NextNumber(-3, 3),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = lightLayer,
			}, { gradient({ { 0, 0 }, { 1, 1 } }) })
			at(T_BURST, 0.85, Q.Quart, OUT, function(e)
				ray.Size = UDim2.fromOffset(len * e, thick)
				ray.BackgroundTransparency = lerp(a0, 1, e)
			end, destroyer(ray))
		end

		for _ = 1, math.floor(CONFIG.Burst * density) do
			local a = rng:NextNumber() * math.pi * 2
			local dist = rng:NextNumber(0.25, 0.75) * maxD
			local sz = rng:NextInteger(2, 5)
			local dx, dy = math.cos(a) * dist, math.sin(a) * dist
			local p = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(sz, sz),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = lightLayer,
			}, { round() })
			at(T_BURST + rng:NextNumber(0, 0.1), rng:NextNumber(0.9, 1.5), Q.Quart, OUT, function(e)
				p.Position = UDim2.new(0.5, dx * e, 0.5, dy * e)
				p.BackgroundTransparency = clamp01(0.1 + e * e * 0.95)
			end, destroyer(p))
		end

		local flare = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 2),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = lightLayer,
		}, { gradient({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }) })
		at(T_BURST, 0.8, Q.Quart, OUT, function(e)
			flare.Size = UDim2.fromOffset(vp.X * 1.15 * e, 2)
			flare.BackgroundTransparency = clamp01(e * e * 1.1)
		end, destroyer(flare))

		local flareV = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(2, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = lightLayer,
		}, { gradient({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }, 90) })
		at(T_BURST, 0.7, Q.Quart, OUT, function(e)
			flareV.Size = UDim2.fromOffset(2, vp.Y * 0.8 * e)
			flareV.BackgroundTransparency = clamp01(e * e * 1.1)
		end, destroyer(flareV))

		for i = 0, 2 do
			local ring = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(40, 40),
				BackgroundTransparency = 1,
				Parent = lightLayer,
			}, { round() })
			local stroke = new("UIStroke", { Color = WHITE, Thickness = 3, Transparency = 1, Parent = ring })
			at(T_BURST + i * 0.12, 1.6, Q.Sine, OUT, function(e)
				local s = lerp(U(60), maxD * 2.2, e)
				ring.Size = UDim2.fromOffset(s, s)
				stroke.Transparency = lerp(0.3, 1, e * e * (3 - 2 * e))
				stroke.Thickness = lerp(3, 0.4, e)
			end, destroyer(ring))
		end

		local flash = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 20,
			Parent = overlay,
		})
		at(T_BURST, 0.5, Q.Quad, OUT, function(e)
			flash.BackgroundTransparency = lerp(0.55, 1, e)
		end, destroyer(flash))

		local sweep = new("Frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.fromScale(0, -0.05),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = overlay,
		})
		local sweepTrail = new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.new(1, 0, 0, U(150)),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = sweep,
		}, { gradient({ { 0, 1 }, { 1, 0.9 } }, 90) })
		at(T_BURST + 0.05, 0.85, Q.Sine, INOUT, function(e)
			sweep.Position = UDim2.fromScale(0, lerp(-0.05, 1.05, e))
			local a = clamp01((e - 0.7) / 0.3)
			sweep.BackgroundTransparency = lerp(0.35, 1, a)
			sweepTrail.BackgroundTransparency = lerp(0, 1, a)
		end, destroyer(sweep))
	end

	local fog = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.4),
		BackgroundColor3 = Color3.fromRGB(225, 225, 225),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = fogLayer,
	}, { gradient({ { 0, 1 }, { 1, 0.86 } }, 90) })
	at(0.6, 1.0, Q.Sine, OUT, function(e)
		fog.BackgroundTransparency = lerp(1, 0, e)
	end)

	do
		local function edge(size, position, anchor, rotation)
			new("Frame", {
				Size = size,
				Position = position,
				AnchorPoint = anchor,
				BackgroundColor3 = BLACK,
				BorderSizePixel = 0,
				Parent = edgeLayer,
			}, { gradient({ { 0, 0.05 }, { 1, 1 } }, rotation) })
		end
		edge(UDim2.fromScale(1, 0.28), UDim2.fromScale(0, 0), Vector2.new(0, 0), 90)
		edge(UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0)
		edge(UDim2.fromScale(0.18, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180)
	end

	local hillDefs = {
		{ group = hillFar, cx = 0.22, d = 0.95, rise = 0.115, top = 46, bot = 8, rim = 0.8 },
		{ group = hillFar, cx = 0.82, d = 1.10, rise = 0.100, top = 46, bot = 8, rim = 0.8 },
		{ group = hillMid, cx = 0.55, d = 1.30, rise = 0.080, top = 64, bot = 10, rim = 0.64 },
		{ group = hillNear, cx = 0.04, d = 0.85, rise = 0.050, top = 86, bot = 14, rim = 0.5 },
		{ group = hillNear, cx = 0.98, d = 0.95, rise = 0.058, top = 86, bot = 14, rim = 0.5 },
	}
	local hillObjs = {}
	for i, h in ipairs(hillDefs) do
		local D = vp.X * h.d
		local rise = vp.Y * h.rise
		local px = vp.X * h.cx
		local frame = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(px, vp.Y),
			Size = UDim2.fromOffset(D, D),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Parent = h.group,
		}, {
			round(),
			new("UIGradient", {
				Color = ColorSequence.new(
					Color3.fromRGB(h.top, h.top, h.top),
					Color3.fromRGB(h.bot, h.bot, h.bot)
				),
				Rotation = 90,
			}),
		})
		local stroke = new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 1, Parent = frame }, {
			gradient({ { 0, 0 }, { 0.12, 0.6 }, { 0.3, 1 }, { 1, 1 } }, 90),
		})
		hillObjs[#hillObjs + 1] = { frame = frame, stroke = stroke, px = px, rise = rise, rim = h.rim, dd = h.d, cxr = h.cx, riser = h.rise }
		at(T_HILLS + i * 0.07, 0.9, Q.Quart, OUT, function(e)
			frame.Position = UDim2.fromOffset(px, lerp(vp.Y, vp.Y - rise, e))
			stroke.Transparency = lerp(1, h.rim, e)
		end)
	end

	local flakes = {}
	local fadeFlakes = {}

	local function addFlake(parent, size, z, alpha, startAbove, fade, opts)
		size = math.max(2, size)
		local f = {
			frame = new("Frame", {
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = fade and 1 or alpha,
				BorderSizePixel = 0,
				Parent = parent,
			}, size >= 4 and { round() } or nil),
			s = size,
			z = z,
			base = alpha,
			x = rng:NextNumber() * vp.X,
			y = startAbove and (-size - rng:NextNumber() * vp.Y * 0.7) or (rng:NextNumber() * vp.Y),
			vy = 0,
			sway = rng:NextNumber(8, 26) * z,
			freq = rng:NextNumber(0.8, 2),
			phase = rng:NextNumber() * 6.28,
			acc = 0,
			half = opts and opts.half or false,
			cull = opts and opts.cull or false,
			bokeh = opts and opts.bokeh or false,
		}
		flakes[#flakes + 1] = f
		if fade then
			fadeFlakes[#fadeFlakes + 1] = f
		end
		return f
	end

	for _ = 1, math.floor(CONFIG.SnowFar * density) do
		local f = addFlake(
			snowBack,
			math.floor(rng:NextNumber(2, 3.4) * S),
			0.5,
			rng:NextNumber(0.55, 0.8),
			false,
			true,
			{ half = true, cull = true }
		)
		f.vy = rng:NextNumber(45, 80) * S
	end
	for _ = 1, math.floor(CONFIG.SnowMid * density) do
		local f = addFlake(
			snowBack,
			math.floor(rng:NextNumber(3.4, 6) * S),
			1,
			rng:NextNumber(0.3, 0.6),
			false,
			true,
			{ cull = true }
		)
		f.vy = rng:NextNumber(90, 140) * S
	end
	for _ = 1, math.floor(CONFIG.Bokeh * density) do
		local f = addFlake(
			snowBack,
			math.floor(rng:NextNumber(46, 110) * S),
			1.6,
			rng:NextNumber(0.95, 0.975),
			false,
			true,
			{ half = true, cull = true, bokeh = true }
		)
		f.vy = rng:NextNumber(18, 40) * S
	end
	for _ = 1, math.floor(CONFIG.SnowNear * density) do
		local f = addFlake(snowFront, math.floor(rng:NextNumber(10, 18) * S), 2, rng:NextNumber(0.72, 0.88), true, false)
		f.vy = rng:NextNumber(190, 280) * S
	end

	at(0, 0.8, Q.Sine, OUT, function(e)
		for i = 1, #fadeFlakes do
			local f = fadeFlakes[i]
			f.frame.BackgroundTransparency = 1 - e * (1 - f.base)
		end
	end)

	local function makeCrystal(parent, size, detail, alpha)
		local holder = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		local th = size >= 22 and 2 or 1
		local function bar(len, bx, by, rotDeg)
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, bx, 0.5, by),
				Size = UDim2.fromOffset(math.max(1, len), th),
				Rotation = rotDeg,
				BackgroundColor3 = WHITE,
				BackgroundTransparency = alpha,
				BorderSizePixel = 0,
				Parent = holder,
			})
		end
		local tiers
		if detail == 2 then
			tiers = { { 0.42, 0.24 }, { 0.72, 0.16 } }
		elseif detail == 1 then
			tiers = { { 0.58, 0.22 } }
		else
			tiers = {}
		end
		for k = 0, 2 do
			local phi = math.rad(k * 60)
			bar(size, 0, 0, k * 60)
			for side = -1, 1, 2 do
				local a0 = phi + (side == 1 and 0 or math.pi)
				for _, tr in ipairs(tiers) do
					local r = size * 0.5 * tr[1]
					local L = size * tr[2]
					local ax, ay = math.cos(a0) * r, math.sin(a0) * r
					for sgn = -1, 1, 2 do
						local psi = a0 + sgn * math.rad(52)
						bar(L, ax + math.cos(psi) * L / 2, ay + math.sin(psi) * L / 2, math.deg(psi))
					end
				end
			end
		end
		if detail == 2 then
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(4, 4),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = alpha,
				BorderSizePixel = 0,
				Parent = holder,
			}, { round() })
		end
		return holder
	end

	local crystals = {}
	local crystalCount = math.floor(CONFIG.Crystals * (lowEnd and 0.7 or 1))
	for i = 1, crystalCount do
		local detail = i <= 3 and 2 or (i <= 7 and 1 or 0)
		local size, alpha, vy
		if detail == 2 then
			size = math.floor(rng:NextInteger(24, 30) * S)
			alpha = rng:NextNumber(0.1, 0.25)
			vy = rng:NextNumber(45, 70) * S
		elseif detail == 1 then
			size = math.floor(rng:NextInteger(15, 20) * S)
			alpha = rng:NextNumber(0.2, 0.4)
			vy = rng:NextNumber(55, 95) * S
		else
			size = math.floor(rng:NextInteger(9, 13) * S)
			alpha = rng:NextNumber(0.3, 0.6)
			vy = rng:NextNumber(65, 110) * S
		end
		size = math.max(size, 8)
		crystals[#crystals + 1] = {
			frame = makeCrystal(detail == 2 and snowFront or snowBack, size, detail, alpha),
			s = size,
			x = rng:NextNumber() * vp.X,
			y = -size - rng:NextNumber() * vp.Y * 0.9,
			vy = vy,
			sway = rng:NextNumber(14, 32),
			freq = rng:NextNumber(0.6, 1.4),
			phase = rng:NextNumber() * 6.28,
			spin = rng:NextNumber(-60, 60),
			rot = rng:NextNumber() * 360,
			hidden = false,
		}
	end

	local twinkles = {}
	local function addTwinkle(parent, pos, base, speed, phase, onAt)
		local holder = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.new(),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		for _, horizontal in ipairs({ true, false }) do
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = horizontal and UDim2.new(1, 0, 0, 1) or UDim2.new(0, 1, 1, 0),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				Parent = holder,
			}, { gradient({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }, horizontal and 0 or 90) })
		end
		twinkles[#twinkles + 1] = { frame = holder, base = base, speed = speed, phase = phase, on = onAt, last = -1 }
	end

	local center = new("Frame", {
		Name = "Center",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		Parent = content,
	}, { new("UIScale", { Scale = S }) })

	local centerScale = center:FindFirstChildOfClass("UIScale")
	at(T_SHRINK, 0.85, Q.Cubic, INOUT, function(e)
		centerScale.Scale = S * lerp(1, LS, e)
		center.Position = UDim2.new(0.5, 0, 0.5, L_Y * S * e)
	end)

	local function centered(size, parent, props)
		props = props or {}
		props.AnchorPoint = Vector2.new(0.5, 0.5)
		props.Position = props.Position or UDim2.new()
		props.Size = UDim2.fromOffset(size, size)
		props.BackgroundTransparency = props.BackgroundTransparency or 1
		props.Parent = parent
		return new("Frame", props)
	end

	local backDisc = centered(200, center, { BackgroundColor3 = WHITE, BorderSizePixel = 0 })
	round().Parent = backDisc
	at(T_LOGO, 0.7, Q.Quart, OUT, function(e)
		local s = lerp(150, 270, e)
		backDisc.Size = UDim2.fromOffset(s, s)
		backDisc.BackgroundTransparency = lerp(1, 0.93, e)
	end)

	local TICKS = lowEnd and 40 or 60
	local LONGEVERY = TICKS / 12
	local tickHolder = centered(340, center)
	local tickList = {}
	for i = 1, TICKS do
		local a = (i / TICKS) * math.pi * 2
		local long = i % LONGEVERY == 0
		tickList[i] = {
			frame = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(170 + math.cos(a) * 164, 170 + math.sin(a) * 164),
				Size = UDim2.fromOffset(2, long and 13 or 5),
				Rotation = math.deg(a) + 90,
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = tickHolder,
			}),
			a = long and 0.2 or 0.6,
		}
	end
	at(T_LOGO, 0.6, Q.Sine, OUT, function(e)
		for i = 1, TICKS do
			local k = clamp01(e * 1.6 - (i / TICKS) * 0.6)
			tickList[i].frame.BackgroundTransparency = lerp(1, tickList[i].a, k)
		end
	end)

	local function arcRing(size, thickness)
		local frame = centered(size, center, nil)
		round().Parent = frame
		local stroke = new("UIStroke", { Color = WHITE, Thickness = thickness, Transparency = 1, Parent = frame })
		local grad = gradient({ { 0, 0 }, { 0.25, 0.9 }, { 0.5, 1 }, { 0.75, 0.9 }, { 1, 0 } })
		grad.Parent = stroke
		return stroke, grad
	end
	local strokeA, gradA = arcRing(300, 2)
	local strokeB, gradB = arcRing(250, 1)
	local strokeC, gradC = arcRing(360, 1)
	at(T_LOGO, 0.6, Q.Sine, OUT, function(e)
		strokeA.Transparency = lerp(1, 0.15, e)
		strokeB.Transparency = lerp(1, 0.5, e)
		strokeC.Transparency = lerp(1, 0.7, e)
	end)

	local orbit = {}
	for i = 1, 3 do
		orbit[i] = centered(i == 1 and 6 or 4, center, { BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0 })
		round().Parent = orbit[i]
	end
	at(T_LOGO + 0.3, 0.5, Q.Sine, OUT, function(e)
		for i = 1, 3 do
			orbit[i].BackgroundTransparency = lerp(1, 0.1 + i * 0.12, e)
		end
	end)

	for _ = 1, 7 do
		local ang = rng:NextNumber() * math.pi * 2
		local rad = rng:NextNumber(125, 245)
		addTwinkle(
			center,
			UDim2.fromOffset(math.cos(ang) * rad, math.sin(ang) * rad),
			rng:NextNumber(10, 20),
			rng:NextNumber(1.4, 3),
			rng:NextNumber() * 6.28,
			T_LOGO + 0.3
		)
	end

	do
		local shockRing = centered(190, center)
		round().Parent = shockRing
		local shockStroke = new("UIStroke", { Color = WHITE, Thickness = 3, Transparency = 1, Parent = shockRing })
		at(T_LOGO + 0.15, 1.1, Q.Sine, OUT, function(e)
			local s = lerp(190, 1000, e)
			shockRing.Size = UDim2.fromOffset(s, s)
			shockStroke.Transparency = lerp(0.1, 1, e * e * (3 - 2 * e))
			shockStroke.Thickness = lerp(3, 0, e)
		end, destroyer(shockRing))
	end

	local logoHolder = centered(210, center)
	local logoScale = new("UIScale", { Scale = 0.25, Parent = logoHolder })

	local function logoImage(color, z)
		return new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = CONFIG.MainLogo,
			ImageColor3 = color,
			ImageTransparency = 1,
			Rotation = -28,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = z,
			Parent = logoHolder,
		})
	end
	local ghostA = logoImage(Color3.fromRGB(120, 120, 120), 1)
	local ghostB = logoImage(Color3.fromRGB(210, 210, 210), 1)
	local logo = logoImage(WHITE, 2)

	at(T_LOGO, 0.3, Q.Sine, OUT, function(e)
		logo.ImageTransparency = 1 - e
	end)
	at(T_LOGO, 0.8, Q.Back, OUT, function(e)
		logoScale.Scale = lerp(0.25, 1, e)
	end)
	at(T_LOGO, 0.7, Q.Quint, OUT, function(e)
		local r = lerp(-28, 0, e)
		logo.Rotation = r
		ghostA.Rotation = r
		ghostB.Rotation = r
	end)
	at(T_LOGO, 0.55, Q.Quint, OUT, function(e)
		local off = lerp(16, 0, e)
		ghostA.Position = UDim2.new(0.5, -off, 0.5, off * 0.2)
		ghostB.Position = UDim2.new(0.5, off, 0.5, -off * 0.2)
		local a = lerp(0.45, 1, e)
		ghostA.ImageTransparency = a
		ghostB.ImageTransparency = a
	end, function()
		ghostA:Destroy()
		ghostB:Destroy()
	end)
	at(T_LOGO + 0.35, 0.3, Q.Linear, OUT, function(e)
		local m = (1 - e) * 6
		logo.Position = UDim2.new(0.5, rng:NextInteger(-1, 1) * m, 0.5, rng:NextInteger(-1, 1) * m * 0.4)
	end, function()
		logo.Position = UDim2.fromScale(0.5, 0.5)
	end)

	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		Parent = content,
	}, { new("UIScale", { Scale = S }) })

	local H_Y = L_Y + math.floor(180 * LS + 47)
	local I_Y = H_Y + 74
	local B_Y = I_Y + 89
	local C_Y = B_Y + 50

	local titleRoot = new("Frame", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, H_Y),
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	local text = CONFIG.Header
	local TS = CONFIG.HeaderSize
	local widths, total = {}, 0
	for i = 1, #text do
		local ch = text:sub(i, i)
		local w
		if ch == " " then
			w = TS * 0.3
		else
			local ok, size = pcall(function()
				return TextService:GetTextSize(ch, TS, CONFIG.HeaderFont, Vector2.new(1000, 1000))
			end)
			w = ok and size.X or TS * 0.55
		end
		widths[i] = w
		total += w + CONFIG.Tracking
	end
	total -= CONFIG.Tracking

	local titleGlow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(total + 220, 90),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = titleRoot,
	}, { round() })
	at(T_TITLE, 0.9, Q.Sine, OUT, function(e)
		titleGlow.BackgroundTransparency = lerp(1, 0.95, e)
	end)

	local letters = {}
	local px = -total / 2
	local DROP = TS * 0.9
	for i = 1, #text do
		local ch = text:sub(i, i)
		if ch ~= " " then
			local label = new("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromOffset(px, DROP),
				Size = UDim2.fromOffset(widths[i], TS * 1.3),
				BackgroundTransparency = 1,
				Text = ch,
				Font = CONFIG.HeaderFont,
				TextSize = TS,
				TextColor3 = WHITE,
				TextTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = titleRoot,
			}, {
				new("UIGradient", {
					Color = ColorSequence.new(WHITE, Color3.fromRGB(165, 165, 165)),
					Rotation = 90,
				}),
			})
			local stroke = new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 1, Parent = label })
			letters[#letters + 1] = { label = label, stroke = stroke, x = px, w = widths[i], rot = rng:NextNumber(-10, 10) }
		end
		px += widths[i] + CONFIG.Tracking
	end

	local n = #letters
	local LETTER_STEP = 0.05
	for i, l in ipairs(letters) do
		at(T_TITLE + (i - 1) * LETTER_STEP, 0.7, Q.Back, OUT, function(e)
			local k = clamp01(e * 1.4)
			l.label.TextTransparency = 1 - k
			l.label.Position = UDim2.fromOffset(l.x, lerp(DROP, 0, e))
			l.label.Rotation = lerp(l.rot, 0, e)
			l.stroke.Transparency = lerp(1, 0.88, k)
		end)
	end
	local letterEnd = T_TITLE + n * LETTER_STEP + 0.7

	at(T_TITLE + n * LETTER_STEP + 0.15, 1.0, Q.Sine, INOUT, function(e)
		for i = 1, n do
			local ph = clamp01(1 - math.abs(e * (n + 6) - 3 - i) / 2.5)
			letters[i].stroke.Transparency = lerp(0.88, 0.4, ph)
		end
	end)

	for _ = 1, lowEnd and 3 or 6 do
		local l = letters[rng:NextInteger(1, n)]
		addTwinkle(
			titleRoot,
			UDim2.fromOffset(l.x + l.w / 2 + rng:NextNumber(-6, 6), -TS * 0.42 + rng:NextNumber(-8, 6)),
			rng:NextNumber(12, 22),
			rng:NextNumber(1.2, 2.2),
			rng:NextNumber() * 6.28,
			T_TITLE + n * LETTER_STEP + 0.3
		)
	end

	local lineGap = total / 2 + 26
	local lineLen = math.clamp(vp.X / S / 2 - lineGap - 20, 0, 140)
	local sideParts = {}
	if lineLen >= 24 then
		for _, dir in ipairs({ -1, 1 }) do
			local line = new("Frame", {
				AnchorPoint = Vector2.new(dir == -1 and 1 or 0, 0.5),
				Position = UDim2.fromOffset(dir * lineGap, 4),
				Size = UDim2.fromOffset(0, 1),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Parent = titleRoot,
			}, { gradient(dir == -1 and { { 0, 1 }, { 1, 0 } } or { { 0, 0 }, { 1, 1 } }) })
			local dia = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(dir * (lineGap - 10), 4),
				Size = UDim2.fromOffset(0, 0),
				Rotation = 45,
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				Parent = titleRoot,
			})
			local cr = makeCrystal(titleRoot, 18, 1, 0.15)
			cr.Position = UDim2.fromOffset(dir * (lineGap + lineLen + 14), 4)
			local cs = new("UIScale", { Scale = 0, Parent = cr })
			sideParts[#sideParts + 1] = { line = line, dia = dia, crystal = cr, cs = cs, dir = dir }
		end
		at(T_TITLE + 0.3, 0.9, Q.Quart, OUT, function(e)
			for _, p in ipairs(sideParts) do
				p.line.Size = UDim2.fromOffset(lineLen * e, 1)
				p.dia.Size = UDim2.fromOffset(6 * e, 6 * e)
				p.cs.Scale = e
			end
		end)
	end

	local ICON = 70
	local HALO = 104
	local iconHolder = new("Frame", {
		Name = "LogoIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, I_Y + 34),
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local iconScale = new("UIScale", { Scale = 0, Parent = iconHolder })
	local iconGlow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(HALO, HALO),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = iconHolder,
	}, { round() })
	local iconRing = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(HALO + 12, HALO + 12),
		BackgroundTransparency = 1,
		Parent = iconHolder,
	}, { round() })
	local iconRingStroke = new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 1, Parent = iconRing })
	local iconRingGrad = gradient({ { 0, 0 }, { 0.25, 0.9 }, { 0.5, 1 }, { 0.75, 0.9 }, { 1, 0 } })
	iconRingGrad.Parent = iconRingStroke
	local iconImg = new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
		Parent = iconHolder,
	})

	local fallBody = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(46, 34),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = iconHolder,
	}, { new("UICorner", { CornerRadius = UDim.new(0.42, 0) }) })
	local fallEyes = {}
	for i, ex in ipairs({ -9, 9 }) do
		fallEyes[i] = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, ex, 0.5, 1),
			Size = UDim2.fromOffset(8, 11),
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = iconHolder,
		}, { round() })
	end

	local iconStatus = "pending"
	local iconReveal = 0
	local function applyIcon()
		if finished then
			return
		end
		local a = iconReveal
		iconGlow.BackgroundTransparency = lerp(1, 0.92, a)
		iconRingStroke.Transparency = lerp(1, 0.55, a)
		iconImg.ImageTransparency = iconStatus == "ok" and (1 - a) or 1
		local fa = iconStatus == "fail" and a or 0
		fallBody.BackgroundTransparency = 1 - fa
		for i = 1, #fallEyes do
			fallEyes[i].BackgroundTransparency = 1 - fa
		end
	end

	at(T_ICON, 0.85, Q.Back, OUT, function(e)
		iconScale.Scale = e
		iconHolder.Position = UDim2.fromOffset(0, I_Y + (1 - e) * 34)
		iconReveal = clamp01(e * 1.6)
		applyIcon()
	end)

	task.spawn(function()
		local src = CONFIG.IconImage
		local asset = src
		if type(src) == "string" and src:match("^https?://") then
			asset = fetchRemoteImage(src)
		end
		if not asset or asset == "" then
			iconStatus = "fail"
			applyIcon()
			return
		end
		iconImg.Image = asset
		if tostring(asset):find("^rbxasset://") then
			iconStatus = "ok"
			applyIcon()
			return
		end
		pcall(function()
			ContentProvider:PreloadAsync({ iconImg })
		end)
		local waited = os.clock()
		while not iconImg.IsLoaded and os.clock() - waited < 4 do
			task.wait(0.1)
		end
		iconStatus = "ok"
		applyIcon()
	end)

	local BTN_W, BTN_H, BTN_R = 250, 54, 17
	local btnHolder = new("Frame", {
		Name = "ButtonHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, B_Y),
		Size = UDim2.fromOffset(BTN_H, BTN_H),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = panel,
	})
	local btnPop = new("UIScale", { Scale = 0, Parent = btnHolder })
	local btn = new("TextButton", {
		Name = "CopyButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = btnHolder,
	})
	local btnPress = new("UIScale", { Scale = 1, Parent = btn })
	local btnCorner = new("UICorner", { CornerRadius = UDim.new(0, BTN_H / 2), Parent = btn })
	local btnStroke = new("UIStroke", {
		Color = WHITE,
		Thickness = 1.5,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = btn,
	})
	local strokeDim = Color3.fromRGB(105, 105, 105)
	local btnStrokeGrad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, strokeDim),
			ColorSequenceKeypoint.new(0.18, strokeDim),
			ColorSequenceKeypoint.new(0.5, WHITE),
			ColorSequenceKeypoint.new(0.82, strokeDim),
			ColorSequenceKeypoint.new(1, strokeDim),
		}),
		Parent = btnStroke,
	})
	local BTN_GRAY = Color3.fromRGB(226, 226, 226)
	local btnGrad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, BTN_GRAY),
			ColorSequenceKeypoint.new(0.42, BTN_GRAY),
			ColorSequenceKeypoint.new(0.5, WHITE),
			ColorSequenceKeypoint.new(0.58, BTN_GRAY),
			ColorSequenceKeypoint.new(1, BTN_GRAY),
		}),
		Rotation = 20,
		Offset = Vector2.new(-1, 0),
		Parent = btn,
	})
	local btnText = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 14, 0.5, 0),
		Size = UDim2.new(1, -60, 1, 0),
		BackgroundTransparency = 1,
		Text = CONFIG.ButtonText,
		Font = CONFIG.ButtonFont,
		TextSize = 17,
		TextColor3 = BLACK,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = btn,
	})

	local copyIcon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 34, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Parent = btn,
	})
	local copyParts = {}
	local function copySquare(x, y, filled)
		local fr = new("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = Color3.fromRGB(236, 236, 236),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = copyIcon,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 3) }) })
		local st = new("UIStroke", {
			Color = BLACK,
			Thickness = 1.6,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = fr,
		})
		copyParts[#copyParts + 1] = { fr = fr, st = st, filled = filled }
	end
	copySquare(0, 0, false)
	copySquare(5, 5, true)

	local function setBtnContent(a)
		btnText.TextTransparency = 1 - a
		if not copyParts.done then
			for i = 1, #copyParts do
				local p = copyParts[i]
				p.st.Transparency = 1 - a
				p.fr.BackgroundTransparency = p.filled and (1 - a) or 1
			end
		end
	end

	local copiedLabel = new("TextLabel", {
		Name = "Copied",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, C_Y - 22),
		Size = UDim2.fromOffset(320, 22),
		BackgroundTransparency = 1,
		Text = CONFIG.CopiedText,
		Font = CONFIG.LabelFont,
		TextSize = 16,
		TextColor3 = WHITE,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 1,
		Parent = panel,
	})
	local copiedLine = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, C_Y + 17),
		Size = UDim2.fromOffset(0, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = panel,
	}, { gradient({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }) })

	local hintLabel = new("TextLabel", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, C_Y - 4),
		Size = UDim2.fromOffset(320, 18),
		BackgroundTransparency = 1,
		Text = (CONFIG.InfoLink:gsub("^https?://", "")),
		Font = CONFIG.LabelFont,
		TextSize = 14,
		TextColor3 = WHITE,
		TextTransparency = 1,
		ZIndex = 1,
		Parent = panel,
	})
	local HINT_GRAY = Color3.fromRGB(165, 165, 165)
	local hintGrad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, HINT_GRAY),
			ColorSequenceKeypoint.new(0.42, HINT_GRAY),
			ColorSequenceKeypoint.new(0.5, WHITE),
			ColorSequenceKeypoint.new(0.58, HINT_GRAY),
			ColorSequenceKeypoint.new(1, HINT_GRAY),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = hintLabel,
	})
	local hintVis = 0

	at(T_BTN, 0.8, Q.Quart, OUT, function(e)
		btnHolder.Size = UDim2.fromOffset(lerp(BTN_H, BTN_W, e), BTN_H)
		btnHolder.Position = UDim2.fromOffset(0, B_Y + (1 - e) * 18)
		btnCorner.CornerRadius = UDim.new(0, lerp(BTN_H / 2, BTN_R, e))
	end)
	at(T_BTN, 0.55, Q.Back, OUT, function(e)
		btnPop.Scale = lerp(0.3, 1, e)
	end)
	at(T_BTN, 0.35, Q.Sine, OUT, function(e)
		btn.BackgroundTransparency = 1 - e
		btnStroke.Transparency = lerp(1, 0.55, e)
	end)
	at(T_BTN + 0.4, 0.4, Q.Sine, OUT, function(e)
		setBtnContent(e)
	end)

	local FX = { sa = 0.55, pingAt = 0, starAt = 3, glowE = 0, kick = 0, is = 1, iconHover = false, mx = 0, my = 0 }
	do
		btn.ClipsDescendants = true
		btn.ZIndex = 2
		btnText.ZIndex = 3
		copyIcon.ZIndex = 3
		FX.hl = new("Frame", {
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 0.5, -3),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = btn,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0, BTN_R - 3) }),
			gradient({ { 0, 0.35 }, { 1, 1 } }, 90),
		})
		at(T_BTN + 0.3, 0.5, Q.Sine, OUT, function(e)
			FX.hl.BackgroundTransparency = 1 - e
		end)

		FX.chk = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Parent = copyIcon,
		})
		FX.chkScale = new("UIScale", { Scale = 0, Parent = FX.chk })
		FX.chkBars = {}
		for _, b in ipairs({ { 5, 4, 10, 45 }, { 10, 10, 8, -47 } }) do
			FX.chkBars[#FX.chkBars + 1] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(b[2], b[3]),
				Size = UDim2.fromOffset(b[1], 2),
				Rotation = b[4],
				BackgroundColor3 = BLACK,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = FX.chk,
			}, { round() })
		end

		FX.iconBtn = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(HALO, HALO),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = iconHolder,
		})
		FX.iconBtn.MouseEnter:Connect(function()
			FX.iconHover = true
		end)
		FX.iconBtn.MouseLeave:Connect(function()
			FX.iconHover = false
		end)

		FX.dots = {}
		for i = 1, 2 do
			local d = i == 1 and 6 or 4
			FX.dots[i] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(d, d),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = iconHolder,
			}, { round() })
		end

		FX.glows = {}
		for i, sz in ipairs({ 640, 430 }) do
			FX.glows[i] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(U(sz), U(sz)),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = lightLayer,
			}, { round() })
		end
		at(T_LOGO, 1.2, Q.Sine, OUT, function(e)
			FX.glowE = e
		end)

		FX.star = {
			on = false,
			life = 0,
			dur = 0.8,
			x = 0,
			y = 0,
			vx = 0,
			vy = 0,
			frame = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(U(130), 2),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Visible = false,
				Parent = snowBack,
			}, { gradient({ { 0, 1 }, { 1, 0 } }) }),
		}
	end

	do
		FX.beams = {}
		for i = 1, 2 do
			local side = i == 1 and -1 or 1
			FX.beams[i] = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5 + side * 0.2, 0, 0.3, 0),
				Size = UDim2.fromOffset(U(i == 1 and 200 or 150), vp.Y * 1.4),
				Rotation = side * 16,
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = lightLayer,
			}, { gradient({ { 0, 1 }, { 0.5, 0.9 }, { 1, 1 } }, 0) })
		end
		for i = 1, lowEnd and 3 or 6 do
			local side = i % 2 == 0 and 1 or -1
			addTwinkle(
				panel,
				UDim2.fromOffset(side * rng:NextNumber(125, 210), rng:NextNumber(I_Y - 30, B_Y + 24)),
				rng:NextNumber(10, 18),
				rng:NextNumber(1.2, 2.4),
				rng:NextNumber() * 6.28,
				T_BTN + 0.5
			)
		end
	end

	local hud = { vis = 1, draw = 0, foot = 0 }
	local hudApply = function() end

	local footerRoom = vp.Y - (cy + (C_Y + 24) * S) > math.max(U(30), 24) + math.max(11, U(13)) + 14
	if CONFIG.HudCorners or (CONFIG.Footer ~= "" and footerRoom) then
		local parts = {}
		local th = math.max(1, U(2))
		local len = math.max(U(46), 26)
		local inset = math.max(U(26), UserInputService.TouchEnabled and 26 or 16)

		if CONFIG.HudCorners then
			for _, cdef in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
				local ax, ay = cdef[1], cdef[2]
				local pos = UDim2.new(ax, ax == 0 and inset or -inset, ay, ay == 0 and inset or -inset)
				local hRot = ax == 0 and 0 or 180
				local vRot = ay == 0 and 90 or 270
				for _, horizontal in ipairs({ true, false }) do
					parts[#parts + 1] = {
						kind = horizontal and "h" or "v",
						f = new("Frame", {
							AnchorPoint = Vector2.new(ax, ay),
							Position = pos,
							Size = UDim2.fromOffset(horizontal and 0 or th, horizontal and th or 0),
							BackgroundColor3 = WHITE,
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							ZIndex = 5,
							Parent = edgeLayer,
						}, { gradient({ { 0, 0 }, { 1, 0.85 } }, horizontal and hRot or vRot) }),
					}
				end
				parts[#parts + 1] = {
					kind = "dot",
					f = new("Frame", {
						AnchorPoint = Vector2.new(ax, ay),
						Position = pos,
						Size = UDim2.fromOffset(th + 2, th + 2),
						BackgroundColor3 = WHITE,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ZIndex = 5,
						Parent = edgeLayer,
					}),
				}
			end
		end

		local footLabel, footLines, footLen
		if CONFIG.Footer ~= "" and footerRoom then
			local fs = math.max(11, U(13))
			local tw = fs * 0.62 * #CONFIG.Footer
			local okSize, size = pcall(function()
				return TextService:GetTextSize(CONFIG.Footer, fs, CONFIG.LabelFont, Vector2.new(1000, 100))
			end)
			if okSize then
				tw = size.X
			end
			local fy = -math.max(U(30), 24)
			local holder = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, fy),
				Size = UDim2.fromOffset(tw + 40, fs + 6),
				BackgroundTransparency = 1,
				ZIndex = 5,
				Parent = edgeLayer,
			})
			footLabel = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = CONFIG.Footer,
				Font = CONFIG.LabelFont,
				TextSize = fs,
				TextColor3 = Color3.fromRGB(190, 190, 190),
				TextTransparency = 1,
				ZIndex = 5,
				Parent = holder,
			})
			footLen = math.clamp(vp.X / 2 - tw / 2 - 90, 0, U(90))
			footLines = {}
			for _, dir in ipairs({ -1, 1 }) do
				footLines[#footLines + 1] = new("Frame", {
					AnchorPoint = Vector2.new(dir == -1 and 1 or 0, 0.5),
					Position = UDim2.new(0.5, dir * (tw / 2 + 14), 0.5, 0),
					Size = UDim2.fromOffset(0, 1),
					BackgroundColor3 = WHITE,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 5,
					Parent = holder,
				}, { gradient(dir == -1 and { { 0, 1 }, { 1, 0 } } or { { 0, 0 }, { 1, 1 } }) })
			end
		end

		hudApply = function()
			local d, v = hud.draw, hud.vis
			local tr = 1 - v * 0.6 * clamp01(d * 3)
			for i = 1, #parts do
				local pt = parts[i]
				if pt.kind == "h" then
					pt.f.Size = UDim2.fromOffset(len * d, th)
				elseif pt.kind == "v" then
					pt.f.Size = UDim2.fromOffset(th, len * d)
				end
				pt.f.BackgroundTransparency = tr
			end
			if footLabel then
				local f = hud.foot
				footLabel.TextTransparency = 1 - v * 0.55 * f
				for i = 1, #footLines do
					footLines[i].Size = UDim2.fromOffset(footLen * f, 1)
					footLines[i].BackgroundTransparency = 1 - v * 0.5 * f
				end
			end
		end

		at(T_SHATTER + 1.8, 1.1, Q.Quart, OUT, function(e)
			hud.draw = e
			hudApply()
		end)
		at(T_BTN + 0.8, 0.9, Q.Quart, OUT, function(e)
			hud.foot = e
			hudApply()
		end)
	end

	local shineStart = nil
	local shineAt = T_TITLE + n * LETTER_STEP + 1.9

	local function playSfx(id, vol)
		if type(id) ~= "string" or id == "" or finished then
			return
		end
		local snd = new("Sound", { SoundId = id, Volume = vol, Parent = gui })
		snd:Play()
		game:GetService("Debris"):AddItem(snd, 8)
	end
	task.delay(T_SHATTER / CONFIG.Speed, playSfx, CONFIG.ShatterSound, 0.5)

	if CONFIG.Sound ~= "" then
		local snd = new("Sound", { SoundId = CONFIG.Sound, Volume = 0.5, Parent = gui })
		task.delay(T_LOGO, function()
			if snd.Parent then
				snd:Play()
			end
		end)
	end

	local logoReady = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ logo })
		end)
		logoReady = true
	end)
	local waitStart = os.clock()
	while not logoReady and os.clock() - waitStart < 0.6 do
		task.wait()
	end

	local parallax = {
		{ frame = bgLayer, k = -3, base = UDim2.fromScale(-0.07, -0.07) },
		{ frame = snowBack, k = -6 },
		{ frame = hillFar, k = -4 },
		{ frame = hillMid, k = -8 },
		{ frame = hillNear, k = -14 },
		{ frame = snowFront, k = 12 },
	}
	local pm = Vector2.zero

	local function degrade()
		for i = #flakes, 1, -1 do
			local f = flakes[i]
			if f.cull and (f.bokeh or i % 2 == 0) then
				f.frame.Visible = false
				flakes[i] = flakes[#flakes]
				flakes[#flakes] = nil
			end
		end
		for i = 1, #crystals do
			if i > 3 and i % 2 == 0 then
				crystals[i].hidden = true
				crystals[i].frame.Visible = false
			end
		end
	end

	local clock0 = os.clock()
	local finishing = false
	local SPEED = CONFIG.Speed

	local frameN = 0
	local dtSum, dtCount = 0, 0
	local qualityDone = CONFIG.Quality ~= "Auto"
	local exiting = false
	local twK = 1

	local HOLD = 2.3
	local LINE_W = 300
	local copyToken = 0
	local holdUntil = 0
	local copiedOnce = false
	local hover, down = false, false
	local bScale, bVel, bLast, gradX = 1, 0, 1, -2

	local function copyToClipboard(str)
		return true
	end

	btn.MouseEnter:Connect(function()
		hover = true
	end)
	btn.MouseLeave:Connect(function()
		hover = false
		down = false
	end)
	btn.MouseButton1Down:Connect(function()
		down = true
	end)
	btn.MouseButton1Up:Connect(function()
		down = false
	end)

	local function onCopy()
		local t0 = (os.clock() - clock0) * SPEED
		if exiting or finishing or t0 < T_BTN + 0.6 then
			return
		end
		local ok = copyToClipboard(CONFIG.InfoLink)
		playSfx(CONFIG.ClickSound, 0.6)
		copiedOnce = true
		holdUntil = os.clock() + HOLD
		bVel += 4
		copyParts.done = true
		at(t0, 0.45, Q.Back, OUT, function(e)
			if exiting then
				return
			end
			local k = clamp01(e * 2)
			for i = 1, #copyParts do
				local cp = copyParts[i]
				cp.st.Transparency = k
				cp.fr.BackgroundTransparency = 1
			end
			FX.chkScale.Scale = e
			for i = 1, #FX.chkBars do
				FX.chkBars[i].BackgroundTransparency = 1 - clamp01(e * 1.5)
			end
		end)
		do
			local m = UserInputService:GetMouseLocation()
			local ap, asz = btn.AbsolutePosition, btn.AbsoluteSize
			local fx = asz.X > 0 and clamp01((m.X - ap.X) / asz.X) or 0.5
			local fy = asz.Y > 0 and clamp01((m.Y - ap.Y) / asz.Y) or 0.5
			local rp = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(fx, fy),
				Size = UDim2.fromOffset(0, 0),
				BackgroundColor3 = BLACK,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = btn,
			}, { round() })
			at(t0, 0.7, Q.Quart, OUT, function(e)
				local sz = BTN_W * 1.5 * e
				rp.Size = UDim2.fromOffset(sz, sz)
				rp.BackgroundTransparency = lerp(0.82, 1, e)
			end, destroyer(rp))
		end

		local ring = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(0, B_Y),
			Size = UDim2.fromOffset(BTN_W, BTN_H),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = panel,
		})
		local ringCorner = new("UICorner", { CornerRadius = UDim.new(0, BTN_R), Parent = ring })
		local ringStroke = new("UIStroke", {
			Color = WHITE,
			Thickness = 2.5,
			Transparency = 0.2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = ring,
		})
		at(t0, 0.7, Q.Quart, OUT, function(e)
			ring.Size = UDim2.fromOffset(BTN_W + 70 * e, BTN_H + 44 * e)
			ringCorner.CornerRadius = UDim.new(0, BTN_R + 22 * e)
			ringStroke.Transparency = lerp(0.2, 1, e)
			ringStroke.Thickness = lerp(2.5, 0.5, e)
		end, destroyer(ring))

		for _ = 1, lowEnd and 8 or 14 do
			local a = rng:NextNumber() * math.pi * 2
			local dist = rng:NextNumber(50, 110)
			local sz = rng:NextInteger(2, 5)
			local dx, dy = math.cos(a) * dist * 1.4, math.sin(a) * dist * 0.8
			local p = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(0, B_Y),
				Size = UDim2.fromOffset(sz, sz),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 2,
				Parent = panel,
			}, { round() })
			at(t0 + rng:NextNumber(0, 0.06), rng:NextNumber(0.5, 0.9), Q.Quart, OUT, function(e)
				p.Position = UDim2.fromOffset(dx * e, B_Y + dy * e)
				p.BackgroundTransparency = clamp01(0.1 + e * e * 0.95)
			end, destroyer(p))
		end

		copyToken += 1
		local tok = copyToken
		copiedLabel.Text = ok and CONFIG.CopiedText or CONFIG.InfoLink
		at(t0, 0.55, Q.Sine, OUT, function(e)
			if exiting then
				return
			end
			FX.kick = 0.2 * math.sin(math.pi * e)
			iconGlow.BackgroundTransparency = lerp(0.78, 0.92, e)
		end)
		at(t0, 0.6, Q.Back, OUT, function(e)
			if exiting or tok ~= copyToken then
				return
			end
			copiedLabel.Position = UDim2.fromOffset(0, lerp(C_Y - 22, C_Y, e))
			copiedLabel.TextTransparency = 1 - clamp01(e * 1.8)
		end)
		at(t0 + 0.3, 0.5, Q.Quart, OUT, function(e)
			if exiting or tok ~= copyToken then
				return
			end
			copiedLine.Size = UDim2.fromOffset(LINE_W * e, 1)
			copiedLine.BackgroundTransparency = lerp(1, 0.25, e)
		end)
		at(t0 + (HOLD - 0.7) * SPEED, 0.6 * SPEED, Q.Quart, IN, function(e)
			if exiting or tok ~= copyToken then
				return
			end
			copiedLine.Size = UDim2.fromOffset(LINE_W * (1 - e), 1)
			copiedLine.BackgroundTransparency = lerp(0.25, 0.6, e)
			copiedLabel.TextTransparency = clamp01((e - 0.35) / 0.65)
		end)
	end
	btn.Activated:Connect(onCopy)
	new("TextButton", {
		Name = "LinkHit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = hintLabel.Position,
		Size = UDim2.fromOffset(260, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 2,
		Parent = panel,
	}).Activated:Connect(onCopy)
	if UserInputService.TouchEnabled then
		new("TextButton", {
			Name = "HitArea",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 28, 0, math.max(BTN_H + 28, 52 / S)),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 1,
			Parent = btnHolder,
		}).Activated:Connect(onCopy)
	end
	skipConn = UserInputService.InputBegan:Connect(function(input)
		local k = input.KeyCode
		if k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter or k == Enum.KeyCode.Space then
			onCopy()
		end
	end)
	FX.iconBtn.Activated:Connect(onCopy)

	conn = RunService.RenderStepped:Connect(function(rawDt)
		local dt = math.min(rawDt, 1 / 20)
		frameN += 1
		local rt = os.clock() - clock0
		local t = rt * SPEED

		if not qualityDone then
			if t > 0.7 and t < 1.7 then
				dtSum += rawDt
				dtCount += 1
			elseif t >= 1.7 then
				qualityDone = true
				if dtCount > 5 and dtSum / dtCount > 1 / 40 then
					degrade()
				end
			end
		end

		for i = #anims, 1, -1 do
			local a = anims[i]
			if t >= a.t0 then
				local p = (t - a.t0) / a.dur
				if p >= 1 then
					a.fn(1)
					if a.done then
						a.done()
					end
					anims[i] = anims[#anims]
					anims[#anims] = nil
				else
					a.fn(TweenService:GetValue(p, a.style, a.dir))
				end
			end
		end

		do
			local cv = camera.ViewportSize
			if
				t > 2.6
				and not exiting
				and cv.X > 100
				and cv.Y > 100
				and (math.abs(cv.X - vp.X) > 2 or math.abs(cv.Y - vp.Y) > 2)
			then
				vp = cv
				cx, cy = vp.X / 2, vp.Y / 2
				maxD = math.sqrt(cx * cx + cy * cy)
				S = computeS(vp)
				centerScale.Scale = S * LS
				local ps = panel:FindFirstChildOfClass("UIScale")
				if ps then
					ps.Scale = S
				end
				for _, ho in ipairs(hillObjs) do
					ho.px = vp.X * ho.cxr
					ho.rise = vp.Y * ho.riser
					local dsz = vp.X * ho.dd
					ho.frame.Size = UDim2.fromOffset(dsz, dsz)
					ho.frame.Position = UDim2.fromOffset(ho.px, vp.Y - ho.rise)
				end
			end
		end

		local target
		if hasMouse then
			local m = UserInputService:GetMouseLocation()
			target = Vector2.new(math.clamp((m.X - cx) / cx, -1, 1), math.clamp((m.Y - cy) / cy, -1, 1))
		else
			target = Vector2.new(math.sin(t * 0.35) * 0.5, math.cos(t * 0.27) * 0.4)
		end
		pm = pm:Lerp(target, 1 - math.exp(-dt * 4))
		for i = 1, #parallax do
			local p = parallax[i]
			local b = p.base or UDim2.new()
			p.frame.Position = UDim2.new(b.X.Scale, b.X.Offset + pm.X * p.k, b.Y.Scale, b.Y.Offset + pm.Y * p.k * 0.6)
		end

		local gust = 70 * math.exp(-((t - 0.8) ^ 2) / 0.18)
		local wind = 16 + math.sin(t * 0.7) * 9 + gust + pm.X * 28
		local vx, vy = vp.X, vp.Y

		for i = 1, #flakes do
			local f = flakes[i]
			local step = dt
			local skip = false
			if f.half then
				f.acc += dt
				if (frameN + i) % 2 ~= 0 then
					skip = true
				else
					step = f.acc
					f.acc = 0
				end
			end
			if not skip then
				local y = f.y + f.vy * step
				local x = f.x + (wind * f.z + math.sin(t * f.freq + f.phase) * f.sway) * step
				if y > vy + f.s then
					y = -f.s
					x = rng:NextNumber() * vx
				end
				if x > vx + f.s then
					x = -f.s
				elseif x < -f.s * 3 then
					x = vx + f.s
				end
				f.x, f.y = x, y
				f.frame.Position = UDim2.fromOffset(x, y)
			end
		end

		for i = 1, #crystals do
			local c = crystals[i]
			if not c.hidden then
				local y = c.y + c.vy * dt
				local x = c.x + (wind * 0.6 + math.sin(t * c.freq + c.phase) * c.sway) * dt
				c.rot += c.spin * dt
				if y > vy + c.s then
					y = -c.s
					x = rng:NextNumber() * vx
				end
				if x > vx + c.s then
					x = -c.s
				elseif x < -c.s * 3 then
					x = vx + c.s
				end
				c.x, c.y = x, y
				c.frame.Position = UDim2.fromOffset(x, y)
				c.frame.Rotation = c.rot
			end
		end

		if t > T_LOGO then
			tickHolder.Rotation = t * 12
			gradA.Rotation = (t * 160) % 360
			gradB.Rotation = (-t * 110) % 360
			gradC.Rotation = (t * 60) % 360

			for i = 1, 3 do
				local ang = t * (0.9 + i * 0.12) + i * 2.094
				orbit[i].Position = UDim2.fromOffset(math.cos(ang) * 205, math.sin(ang) * 205)
			end

			local bob = clamp01((t - T_LOGO - 0.8) / 0.6)
			logoHolder.Position = UDim2.fromOffset(0, math.sin(t * 1.7) * 3 * bob)
		end

		for i = 1, #twinkles do
			local tw = twinkles[i]
			local on = clamp01((t - tw.on) / 0.4)
			if on > 0 then
				local pulse = math.max(0, math.sin(t * tw.speed + tw.phase))
				local s = tw.base * pulse * pulse * on * twK
				if math.abs(s - tw.last) > 0.15 then
					tw.last = s
					tw.frame.Size = UDim2.fromOffset(s, s)
				end
			end
		end

		if not exiting then
			panel.Position = UDim2.new(0.5, pm.X * -5, 0.5, pm.Y * -3)
			if t > T_SHRINK + 0.9 then
				center.Position = UDim2.new(0.5, pm.X * -3, 0.5, L_Y * S + pm.Y * -2)
			end
			if t > T_LOGO then
				for i = 1, 2 do
					local g = FX.glows[i]
					local base = i == 1 and 0.975 or 0.968
					g.BackgroundTransparency = lerp(1, base + math.sin(t * 1.1 + i) * 0.006, FX.glowE)
					local sz = U(i == 1 and 640 or 430) + math.sin(t * 0.9 + i * 1.7) * 14
					g.Size = UDim2.fromOffset(sz, sz)
				end
				for i = 1, 2 do
					local bm = FX.beams[i]
					bm.Rotation = (i == 1 and -16 or 16) + math.sin(t * 0.35 + i * 2) * 3
					bm.BackgroundTransparency = 1 - FX.glowE * (0.75 + math.sin(t * 0.8 + i) * 0.25)
				end
				if t > T_LOGO + 0.9 then
					logoScale.Scale = 1 + math.sin(t * 1.4) * 0.012
					logo.Rotation = pm.X * 2.2
				end
			end
			if t > 2.4 then
				local st = FX.star
				if st.on then
					st.life += dt
					local pr = st.life / st.dur
					if pr >= 1 then
						st.on = false
						st.frame.Visible = false
						FX.starAt = t + rng:NextNumber(2.6, 5)
					else
						st.x += st.vx * dt
						st.y += st.vy * dt
						st.frame.Position = UDim2.fromOffset(st.x, st.y)
						st.frame.BackgroundTransparency = 1 - math.sin(math.pi * pr) * 0.8
					end
				elseif t >= FX.starAt then
					local ang = math.rad(rng:NextNumber(16, 34))
					local spd = rng:NextNumber(850, 1150) * S
					st.vx, st.vy = math.cos(ang) * spd, math.sin(ang) * spd
					st.x, st.y = rng:NextNumber(0.04, 0.6) * vx, rng:NextNumber(0.03, 0.25) * vy
					st.life = 0
					st.on = true
					st.frame.Rotation = math.deg(ang)
					st.frame.Position = UDim2.fromOffset(st.x, st.y)
					st.frame.Visible = true
				end
			end
		end
		if t > T_ICON + 0.85 and not exiting then
			iconHolder.Position = UDim2.fromOffset(0, I_Y + math.sin(t * 1.9) * 2.5)
			local g = HALO + math.sin(t * 2.2) * 6
			iconGlow.Size = UDim2.fromOffset(g, g)
			iconRingGrad.Rotation = (t * 140) % 360
			FX.is += ((FX.iconHover and 1.12 or 1) - FX.is) * (1 - math.exp(-dt * 12))
			iconScale.Scale = FX.is + FX.kick
			local orbitR = HALO / 2 + 10
			local dotA = clamp01((t - T_ICON - 0.85) / 0.5)
			for i = 1, 2 do
				local ang = t * 1.5 + (i - 1) * math.pi
				FX.dots[i].Position = UDim2.new(0.5, math.cos(ang) * orbitR, 0.5, math.sin(ang) * orbitR * 0.9)
				FX.dots[i].BackgroundTransparency = lerp(1, 0.2 + i * 0.1, dotA)
			end
			if t >= FX.pingAt then
				FX.pingAt = t + 3.4
				local pr = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(0, I_Y),
					Size = UDim2.fromOffset(HALO, HALO),
					BackgroundTransparency = 1,
					Parent = panel,
				}, { round() })
				local ps = new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.5, Parent = pr })
				at(t, 1.5, Q.Sine, OUT, function(e)
					local sz = lerp(HALO, HALO * 1.9, e)
					pr.Size = UDim2.fromOffset(sz, sz)
					ps.Transparency = lerp(0.5, 1, e)
					ps.Thickness = lerp(1.5, 0.4, e)
				end, destroyer(pr))
			end
		end
		if t > T_BTN + 0.6 and not exiting then
			local tgt = down and 0.92 or (hover and 1.06 or 1)
			bVel += ((tgt - bScale) * 380 - bVel * 22) * dt
			bScale += bVel * dt
			if math.abs(bScale - bLast) > 0.0005 then
				bLast = bScale
				btnPress.Scale = bScale
			end
			local sp = ((t - T_BTN - 0.6) % 3) / 0.9
			local gx = sp < 1 and lerp(-1, 1, sp) or -1
			if gx ~= gradX then
				gradX = gx
				btnGrad.Offset = Vector2.new(gx, 0)
			end
			local k = 1 - math.exp(-dt * 10)
			FX.sa += ((hover and 0.08 or (0.55 + math.sin(t * 2.2) * 0.1)) - FX.sa) * k
			btnStroke.Transparency = FX.sa
			btnStroke.Thickness = lerp(btnStroke.Thickness, hover and 2.4 or 1.5, k)
			btnStrokeGrad.Rotation = (t * 95) % 360
			local tx, ty = 0, 0
			if hover and hasMouse then
				local m = UserInputService:GetMouseLocation()
				local ap, asz = btnHolder.AbsolutePosition, btnHolder.AbsoluteSize
				tx = math.clamp((m.X - (ap.X + asz.X / 2)) / math.max(asz.X, 1), -0.5, 0.5) * 9
				ty = math.clamp((m.Y - (ap.Y + asz.Y / 2)) / math.max(asz.Y, 1), -0.5, 0.5) * 6
			end
			FX.mx += (tx - FX.mx) * k
			FX.my += (ty - FX.my) * k
			btn.Position = UDim2.new(0.5, FX.mx, 0.5, FX.my)
		end
		do
			local target = (t > T_BTN + 1.4 and not copiedOnce and not exiting) and 1 or 0
			if hintVis > 0.003 or target == 1 then
				hintVis += (target - hintVis) * (1 - math.exp(-dt * (target == 1 and 3 or 14)))
				hintLabel.TextTransparency = 1 - hintVis * 0.72
				local hp = ((t - T_BTN - 1.4) % 4.2) / 1.1
				hintGrad.Offset = Vector2.new(hp < 1 and lerp(-1, 1, hp) or -1, 0)
			end
		end
		if t > T_TITLE + 1 and not exiting then
			titleGlow.BackgroundTransparency = 0.94 + math.sin(t * 1.3) * 0.015
			for _, p in ipairs(sideParts) do
				p.dia.Rotation = 45 + math.sin(t * 1.5 + 1) * 8
				p.crystal.Rotation = t * 24 * p.dir
			end
		end

		if t > letterEnd + 0.1 and not exiting then
			local near, mx = false, 0
			if hasMouse then
				local m = UserInputService:GetMouseLocation()
				mx = (m.X - cx) / S
				near = math.abs(m.Y - (cy + H_Y * S)) < 46 * S
			end
			local hk = 1 - math.exp(-dt * 12)
			for i = 1, n do
				local l = letters[i]
				local tgt = 0
				if near then
					local d = math.abs(mx - (l.x + l.w / 2)) / 70
					if d < 1 then
						tgt = -9 * (1 - d) * (1 - d)
					end
				end
				l.h = (l.h or 0) + (tgt - (l.h or 0)) * hk
				l.label.Position = UDim2.fromOffset(l.x, math.sin(t * 2.1 + i * 0.6) * 2.5 + l.h)
			end
			if not shineStart and t >= shineAt then
				shineStart = t
				shineAt = math.huge
			end
			if shineStart then
				local p = (t - shineStart) / 1.3
				if p >= 1 then
					for i = 1, n do
						letters[i].stroke.Transparency = 0.88
					end
					shineStart = nil
					shineAt = t + 2.2
				else
					for i = 1, n do
						local ph = clamp01(1 - math.abs(p * (n + 6) - 3 - i) / 2.5)
						letters[i].stroke.Transparency = lerp(0.88, 0.35, ph)
					end
				end
			end
		end

		if t > T_BURST then
			for i = 1, #bands do
				local bd = bands[i]
				bd.grad.Offset = Vector2.new(math.sin(t * bd.speed + bd.phase) * bd.amp, 0)
				bd.grad.Rotation = bd.rot + math.sin(t * bd.speed * 0.7 + bd.phase) * 9
			end
			if t > T_SHATTER + 2.8 then
				bloomScale.Scale = 1 + math.sin(t * 0.6) * 0.035
			end
		end
	end)

	while true do
		local timeUp = CONFIG.AutoClose and os.clock() - clock0 >= CONFIG.Duration
		if (copiedOnce or timeUp) and os.clock() >= holdUntil then
			break
		end
		task.wait()
	end

	if CONFIG.WaitForLoad then
		local s = os.clock()
		while not game:IsLoaded() and os.clock() - s < 10 do
			task.wait(0.1)
		end
	end

	finishing = true
	task.wait(0.2)

	local E = (os.clock() - clock0) * SPEED
	exiting = true

	at(E, 0.45, Q.Sine, OUT, function(e)
		twK = 1 - e
		titleGlow.BackgroundTransparency = lerp(0.94, 1, e)
	end)

	for i, l in ipairs(letters) do
		at(E + 0.1 + (i - 1) * 0.025, 0.45, Q.Quad, IN, function(e)
			l.y0 = l.y0 or l.label.Position.Y.Offset
			l.label.TextTransparency = e
			l.label.Position = UDim2.fromOffset(l.x, l.y0 - 24 * e)
			l.label.Rotation = l.rot * 0.5 * e
			l.stroke.Transparency = lerp(0.88, 1, e)
		end)
	end

	at(E + 0.05, 0.45, Q.Quad, IN, function(e)
		iconScale.Scale = 1 - e
		iconHolder.Position = UDim2.fromOffset(0, I_Y + 26 * e)
		iconReveal = 1 - e
		applyIcon()
	end)

	at(E + 0.1, 0.5, Q.Quart, IN, function(e)
		btnHolder.Size = UDim2.fromOffset(lerp(BTN_W, BTN_H, e), BTN_H)
		btnCorner.CornerRadius = UDim.new(0, lerp(BTN_R, BTN_H / 2, e))
		btnPop.Scale = lerp(1, 0.2, e * e)
		btn.BackgroundTransparency = e
		btnStroke.Transparency = lerp(0.55, 1, e)
		setBtnContent(1 - clamp01(e * 2.5))
	end)

	at(E, 0.4, Q.Quad, IN, function(e)
		hud.vis = 1 - e
		hudApply()
	end)

	local c0, l0
	at(E, 0.3, Q.Quad, IN, function(e)
		c0 = c0 or copiedLabel.TextTransparency
		l0 = l0 or copiedLine.BackgroundTransparency
		copiedLabel.TextTransparency = lerp(c0, 1, e)
		copiedLine.BackgroundTransparency = lerp(l0, 1, e)
	end)

	FX.star.on = false
	FX.star.frame.Visible = false
	at(E, 0.45, Q.Quad, IN, function(e)
		for i = 1, 2 do
			FX.glows[i].BackgroundTransparency = lerp(0.97, 1, e)
			FX.dots[i].BackgroundTransparency = lerp(0.3, 1, e)
		end
		FX.hl.BackgroundTransparency = e
		for i = 1, #FX.chkBars do
			FX.chkBars[i].BackgroundTransparency = math.max(FX.chkBars[i].BackgroundTransparency, e)
		end
		FX.b0 = FX.b0 or FX.beams[1].BackgroundTransparency
		for i = 1, 2 do
			FX.beams[i].BackgroundTransparency = lerp(FX.b0, 1, e)
		end
	end)

	if #sideParts > 0 then
		at(E + 0.1, 0.45, Q.Quad, IN, function(e)
			for _, p in ipairs(sideParts) do
				p.line.Size = UDim2.fromOffset(lineLen * (1 - e), 1)
				p.line.BackgroundTransparency = lerp(0.2, 1, e)
				p.dia.Size = UDim2.fromOffset(6 * (1 - e), 6 * (1 - e))
				p.cs.Scale = 1 - e
			end
		end)
	end

	at(E, 0.18, Q.Sine, OUT, function(e)
		logoScale.Scale = lerp(1, 0.9, e)
	end)
	at(E + 0.18, 0.55, Q.Cubic, IN, function(e)
		logoScale.Scale = lerp(0.9, 1.4, e)
		logo.ImageTransparency = e
	end)

	at(E + 0.18, 0.6, Q.Cubic, IN, function(e)
		if centerScale then
			centerScale.Scale = S * LS * lerp(1, 1.35, e)
		end
		strokeA.Transparency = lerp(0.15, 1, e)
		strokeB.Transparency = lerp(0.5, 1, e)
		strokeC.Transparency = lerp(0.7, 1, e)
		backDisc.BackgroundTransparency = lerp(0.93, 1, e)
		for i = 1, TICKS do
			tickList[i].frame.BackgroundTransparency = lerp(tickList[i].a, 1, e)
		end
		for i = 1, 3 do
			orbit[i].BackgroundTransparency = lerp(0.1 + i * 0.12, 1, e)
		end
	end)

	at(E + 0.2, 0.7, Q.Quad, IN, function(e)
		for _, h in ipairs(hillObjs) do
			h.frame.Position = UDim2.fromOffset(h.px, lerp(vp.Y - h.rise, vp.Y + 24, e))
			h.stroke.Transparency = lerp(h.rim, 1, e)
		end
		fog.BackgroundTransparency = lerp(0, 1, e)
	end)

	do
		local outRing = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(U(120), U(120)),
			BackgroundTransparency = 1,
			Parent = lightLayer,
		}, { round() })
		local outStroke = new("UIStroke", { Color = WHITE, Thickness = 2.5, Transparency = 1, Parent = outRing })
		at(E + 0.4, 0.8, Q.Sine, OUT, function(e)
			local sz = lerp(U(120), maxD * 2.1, e)
			outRing.Size = UDim2.fromOffset(sz, sz)
			outStroke.Transparency = lerp(0.2, 1, e * e * (3 - 2 * e))
			outStroke.Thickness = lerp(2.5, 0.4, e)
		end, destroyer(outRing))

		local outFlash = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = overlay,
		})
		at(E + 0.4, 0.5, Q.Quad, OUT, function(e)
			outFlash.BackgroundTransparency = lerp(0.86, 1, e)
		end, destroyer(outFlash))
	end

	at(E + 0.4, 0.05, Q.Linear, OUT, function() end, function()
		degrade()
	end)

	while (os.clock() - clock0) * SPEED < E + 0.65 do
		task.wait()
	end
	local fadeGroup = new("CanvasGroup", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 0,
		Parent = gui,
	})
	root.Parent = fadeGroup
	at((os.clock() - clock0) * SPEED, 0.5, Q.Sine, IN, function(e)
		fadeGroup.GroupTransparency = e
	end)
	task.wait(0.5 / SPEED + 0.06)

	cleanup()
	table.clear(anims)
	table.clear(flakes)
	table.clear(fadeFlakes)
	table.clear(crystals)
	table.clear(twinkles)
	table.clear(bands)
end

xpcall(main, debug.traceback)
cleanup()
