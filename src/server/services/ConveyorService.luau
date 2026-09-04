--!strict
-- ConveyorService: Spawning crates, belt progression & claiming logic
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

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

		ConveyorService.CheckEndofBeltCrates(now)
	end)

	print("[ConveyorService] Initialized conveyor belt logistics service.")
end

function ConveyorService.RollCrateRarity(pneumaticLevel: number): Types.CrateRarity
	local roll = math.random() * 100
	local boost = pneumaticLevel * (TierBalance.UPGRADES.PneumaticLine.chanceBonusPerLevel * 100)

	-- Adjusted drop chances with Pneumatic Line upgrade boost
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

function ConveyorService.SpawnCratesForPlayers()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetPlayerData(player)
		if not data then continue end

		local pneumaticLevel = data.Upgrades.pneumaticLineLevel
		local rarity = ConveyorService.RollCrateRarity(pneumaticLevel)
		local crateId = HttpService:GenerateGUID(false)

		local crate: ActiveCrate = {
			id = crateId,
			rarity = rarity,
			spawnTime = now,
			owner = player,
		}

		activeBeltCrates[crateId] = crate
		print(string.format("[ConveyorService] Dropped %s crate (%s) on belt for %s", rarity, crateId, player.Name))
	end
end

function ConveyorService.CheckEndofBeltCrates(now: number)
	for crateId, crate in pairs(activeBeltCrates) do
		if now - crate.spawnTime >= BELT_TRAVEL_TIME then
			-- Reached end of belt
			local player = crate.owner
			local data = DataService.GetPlayerData(player)
			
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

	-- Update state and remove crate from belt
	DataService.MutatePlayerData(player, function(d)
		d.WorkbenchItems[tostring(openSlot)] = newItem
	end)

	activeBeltCrates[crateId] = nil

	print(string.format("[ConveyorService] Player %s claimed %s crate -> Unboxed %s Tier %d to Slot %d", player.Name, crate.rarity, randomCategory, tierLevel, openSlot))
	return true, "Success", newItem
end

return ConveyorService
