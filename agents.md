# Agent Directives & Architecture: Scrap to Supercar

## 1. Engine & Technical Standards
- **Engine:** Roblox Studio / Luau.
- **Typing:** Strict typing mandatory (`--!strict`) across all modules.
- **Tooling:** Managed via **Rojo** and **VS Code**. Scripts live in `src/`.
- **Authority:** Server-authoritative design. All transactions, inventories, part merges, and lift mounting are validated strictly on the server. Clients handle visual interpolation, raycasting feedback, and UI prediction only.
- **Data Persistence:** `ProfileStore` (or `ProfileService`) for atomic, session-locked data saving.

---

## 2. Agent Roles & File Ownership

### Agent Alpha: Data Architecture & Economy (`EconomyAgent`)
- **Files Owned:**
  - `src/server/services/DataService.luau`
  - `src/server/services/EconomyService.luau`
  - `src/shared/config/TierBalance.luau`
  - `src/shared/types/Types.luau`
- **Scope:**
  - Schema management (Cash, Rep Tokens, Rebirth count, Plot customization, 50-slot crate storage).
  - Passive Cash/sec tick calculations for active showroom/lift bays.
  - Rebirth validation, progression wipe, and Reputation Token formula execution.

### Agent Beta: In-World 3D Interaction & Lifting (`InteractionAgent`)
- **Files Owned:**
  - `src/client/controllers/SnapController.luau`
  - `src/client/controllers/LiftHighlightController.luau`
  - `src/server/services/MergeService.luau`
  - `src/server/services/LiftService.luau`
- **Scope:**
  - In-world 3D raycast snapping on workbench nodes.
  - Equipping/holding components $\rightarrow$ green bounding `Highlight` on corresponding lift bays.
  - `[E]` ProximityPrompt interaction to mount sub-assemblies (Engine, Chassis, Body).
  - Evaluating finished cars (Pure Tier vs. Hybrid Build) and updating visual car models.

### Agent Gamma: Conveyor Logistics & Crate Hopper (`LogisticsAgent`)
- **Files Owned:**
  - `src/server/services/ConveyorService.luau`
  - `src/client/controllers/ConveyorVisualizer.luau`
  - `src/server/services/HopperService.luau`
- **Scope:**
  - Spawning crates with configurable rarity tables and speed/interval scaling.
  - Efficient belt movement replication.
  - End-of-belt logic: Shredder (unowned) vs. 50-slot Crate Hopper (Gamepass owned).

### Agent Delta: NPC Trade Broker (`TradeAgent`)
- **Files Owned:**
  - `src/server/services/NPCService.luau`
  - `src/client/controllers/DialogUIController.luau`
- **Scope:**
  - Spawning NPC collectors along the front shop entrance on 60–90s intervals.
  - Generating strictly Pure Tier vehicle requests.
  - Validating requested vehicles on lifts $\rightarrow$ immediate lump-sum cash payouts $\rightarrow$ clearing lift slots.

---

## 3. Network Remote Contract

| Remote Name | Class | Sender | Receiver | Payload |
|---|---|---|---|---|
| `RequestMerge` | RemoteFunction | Client | Server | `itemA: Instance, itemB: Instance` |
| `InstallComponent` | RemoteFunction | Client | Server | `liftId: number, itemInstance: Instance` |
| `ClaimCrate` | RemoteFunction | Client | Server | `crateInstance: Instance` |
| `AcceptNPCOffer` | RemoteFunction | Client | Server | `npcId: string, liftId: number` |
| `ToggleLiftHighlight` | BindableEvent | Client | Client | `targetSlot: Instance, enabled: boolean` |