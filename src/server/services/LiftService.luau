--!strict
-- LiftService: Mounting sub-assemblies onto hydraulic lifts & vehicle completion
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)
local DataService = require(script.Parent.DataService)

local LiftService = {}

function LiftService.Init()
	print("[LiftService] Initialized hydraulic lift assembly service.")
end

function LiftService.InstallComponent(player: Player, liftId: number, gridSlot: number): (boolean, string, Types.MountedCar?)
	local data = DataService.GetPlayerData(player)
	if not data then
		return false, "Player data not found", nil
	end

	if liftId < 1 or liftId > data.UnlockedLifts then
		return false, "Lift slot is locked or invalid", nil
	end

	local slotKey = tostring(gridSlot)
	local item = data.WorkbenchItems[slotKey]
	if not item then
		return false, "No item found in specified workbench slot", nil
	end

	local liftKey = tostring(liftId)
	local car = data.Lifts[liftKey]
	if not car then
		car = {
			liftId = liftId,
			engineTier = nil,
			chassisTier = nil,
			bodyTier = nil,
			isComplete = false,
			isPureTier = false,
			pureTierLevel = nil,
			cashPerSecond = 0,
		}
	end

	-- Check if slot on lift is already occupied for this category
	if item.category == "Engine" and car.engineTier ~= nil then
		return false, "Lift already has an Engine installed", nil
	elseif item.category == "Chassis" and car.chassisTier ~= nil then
		return false, "Lift already has a Chassis installed", nil
	elseif item.category == "Body" and car.bodyTier ~= nil then
		return false, "Lift already has a Body installed", nil
	end

	-- Install item onto car
	if item.category == "Engine" then
		car.engineTier = item.tier
	elseif item.category == "Chassis" then
		car.chassisTier = item.tier
	elseif item.category == "Body" then
		car.bodyTier = item.tier
	end

	-- Recalculate car completion and cash/sec
	local cashPerSec, isPure, pureLevel = TierBalance.CalculateCarCashPerSec(
		car.engineTier,
		car.chassisTier,
		car.bodyTier,
		data.Upgrades.torqueMultiplierLevel
	)

	car.isComplete = (car.engineTier ~= nil) and (car.chassisTier ~= nil) and (car.bodyTier ~= nil)
	car.isPureTier = isPure
	car.pureTierLevel = pureLevel
	car.cashPerSecond = cashPerSec

	-- Apply changes to player data
	DataService.MutatePlayerData(player, function(d)
		d.WorkbenchItems[slotKey] = nil
		d.Lifts[liftKey] = car
	end)

	print(string.format(
		"[LiftService] Player %s mounted %s Tier %d to Lift %d (Complete: %s, Cash/sec: %d)",
		player.Name, item.category, item.tier, liftId, tostring(car.isComplete), cashPerSec
	))

	return true, "Success", car
end

return LiftService
