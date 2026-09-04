--!strict
-- ConveyorService: Physical 3D Crate spawning, rapid belt progression & glowing interactable crates
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)
local PartMeshConfig = require(ReplicatedStorage.Shared.config.PartMeshConfig)
local DataService = require(script.Parent.DataService)
local HopperService = require(script.Parent.HopperService)
local PlotService = require(script.Parent.PlotService)

local ConveyorService = {}
local SPAWN_INTERVAL = 2.5 -- Rapid 2.5-second crate drops
local BELT_TRAVEL_TIME = 10.0 -- 10 seconds travel time along full belt

type ActiveCrate = {
	id: string,
	rarity: Types.CrateRarity,
	spawnTime: number,
	owner: Player,
	model: Part?,
}

local activeBeltCrates: { [string]: ActiveCrate } = {}
local lastSpawnTime = 0

function ConveyorService.Init()
	-- Spawn initial batch of crates immediately on server boot
	task.defer(function()
		task.wait(1)
		ConveyorService.SpawnCratesForPlayers()
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastSpawnTime >= SPAWN_INTERVAL then
			lastSpawnTime = now
			ConveyorService.SpawnCratesForPlayers()
		end

		ConveyorService.UpdatePhysicalCrates(now)
	end)

	print("[ConveyorService] Initialized rapid 3D conveyor belt spawner.")
end

function ConveyorService.RollCrateRarity(pneumaticLevel: number): Types.CrateRarity
	local roll = math.random() * 100
	local boost = pneumaticLevel * (TierBalance.UPGRADES.PneumaticLine.chanceBonusPerLevel * 100)

	local legWeight = 3 + (boost * 0.1)
	local rareWeight = 12 + (boost * 0.3)
	local uncomWeight = 25 + (boost * 0.6)

	if roll <= legWeight then
		return "Legendary"
	elseif roll <= legWeight + rareWeight then
		return "Rare"
	elseif roll <= legWeight + rareWeight + uncomWeight then
		return "Uncommon"
	else
		return "Common"
	end
end

local function getCrateColor(rarity: Types.CrateRarity): Color3
	if rarity == "Legendary" then return Color3.fromRGB(255, 180, 0) end
	if rarity == "Rare" then return Color3.fromRGB(180, 0, 255) end
	if rarity == "Uncommon" then return Color3.fromRGB(0, 180, 255) end
	return Color3.fromRGB(200, 120, 50) -- Common Wood/Gold
end

function ConveyorService.SpawnCrateForPlayer(player: Player)
	local data = DataService.GetPlayerData(player)
	if not data then return end

	local plotFolder = PlotService.GetPlayerPlotFolder(player)
	if not plotFolder then return end

	local conveyor = plotFolder:FindFirstChild("ConveyorBelt") :: Part?
	if not conveyor then return end

	local now = os.clock()
	local pneumaticLevel = data.Upgrades.pneumaticLineLevel
	local rarity = ConveyorService.RollCrateRarity(pneumaticLevel)
	local crateId = HttpService:GenerateGUID(false)

	-- Create Highly Visible 3D Crate Part
	local cratePart = Instance.new("Part")
	cratePart.Name = "Crate_" .. crateId
	cratePart.Size = Vector3.new(4, 4, 4)
	cratePart.Color = getCrateColor(rarity)
	cratePart.Material = Enum.Material.Wood
	cratePart.Anchored = true
	cratePart.CanCollide = false
	cratePart:SetAttribute("CrateId", crateId)
	cratePart:SetAttribute("Rarity", rarity)

	-- Add Glowing Highlight Effect so crate is impossible to miss
	local highlight = Instance.new("Highlight")
	highlight.FillColor = getCrateColor(rarity)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 0
	highlight.Parent = cratePart

	-- Position at start of conveyor (rear of belt)
	local startCF = conveyor.CFrame * CFrame.new(0, 4, -25)
	cratePart.CFrame = startCF
	cratePart.Parent = Workspace -- Parent directly in Workspace for maximum visibility

	-- ProximityPrompt for [E] Claim Crate
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim " .. rarity .. " Crate"
	prompt.ObjectText = "Conveyor Belt"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 30
	prompt.Parent = cratePart

	prompt.Triggered:Connect(function(claimingPlayer)
		if claimingPlayer == player then
			ConveyorService.ClaimCrate(claimingPlayer, crateId)
		end
	end)

	-- Floating BillboardGui Indicator above Crate
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 140, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = cratePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "[" .. rarity .. " Crate]\nPress E"
	label.TextColor3 = getCrateColor(rarity)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = billboard

	local crate: ActiveCrate = {
		id = crateId,
		rarity = rarity,
		spawnTime = now,
		owner = player,
		model = cratePart,
	}

	activeBeltCrates[crateId] = crate
	print(string.format("[ConveyorService] Spawning glowing %s crate for %s on conveyor", rarity, player.Name))
