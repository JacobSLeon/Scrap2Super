--!strict
-- ScrapDisposalService: 3D Scrap Recycler Machine & Cash Rewards for Unwanted Waste Parts
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local PartIndexService = require(script.Parent.PartIndexService)
local CarryingService = require(script.Parent.CarryingService)

local ScrapDisposalService = {}

function ScrapDisposalService.Init()
	print("[ScrapDisposalService] Initialized 3D scrap disposal & recycling service.")
end

local function getOrCreateScrapMachinePart(plotFolder: Folder): Part?
	local floor = (plotFolder:FindFirstChild("PlotFloor") or plotFolder:FindFirstChild("Floor")) :: Part?
	if not floor then return nil end

	local machine = plotFolder:FindFirstChild("ScrapRecyclerMachine") :: Part?
	local targetCF = floor.CFrame * CFrame.new(-13.5, 3.0, 0)

	if not machine then
		-- Spawn Physical 3D Scrap Recycler Machine in back-left corner out of the way
		machine = Instance.new("Part")
		machine.Name = "ScrapRecyclerMachine"
		machine.Size = Vector3.new(5, 5, 5)
		machine.CFrame = targetCF
		machine.Color = Color3.fromRGB(30, 35, 45)
		machine.Material = Enum.Material.DiamondPlate
		machine.Anchored = true
		machine.CanCollide = true
		machine.TopSurface = Enum.SurfaceType.Smooth
		machine.BottomSurface = Enum.SurfaceType.Smooth
		machine.Parent = plotFolder

		-- Glowing Hazard Highlight
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(0, 230, 120)
		highlight.OutlineColor = Color3.fromRGB(255, 200, 0)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 0.2
		highlight.Parent = machine

		-- Overhead 3D Billboard Indicator
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ScrapBillboard"
		billboard.Size = UDim2.new(0, 240, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 4.0, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = machine
		billboard.Parent = machine

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "♻️ SCRAP RECYCLER & DISPOSAL\n(Gain Cash for Waste Parts)"
		label.TextColor3 = Color3.fromRGB(0, 240, 140)
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = billboard
	else
		machine.CFrame = targetCF
	end

	return machine
end

function ScrapDisposalService.SetupPlotScrapPrompts(player: Player)
	local plotFolder = PlotService.GetPlayerPlotFolder(player)
	if not plotFolder then return end

	local machine = getOrCreateScrapMachinePart(plotFolder)
	if not machine then return end

	-- Clear existing prompt
	local existingPrompt = machine:FindFirstChild("ScrapPrompt")
	if existingPrompt then existingPrompt:Destroy() end

	local isHolding = CarryingService.IsHolding(player)
	local cat, tier = CarryingService.GetHeldItem(player)

	local level = 1
	if cat and tier then
		level = PartIndexService.GetPartLevel(player, cat, tier)
	end

	local payout = if (cat and tier) then TierBalance.CalculateScrapPayout(cat, tier, level) else 0

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ScrapPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 30
	prompt.ObjectText = "Scrap Disposal Machine"

	if isHolding and cat and tier then
		prompt.ActionText = string.format("♻️ Recycle Held %s (T%d) [F] (+$%d Cash)", cat, tier, payout)
	else
		prompt.ActionText = "♻️ Recycle Held Waste Part [F]"
	end
	prompt.Parent = machine

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then return end

		local checkCat, checkTier = CarryingService.GetHeldItem(player)
		if not checkCat or not checkTier then
			print(string.format("[ScrapDisposal] Player %s is not holding a part to scrap!", player.Name))
			return
		end

		local checkLevel = PartIndexService.GetPartLevel(player, checkCat, checkTier)
		local scrapCash = TierBalance.CalculateScrapPayout(checkCat, checkTier, checkLevel)

		-- Drop/destroy held part visual from player
		CarryingService.DropHeldItem(player, true)

		-- Award cash
		EconomyService.AddCash(player, scrapCash)

		-- Show 3D Floating Cash Effect (+$$$) above Machine
		ScrapDisposalService.ShowFloatingCashEffect(machine, scrapCash)

		-- Refresh prompts
		ScrapDisposalService.SetupPlotScrapPrompts(player)

		print(string.format("[ScrapDisposal] Player %s recycled %s T%d for +$%d Cash!", player.Name, checkCat, checkTier, scrapCash))
	end)
end

function ScrapDisposalService.ScrapWorkbenchItem(player: Player, slotNum: number): (boolean, string, number)
	local data = DataService.GetPlayerData(player)
	if not data then return false, "Player data not found", 0 end

	local slotKey = tostring(slotNum)
	local item = data.WorkbenchItems[slotKey]
	if not item then
		return false, "Slot is empty", 0
	end

	local level = PartIndexService.GetPartLevel(player, item.category, item.tier)
	local payout = TierBalance.CalculateScrapPayout(item.category, item.tier, level)

	DataService.MutatePlayerData(player, function(d)
		d.WorkbenchItems[slotKey] = nil
	end)

	EconomyService.AddCash(player, payout)

	local ConveyorService = require(script.Parent.ConveyorService)
	ConveyorService.RenderEmptyWorkbenchSlotPrompt(player, slotNum)

	print(string.format("[ScrapDisposal] Player %s scrapped workbench item %s T%d from Slot %d for +$%d Cash", player.Name, item.category, item.tier, slotNum, payout))
	return true, "Success", payout
end

function ScrapDisposalService.ShowFloatingCashEffect(parentPart: BasePart, amount: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "FloatingCashEffect"
	bb.Size = UDim2.new(0, 160, 0, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = parentPart
	bb.Parent = parentPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = string.format("+$%d Cash!", amount)
	label.TextColor3 = Color3.fromRGB(0, 255, 120)
	label.TextSize = 22
	label.Font = Enum.Font.FredokaOne
	label.Parent = bb

	task.spawn(function()
		for i = 1, 30 do
			task.wait(0.03)
			bb.StudsOffset = bb.StudsOffset + Vector3.new(0, 0.1, 0)
		end
		bb:Destroy()
	end)
end

return ScrapDisposalService
