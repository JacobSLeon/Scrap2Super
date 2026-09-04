# Scrap to Supercar — System Specification

## 1. Core Game Loop
1. **Inflow:** Crates travel along a conveyor belt. Players claim crates via click/prompt.
2. **Merge:** Unbox parts onto an in-world 3D workbench grid (e.g., 4x4 snapping slots). Drag and merge matching tiers to upgrade components.
3. **Assembly:** Walk completed sub-assemblies to a Hydraulic Lift. Press `[E]` to mount parts onto the chassis.
4. **Passive Income:** Complete cars on lifts generate passive Cash/sec.
5. **Burst Income (Trading):** Sell pure-tier cars to visiting NPC collectors for instant lump-sum payouts.
6. **Rebirth (Sell Shop):** Reset Cash, parts, and standard upgrades to earn Reputation Tokens, upgrade shop aesthetics, and permanently unlock +1 Hydraulic Lift per rebirth.

---

## 2. Vehicle Assembly Rules (The Rule of 3)
A complete car requires three mounted sub-assemblies:
- **Assembly 1: Engine Block** (Spark Plug $\rightarrow$ Piston $\rightarrow$ Camshaft $\rightarrow$ Turbo $\rightarrow$ Engine Block)
- **Assembly 2: Rolling Chassis** (Brake Pad $\rightarrow$ Coilover $\rightarrow$ Axle $\rightarrow$ Brake/Wheel Kit $\rightarrow$ Rolling Chassis)
- **Assembly 3: Aero Body** (Primer $\rightarrow$ Quarter Panel $\rightarrow$ Hood/Trunk $\rightarrow$ Aero Spoiler $\rightarrow$ Widebody Shell)

### Vehicle Classifications
- **Pure Tier Cars:** All three mounted assemblies share the same tier level ($T_n$).
  - Generates passive Cash/sec with a **1.25x Pure Synergy Bonus**.
  - **Eligible for NPC Trade Offers.**
- **Hybrid Cars:** Mounted assemblies have mixed tier levels.
  - Generates passive Cash/sec equal to the sum of individual part values.
  - **Ineligible for NPC Trade Offers** (NPCs demand pure builds).

---

## 3. In-World 3D Interaction Spec
- **Workbench Snapping:** Physical snapping nodes on the garage table with bounding-box placement indicators.
- **Lift Alignment & Visual Feedback:**
  - When holding a valid sub-assembly in hand, the designated attachment slot on the player's Hydraulic Lift renders a visible green `Highlight` outline.
  - Walking to the lift reveals an interaction prompt: `[E] Install [Component]`.
  - Adding components updates the physical car model iteratively:
    - *Bare Lift $\rightarrow$ Rolling Chassis $\rightarrow$ Engine Installed $\rightarrow$ Full Body Mounted.*

---

## 4. Conveyor Logistics & Crate Storage
- **Conveyor Spawning:** Drops crates at an adjustable interval (Base: 4 seconds).
- **Rarity Classes:** Common (Rusted) $\rightarrow$ Uncommon (Street) $\rightarrow$ Rare (Pro) $\rightarrow$ Legendary (Spec-R).
- **End-of-Belt Retention:**
  - *Standard:* Crates that hit the end fall into the shredder and are destroyed.
  - *Premium (Robux / Gamepass):* Activates the **Overflow Hopper (50-Slot Inventory)**. Uncollected crates are automatically routed into storage, accessible via an adjacent terminal.

---

## 5. Economic Formulas & Balancing
- **Cash ($):** Transient currency spent on conveyor spawn rate, crate tier probabilities, workbench expansion, and garage paint. Resets on rebirth.
- **Reputation Tokens (Rep):** Permanent prestige currency awarded on rebirth:
  $$\text{Rep Earned} = \left\lfloor \sqrt{\frac{\text{Lifetime Cash Earned}}{10,000}} \right\rfloor$$
- **Black Market Upgrades (Rep Tree):**
  - *Pneumatic Line:* +5% chance for higher-tier crates to drop directly from the belt.
  - *Torque Multiplier:* Global +10% passive income boost across all active lifts.
  - *Priority Broker:* NPC buyers arrive 20% faster with +15% trade payout values.

---

## 6. Plot Customization
- **Signage:** Billboard mounted above the bay entrance displaying custom text sanitized via `TextService:FilterStringAsync`.
- **Paint Station:** Interactive booth allowing players to configure Primary and Secondary colors across garage beams, trims, and lift posts.