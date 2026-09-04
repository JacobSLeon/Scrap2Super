--!strict
-- Client Entrypoint for Scrap to Supercar
local SnapController = require(script.controllers.SnapController)
local LiftHighlightController = require(script.controllers.LiftHighlightController)

print("[Client] Initializing Scrap to Supercar Client Controllers...")

SnapController.Init()
LiftHighlightController.Init()

print("[Client] All Core Controllers Successfully Initialized!")
