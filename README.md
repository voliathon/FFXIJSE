<!-- BEGIN DISCLAIMER (managed by FFXIWindower author; do not remove) -->
## ⚠️ Disclaimer — Use at Your Own Risk

This is unofficial, fan-made software for *Final Fantasy XI*. It is **not affiliated with, endorsed by, or supported by Square Enix Holdings Co., Ltd.** FINAL FANTASY is a registered trademark of Square Enix.

**Square Enix's official position is that third-party tools and modifications to the FFXI client are prohibited by the Terms of Service.** Installing or using this software may result in account suspension, account termination, character data loss, or other action taken by Square Enix at their sole discretion.

This software is provided **AS IS, without warranty of any kind**, express or implied — including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the author or contributors be liable for any claim, damages, account action, lost time, lost progress, file corruption, or any other liability arising from the use of, or inability to use, this software.

**By installing, building, or running this software you acknowledge that you understand and accept these risks.**

<!-- END DISCLAIMER -->
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

## Capes tab

The 4th tab (**Capes**) tracks the Ambuscade JSE cape for the
**currently-selected job** (Cichol's Mantle for WAR, Alaunus's Cape
for WHM, etc. — the Mhaura Gorpa-Masorpa cape, one per job). It
walks every storage and lists **every copy of that cape you own**,
so if you keep two Alaunus's Capes with different augment builds
they both show up (disambiguated with `(#1)`, `(#2)`).

For each cape it reads the augments via `extdata.decode()` and shows
per-slot status. Long augment strings are word-wrapped to multiple
lines so nothing runs off the right edge.

```
┌─ FFXIJSE ───────────────[AF][Relic][Empy][Capes]─────────────┐
│ ✗ Alaunus's Cape (#2)  3/4 filled                            │
│   ✓ MND+20  [Thread MAX]                                     │
│   ✗ Mag. Acc.+20 /Mag. Dmg.+20  [Dust → Abdhaljs Dust]       │
│       Abdhaljs Dust → {Inv 4, Case 2}                        │
│   ✓ "Fast Cast"+10  [Sap MAX]                                │
│   (1 Augment Available)                                      │
│ ✓ Alaunus's Cape (#3)  FULL (4/4 MAX)                        │
│   ✓ MND+20  [Thread MAX]                                     │
│   ✓ Accuracy+20 Attack+20  [Dust MAX]                        │
│   ✓ STR+10  [Dye MAX]                                        │
│   ✓ "Cure" potency+10  [Sap MAX]                             │
└──────────────────────────────────────────────────────────────┘
```

Per-line meaning:
- **Green `✓ ... [Thread MAX]`** — augment is at the category maximum.
- **Red `✗ ... [Thread → Abdhaljs Thread]`** — augment is below max;
  the bracketed item is what to bring to Gorpa-Masorpa to upgrade it.
- **Grey sub-line `Abdhaljs Dust → {Inv 4, Case 2}`** — shown under each
  non-max augment. Lists the bags holding the upgrade item and how
  many you have, so you can see at a glance whether you're ready to
  upgrade or still need to farm. `(none in storage)` if you have zero.
- **Red `(N Augments Available)`** — footer below the last augment;
  this many slots are unfilled and can still take a new augment item.

Header summary next to the cape name (and job tag):
- `FULL (4/4 MAX)` — every slot is filled and at the category max.
- `N/4 MAX` — all 4 slots filled, N of them at max.
- `N/4 filled` — N slots have augments; the rest are empty.

