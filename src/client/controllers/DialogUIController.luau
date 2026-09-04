--!strict
-- DialogUIController: Handles 3D interaction prompts and trade UI for visiting NPCs
local Players = game:GetService("Players")

local DialogUIController = {}
local localPlayer = Players.LocalPlayer

function DialogUIController.Init()
	print("[DialogUIController] Initialized NPC dialog UI controller.")
end

function DialogUIController.PromptNPCTrade(npcId: string, requestedTier: number, offerAmount: number)
	print(string.format("[DialogUIController] Prompting trade offer: NPC %s wants Pure Tier %d for $%d", npcId, requestedTier, offerAmount))
end

return DialogUIController
