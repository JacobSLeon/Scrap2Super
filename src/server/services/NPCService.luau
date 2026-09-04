--!strict
-- NPCService: Spawning NPC collectors, generating Pure Tier offers & resolving trades
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local NPCService = {}
local MIN_SPAWN_INTERVAL = 60 -- Seconds
local MAX_SPAWN_INTERVAL = 90 -- Seconds
local OFFER_DURATION = 120 -- Offer expires after 2 minutes

local activeOffers: { [string]: Types.NPCTradeOffer } = {}
local lastSpawnTime = 0
local nextInterval = 60

function NPCService.Init()
	nextInterval = math.random(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL)
	
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastSpawnTime >= nextInterval then
			lastSpawnTime = now
			nextInterval = math.random(MIN_SPAWN_INTERVAL, MAX_SPAWN_INTERVAL)
			NPCService.SpawnNPCOffersForPlayers()
		end

		NPCService.CleanupExpiredOffers(now)
	end)

	print("[NPCService] Initialized NPC trade broker service.")
end

function NPCService.SpawnNPCOffersForPlayers()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetPlayerData(player)
		if not data then continue end

		-- Check PriorityBroker upgrade (20% faster arrival per level)
		local priorityLevel = data.Upgrades.priorityBrokerLevel
		local requestedTier = math.random(1, 5)

		-- Calculate trade payout with 1.5x base multiplier + PriorityBroker payout bonus (+15% per level)
		local baseTierValue = TierBalance.TIER_CASH_PER_SEC[requestedTier] * 100
		local brokerBonus = 1 + (priorityLevel * TierBalance.UPGRADES.PriorityBroker.payoutBonusPerLevel)
		local offerAmount = math.floor(baseTierValue * 1.5 * brokerBonus)

		local npcId = HttpService:GenerateGUID(false)
		local offer: Types.NPCTradeOffer = {
			npcId = npcId,
			requestedTier = requestedTier,
			offerAmount = offerAmount,
			expiresAt = now + OFFER_DURATION,
			plotId = 1, -- Player's assigned plot ID
		}

		activeOffers[npcId] = offer
		print(string.format("[NPCService] NPC %s arrived for %s requesting Pure Tier %d Car ($%d)", npcId, player.Name, requestedTier, offerAmount))
	end
end

function NPCService.CleanupExpiredOffers(now: number)
	for npcId, offer in pairs(activeOffers) do
		if now >= offer.expiresAt then
			activeOffers[npcId] = nil
		end
	end
end

function NPCService.AcceptOffer(player: Player, npcId: string, liftId: number): (boolean, string, number)
	local offer = activeOffers[npcId]
	if not offer then
		return false, "NPC offer expired or invalid", 0
	end

	local data = DataService.GetPlayerData(player)
	if not data then
		return false, "Player data not found", 0
	end

	local liftKey = tostring(liftId)
	local car = data.Lifts[liftKey]
	if not car then
		return false, "No vehicle found on specified lift", 0
	end

	if not car.isComplete then
		return false, "Vehicle on lift is incomplete", 0
	end

	if not car.isPureTier then
		return false, "NPCs only accept Pure Tier vehicles (all 3 parts must share the same tier level)", 0
	end

	if car.pureTierLevel ~= offer.requestedTier then
		return false, string.format("NPC requested a Pure Tier %d vehicle, but lift has Tier %d", offer.requestedTier, car.pureTierLevel or 0), 0
	end

	-- Execute trade payout & clear lift bay
	local payoutAmount = offer.offerAmount
	EconomyService.AddCash(player, payoutAmount)

	DataService.MutatePlayerData(player, function(d)
		d.Lifts[liftKey] = {
			liftId = liftId,
			engineTier = nil,
			chassisTier = nil,
			bodyTier = nil,
			isComplete = false,
			isPureTier = false,
			pureTierLevel = nil,
			cashPerSecond = 0,
		}
	end)

	activeOffers[npcId] = nil
	print(string.format("[NPCService] Player %s sold Pure Tier %d car on Lift %d to NPC for $%d lump-sum payout!", player.Name, offer.requestedTier, liftId, payoutAmount))
	return true, "Success", payoutAmount
end

return NPCService
