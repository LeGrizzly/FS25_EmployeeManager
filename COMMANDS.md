# Console Commands Reference

Open the in-game console with the **`** (backtick) key and type any command below.

> Tip: Type `emHelp` to see a quick list of all commands directly in the console.

---

## General

| Command | Description |
|---------|-------------|
| `emHelp` | Lists all available Employee Manager commands with usage info |
| `emStatus` | Displays the current status of all employees and active jobs |
| `emToggleHUD` | Toggles the on-screen Employee Status HUD overlay |

---

## Hiring & Firing

| Command | Usage | Description |
|---------|-------|-------------|
| `emListCandidates` | `emListCandidates` | Lists all available candidates for hire with their skills and traits |
| `emHireRandom` | `emHireRandom` | Generates a new random candidate from the employee templates |
| `emHire` | `emHire <id>` | Hires a candidate by their ID |
| `emFire` | `emFire <id>` | Fires an employee by their ID |

---

## Employee Management

| Command | Usage | Description |
|---------|-------|-------------|
| `emList` | `emList` | Lists all hired employees with their skills, traits, wages, and status |
| `emTrain` | `emTrain <id> <skillName>` | Trains an employee in a specific skill (driving, harvesting, or technical). Costs money and has a cooldown |

### Training Details
- **skillName** must be one of: `driving`, `harvesting`, `technical`
- Cost scales exponentially with the employee's current level
- Cooldown: 2 in-game days for levels 1-5, 3 days for levels 6-10
- Maximum skill level is 10

---

## Vehicle Assignment

| Command | Usage | Description |
|---------|-------|-------------|
| `emAssignVehicle` | `emAssignVehicle <id> <vehId>` | Assigns a vehicle to an employee |
| `emUnassignVehicle` | `emUnassignVehicle <id>` | Removes the vehicle assignment from an employee |
| `emRentVehicle` | `emRentVehicle <empId> <storeItemName>` | Rents a vehicle from the store for an employee by store item name |
| `emDebugVehicles` | `emDebugVehicles` | Lists all vehicles owned by your farm with their IDs |

---

## Task & Job Management

| Command | Usage | Description |
|---------|-------|-------------|
| `emStartTask` | `emStartTask <id> <taskName> [fieldId]` | Starts a specific task for an employee. Optionally specify a field ID |
| `emStartFieldWork` | `emStartFieldWork <id> <fieldId> <type>` | Starts a fieldwork job on a specific field |
| `emStartJob` | `emStartJob <id> [fieldId] [cropName]` | Starts full autonomy mode for an employee. Requires a target crop to be set |
| `emStopJob` | `emStopJob <id>` | Stops the current job for an employee |

### Task Types
Tasks available for `emStartTask`:
- `SOW` — Sowing (requires Driving 2)
- `CULTIVATE` — Cultivating (requires Driving 3)
- `PLOW` — Plowing (requires Driving 4)
- `HARVEST` — Harvesting (requires Harvesting 4)
- `MOW` — Mowing (requires Driving 2)
- `BALE` — Baling (requires Technical 3)
- `MULCH_LEAVES` — Mulching leaves

---

## Crops & Fields

| Command | Usage | Description |
|---------|-------|-------------|
| `emSetTargetCrop` | `emSetTargetCrop <id> <fieldId> <cropName>` | Sets a target crop for an employee on a specific field (used for full autonomy mode) |
| `emSetCrop` | `emSetCrop <id> <fieldId> <cropName>` | Alias for `emSetTargetCrop` |
| `emListCrops` | `emListCrops` | Lists all supported crop types |
| `emListFields` | `emListFields` | Lists all fields owned by your farm with their IDs |

---

## Parking Management

| Command | Usage | Description |
|---------|-------|-------------|
| `emParkingAdd` | `emParkingAdd <name>` | Creates a new parking spot at your current player position |
| `emParkingList` | `emParkingList` | Lists all registered parking spots |
| `emParkingRemove` | `emParkingRemove <id>` | Removes a parking spot by its ID |
| `emParkingAssign` | `emParkingAssign <spotId> <vehicleId>` | Assigns a vehicle to a parking spot for automatic return after jobs |

---

## GUI

| Command | Usage | Description |
|---------|-------|-------------|
| `emMenuWorkflow` | `emMenuWorkflow` | Opens the Workflow Editor menu directly |

---

## Debug Commands

These commands are intended for testing and debugging purposes.

| Command | Usage | Description |
|---------|-------|-------------|
| `emClearAll` | `emClearAll` | Removes all employees (use with caution!) |
| `emReloadGui` | `emReloadGui` | Reloads the GUI (development only) |
| `emGuiReloadFrames` | `emGuiReloadFrames` | Reloads GUI frames (development only) |

---

## Examples

```
-- Hire workflow
emListCandidates            -- See available candidates
emHire 3                    -- Hire candidate #3
emList                      -- Verify they appear in your roster

-- Assign work
emDebugVehicles             -- Find vehicle IDs
emAssignVehicle 1 5         -- Assign vehicle 5 to employee 1
emListFields                -- Find field IDs
emStartFieldWork 1 3 SOW    -- Employee 1 sows field 3

-- Full autonomy
emSetTargetCrop 1 3 wheat   -- Set target crop
emStartJob 1 3 wheat        -- Start autonomous work

-- Training
emTrain 1 driving           -- Train employee 1's driving skill

-- Parking
emParkingAdd MainBarn        -- Create parking spot at your position
emParkingAssign 1 5          -- Vehicle 5 returns to spot 1 after jobs
```
