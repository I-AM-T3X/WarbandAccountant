# WarbandAccountant

**Warband Accountant** is a World of Warcraft addon that automates gold management across your entire Warband. Set a target gold amount for each character and the addon handles the rest, depositing excess gold to your Warband Bank or withdrawing from it to top characters up, every time you open the bank. Whether you need every alt to keep a repair fund, your crafter stocked with materials capital, or your auctioneer sitting on a trading bankroll, Warband Accountant removes the manual work of moving gold between characters.

Version 2.3.0 adds Savings Goals, WoW Token affordability on the Overview, time ranges on every graph, and a rebuilt native graph engine.

Full documentation lives in the [Wiki](https://github.com/I-AM-T3X/WarbandAccountant/wiki).

---

## Features

### Overview Dashboard
Stat cards show your Warband Bank balance, gold in bags, income this week, and the current WoW Token price. Below them are your tracked guild bank balance, your combined Account Total (Warband Bank plus every character's current gold), and a full character list with each character's current gold, target, and difference.

### Automatic Transfers
Opening your Warband Bank triggers instant calculations. Characters above their target deposit the excess. Characters below their target withdraw the deficit, as long as the Warband Bank can cover it. Smart processing prevents duplicate transactions during the same bank visit, and you can require a confirmation prompt before any transfer.

### Per-Character Gold Targets
Set a precise gold target for every character in your Warband. Assign a character type to apply that category's default, or enter any custom amount.

### 6 Renameable Character Categories
Six built-in categories, each with its own configurable default gold target:

| Category | Default Target |
|---|---|
| Main | 100g |
| Main Alt | 100g |
| Alt | 100g |
| Crafter | 50g |
| Auctioneer | 500g |
| Bank Alt | 200g |

Every category name and default is editable from the Settings tab. Custom names show up everywhere in the addon automatically.

### Savings Goals
Set a gold amount to work toward and the Goals tab tracks it for you.
- Progress bar, a finish estimate based on how fast your Warband Bank has actually been growing, and a 30-day graph with your goal line and projected pace
- Follow the WoW Token price instead of a fixed amount with **Use WoW Token price**
- Optional end date with days left, the gold needed per day or week, and an on pace or behind pace status, plus an end-date marker and required-pace line on the graph
- Estimates can be shown in days or weeks
- A one-time chat message when you reach the goal

### Gold History
A graph of your gold over time. View your Warband Bank total, your Account Total, or a single character's net contribution to the bank. Choose 24 Hours, 7 Days, 30 Days, or All, and hover for a crosshair readout.

### WoW Token Tracking
A price graph (24 Hours, 3 Days, or 7 Days), a full price history log, optional low and high price alerts, and an optional floating price frame that can also show your weekly profit. Overview Token affordability shows how many Tokens your Warband Bank gold can buy and roughly how long until the next one.

### Transaction Ledger
Every automatic and manual transfer is recorded. Filter by character, track the running Warband Bank balance after each transaction, and monitor lifetime deposited, withdrawn, and net gold. Stores up to 5,000 entries.

### Weekly Income Tracking
Tracks net Warband Bank income since your weekly reset. The reset time comes straight from the game's own reset countdown, so it is correct on every region and realm with no hardcoded schedule.

### Guild Bank Tracking
Guild Masters can see their guild bank balance in the Overview and minimap tooltip. The last known balance is cached and visible from any character, including alts in other guilds. If you manage two or more guild banks, a Guild Banks tab lists them all with a combined total. The game only reports the balance while the guild bank is open, so the number is refreshed whenever a Guild Master opens it.

### Per-Character Pause
Disable automation for individual characters without removing them from tracking, useful for characters holding gold for a specific purchase or being leveled.

### Languages
Available in English and Simplified Chinese. Volunteers are welcome to help with more languages.

### Minimap Button
Built with LibDBIcon for compatibility with MinimapButtonBag Reborn, SexyMap, ElvUI, and other button managers. Hover for a quick summary tooltip. Left-click opens Overview, right-click opens Settings.

---

## Slash Commands

```
/wba                    Open Overview
/wba targets            Jump to Targets tab
/wba ledger             Jump to Ledger tab
/wba token              Jump to Token History tab
/wba settings           Jump to Settings tab
/wba changelog          Jump to Changelog tab
/wba support            Jump to Support tab
/wba tutorial           Replay the first-run tutorial
/wba process            Force transfer check (bank must be open)
/wba weekly             Show weekly income debug info
/wba debuginfo          Region, realm and time diagnostics for bug reports
/wba delete <name>      Remove a character from tracking
/wba resetgm            Reset Guild Master cache
/wba clearguild         Clear cached guild bank data
```

---

## Settings

All settings are inside the addon window (Settings tab). The Blizzard addon panel entry is a lightweight stub that opens the addon.

- **Automation**: toggle auto-deposit and auto-withdraw independently, and optionally require a confirmation popup before any transfer.
- **Display**: Targets sort mode, minimap button, UI scale (50% to 300%), thousands separator, and whether the Changelog opens automatically after an update.
- **Language**: English or Simplified Chinese.
- **Category Names & Default Targets**: rename any of the 6 categories and set their default gold targets.
- **Guild Bank**: choose which synced guild an alt displays.
- **Savings Goal**: name, amount, WoW Token price, end date, and days or weeks estimate.
- **Token Price**: update frequency, floating frame options, price alerts, and legacy data import.
- **Danger Zone**: reset statistics, clear ledger or Token history, or reset the window position.

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

All libraries (LibDBIcon-1.0, LibDataBroker-1.1, CallbackHandler-1.0, LibStub) are bundled, so no separate installs are required. The graphs are drawn by a built-in module with no external graph library.

---

## Compatibility

- **Retail WoW**: patch 12.0.7 and later (Midnight), including 12.1.0 and 12.1.5
- Not compatible with Classic, Cataclysm Classic, or Season of Discovery

---

## Bug Reports & Feature Requests

Please open an issue on the [GitHub Issues](https://github.com/I-AM-T3X/WarbandAccountant/issues) page. Include the output of `/wba debuginfo` and any error text from the in-game error frame.

You can also reach me on Discord: [discord.gg/TDtKmmKGbU](https://discord.gg/TDtKmmKGbU)

---

## License

Licensed under the [GNU General Public License v3.0](LICENSE).
