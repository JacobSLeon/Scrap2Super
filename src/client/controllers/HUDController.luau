--!strict
-- HUDController: Modern screen HUD displaying Cash, Passive Income, Rep Tokens & Rebirth
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HUDController = {}
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local cashLabel: TextLabel
local repLabel: TextLabel
local rebirthBtn: TextButton

function HUDController.Init()
	print("[HUDController] Initializing ScreenGui HUD controller.")

	-- Create ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ScrapToSupercarHUD"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Top Stats Container
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(0, 320, 0, 90)
	statsFrame.Position = UDim2.new(0.02, 0, 0.02, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	statsFrame.BackgroundTransparency = 0.15
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = statsFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 180, 255)
	stroke.Thickness = 2
	stroke.Parent = statsFrame

	-- Cash Label
	cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Size = UDim2.new(1, -20, 0, 40)
	cashLabel.Position = UDim2.new(0, 10, 0, 5)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Text = "Cash: $100"
	cashLabel.TextColor3 = Color3.fromRGB(0, 230, 120)
	cashLabel.TextSize = 24
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.Parent = statsFrame

	-- Rep Tokens Label
	repLabel = Instance.new("TextLabel")
	repLabel.Name = "RepLabel"
	repLabel.Size = UDim2.new(1, -20, 0, 35)
	repLabel.Position = UDim2.new(0, 10, 0, 45)
	repLabel.BackgroundTransparency = 1
	repLabel.Text = "Rep Tokens: 0"
	repLabel.TextColor3 = Color3.fromRGB(240, 190, 40)
	repLabel.TextSize = 18
	repLabel.Font = Enum.Font.FredokaOne
	repLabel.TextXAlignment = Enum.TextXAlignment.Left
	repLabel.Parent = statsFrame

	-- Rebirth Button (Bottom Right)
	rebirthBtn = Instance.new("TextButton")
	rebirthBtn.Name = "RebirthButton"
	rebirthBtn.Size = UDim2.new(0, 180, 0, 50)
	rebirthBtn.Position = UDim2.new(0.98, -180, 0.95, -50)
	rebirthBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	rebirthBtn.Text = "REBIRTH (+0 Rep)"
	rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	rebirthBtn.TextSize = 18
	rebirthBtn.Font = Enum.Font.FredokaOne
	rebirthBtn.Parent = screenGui

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = rebirthBtn

	-- Remote listeners for real-time state sync
	rebirthBtn.MouseButton1Click:Connect(function()
		local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
		local remotesFolder = sharedFolder:WaitForChild("remotes")
		local requestRebirthRF = remotesFolder:WaitForChild("RequestRebirth") :: RemoteFunction
		local success, repEarned = requestRebirthRF:InvokeServer()
		if success then
			print("[HUDController] Successfully rebirthed!")
		end
	end)
end

return HUDController
