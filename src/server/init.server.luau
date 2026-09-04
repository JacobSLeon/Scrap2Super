--!strict
-- Server Entrypoint for Scrap to Supercar
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.services.DataService)
local EconomyService = require(script.services.EconomyService)
local MergeService = require(script.services.MergeService)
local LiftService = require(script.services.LiftService)
local HopperService = require(script.services.HopperService)
local ConveyorService = require(script.services.ConveyorService)

print("[Server] Initializing Scrap to Supercar Server Services...")

-- Ensure Remotes folder exists
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local remotesFolder = sharedFolder:FindFirstChild("remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "remotes"
	remotesFolder.Parent = sharedFolder
end

local function getOrCreateRemoteFunction(name: string): RemoteFunction
	local rf = remotesFolder:FindFirstChild(name)
	if not rf then
		rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = remotesFolder
	end
	return rf :: RemoteFunction
end

local requestMergeRF = getOrCreateRemoteFunction("RequestMerge")
local installComponentRF = getOrCreateRemoteFunction("InstallComponent")
local claimCrateRF = getOrCreateRemoteFunction("ClaimCrate")
local withdrawHopperCrateRF = getOrCreateRemoteFunction("WithdrawHopperCrate")

-- Service Initializations
DataService.Init()
EconomyService.Init()
MergeService.Init()
LiftService.Init()
HopperService.Init()
ConveyorService.Init()

-- Network Handlers
requestMergeRF.OnServerInvoke = function(player: Player, slotA: any, slotB: any)
	if typeof(slotA) ~= "number" or typeof(slotB) ~= "number" then
		return false, "Invalid arguments", nil
	end
	return MergeService.MergeItems(player, slotA, slotB)
end

installComponentRF.OnServerInvoke = function(player: Player, liftId: any, gridSlot: any)
	if typeof(liftId) ~= "number" or typeof(gridSlot) ~= "number" then
		return false, "Invalid arguments", nil
	end
	return LiftService.InstallComponent(player, liftId, gridSlot)
end

claimCrateRF.OnServerInvoke = function(player: Player, crateId: any)
	if typeof(crateId) ~= "string" then
		return false, "Invalid argument: crateId must be string", nil
	end
	return ConveyorService.ClaimCrate(player, crateId)
end

withdrawHopperCrateRF.OnServerInvoke = function(player: Player, crateId: any)
	if typeof(crateId) ~= "string" then
		return false, "Invalid argument: crateId must be string", nil
	end
	return HopperService.WithdrawCrate(player, crateId)
end

print("[Server] All Core Services & Remotes Successfully Initialized!")
