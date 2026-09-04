--!strict
-- LiftHighlightController: Client-side green highlight outlines for active lift bays
local Workspace = game:GetService("Workspace")

local LiftHighlightController = {}
local activeHighlights: { [Instance]: Highlight } = {}

function LiftHighlightController.Init()
	print("[LiftHighlightController] Initialized lift highlight feedback controller.")
end

function LiftHighlightController.SetSlotHighlight(targetSlot: Instance, enabled: boolean, color: Color3?)
	if enabled then
		local existing = activeHighlights[targetSlot]
		if not existing then
			local highlight = Instance.new("Highlight")
			highlight.Name = "LiftTargetHighlight"
			highlight.FillColor = color or Color3.fromRGB(0, 255, 120)
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = 0.5
			highlight.OutlineTransparency = 0.1
			highlight.Adornee = targetSlot
			highlight.Parent = targetSlot
			activeHighlights[targetSlot] = highlight
		end
	else
		local existing = activeHighlights[targetSlot]
		if existing then
			existing:Destroy()
			activeHighlights[targetSlot] = nil
		end
	end
end

function LiftHighlightController.ClearAllHighlights()
	for slot, highlight in pairs(activeHighlights) do
		highlight:Destroy()
		activeHighlights[slot] = nil
	end
end

return LiftHighlightController
