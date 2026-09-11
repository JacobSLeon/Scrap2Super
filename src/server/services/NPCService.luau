--!strict
-- NPCService: Spawning physical 3D NPC collectors, generating Pure Tier offers & resolving trades
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Types = require(ReplicatedStorage.Shared.types.Types)
local TierBalance = require(ReplicatedStorage.Shared.config.TierBalance)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)

local NPCService = {}
local MIN_SPAWN_INTERVAL = 30 -- Faster 30s interval for active studio testing
local MAX_SPAWN_INTERVAL = 45 -- Faster 45s interval for active studio testing
local OFFER_DURATION = 120 -- Offer expires after 2 minutes

type ActiveNPCOffer = {
	offer: Types.NPCTradeOffer,
	model: Model?,
}

local activeOffers: { [string]: ActiveNPCOffer } = {}
local lastSpawnTime = 0
local nextInterval = 30

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

	print("[NPCService] Initialized physical 3D NPC trade broker service.")
end

function NPCService.SpawnNPCOffersForPlayers()
	local now = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.GetPlayerData(player)
		if not data then continue end

		local plotFolder = PlotService.GetPlayerPlotFolder(player)
		if not plotFolder then continue end

		local buyerPad = plotFolder:FindFirstChild("NPCBuyerPad") :: Part?
		if not buyerPad then continue end

		local priorityLevel = data.Upgrades.priorityBrokerLevel
		local requestedTier = math.random(1, 5)

		local baseTierValue = TierBalance.TIER_CASH_PER_SEC[requestedTier] * 100
		local brokerBonus = 1 + (priorityLevel * TierBalance.UPGRADES.PriorityBroker.payoutBonusPerLevel)
		local offerAmount = math.floor(baseTierValue * 1.5 * brokerBonus)

		local npcId = HttpService:GenerateGUID(false)
		local offerData: Types.NPCTradeOffer = {
			npcId = npcId,
			requestedTier = requestedTier,
			offerAmount = offerAmount,
			expiresAt = now + OFFER_DURATION,
			plotId = PlotService.GetPlayerPlotId(player) or 1,
		}

		-- Spawn 3D NPC Dummy Character Model
		local npcModel = Instance.new("Model")
		npcModel.Name = "NPCCollector_" .. npcId

		local torso = Instance.new("Part")
		torso.Name = "HumanoidRootPart"
		torso.Size = Vector3.new(2, 5, 2)
		torso.CFrame = buyerPad.CFrame * CFrame.new(0, 3.5, 0)
		torso.Color = Color3.fromRGB(40, 180, 220)
		torso.Material = Enum.Material.SmoothPlastic
		torso.Anchored = true
		torso.Parent = npcModel

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.5, 1.5, 1.5)
		head.CFrame = torso.CFrame * CFrame.new(0, 3, 0)
		head.Color = Color3.fromRGB(240, 200, 160)
		head.Anchored = true
		head.Parent = npcModel

		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = npcModel

		npcModel.PrimaryPart = torso
		npcModel.Parent = buyerPad

		-- ProximityPrompt for [E] Talk to Buyer / Sell Vehicle
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = string.format("Sell Tier %d ($%d)", requestedTier, offerAmount)
		prompt.ObjectText = "Collector"
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 20
		prompt.Parent = torso

		prompt.Triggered:Connect(function(interactPlayer)
			if interactPlayer == player then
				local success, msg, payout = NPCService.AcceptOffer(interactPlayer, npcId, 1)
				if not success then
					warn("[NPCService] Trade declined: " .. msg)
				end
			end
		end)

		activeOffers[npcId] = {
			offer = offerData,
			model = npcModel,
		}

		print(string.format("[NPCService] 3D NPC %s spawned on %s's pad requesting Pure Tier %d ($%d)", npcId, player.Name, requestedTier, offerAmount))
	end
end

function NPCService.CleanupExpiredOffers(now: number)
	for npcId, offerEntry in pairs(activeOffers) do
		if now >= offerEntry.offer.expiresAt then
			if offerEntry.model then
				offerEntry.model:Destroy()
			end
			activeOffers[npcId] = nil
		end
	end
end

function NPCService.AcceptOffer(player: Player, npcId: string, liftId: number): (boolean, string, number)
	if not DataService.TryLockPlayer(player) then
		return false, "Action in progress", 0
	end

	local offerEntry = activeOffers[npcId]
	if not offerEntry then
		DataService.UnlockPlayer(player)
		return false, "NPC offer expired or invalid", 0
	end

	local offer = offerEntry.offer
	local data = DataService.GetPlayerData(player)
	if not data then
		DataService.UnlockPlayer(player)
		return false, "Player data not found", 0
	end

	local liftKey = tostring(liftId)
	local car = data.Lifts[liftKey]
	if not car then
		DataService.UnlockPlayer(player)
		return false, "No vehicle found on specified lift", 0
	end

	if not car.isComplete then
		DataService.UnlockPlayer(player)
		return false, "Vehicle on lift is incomplete", 0
	end

	if not car.isPureTier then
		DataService.UnlockPlayer(player)
		return false, "NPCs only accept Pure Tier vehicles", 0
	end

	if car.pureTierLevel ~= offer.requestedTier then
		DataService.UnlockPlayer(player)
		return false, string.format("NPC requested Pure Tier %d, but lift has Tier %d", offer.requestedTier, car.pureTierLevel or 0), 0
	end

	local payoutAmount = offer.offerAmount
	EconomyService.AddCash(player, payoutAmount)

	DataService.MutatePlayerData(player, function(d)
		d.Lifts[liftKey] = {
			liftId = liftId,
			engineTier = nil,
			chassisTier = nil,
			bodyTier = nil,
			engineState = nil,
			chassisState = nil,
			bodyState = nil,
			isComplete = false,
			isPureTier = false,
			pureTierLevel = nil,
			cashPerSecond = 0,
		}
	end)

	if offerEntry.model then
		offerEntry.model:Destroy()
	end
	activeOffers[npcId] = nil

	DataService.UnlockPlayer(player)
	print(string.format("[NPCService] Player %s sold Pure Tier %d car on Lift %d to NPC for $%d payout!", player.Name, offer.requestedTier, liftId, payoutAmount))
	return true, "Success", payoutAmount
end

return NPCService
