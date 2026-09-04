--!strict
-- ConveyorService: Physical 3D Crate spawning, belt progression & interactive claiming
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)
local DataService = require(script.Parent.DataService)
local HopperService = require(script.Parent.HopperService)

local ConveyorService = {}
local SPAWN_INTERVAL = 4.0 -- Base crate drop every 4 seconds
local BELT_TRAVEL_TIME = 10.0 -- Seconds to travel full 60-stud belt

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
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastSpawnTime >= SPAWN_INTERVAL then
			lastSpawnTime = now
			ConveyorService.SpawnCratesForPlayers()
		end

		ConveyorService.UpdatePhysicalCrates(now)
	end)

	print("[ConveyorService] Initialized 3D physical conveyor belt logistics service.")
end

function ConveyorService.RollCrateRarity(pneumaticLevel: number): Types.CrateRarity
	local roll = math.random() * 100
	local boost = pneumaticLevel * (TierBalance.UPGRADES.PneumaticLine.chanceBonusPerLevel * 100)

	local legWeight = 2 + (boost * 0.1)
	local rareWeight = 8 + (boost * 0.3)
	local uncomWeight = 20 + (boost * 0.6)

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
	if rarity == "Legendary" then return Color3.fromRGB(255, 170, 0) end
	if rarity == "Rare" then return Color3.fromRGB(170, 0, 255) end
	if rarity == "Uncommon" then return Color3.fromRGB(0, 170, 255) end
	return Color3.fromRGB(160, 110, 60) -- Common Rusted
end

function ConveyorService.SpawnCratesForPlayers()
	local now = os.clock()
	local map = Workspace:FindFirstChild("ChopShopDistrict")
	if not map then return end

	for index, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetPlayerData(player)
		if not data then continue end

		local plotId = index -- Assign plot 1 to player 1, etc.
		local plotFolder = map:FindFirstChild("Plot_" .. tostring(plotId))
		if not plotFolder then continue end

		local conveyor = plotFolder:FindFirstChild("ConveyorBelt")
		if not conveyor then continue end

		local pneumaticLevel = data.Upgrades.pneumaticLineLevel
		local rarity = ConveyorService.RollCrateRarity(pneumaticLevel)
		local crateId = HttpService:GenerateGUID(false)

		-- Create 3D Crate Part on belt start
		local cratePart = Instance.new("Part")
		cratePart.Name = "Crate_" .. crateId
		cratePart.Size = Vector3.new(3, 3, 3)
		cratePart.Color = getCrateColor(rarity)
		cratePart.Material = Enum.Material.Wood
		cratePart.Anchored = true
		cratePart.CanCollide = false
		cratePart:SetAttribute("CrateId", crateId)
		cratePart:SetAttribute("Rarity", rarity)

		-- Position at start of conveyor (rear of belt)
		local beltCF = conveyor.CFrame
		cratePart.CFrame = beltCF * CFrame.new(0, 3, -25)
		cratePart.Parent = conveyor

		-- ProximityPrompt for [E] Claim Crate
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Claim " .. rarity .. " Crate"
		prompt.ObjectText = "Conveyor Belt"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 15
		prompt.Parent = cratePart

		prompt.Triggered:Connect(function(claimingPlayer)
			if claimingPlayer == player then
				ConveyorService.ClaimCrate(claimingPlayer, crateId)
			end
		end)

		local crate: ActiveCrate = {
			id = crateId,
			rarity = rarity,
			spawnTime = now,
			owner = player,
			model = cratePart,
		}

		activeBeltCrates[crateId] = crate
		print(string.format("[ConveyorService] Dropped 3D %s crate on Plot %d belt for %s", rarity, plotId, player.Name))
	end
end

function ConveyorService.UpdatePhysicalCrates(now: number)
	for crateId, crate in pairs(activeBeltCrates) do
		local elapsed = now - crate.spawnTime
		local progress = math.clamp(elapsed / BELT_TRAVEL_TIME, 0, 1)

		if crate.model and crate.model.Parent then
			local conveyor = crate.model.Parent :: Part
			local startCF = conveyor.CFrame * CFrame.new(0, 3, -25)
			local endCF = conveyor.CFrame * CFrame.new(0, 3, 25)
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

function ConveyorService.RenderWorkbenchItemVisual(player: Player, slotNum: number, item: Types.WorkbenchItem)
	local map = Workspace:FindFirstChild("ChopShopDistrict")
	if not map then return end
	local plotFolder = map:FindFirstChild("Plot_1") -- Assuming player 1 for studio test
	if not plotFolder then return end

	local gridFolder = plotFolder:FindFirstChild("WorkbenchGrid")
	if not gridFolder then return end

	local node = gridFolder:FindFirstChild("GridNode_" .. tostring(slotNum)) :: Part?
	if not node then return end

	-- Destroy any existing part model on this node
	local existing = node:FindFirstChild("PartVisual")
	if existing then existing:Destroy() end

	-- Create 3D Part Visual on node
	local partVisual = Instance.new("Part")
	partVisual.Name = "PartVisual"
	partVisual.Size = Vector3.new(2.5, 2.5, 2.5)
	partVisual.CFrame = node.CFrame * CFrame.new(0, 1.3, 0)
	partVisual.Anchored = true
	partVisual.CanCollide = false

	if item.category == "Engine" then
		partVisual.Color = Color3.fromRGB(220, 50, 50)
		partVisual.Material = Enum.Material.Metal
	elseif item.category == "Chassis" then
		partVisual.Color = Color3.fromRGB(50, 120, 220)
		partVisual.Material = Enum.Material.DiamondPlate
	else
		partVisual.Color = Color3.fromRGB(50, 200, 80)
		partVisual.Material = Enum.Material.SmoothPlastic
	end
	partVisual.Parent = node

	-- Add Merge / Install ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = string.format("Interact %s (T%d)", item.category, item.tier)
	prompt.ObjectText = "Workbench Slot " .. tostring(slotNum)
	prompt.HoldDuration = 0
	prompt.Parent = partVisual
end

return ConveyorService