end

function ConveyorService.SpawnCratesForPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		ConveyorService.SpawnCrateForPlayer(player)
	end
end

function ConveyorService.UpdatePhysicalCrates(now: number)
	for crateId, crate in pairs(activeBeltCrates) do
		local elapsed = now - crate.spawnTime
		local progress = math.clamp(elapsed / BELT_TRAVEL_TIME, 0, 1)

		local plotFolder = PlotService.GetPlayerPlotFolder(crate.owner)
		local conveyor = if plotFolder then (plotFolder:FindFirstChild("ConveyorBelt") :: Part?) else nil

		if crate.model and crate.model.Parent and conveyor then
			local startCF = conveyor.CFrame * CFrame.new(0, 4, -25)
			local endCF = conveyor.CFrame * CFrame.new(0, 4, 25)
			crate.model.CFrame = startCF:Lerp(endCF, progress)
		end

		if progress >= 1 then
			-- Reached end of belt -> Shredder or Hopper
			local player = crate.owner
			local data = DataService.GetPlayerData(player)

			if crate.model then
				crate.model:Destroy()
			end

			if data and data.HasOverflowHopper then
				HopperService.StoreCrate(player, crate.rarity)
			else
				print(string.format("[ConveyorService] Crate %s fell into Shredder for %s", crateId, player.Name))
			end

			activeBeltCrates[crateId] = nil
		end
	end
end

