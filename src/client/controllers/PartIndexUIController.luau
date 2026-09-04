--!strict
-- PartIndexUIController: Client UI panel for viewing discovered parts, levels & duplicate progress
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UserInputService = game:GetService("UserInputService")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)

local PartIndexUIController = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local screenGui: ScreenGui
local mainFrame: Frame
local gridLayout: UIGridLayout
local scrollFrame: ScrollingFrame
local activeFilter: string = "All"

local CATEGORIES: { Types.SubAssemblyCategory } = { "Engine", "Chassis", "Body" }

local function getPartDisplayName(category: Types.SubAssemblyCategory, tier: number): string
	local catDefs = TierBalance.TIER_DEFINITIONS[category]
	if catDefs and catDefs[tier] then
		return catDefs[tier].name
	end
	return string.format("%s T%d", category, tier)
end

function PartIndexUIController.Init()
	print("[PartIndexUIController] Initializing Part Index GUI panel...")

	-- ScreenGui with high DisplayOrder
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PartIndexScreenGui"
	screenGui.DisplayOrder = 100
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Open/Close Toggle Button (Top Left beside Stats HUD)
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "PartIndexToggleButton"
	toggleBtn.Size = UDim2.new(0, 150, 0, 90)
	toggleBtn.Position = UDim2.new(0.02, 335, 0.02, 0)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	toggleBtn.BackgroundTransparency = 0.15
	toggleBtn.Text = "📖 PART INDEX\n[Press P]"
	toggleBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
	toggleBtn.TextSize = 17
	toggleBtn.Font = Enum.Font.FredokaOne
	toggleBtn.Parent = screenGui

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = toggleBtn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(0, 180, 255)
	btnStroke.Thickness = 2
	btnStroke.Parent = toggleBtn

	-- Keybind listener for [P] key
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.I then
			mainFrame.Visible = not mainFrame.Visible
			if mainFrame.Visible then
				PartIndexUIController.Refresh()
			end
		end
	end)

	-- Main Window Frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "PartIndexMainFrame"
	mainFrame.Size = UDim2.new(0, 680, 0, 500)
	mainFrame.Position = UDim2.new(0.5, -340, 0.5, -250)
	mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = mainFrame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(0, 180, 255)
	frameStroke.Thickness = 2
	frameStroke.Parent = mainFrame

	-- Header Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "HeaderTitle"
	titleLabel.Size = UDim2.new(1, -60, 0, 35)
	titleLabel.Position = UDim2.new(0, 15, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "📖 PART INDEX & LEVEL PROGRESSION"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 22
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = mainFrame

	-- Subtitle Info
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "HeaderSubtitle"
	subtitleLabel.Size = UDim2.new(1, -60, 0, 20)
	subtitleLabel.Position = UDim2.new(0, 15, 0, 45)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Collect 3 duplicate parts to Level Up and boost passive vehicle cash rate (+25% / level)!"
	subtitleLabel.TextColor3 = Color3.fromRGB(160, 175, 195)
	subtitleLabel.TextSize = 13
	subtitleLabel.Font = Enum.Font.SourceSans
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = mainFrame

	-- Close Button [X]
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -48, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	-- Category Filter Tabs Frame
	local tabFrame = Instance.new("Frame")
	tabFrame.Name = "TabFrame"
	tabFrame.Size = UDim2.new(1, -30, 0, 36)
	tabFrame.Position = UDim2.new(0, 15, 0, 72)
	tabFrame.BackgroundTransparency = 1
	tabFrame.Parent = mainFrame

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.Padding = UDim.new(0, 10)
	tabList.Parent = tabFrame

	local filters = { "All", "Engine", "Chassis", "Body" }
	for _, filterName in ipairs(filters) do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "Tab_" .. filterName
		tabBtn.Size = UDim2.new(0, 140, 1, 0)
		tabBtn.BackgroundColor3 = if filterName == activeFilter then Color3.fromRGB(0, 150, 220) else Color3.fromRGB(30, 34, 46)
		tabBtn.Text = filterName
		tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabBtn.TextSize = 15
		tabBtn.Font = Enum.Font.FredokaOne
		tabBtn.Parent = tabFrame

		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 6)
		tCorner.Parent = tabBtn

		tabBtn.MouseButton1Click:Connect(function()
			activeFilter = filterName
			for _, child in ipairs(tabFrame:GetChildren()) do
				if child:IsA("TextButton") then
					child.BackgroundColor3 = if child.Name == "Tab_" .. activeFilter then Color3.fromRGB(0, 150, 220) else Color3.fromRGB(30, 34, 46)
				end
			end
			PartIndexUIController.Refresh()
		end)
	end

	-- Scrolling Grid for Part Cards
	scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "PartGridScroll"
	scrollFrame.Size = UDim2.new(1, -30, 1, -125)
	scrollFrame.Position = UDim2.new(0, 15, 0, 115)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 760)
	scrollFrame.ScrollBarThickness = 8
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
	scrollFrame.Parent = mainFrame

	gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 205, 0, 115)
	gridLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollFrame

	-- Toggle Button Connections
	toggleBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = not mainFrame.Visible
		if mainFrame.Visible then
			PartIndexUIController.Refresh()
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
	end)
end

