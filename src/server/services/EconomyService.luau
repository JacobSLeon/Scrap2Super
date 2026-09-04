--!strict
-- EconomyService: Passive cash ticks, currency transactions & Rebirth system
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)
local DataService = require(script.Parent.DataService)

local EconomyService = {}
local TICK_INTERVAL = 1.0 -- Cash tick every 1 second
local lastTickTime = 0

function EconomyService.Init()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTickTime >= TICK_INTERVAL then
			lastTickTime = now
			EconomyService.ProcessPassiveIncomeTick()
		end
	end)
end

function EconomyService.ProcessPassiveIncomeTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetPlayerData(player)
		if not data then
			continue
		end

		local totalCashPerSec = 0
		for _, liftData in pairs(data.Lifts) do
			if liftData.isComplete then
				local cashPerSec = TierBalance.CalculateCarCashPerSec(
					liftData.engineTier,
					liftData.chassisTier,
					liftData.bodyTier,
					data.Upgrades.torqueMultiplierLevel
				)
				liftData.cashPerSecond = cashPerSec
				totalCashPerSec += cashPerSec
			else
				liftData.cashPerSecond = 0
			end
		end

		if totalCashPerSec > 0 then
			data.Cash += totalCashPerSec
			data.LifetimeCash += totalCashPerSec
		end
	end
end

function EconomyService.AddCash(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end
	return DataService.MutatePlayerData(player, function(data)
		data.Cash += amount
		data.LifetimeCash += amount
	end)
end

function EconomyService.CanAfford(player: Player, amount: number): boolean
	local data = DataService.GetPlayerData(player)
	if not data then
		return false
	end
	return data.Cash >= amount
end

function EconomyService.DeductCash(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end

	local data = DataService.GetPlayerData(player)
	if not data or data.Cash < amount then
		return false
	end

	return DataService.MutatePlayerData(player, function(d)
		d.Cash -= amount
	end)
end

function EconomyService.Rebirth(player: Player): (boolean, number)
	local data = DataService.GetPlayerData(player)
	if not data then
		return false, 0
	end

	local repEarned = TierBalance.CalculateRepEarned(data.LifetimeCash)
	if repEarned <= 0 then
		return false, 0
	end

	DataService.MutatePlayerData(player, function(d)
		d.Cash = 0
		d.LifetimeCash = 0
		d.ReputationTokens += repEarned
		d.RebirthCount += 1
		
		-- Permanently unlock +1 Hydraulic Lift per rebirth (max 6)
		d.UnlockedLifts = math.min(6, d.UnlockedLifts + 1)
		
		-- Reset transient workbench items and reset lifts
		d.WorkbenchItems = {}
		for i = 1, d.UnlockedLifts do
			local key = tostring(i)
			d.Lifts[key] = {
				liftId = i,
				engineTier = nil,
				chassisTier = nil,
				bodyTier = nil,
				isComplete = false,
				isPureTier = false,
				pureTierLevel = nil,
				cashPerSecond = 0,
			}
		end
	end)

	print(string.format("[EconomyService] Player %s rebirthed! Earned %d Rep Tokens.", player.Name, repEarned))
	return true, repEarned
end

return EconomyService
