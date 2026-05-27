--[[
Original Empyrean (lvl 85 Magian Trial era) armor pieces, per job.

The base FFXIJSE / JSE data files only track the Reforged Empyrean chains
(Beckoner's, Boii, Bhikku, Wicce, ...). Many players still own the
ORIGINAL Empyrean sets from the 75-85 cap Abyssea/Magian era (Caller's,
Ravager's, Tantra, Goetia, ...) — those are tracked here so they show
up in the Empy tab alongside the modern Reforged pieces.

Source: BG-Wiki only.
  https://www.bg-wiki.com/ffxi/Category:Empyrean_Armor
  https://www.bg-wiki.com/ffxi/Category:Reforged_Empyrean_Armor
  Per-set upgrade tables (e.g. Ravager's Armor Set /+1 /+2)

Upgrade chain (what this file tracks):

  NQ Original → (Magian Trial) → Original +1 → (cross-set, x10 Rem's Tale)
                                              ↘ Reforged NQ
                              → Original +2 → (cross-set, x5 Rem's Tale)
                                              ↗ Reforged NQ
  Reforged NQ → +1 → +2 → +3   (modern chain, lives in each job's main
                                .lua file — already correct, untouched)

For each Original Empyrean piece:

  ["+1"] tier = NQ → +1 Magian Trial.
                Materials: "[Set] Seal: [Slot]" x8 (or x10 for body).
                Same pattern across every job — only the [Set] name varies
                (Ravager's, Caller's, Tantra, ...).

  ["+2"] tier = Original +1 → Reforged NQ cross-set conversion.
                x10 Rem's Tale Ch.N + slot ingredient + job-specific HNM drop.

  ["+3"] tier = Original +2 → Reforged NQ cross-set conversion.
                Same recipe as +2 but x5 Rem's Tale instead of x10.

The +1 → +2 Magian Trial path (Stone/Coin of Vision etc.) is
INTENTIONALLY SKIPPED. Players who reach Original +1 or +2 should
reforge to Reforged NQ rather than continue the Magian chain — that's
the recommended path on BG-Wiki and the addon defaults to showing it.

piece[4] is the Reforged set's NQ name for the same slot, so the UI
shows "Caller's Horn +2 → Beckoner's Horn" instead of "+2 → +3".

GEO and RUN have no Original Empyrean set (post-Adoulin jobs).
]]

-- Universal slot data — Rem's Tale chapter + Abyssean slot ingredient.
-- Cross-set recipe is the same for every job; only the job-specific
-- ingredient (Carabosse's Gem for SMN, Helm of Briareus for WAR, ...)
-- varies. Magian Seal counts: 8 for every slot EXCEPT body which is 10.
local SLOTS = {
    head  = { chapter = "Rem's Tale Ch.1", slot_item = "Phoenix Feather",  seal = "Head",  seal_count = 8  },
    body  = { chapter = "Rem's Tale Ch.2", slot_item = "Malboro Fiber",    seal = "Body",  seal_count = 10 },
    hands = { chapter = "Rem's Tale Ch.3", slot_item = "Beetle Blood",     seal = "Hands", seal_count = 8  },
    legs  = { chapter = "Rem's Tale Ch.4", slot_item = "Damascene Cloth",  seal = "Legs",  seal_count = 8  },
    feet  = { chapter = "Rem's Tale Ch.5", slot_item = "Oxblood",          seal = "Feet",  seal_count = 8  },
}

-- Job-specific HNM-drop ingredient (the BG-Wiki "Job Ingredient" column).
local JOB_INGREDIENT = {
    WAR = "Helm of Briareus",
    MNK = "Itzpapalotl's Scale",
    WHM = "Orthrus's Claw",
    BLM = "Glavoid Shell",
    RDM = "Cirein-croin's Lantern",
    THF = "Alfard's Fang",
    PLD = "Kukulkan's Fang",
    DRK = "Helm of Briareus",
    BST = "Carabosse's Gem",
    BRD = "Dragua's Scale",
    RNG = "Ulhuadshi's Fang",
    SAM = "Apademak's Horn",
    NIN = "Bukhis's Wing",
    DRG = "Azdaja's Horn",
    SMN = "Carabosse's Gem",
    BLU = "Isgebind's Heart",
    COR = "Sobek's Skin",
    PUP = "Carabosse's Gem",
    DNC = "Two-Leaf Chloris Bud",
    SCH = "Sedna's Tusk",
}

-- Cross-set conversion recipe: Original +N → Reforged NQ.
-- x10 Rem's Tale from +1 owners, x5 from +2 owners (BG-Wiki).
local function conversion(slot_key, job, rem_count)
    local s = SLOTS[slot_key]
    return {
        { name = s.chapter,            count = rem_count },
        { name = JOB_INGREDIENT[job],  count = 1         },
        { name = s.slot_item,          count = 1         },
    }
end

-- Magian Trial NQ → +1: "[Set] Seal: [Slot]" x N.
-- Format examples (from BG-Wiki Empyrean Armor pages):
--   Ravager's Seal: Head x8
--   Caller's Seal: Body x10
--   Tantra Seal: Hands x8
local function magian_seal(set_name, slot_key)
    local s = SLOTS[slot_key]
    return {
        { name = set_name .. " Seal: " .. s.seal, count = s.seal_count },
    }
end

-- Build one piece given its set name (for seal item), names list, slot,
-- owning job, and the corresponding Reforged Empyrean NQ name.
local function piece(set_name, names, slot_key, job, into_name)
    return {
        names,
        0,
        {
            ["+1"] = magian_seal(set_name, slot_key),
            ["+2"] = conversion(slot_key, job, 10),
            ["+3"] = conversion(slot_key, job, 5),
        },
        into_name,
    }
end

-- Convenience builder for a full 5-piece set.
--   set_name: the prefix that goes on the seal items ("Ravager's", "Caller's", ...)
--   entries:  { head={names}, body={names}, hands={names}, legs={names}, feet={names} }
--   reforged: { head="Reforged head name", body=..., ... }
local function set(job, set_name, entries, reforged)
    return {
        piece(set_name, entries.head,  'head',  job, reforged.head),
        piece(set_name, entries.body,  'body',  job, reforged.body),
        piece(set_name, entries.hands, 'hands', job, reforged.hands),
        piece(set_name, entries.legs,  'legs',  job, reforged.legs),
        piece(set_name, entries.feet,  'feet',  job, reforged.feet),
    }
end

return {
    WAR = set('WAR', "Ravager's",
        { head  = { "Ravager's Mask",     "Rvg. Mask"     },
          body  = { "Ravager's Lorica",   "Rvg. Lorica"   },
          hands = { "Ravager's Mufflers", "Rvg. Mufflers" },
          legs  = { "Ravager's Cuisses",  "Rvg. Cuisses"  },
          feet  = { "Ravager's Calligae", "Rvg. Calligae" } },
        { head = "Boii Mask", body = "Boii Lorica", hands = "Boii Mufflers",
          legs = "Boii Cuisses", feet = "Boii Calligae" }),

    MNK = set('MNK', "Tantra",
        { head  = { "Tantra Crown"   },
          body  = { "Tantra Cyclas"  },
          hands = { "Tantra Gloves"  },
          legs  = { "Tantra Hose"    },
          feet  = { "Tantra Gaiters" } },
        { head = "Bhikku Crown", body = "Bhikku Cyclas", hands = "Bhikku Gloves",
          legs = "Bhikku Hose",  feet = "Bhikku Gaiters" }),

    WHM = set('WHM', "Orison",
        { head  = { "Orison Cap"        },
          body  = { "Orison Bliaud"     },
          hands = { "Orison Mitts"      },
          legs  = { "Orison Pantaloons", "Orison Pant." },
          feet  = { "Orison Duckbills"  } },
        { head = "Ebers Cap", body = "Ebers Bliaut", hands = "Ebers Mitts",
          legs = "Ebers Pantaloons", feet = "Ebers Duckbills" }),

    BLM = set('BLM', "Goetia",
        { head  = { "Goetia Petasos"  },
          body  = { "Goetia Coat"     },
          hands = { "Goetia Gloves"   },
          legs  = { "Goetia Chausses" },
          feet  = { "Goetia Sabots"   } },
        { head = "Wicce Petasos", body = "Wicce Coat", hands = "Wicce Gloves",
          legs = "Wicce Chausses", feet = "Wicce Sabots" }),

    RDM = set('RDM', "Estoqueur's",
        { head  = { "Estoqueur's Chappel",    "Est. Chappel"    },
          body  = { "Estoqueur's Sayon",      "Est. Sayon"      },
          hands = { "Estoqueur's Gantherots", "Est. Gantherots", "Est. Ganth." },
          legs  = { "Estoqueur's Fuseau",     "Est. Fuseau"     },
          feet  = { "Estoqueur's Houseaux",   "Est. Houseaux"   } },
        { head = "Lethargy Chappel", body = "Lethargy Sayon",
          hands = "Lethargy Gantherots", legs = "Lethargy Fuseau",
          feet = "Lethargy Houseaux" }),

    THF = set('THF', "Raider's",
        { head  = { "Raider's Bonnet",    "Rd. Bonnet"    },
          body  = { "Raider's Vest",      "Rd. Vest"      },
          hands = { "Raider's Armlets",   "Rd. Armlets"   },
          legs  = { "Raider's Culottes",  "Rd. Culottes"  },
          feet  = { "Raider's Poulaines", "Rd. Poulaines" } },
        { head = "Skulker's Bonnet", body = "Skulker's Vest",
          hands = "Skulker's Armlets", legs = "Skulker's Culottes",
          feet = "Skulker's Poulaines" }),

    PLD = set('PLD', "Creed",
        { head  = { "Creed Armet"     },
          body  = { "Creed Cuirass"   },
          hands = { "Creed Gauntlets" },
          legs  = { "Creed Cuisses"   },
          feet  = { "Creed Sabatons"  } },
        { head = "Chevalier's Armet", body = "Chevalier's Cuirass",
          hands = "Chevalier's Gauntlets", legs = "Chevalier's Cuisses",
          feet = "Chevalier's Sabatons" }),

    DRK = set('DRK', "Bale",
        { head  = { "Bale Burgeonet" },
          body  = { "Bale Cuirass"   },
          hands = { "Bale Gauntlets" },
          legs  = { "Bale Flanchard" },
          feet  = { "Bale Sollerets" } },
        { head = "Heathen's Burgeonet", body = "Heathen's Cuirass",
          hands = "Heathen's Gauntlets", legs = "Heathen's Flanchard",
          feet = "Heathen's Sollerets" }),

    BST = set('BST', "Ferine",
        { head  = { "Ferine Cabasset" },
          body  = { "Ferine Gausape"  },
          hands = { "Ferine Manoplas" },
          legs  = { "Ferine Quijotes" },
          feet  = { "Ferine Ocreae"   } },
        { head = "Nukumi Cabasset", body = "Nukumi Gausape",
          hands = "Nukumi Manoplas", legs = "Nukumi Quijotes",
          feet = "Nukumi Ocreae" }),

    BRD = set('BRD', "Aoidos'",
        { head  = { "Aoidos' Calot",       "Aoi. Calot"       },
          body  = { "Aoidos' Hongreline",  "Aoi. Hongreline"  },
          hands = { "Aoidos' Manchettes",  "Aoi. Manchettes"  },
          legs  = { "Aoidos' Rhingrave",   "Aoi. Rhingrave"   },
          feet  = { "Aoidos' Cothurnes",   "Aoi. Cothurnes"   } },
        { head = "Fili Calot", body = "Fili Hongreline",
          hands = "Fili Manchettes", legs = "Fili Rhingrave",
          feet = "Fili Cothurnes" }),

    RNG = set('RNG', "Sylvan",
        { head  = { "Sylvan Gapette"    },
          body  = { "Sylvan Caban"      },
          hands = { "Sylvan Glovelettes", "Sylvan Glove." },
          legs  = { "Sylvan Bragues"    },
          feet  = { "Sylvan Bottillons" } },
        { head = "Amini Gapette", body = "Amini Caban",
          hands = "Amini Glovelettes", legs = "Amini Bragues",
          feet = "Amini Bottillons" }),

    SAM = set('SAM', "Unkai",
        { head  = { "Unkai Kabuto"   },
          body  = { "Unkai Domaru"   },
          hands = { "Unkai Kote"     },
          legs  = { "Unkai Haidate"  },
          feet  = { "Unkai Sune-Ate" } },
        { head = "Kasuga Kabuto", body = "Kasuga Domaru",
          hands = "Kasuga Kote", legs = "Kasuga Haidate",
          feet = "Kasuga Sune-Ate" }),

    NIN = set('NIN', "Iga",
        { head  = { "Iga Zukin"  },
          body  = { "Iga Ningi"  },
          hands = { "Iga Tekko"  },
          legs  = { "Iga Hakama" },
          feet  = { "Iga Kyahan" } },
        { head = "Hattori Zukin", body = "Hattori Ningi",
          hands = "Hattori Tekko", legs = "Hattori Hakama",
          feet = "Hattori Kyahan" }),

    DRG = set('DRG', "Lancer's",
        { head  = { "Lancer's Mezail",     "Lncr. Mezail",    "Lan. Mezail"    },
          body  = { "Lancer's Plackart",   "Lncr. Plackart",  "Lan. Plackart"  },
          hands = { "Lancer's Vambraces",  "Lncr. Vambraces", "Lan. Vambraces" },
          legs  = { "Lancer's Cuissots",   "Lncr. Cuissots",  "Lan. Cuissots"  },
          feet  = { "Lancer's Schynbalds", "Lncr. Schyn.",    "Lan. Schynbalds" } },
        { head = "Peltast's Mezail", body = "Peltast's Plackart",
          hands = "Peltast's Vambraces", legs = "Peltast's Cuissots",
          feet = "Peltast's Schynbalds" }),

    SMN = set('SMN', "Caller's",
        { head  = { "Caller's Horn"     },
          body  = { "Caller's Doublet"  },
          hands = { "Caller's Bracers"  },
          legs  = { "Caller's Spats"    },
          feet  = { "Caller's Pigaches" } },
        { head = "Beckoner's Horn", body = "Beckoner's Doublet",
          hands = "Beckoner's Bracers", legs = "Beckoner's Spats",
          feet = "Beckoner's Pigaches" }),

    BLU = set('BLU', "Mavi",
        { head  = { "Mavi Kavuk"     },
          body  = { "Mavi Mintan"    },
          hands = { "Mavi Bazubands" },
          legs  = { "Mavi Tayt"      },
          feet  = { "Mavi Basmak"    } },
        { head = "Hashishin Kavuk", body = "Hashishin Mintan",
          hands = "Hashishin Bazubands", legs = "Hashishin Tayt",
          feet = "Hashishin Basmak" }),

    COR = set('COR', "Navarch's",
        { head  = { "Navarch's Tricorne", "Nav. Tricorne" },
          body  = { "Navarch's Frac",     "Nav. Frac"     },
          hands = { "Navarch's Gants",    "Nav. Gants"    },
          legs  = { "Navarch's Culottes", "Nav. Culottes" },
          feet  = { "Navarch's Bottes",   "Nav. Bottes"   } },
        { head = "Chasseur's Tricorne", body = "Chasseur's Frac",
          hands = "Chasseur's Gants", legs = "Chasseur's Culottes",
          feet = "Chasseur's Bottes" }),

    PUP = set('PUP', "Cirque",
        { head  = { "Cirque Cappello"  },
          body  = { "Cirque Farsetto"  },
          hands = { "Cirque Guanti"    },
          legs  = { "Cirque Pantaloni" },
          feet  = { "Cirque Scarpe"    } },
        { head = "Karagoz Cappello", body = "Karagoz Farsetto",
          hands = "Karagoz Guanti", legs = "Karagoz Pantaloni",
          feet = "Karagoz Scarpe" }),

    DNC = set('DNC', "Charis",
        { head  = { "Charis Tiara"     },
          body  = { "Charis Casaque"   },
          hands = { "Charis Bangles"   },
          legs  = { "Charis Tights"    },
          feet  = { "Charis Toe Shoes" } },    -- BG-Wiki: space, not "Toeshoes"
        { head = "Maculele Tiara", body = "Maculele Casaque",
          hands = "Maculele Bangles", legs = "Maculele Tights",
          feet = "Maculele Toe Shoes" }),

    SCH = set('SCH', "Savant's",
        { head  = { "Savant's Bonnet",  "Sav. Bonnet"  },
          body  = { "Savant's Gown",    "Sav. Gown"    },
          hands = { "Savant's Bracers", "Sav. Bracers" },
          legs  = { "Savant's Pants",   "Sav. Pants"   },
          feet  = { "Savant's Loafers", "Sav. Loafers" } },
        { head = "Arbatel Bonnet", body = "Arbatel Gown",
          hands = "Arbatel Bracers", legs = "Arbatel Pants",
          feet = "Arbatel Loafers" }),

    -- GEO and RUN intentionally omitted — those jobs were introduced
    -- after the Original Empyrean tier and have no 85-cap set.
}
