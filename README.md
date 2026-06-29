# WarbandAccountant

**Warband Accountant** is a World of Warcraft addon that automates gold management across your entire Warband. Set a target gold amount for each character and the addon handles the rest — depositing excess gold to your Warband Bank or withdrawing from it to top characters up, every time you open the bank. Whether you need every alt to maintain a repair fund, your crafter stocked with materials capital, or your auctioneer sitting on a trading bankroll, Warband Accountant eliminates the manual micromanagement of moving gold between characters.

Version 2.0.0 brings a complete UI overhaul — everything now lives in a single unified window with a side navigation bar, including a new Overview dashboard, inline settings, and an expanded character type system with 6 fully renameable categories.

---

## Features

### Overview Dashboard
At-a-glance stat cards show your Warband Bank balance, total gold across all characters, weekly income since reset, and your session gain or loss. Below the cards is a full character list showing each character's current gold, their target, and the difference.

### Automatic Transfers
Opening your Warband Bank triggers instant calculations. Characters above their target deposit the excess; characters below their target withdraw the deficit — as long as the Warband Bank can cover it. Smart processing prevents duplicate transactions during the same bank visit.

### Per-Character Gold Targets
Set a precise gold target for every character in your Warband. Assign a character type to automatically apply that category's default, or enter any custom amount.

### 6 Renameable Character Categories
Six built-in character categories, each with its own configurable default gold target:

| Category | Default Target |
|---|---|
| Main | 50,000g |
| Main Alt | 25,000g |
| Alt | 500g |
| Crafter | 5,000g |
| Auctioneer | 500,000g |
| Bank Alt | 20,000g |

Every category name is renameable from the Settings tab. Custom names propagate everywhere in the addon automatically.

### Transaction Ledger
Every automatic and manual transfer is recorded. Filter by character, track the running Warband Bank balance after each transaction, and monitor lifetime deposited, withdrawn, and net gold. Stores up to 1,000 entries.

### Weekly Income Tracking
Tracks net Warband Bank income since your weekly reset, automatically calibrated per region:
- **NA:** Tuesday
- **EU:** Wednesday
- **KR / TW:** Thursday

### Guild Bank Tracking
Guild Masters can see their Guild Bank balance in the Overview dashboard and minimap tooltip. The last known balance is cached and visible from any character in the guild.

### Per-Character Pause
Disable automation for individual characters without removing them from tracking — useful for characters holding gold for a specific purchase or currently being leveled.

### Minimap Button
Built with LibDBIcon for full compatibility with MinimapButtonBag Reborn, SexyMap, ElvUI, and other button managers. Hover for a quick summary tooltip. Left-click opens Overview, right-click opens Settings.

---

## Slash Commands

```
/wba                    Open Overview
/wba targets            Jump to Targets tab
/wba ledger             Jump to Ledger tab
/wba settings           Jump to Settings tab
/wba changelog          Jump to Changelog tab
/wba process            Force transfer check (bank must be open)
/wba delete <name>      Remove a character from tracking
/wba weekly             Show weekly income debug info
/wba resetgm            Reset Guild Master cache
/wba clearguild         Clear cached guild bank data
```

---

## Settings

All settings are inside the addon window (Settings tab). The Blizzard addon panel entry is a lightweight stub that opens the addon.

- **Automation** — Toggle auto-deposit and auto-withdraw independently. Optionally require a confirmation popup before any transfer.
- **Display** — Sort mode for the Targets tab (arrow buttons or number input). Show or hide the minimap button.
- **Category Names & Default Targets** — Rename any of the 6 categories and configure their default gold targets.
- **Danger Zone** — Reset all statistics, clear ledger history, or reset the window position.

---

## Installation

### CurseForge App (recommended)
Search for **Warband Accountant** and install directly.

### Manual
1. Download the latest release from the [Releases](https://github.com/I-AM-T3X/WarbandAccountant/releases) page
2. Extract the `WarbandAccountant` folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Restart WoW or reload your UI (`/reload`)

All libraries (LibDBIcon-1.0, LibDataBroker-1.1, CallbackHandler-1.0, LibStub) are bundled — no separate installs required.

---

## Compatibility

- **Retail WoW** — patch 12.0.0+ (Midnight: Revelations)
- Not compatible with Classic, Cataclysm Classic, or Season of Discovery

---

## Bug Reports & Feature Requests

Please open an issue on the [GitHub Issues](https://github.com/I-AM-T3X/WarbandAccountant/issues) page. Include your addon version and any error output from the in-game error frame.

You can also reach me on Discord: [discord.gg/TDtKmmKGbU](https://discord.gg/TDtKmmKGbU)

---

## License

Licensed under the [GNU General Public License v3.0](LICENSE).