function ConveyorService.ClaimCrate(player: Player, crateId: string): (boolean, string, Types.WorkbenchItem?)
	local crate = activeBeltCrates[crateId]
	if not crate then
		return false, "Crate no longer exists on conveyor belt", nil
	end

	if crate.owner ~= player then
		return false, "Crate belongs to another player", nil
	end

	local data = DataService.GetPlayerData(player)
	if not data then
		return false, "Player data not found", nil
	end

	-- Find open workbench slot (1 to 16)
	local openSlot: number? = nil
	for i = 1, 16 do
		if data.WorkbenchItems[tostring(i)] == nil then
			openSlot = i
			break
		end
	end

	if not openSlot then
		return false, "Workbench is full (16/16 slots occupied)", nil
	end

	-- Determine sub-assembly category & tier
	local categories: { Types.SubAssemblyCategory } = { "Engine", "Chassis", "Body" }
	local randomCategory = categories[math.random(1, #categories)]
	local tierLevel = 1
	if crate.rarity == "Uncommon" then tierLevel = 2 end
	if crate.rarity == "Rare" then tierLevel = 3 end
	if crate.rarity == "Legendary" then tierLevel = 4 end

	local newItem: Types.WorkbenchItem = {
		id = HttpService:GenerateGUID(false),
		category = randomCategory,
		tier = tierLevel,
		gridSlot = openSlot,
	}

	-- Record acquired part in PartIndex & check leveling progress
	local PartIndexService = require(script.Parent.PartIndexService)
	PartIndexService.RecordPartAcquired(player, randomCategory, tierLevel)

	-- Destroy 3D crate model
	if crate.model then
		crate.model:Destroy()
	end

	-- Update state and remove crate from belt
	DataService.MutatePlayerData(player, function(d)
		d.WorkbenchItems[tostring(openSlot)] = newItem
	end)

	activeBeltCrates[crateId] = nil

	-- Update 3D Workbench visual node
	ConveyorService.RenderWorkbenchItemVisual(player, openSlot, newItem)

	print(string.format("[ConveyorService] Player %s claimed %s crate -> Unboxed %s Tier %d to Slot %d", player.Name, crate.rarity, randomCategory, tierLevel, openSlot))
	return true, "Success", newItem
end

function ConveyorService.ClearWorkbenchSlotVisual(player: Player, slotNum: number)
	local plotFolder = PlotService.GetPlayerPlotFolder(player)
	if not plotFolder then return end

	local gridFolder = plotFolder:FindFirstChild("WorkbenchGrid")
	if not gridFolder then return end

	local node = gridFolder:FindFirstChild("GridNode_" .. tostring(slotNum)) :: Part?
	if not node then return end

	for _, child in ipairs(node:GetChildren()) do
		child:Destroy()
	end
end

function ConveyorService.RenderAllWorkbenchItems(player: Player)
	local data = DataService.GetPlayerData(player)
	if not data then return end

	for slotNum = 1, 16 do
		local slotStr = tostring(slotNum)
		local item = data.WorkbenchItems[slotStr]
		if item then
			ConveyorService.RenderWorkbenchItemVisual(player, slotNum, item)
		else
			ConveyorService.RenderEmptyWorkbenchSlotPrompt(player, slotNum)
		end
	end
end

function ConveyorService.RenderEmptyWorkbenchSlotPrompt(player: Player, slotNum: number)
	local plotFolder = PlotService.GetPlayerPlotFolder(player)
	if not plotFolder then return end

	local gridFolder = plotFolder:FindFirstChild("WorkbenchGrid")
	if not gridFolder then return end

	local node = gridFolder:FindFirstChild("GridNode_" .. tostring(slotNum)) :: Part?
	if not node then return end

	ConveyorService.ClearWorkbenchSlotVisual(player, slotNum)

	local CarryingService = require(script.Parent.CarryingService)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WorkbenchPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.ActionText = "Place Held Part [F]"
	prompt.ObjectText = "Empty Workbench Slot " .. tostring(slotNum)
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 30
	prompt.Parent = node

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then return end

		if not CarryingService.IsHolding(player) then return end

		local cat, tier = CarryingService.DropHeldItem(player, true)
		if not cat or not tier then return end

		local HttpService = game:GetService("HttpService")
		local newItem: Types.WorkbenchItem = {
			id = HttpService:GenerateGUID(false),
			category = cat,
			tier = tier,
			gridSlot = slotNum,
		}

		DataService.MutatePlayerData(player, function(d)
			d.WorkbenchItems[tostring(slotNum)] = newItem
		end)

		ConveyorService.RenderWorkbenchItemVisual(player, slotNum, newItem)
		print(string.format("[Workbench] Player %s placed held %s T%d onto Slot %d", player.Name, cat, tier, slotNum))
	end)
end

function ConveyorService.RenderWorkbenchItemVisual(player: Player, slotNum: number, item: Types.WorkbenchItem)
	local plotFolder = PlotService.GetPlayerPlotFolder(player)
	if not plotFolder then return end

	local gridFolder = plotFolder:FindFirstChild("WorkbenchGrid")
	if not gridFolder then return end

	local node = gridFolder:FindFirstChild("GridNode_" .. tostring(slotNum)) :: Part?
	if not node then return end

	-- Destroy any existing visual models/prompts on this node
	for _, child in ipairs(node:GetChildren()) do
		child:Destroy()
	end

	-- Create 3D Part Visual on node using PartMeshConfig template
	local targetCF = node.CFrame * CFrame.new(0, 1.4, 0)
	local partVisual = PartMeshConfig.CreateVisualInstance(item.category, item.tier, targetCF)
	partVisual.Name = "PartVisual"
	partVisual.Parent = node

	local CarryingService = require(script.Parent.CarryingService)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WorkbenchPrompt"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.ActionText = string.format("Pick Up Part [F] (%s T%d)", item.category, item.tier)
	prompt.ObjectText = "Workbench Slot " .. tostring(slotNum)
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 30
	prompt.Parent = node

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then return end

		if CarryingService.IsHolding(player) then
			print(string.format("[Workbench] Player %s is already holding a part! Place or mount it first.", player.Name))
			return
		end

		local data = DataService.GetPlayerData(player)
		if not data then return end

		local currentItem = data.WorkbenchItems[tostring(slotNum)]
		if not currentItem then return end

		-- Pick up part into player's hands
		local success = CarryingService.PickUpItem(player, currentItem.category, currentItem.tier)
		if success then
			DataService.MutatePlayerData(player, function(d)
				d.WorkbenchItems[tostring(slotNum)] = nil
			end)

			ConveyorService.RenderEmptyWorkbenchSlotPrompt(player, slotNum)
			print(string.format("[Workbench] Player %s picked up %s T%d from Slot %d", player.Name, currentItem.category, currentItem.tier, slotNum))
		end
	end)
end

return ConveyorService
