--!strict
-- CarryingService: Manages 3D physical part carrying, character welds & holding states
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)
local PartMeshConfig = require(ReplicatedStorage.Shared.config.PartMeshConfig)

type HeldItemState = {
	category: Types.SubAssemblyCategory,
	tier: number,
	visualModel: Instance?,
}

local CarryingService = {}
local playerHeldItems: { [Player]: HeldItemState } = {}

function CarryingService.Init()
	print("[CarryingService] Initialized physical 3D part carrying system.")

	-- Clean up held items if player leaves
	Players.PlayerRemoving:Connect(function(player)
		CarryingService.DropHeldItem(player, false)
	end)
end

function CarryingService.GetHeldItem(player: Player): (Types.SubAssemblyCategory?, number?)
	local state = playerHeldItems[player]
	if state then
		return state.category, state.tier
	end
	return nil, nil
end

function CarryingService.IsHolding(player: Player): boolean
	return playerHeldItems[player] ~= nil
end

function CarryingService.PickUpItem(player: Player, category: Types.SubAssemblyCategory, tier: number): boolean
	if CarryingService.IsHolding(player) then
		return false
	end

	local character = player.Character
	if not character then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return false end

	-- Create 3D Visual Mesh welded to player's character in front of chest
	local targetCF = rootPart.CFrame * CFrame.new(0, 0.2, -2.4)
	local visualModel = PartMeshConfig.CreateVisualInstance(category, tier, targetCF)
	visualModel.Name = "HeldPartVisual"
	visualModel.Parent = character

	-- Anchor, Collision, Massless & Welding for held models and single parts
	local allParts: { BasePart } = {}
	if visualModel:IsA("BasePart") then
		table.insert(allParts, visualModel)
	end
	for _, desc in ipairs(visualModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(allParts, desc)
		end
	end

	local mainTarget: BasePart? = if visualModel:IsA("BasePart") then visualModel else visualModel:FindFirstChildWhichIsA("BasePart", true)

	if mainTarget then
		for _, part in ipairs(allParts) do
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true

			if part ~= mainTarget then
				local innerWeld = Instance.new("WeldConstraint")
				innerWeld.Part0 = mainTarget
				innerWeld.Part1 = part
				innerWeld.Parent = part
			end
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootPart
		weld.Part1 = mainTarget
		weld.Parent = mainTarget
	end

	-- Overhead Carrying Indicator Billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CarryingBillboard"
	billboard.Size = UDim2.new(0, 220, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 4.0, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = rootPart
	billboard.Parent = character

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = string.format("Carrying %s (T%d)", category, tier)
	label.TextColor3 = Color3.fromRGB(0, 240, 255)
	label.TextScaled = false
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	playerHeldItems[player] = {
		category = category,
		tier = tier,
		visualModel = visualModel,
	}

	local LiftService = require(script.Parent.LiftService)
	LiftService.SetupPlotLiftPrompts(player)

	local ScrapDisposalService = require(script.Parent.ScrapDisposalService)
	ScrapDisposalService.SetupPlotScrapPrompts(player)

	print(string.format("[CarryingService] Player %s picked up %s T%d", player.Name, category, tier))
	return true
end

function CarryingService.DropHeldItem(player: Player, destroyVisual: boolean): (Types.SubAssemblyCategory?, number?)
	local state = playerHeldItems[player]
	if not state then return nil, nil end

	local category = state.category
	local tier = state.tier

	if state.visualModel and state.visualModel.Parent then
		state.visualModel:Destroy()
	end

	local character = player.Character
	if character then
		local bb = character:FindFirstChild("CarryingBillboard")
		if bb then bb:Destroy() end
		local heldVisual = character:FindFirstChild("HeldPartVisual")
		if heldVisual then heldVisual:Destroy() end
	end

	playerHeldItems[player] = nil

	local LiftService = require(script.Parent.LiftService)
	LiftService.SetupPlotLiftPrompts(player)

	local ScrapDisposalService = require(script.Parent.ScrapDisposalService)
	ScrapDisposalService.SetupPlotScrapPrompts(player)

	print(string.format("[CarryingService] Player %s dropped/mounted %s T%d", player.Name, category, tier))
	return category, tier
end

return CarryingService
