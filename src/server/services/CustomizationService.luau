--!strict
-- CustomizationService: Signboard Text Filtering & Paint Booth booth coloring
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.types.Types)
local DataService = require(script.Parent.DataService)

local CustomizationService = {}

function CustomizationService.Init()
	print("[CustomizationService] Initialized plot customization & paint service.")
end

function CustomizationService.UpdateSignboard(player: Player, newText: string): (boolean, string)
	if string.len(newText) == 0 or string.len(newText) > 30 then
		return false, "Sign text must be between 1 and 30 characters"
	end

	local filteredText = newText
	local success, err = pcall(function()
		local filterResult = TextService:FilterStringAsync(newText, player.UserId, Enum.TextFilterContext.PublicChat)
		filteredText = filterResult:GetNonChatStringForBroadcastAsync()
	end)

	if not success then
		warn("[CustomizationService] Text filtering failed: " .. tostring(err))
		filteredText = "Chop Shop"
	end

	DataService.MutatePlayerData(player, function(d)
		d.Customization.signText = filteredText
	end)

	print(string.format("[CustomizationService] Updated signboard for %s to: '%s'", player.Name, filteredText))
	return true, filteredText
end

function CustomizationService.UpdateGaragePaint(player: Player, primaryColor: Types.RGBColor, secondaryColor: Types.RGBColor): boolean
	return DataService.MutatePlayerData(player, function(d)
		d.Customization.primaryColor = primaryColor
		d.Customization.secondaryColor = secondaryColor
	end)
end

return CustomizationService