function PartIndexUIController.Refresh()
	if not scrollFrame then return end

	-- Fetch latest PartIndex from Server
	local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
	local remotesFolder = sharedFolder:WaitForChild("remotes")
	local getPartIndexRF = remotesFolder:WaitForChild("GetPartIndex") :: RemoteFunction

	local partIndexData: { [string]: Types.PartIndexEntry } = {}
	local success, result = pcall(function()
		return getPartIndexRF:InvokeServer()
	end)
	if success and typeof(result) == "table" then
		partIndexData = result
	end

	-- Clear existing cards
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local order = 0
	for _, cat in ipairs(CATEGORIES) do
		if activeFilter ~= "All" and activeFilter ~= cat then
			continue
		end

		for tier = 1, 6 do
			order += 1
			local key = string.format("%s_T%d", cat, tier)
			local entry = partIndexData[key]
			local discovered = entry and entry.discovered or false
			local level = entry and entry.level or 1
			local dups = entry and entry.duplicatesCount or 0
			local partName = getPartDisplayName(cat, tier)

			local card = Instance.new("Frame")
			card.Name = key
			card.LayoutOrder = order
			card.BackgroundColor3 = if discovered then Color3.fromRGB(28, 32, 44) else Color3.fromRGB(20, 22, 28)
			card.BackgroundTransparency = if discovered then 0 else 0.4
			card.Parent = scrollFrame

			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 8)
			cCorner.Parent = card

			local cStroke = Instance.new("UIStroke")
			cStroke.Color = if discovered then Color3.fromRGB(0, 180, 255) else Color3.fromRGB(60, 65, 75)
			cStroke.Thickness = if discovered then 1.5 else 1
			cStroke.Parent = card

			-- Title Header
			local cardTitle = Instance.new("TextLabel")
			cardTitle.Size = UDim2.new(1, -10, 0, 22)
			cardTitle.Position = UDim2.new(0, 8, 0, 6)
			cardTitle.BackgroundTransparency = 1
			cardTitle.Text = string.format("T%d: %s", tier, partName)
			cardTitle.TextColor3 = if discovered then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(120, 125, 135)
			cardTitle.TextSize = 14
			cardTitle.Font = Enum.Font.FredokaOne
			cardTitle.TextXAlignment = Enum.TextXAlignment.Left
			cardTitle.Parent = card

			-- Category Tag
			local catTag = Instance.new("TextLabel")
			catTag.Size = UDim2.new(1, -10, 0, 16)
			catTag.Position = UDim2.new(0, 8, 0, 28)
			catTag.BackgroundTransparency = 1
			catTag.Text = string.format("[%s Category]", cat)
			catTag.TextColor3 = if discovered then Color3.fromRGB(0, 200, 255) else Color3.fromRGB(90, 95, 105)
			catTag.TextSize = 12
			catTag.Font = Enum.Font.SourceSansBold
			catTag.TextXAlignment = Enum.TextXAlignment.Left
			catTag.Parent = card

			if discovered then
				-- Level Badge
				local levelBadge = Instance.new("TextLabel")
				levelBadge.Size = UDim2.new(1, -10, 0, 20)
				levelBadge.Position = UDim2.new(0, 8, 0, 46)
				levelBadge.BackgroundTransparency = 1
				local mult = 1 + ((level - 1) * 0.25)
				levelBadge.Text = string.format("Level %d (Boost: %.2fx)", level, mult)
				levelBadge.TextColor3 = Color3.fromRGB(255, 205, 40)
				levelBadge.TextSize = 13
				levelBadge.Font = Enum.Font.FredokaOne
				levelBadge.TextXAlignment = Enum.TextXAlignment.Left
				levelBadge.Parent = card

				-- Progress Bar BG
				local pBarBg = Instance.new("Frame")
				pBarBg.Size = UDim2.new(1, -16, 0, 14)
				pBarBg.Position = UDim2.new(0, 8, 0, 70)
				pBarBg.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
				pBarBg.Parent = card

				local pCorner = Instance.new("UICorner")
				pCorner.CornerRadius = UDim.new(0, 4)
				pCorner.Parent = pBarBg

				-- Progress Bar Fill
				local fillPct = math.clamp(dups / 3, 0, 1)
				local pBarFill = Instance.new("Frame")
				pBarFill.Size = UDim2.new(fillPct, 0, 1, 0)
				pBarFill.BackgroundColor3 = Color3.fromRGB(0, 220, 130)
				pBarFill.Parent = pBarBg

				local fCorner = Instance.new("UICorner")
				fCorner.CornerRadius = UDim.new(0, 4)
				fCorner.Parent = pBarFill

				-- Progress Text
				local pText = Instance.new("TextLabel")
				pText.Size = UDim2.new(1, 0, 1, 0)
				pText.BackgroundTransparency = 1
				pText.Text = string.format("%d / 3 Duplicates", dups)
				pText.TextColor3 = Color3.fromRGB(255, 255, 255)
				pText.TextSize = 11
				pText.Font = Enum.Font.FredokaOne
				pText.Parent = pBarBg
			else
				-- Locked Status
				local lockedLabel = Instance.new("TextLabel")
				lockedLabel.Size = UDim2.new(1, -10, 0, 30)
				lockedLabel.Position = UDim2.new(0, 8, 0, 52)
				lockedLabel.BackgroundTransparency = 1
				lockedLabel.Text = "🔒 Undiscovered\nUnbox crates to discover!"
				lockedLabel.TextColor3 = Color3.fromRGB(110, 115, 125)
				lockedLabel.TextSize = 12
				lockedLabel.Font = Enum.Font.SourceSansItalic
				lockedLabel.TextXAlignment = Enum.TextXAlignment.Left
				lockedLabel.Parent = card
			end
		end
	end
end

return PartIndexUIController
