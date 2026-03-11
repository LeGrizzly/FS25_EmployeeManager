# Advanced Employee Manager for Farming Simulator 25

Bring a new level of depth to your farm's workforce. Hire and manage employees with unique skills to optimize your operations.

> [!IMPORTANT]  
> **Note:** This mod is currently in a testing phase for bug fixing and error correction.

## Features

### Employee Roster & Hiring
- Browse and hire from a pool of 20 unique employee templates, each with distinct skill ranges and personality traits
- View your full workforce roster with detailed stats: skills, traits, wages, fatigue, and current assignments
- Fire underperforming employees when needed

### Skill System (3 Skills, 10 Levels)
Each employee has three skills that grow through on-the-job experience:

- **Driving** — Affects fuel consumption and AI work speed
  - Levels 3-4: -5% to -10% fuel consumption
  - Levels 5-6: +5% to +10% AI work speed
  - Levels 7-8: -15% fuel
  - Levels 9-10: -20% fuel, +20% speed
- **Harvesting** — Affects crop yield
  - Levels 1-2: -5% to -3% yield penalty
  - Levels 3-4: Normal yield
  - Levels 5-6: +3% to +5% bonus yield
  - Levels 7-10: Up to +15% bonus yield
- **Technical** — Affects equipment wear
  - Reduces wear from 0% (level 1) up to 62.5% (level 10)

#### Exponential XP Curve
Skills progress quickly at low levels but require real investment at higher levels:

| Level | XP Required | Approx. Playtime |
|-------|-------------|------------------|
| 1 to 2 | 100 | ~2 hours |
| 5 to 6 | 506 | ~11 hours cumulative |
| 9 to 10 | 2,563 | ~50 hours cumulative |

Experience is earned automatically while employees perform tasks (driving, harvesting, fieldwork, etc.).

### Trait System (Up to 2 Traits)
Each employee can have up to 2 personality traits that modify their performance:

| Trait | Effect |
|-------|--------|
| **Careful** | -15% equipment wear |
| **Reckless** | +20% equipment wear |
| **Hard Worker** | +10% work speed |
| **Quick Learner** | +25% XP gain |
| **Fuel Saver** | -10% fuel consumption |
| **Frugal** | -10% wages |

Traits stack multiplicatively when an employee has two traits.

### Milestone System
Employees earn milestone titles as they level up, providing permanent bonuses:

| Level | Title | Reward |
|-------|-------|--------|
| 3 | Apprentice | Unlocks intermediate tasks |
| 5 | Companion | +5% permanent wage bonus |
| 7 | Expert | Recognition badge in GUI |
| 10 | Master | +5% additional wage bonus, title displayed |

Milestone achievements trigger in-game notifications.

### Training System
- Train employees at any time by spending money to instantly level up a skill
- Training cost scales exponentially with skill level
- Cooldown between training sessions: 2 days (levels 1-5), 3 days (levels 6-10)
- Strategic choice: invest in training or let skills grow naturally through work

### Workflow & Task Management
- Assign employees to specific tasks: sowing, cultivating, plowing, harvesting, mowing, mulching, baling, and more
- Skill gates ensure employees meet minimum requirements before taking on advanced tasks
- Task assignment respects vehicle compatibility and employee qualifications

| Task | Required Skill |
|------|---------------|
| Sow | Driving 2 |
| Cultivate | Driving 3 |
| Plow | Driving 4 |
| Harvest | Harvesting 4 |
| Bale | Technical 3 |
| Mow | Driving 2 |

### Wage & Payroll System
- Dynamic wages based on skill levels: `$5 + (driving x 0.8) + (harvesting x 0.8) + (technical x 0.4)`
- Trait modifiers (Frugal reduces wages by 10%)
- Milestone bonuses increase wages permanently
- Automatic hourly payroll processing
- Wage breakdown visible in employee details

### Fatigue & Break Management
- Employees accumulate fatigue while working
- Automatic break scheduling when fatigue reaches threshold
- Break duration and fatigue recovery configurable
- Shift tracking with work hour limits

### Vehicle & Parking Management
- Assign vehicles to employees for their tasks
- Automatic parking return when jobs are completed
- Parking spot management for your fleet

### Employee Analytics
- Track kilometers driven per employee
- Monitor work hours and shift history
- View pending wages and payroll history
- Fatigue levels and break status at a glance

### Multiplayer Support
- Full multiplayer synchronization via network events
- Server-authoritative employee management
- Stream versioning for save compatibility

### Console Commands
27 commands available to manage your workforce directly from the console. Here are the most common ones:

- `emHelp` — List all available commands
- `emList` — Display all employees with skills, traits, and status
- `emHire <id>` — Hire a candidate by ID
- `emFire <id>` — Fire an employee by ID
- `emStartJob <id>` — Start full autonomy mode
- `emTrain <id> <skill>` — Train an employee's skill
- `emStatus` — Check status of all employees and jobs

See **[COMMANDS.md](COMMANDS.md)** for the full reference with usage examples.

## Save Compatibility
- Backward compatible with older saves
- Automatic migration from single-trait to multi-trait format
- Skills from previous versions (1-5 range) load seamlessly into the new 10-level system

## Installation
1. Download the latest release
2. Place the ZIP file in your FS25 mods folder
3. Enable the mod in the game's mod manager

---

## Feedback

Your feedback is invaluable as we cultivate this project. Please feel free to raise an issue on this repository to report bugs or suggest new features.

---

## Credits
- **Author**: LeGrizzly
- **Version**: 0.0.6

---

## 📝 License

This mod is licensed under **[CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)**.

You may share it in its original form with attribution. You may not sell it, modify and redistribute it, or reupload it under a different name or authorship. Contributions via pull request are explicitly permitted and encouraged.

---

## ☕ Support

If you enjoy this mod and want to support my work, consider buying me a coffee!
<br><br>
<a href="https://buymeacoffee.com/legrizzly"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" width="150" alt="Buy Me A Coffee" /></a>
