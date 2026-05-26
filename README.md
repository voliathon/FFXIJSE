# FFXIJSE

Job Specific Equipment tracker with a GSUI-style window.

## Special Thanks

All credit for the underlying addon goes to **Nalfey of Asura**, who
researched the upgrade-data, wrote the inventory + currency scanners,
and built the original JSE addon. FFXIJSE is a derivative work — the
data modules `inventory.lua`, `currency.lua`, `job_equipment.lua`, and
the per-job files in `jobs/` are Nalfey's, unmodified.

Thanks also to **Daleterrence**, who hosts the upstream JSE mirror with
Nalfey's permission so the broader community can find and install it.

This fork adds a draggable GSUI-style window UI on top of Nalfey's
data layer. The original JSE chat-based output is fully usable on its
own — installing FFXIJSE is only about the visual presentation.

## What this is

Tracks AF / Relic / Empyrean equipment across the NQ → +1 → +2 → +3 →
+4 upgrade chain. Reads your inventory across every storage slip
(Storage NPCs, Mog Wardrobes, etc.), tracks the relevant currencies
(Rem's Tale Chapters, Apollyon Units, Temenos Units, Gallimaufry), and
tells you for every piece on the selected job:

- which tier you currently own
- which materials are needed to reach the next tier
- whether you have all the materials right now to do that upgrade

## Install

```
cd path\to\Windower4\addons
git clone https://github.com/mullerdane85-hash/FFXIJSE.git
```

In-game:

```
//lua load FFXIJSE
```

To autoload every session, add `lua load FFXIJSE` to
`scripts\init.txt`.

## Window

Press **O** to toggle the window (chat-aware — the key passes through
to chat when typing). Or run `//fj` (or `//ffxijse`).

Layout (matches GSUI's visual style — blue border, dark title bar,
tab buttons inside the title bar):

```
┌─ 3px blue border ────────────────────────────────────────────┐
│ FFXIJSE       [AF][Relic][Empy]                      [WAR]   │
├──────────────────────────────────────────────────────────────┤
│  Pummeler's Mask              ✗ NEED  +2 → +3                │
│     P. WAR Card           0/12    ✗                          │
│     Kin's Scale           4/1     ✓                          │
│     Khoma Cloth           0/1     ✗                          │
│  Pummeler's Lorica            ✓ MAXED (+4)                   │
│  Pummeler's Mufflers          ✓ MAXED (+4)                   │
│  ...                                                          │
└──────────────────────────────────────────────────────────────┘
```

Per-piece status indicator:
- `✓ MAXED (+4)` — piece is at maximum tier
- `✓ READY +2 → +3` — you have ALL materials to do the next upgrade
- `✗ NEED +2 → +3` — you own the piece but lack some materials
- `? owns NONE → +1` — you don't own the piece at all

Below each non-maxed piece, the required materials list:
- `✓` = you have enough
- `✗` = you need more

## Commands

| Command | What |
|---|---|
| `//fj` (or `//ffxijse`) | Toggle the window (same as O key) |
| `//fj show` / `//fj hide` | Explicit show/hide |
| `//fj af` / `//fj relic` / `//fj empy` | Switch tab |
| `//fj job <JOB>` | Override displayed job (e.g. `//fj job war`) |
| `//fj job auto` | Clear override; track current main job |
| `//fj refresh` | Re-scan inventory + currency |
| `//fj help` | Command list |

By default the window auto-detects your current main job and updates
on job change / zone change. The `J` key toggles visibility.

## Data behavior

Same as the original JSE:
- Reads inventory across **all storage slips** (Storage NPCs, Mog
  Wardrobes, etc.) via the Slips library
- Tracks Rem's Tale Chapters, Apollyon Units, Temenos Units, and
  Gallimaufry via currency packets
- Per-character data file written under `data/` (gitignored)
- Cross-character mule check is NOT yet ported from JSE's `//jseall`
  command — TODO

## Credits

- **Nalfey of Asura** — original JSE addon. Data modules, scanning,
  currency tracking, the entire job-equipment database. All credit
  for the actual upgrade-data research and packet handling goes to
  Nalfey. FFXIJSE could not exist without that work.
- **Daleterrence** — hosts the upstream JSE mirror with Nalfey's
  permission. FFXIJSE is derived from that mirror.
- **mullerdane85-hash** — GSUI-style window UI on top of Nalfey's
  data layer.

BSD 3-clause license inherited from JSE — see `LICENSE`.

## TODO / future extensions

- `//ffxijse all` cross-character / mule check (port from JSE's
  `//jseall`)
- Auto-refresh when the player approaches a known ??? NPC for
  upgrade turn-ins (Voliathon's request — proximity-based refresh)
- Job picker dropdown in the title bar (currently job override is
  command-only)
- Per-tier filter (e.g. show only pieces stuck at +2)