Slot → item mapping (matches capetrader's order):
1. **Thread** → Abdhaljs Thread (stats: HP/MP, STR/DEX/VIT/AGI/INT/MND/CHR)
2. **Dust**   → Abdhaljs Dust   (combat: acc/atk, racc/ratk, macc/mdmg, eva/meva)
3. **Dye**    → Abdhaljs Dye    (secondary stats — same stat pool, smaller cap)
4. **Sap**    → Abdhaljs Sap    (effects: WSD, crit, STP, DA, haste, dual wield, etc.)

The job dropdown filters the Capes tab the same way it filters
AF/Relic/Empy — pick WHM and you see your Alaunus's Capes only.
Switch jobs via the `[JOB ▼]` dropdown to inspect a different cape.

Reference data (max values and category match rules) sourced from
BG-Wiki's JSE Capes page. FFXIJSE only reads the cape — it doesn't
trade for you. Use `//capetrader` for the actual augment automation
(or the in-game NPC at Mhaura).

## Commands

| Command | What |
|---|---|
| `//fj` (or `//ffxijse`) | Toggle the window (same as O key) |
| `//fj show` / `//fj hide` | Explicit show/hide |
| `//fj af` / `//fj relic` / `//fj empy` / `//fj capes` | Switch tab |
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

### Original Empyrean (lvl 85 Magian Trial era)

The base JSE data files only track **Reforged** Empyrean (Beckoner's,
Boii, Bhikku, Wicce, ...). FFXIJSE adds a supplementary file
`jobs/_original_empyrean.lua` that registers the **Original** Empyrean
sets from the Abyssea / Magian Trial era (caps at +2):

- WAR Ravager's · MNK Tantra · WHM Orison · BLM Goetia · RDM Estoqueur's
- THF Raider's · PLD Creed · DRK Bale · BST Ferine · BRD Aoidos'
- RNG Sylvan · SAM Unkai · NIN Iga · DRG Lancer's · SMN Caller's
- BLU Mavi · COR Navarch's · PUP Cirque · DNC Charis · SCH Savant's

GEO and RUN have no Original Empyrean tier (post-Adoulin jobs).

These appear in the **Empy tab** alongside the Reforged pieces so you
can see all your Empyrean armor in one list. Each Original piece shows
the cross-set conversion to its Reforged equivalent — e.g.:

```
✗ Caller's Horn +2  → Beckoner's Horn
    Rem's Tale Ch.1  3/5  [Inv 3]
    Carabosse's Gem  0/1
    Phoenix Feather  2/1  ✓
```

For each tier, the addon shows the practical upgrade recipe:

```
✗ Caller's Horn
    Caller's Seal: Head  3/8  [Sat]

✗ Caller's Horn +1  → Beckoner's Horn
    Rem's Tale Ch.1   4/10  [Inv]
    Carabosse's Gem   0/1
    Phoenix Feather   2/1   ✓  [Inv]

✗ Caller's Horn +2  → Beckoner's Horn
    Rem's Tale Ch.1   3/5   [Inv]
    Carabosse's Gem   0/1
    Phoenix Feather   2/1   ✓  [Inv]
```

- **NQ → +1**: real Magian Trial recipe — 8 of `[Set] Seal: [Slot]`
  (10 for body). Set name varies per job: Caller's Seal: Head,
  Ravager's Seal: Head, Tantra Seal: Head, etc.
- **+1 → Reforged NQ**: cross-set conversion (the practical path),
  x10 Rem's Tale + slot ingredient + job-specific ingredient.
- **+2 → Reforged NQ**: same recipe but x5 Rem's Tale instead.

The +1 → +2 Magian step (Stone/Coin of Vision/Ardor/etc.) is
intentionally skipped — at +1 or +2, the addon recommends reforging
to the modern Reforged NQ rather than continuing the obsolete Magian
chain. That matches the path BG-Wiki recommends for modern play.

Recipe components (universal across all 20 jobs, per BG-Wiki):

| Slot | Rem's Tale | Slot Ingredient |
|---|---|---|
| Head  | Ch.1 | Phoenix Feather |
| Body  | Ch.2 | Malboro Fiber   |
| Hands | Ch.3 | Beetle Blood    |
| Legs  | Ch.4 | Damascene Cloth |
| Feet  | Ch.5 | Oxblood         |

Job ingredient (varies per job — Carabosse's Gem for SMN/BST/PUP,
Helm of Briareus for WAR/DRK, Orthrus's Claw for WHM, etc.) — see
`jobs/_original_empyrean.lua` for the full per-job table.

Set names + conversion recipes sourced from BG-Wiki (Category:
Reforged_Empyrean_Armor and Category:Empyrean_Armor).

### Diag command

If a piece you own isn't showing up, run `//fj diag <substring>` to
dump every storage entry whose name matches — useful for verifying
the addon is reading items correctly and the names align with the
data files.

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
