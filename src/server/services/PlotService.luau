--!strict
-- PlotService: Assigning player plots (1 to 6) & managing signboard gantry orientation
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotService = {}
local assignedPlots: { [Player]: number } = {}
local plotOwners: { [number]: Player } = {}

local MAX_PLOTS = 6

local function teleportToPlot(player: Player)
	local plotFolder = PlotService.GetPlayerPlotFolder(player)
	if not plotFolder then return end

	local floor = (plotFolder:FindFirstChild("PlotFloor") or plotFolder:FindFirstChild("Floor")) :: Part?
	if not floor then return end

	local spawnCF = floor.CFrame * CFrame.new(0, 5, 15)
	local character = player.Character or player.CharacterAdded:Wait()
	if character and character.PrimaryPart then
		character:PivotTo(spawnCF)
		print(string.format("[PlotService] Teleported player %s to Plot %d entrance", player.Name, assignedPlots[player] or 0))
	end
end

local function assignPlotForPlayer(player: Player): number?
	-- Find first free plot from 1 to 6
	for i = 1, MAX_PLOTS do
		if plotOwners[i] == nil then
			assignedPlots[player] = i
			plotOwners[i] = player

			-- Update 3D Signboard Text on front of Plot
			PlotService.UpdatePlotSignboard(i, player.Name .. "'s Chop Shop")
			print(string.format("[PlotService] Assigned Plot %d to player %s", i, player.Name))

			-- Teleport current character to assigned plot & setup lift prompts
			task.defer(function()
				teleportToPlot(player)
				local LiftService = require(script.Parent.LiftService)
				LiftService.SetupPlotLiftPrompts(player)
				LiftService.RenderAllLiftVisuals(player)
			end)
			return i
		end
	end
	warn(string.format("[PlotService] No free plots available for player %s", player.Name))
	return nil
end

function PlotService.Init()
	Players.PlayerAdded:Connect(function(player)
		assignPlotForPlayer(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			teleportToPlot(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if not assignedPlots[player] then
			assignPlotForPlayer(player)
		end
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			teleportToPlot(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local plotId = assignedPlots[player]
		if plotId then
			plotOwners[plotId] = nil
			assignedPlots[player] = nil
			PlotService.UpdatePlotSignboard(plotId, "Chop Shop #" .. tostring(plotId))
			print(string.format("[PlotService] Unassigned Plot %d for leaving player %s", plotId, player.Name))
		end
	end)

	print("[PlotService] Initialized garage plot assignment & player spawning service.")
end

function PlotService.GetPlayerPlotId(player: Player): number?
	return assignedPlots[player]
end

function PlotService.GetPlayerPlotFolder(player: Player): Folder?
	local plotId = assignedPlots[player]
	if not plotId then return nil end

	local map = Workspace:FindFirstChild("ChopShopDistrict")
	if not map then return nil end

	return map:FindFirstChild("Plot_" .. tostring(plotId)) :: Folder?
end

function PlotService.UpdatePlotSignboard(plotId: number, text: string)
	local map = Workspace:FindFirstChild("ChopShopDistrict")
	if not map then return end

	local plotFolder = map:FindFirstChild("Plot_" .. tostring(plotId))
	if not plotFolder then return end

	local signGantry = plotFolder:FindFirstChild("SignGantry")
	if not signGantry then return end

	for _, child in ipairs(signGantry:GetChildren()) do
		if child:IsA("SurfaceGui") then
			local label = child:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = text
			end
		end
	end
end

return PlotService
