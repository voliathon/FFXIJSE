--[[
Original Artifact Armor (the lvl 50-75 AF set) per job.

The base FFXIJSE / JSE data files only track Reforged Artifact Armor
(Pummeler's, Theophany, Spaekona's, ...) on the ARTIFACT tab. This file
adds the ORIGINAL AF sets (Fighter's, Healer's, Wizard's, Evoker's,
Rogue's, ...) so they also show up in the ARTIFACT tab — with the real
cross-set conversion recipe to their Reforged counterpart.

Source: BG-Wiki only.
  https://www.bg-wiki.com/ffxi/Category:Artifact_Armor
  https://www.bg-wiki.com/ffxi/Category:Artifact_Armor_%2B1
  https://www.bg-wiki.com/ffxi/Category:Reforged_Artifact_Armor

Cross-set recipe (Original AF → Reforged AF NQ, performed by Monisette
in Port Jeuno):

  NQ Original AF + Rem's Tale Ch.X x10 + slot ingredient + job ingredient
                                                              → Reforged NQ
  Original AF +1 + Rem's Tale Ch.X x5  + slot ingredient + job ingredient
                                                              → Reforged NQ

  Slot ingredients (same as Reforged Empyrean):
    Head=Phoenix Feather  Body=Malboro Fiber  Hands=Beetle Blood
    Legs=Damascene Cloth  Feet=Oxblood

  Rem's Tale chapter (same as Reforged Empyrean):
    Head=Ch.1  Body=Ch.2  Hands=Ch.3  Legs=Ch.4  Feet=Ch.5

  Job ingredients (DIFFERENT from Reforged Empyrean — these are the
  Reforged AF-specific items, listed below per job).

piece[4] is the corresponding Reforged AF NQ name so the UI can show
"Wizard's Petasos +1 → Spaekona's Petasos" instead of "+1 → +2".

piece[5] = "NQ" — unlike Empyrean where NQ→+1 has its own Magian step,
NQ AF can convert directly to Reforged NQ (just with more Rem's Tale).
This makes the cross-set label visible to NQ owners too.

GEO and RUN have no Original AF (post-Adoulin jobs).
]]

-- Universal slot ingredients (same as the Reforged Empyrean recipe).
local SLOTS = {
    head  = { chapter = "Rem's Tale Ch.1", slot_item = "Phoenix Feather"  },
    body  = { chapter = "Rem's Tale Ch.2", slot_item = "Malboro Fiber"    },
    hands = { chapter = "Rem's Tale Ch.3", slot_item = "Beetle Blood"     },
    legs  = { chapter = "Rem's Tale Ch.4", slot_item = "Damascene Cloth"  },
    feet  = { chapter = "Rem's Tale Ch.5", slot_item = "Oxblood"          },
}

-- Reforged-AF job ingredient. NOT the same as the Reforged-Empyrean job
-- ingredients — Monisette uses different items for the two upgrade lines.
-- (Source: BG-Wiki Reforged_Artifact_Armor.)
local JOB_INGREDIENT = {
    WAR = "Tiger Leather",
    MNK = "Gold Thread",
    WHM = "Imp. Silk Cloth",
    BLM = "Karakul Cloth",
    RDM = "Scarlet Linen",
    THF = "Gold Thread",
    PLD = "Gold Sheet",
    DRK = "Darksteel Sheet",
    BST = "Tiger Leather",
    BRD = "Imp. Silk Cloth",
    RNG = "Karakul Cloth",
    SAM = "Tama-Hagane",
    NIN = "Tama-Hagane",
    DRG = "Gold Sheet",
    SMN = "Scarlet Linen",
    BLU = "Imp. Silk Cloth",
    COR = "Karakul Cloth",
    PUP = "Karakul Cloth",
    DNC = "Gold Thread",
    SCH = "Scarlet Linen",
}

-- Build a conversion recipe: Original AF (NQ or +1) → Reforged AF NQ.
local function conversion(slot_key, job, rem_count)
    local s = SLOTS[slot_key]
    return {
        { name = s.chapter,           count = rem_count },
        { name = JOB_INGREDIENT[job], count = 1         },
        { name = s.slot_item,         count = 1         },
    }
end

-- Build a piece. AF has TWO conversion paths (NQ→Reforged with x10
-- Rem's Tale, +1→Reforged with x5). We stuff them into "+1" and "+2"
-- tier slots in the data structure — when the user owns NQ, next_tier
-- = "+1" so they see the x10 recipe; when they own +1, next_tier = "+2"
-- so they see the cheaper x5 recipe.
local function piece(names, slot_key, job, into_name)
    return {
        names,
        0,
        {
            ["+1"] = conversion(slot_key, job, 10),  -- NQ → Reforged NQ
            ["+2"] = conversion(slot_key, job, 5),   -- +1 → Reforged NQ
        },
        into_name,
        "NQ",   -- piece[5]: cross-set conversion is valid starting from NQ tier
    }
end

local function set(job, entries, reforged)
    return {
        piece(entries.head,  'head',  job, reforged.head),
        piece(entries.body,  'body',  job, reforged.body),
        piece(entries.hands, 'hands', job, reforged.hands),
        piece(entries.legs,  'legs',  job, reforged.legs),
        piece(entries.feet,  'feet',  job, reforged.feet),
    }
end

return {
    WAR = set('WAR',
        { head  = { "Fighter's Mask"     },
          body  = { "Fighter's Lorica"   },
          hands = { "Fighter's Mufflers" },
          legs  = { "Fighter's Cuisses"  },
          feet  = { "Fighter's Calligae" } },
        { head  = "Pummeler's Mask",     body  = "Pummeler's Lorica",
          hands = "Pummeler's Mufflers", legs  = "Pummeler's Cuisses",
          feet  = "Pummeler's Calligae" }),

    MNK = set('MNK',
        { head  = { "Temple Crown"   },
          body  = { "Temple Cyclas"  },
          hands = { "Temple Gloves"  },
          legs  = { "Temple Hose"    },
          feet  = { "Temple Gaiters" } },
        { head  = "Anchorite's Crown",   body  = "Anchorite's Cyclas",
          hands = "Anchorite's Gloves",  legs  = "Anchorite's Hose",
          feet  = "Anchorite's Gaiters" }),

    WHM = set('WHM',
        { head  = { "Healer's Cap"        },
          body  = { "Healer's Bliaut"     },
          hands = { "Healer's Mitts"      },
          legs  = { "Healer's Pantaloons" },
          feet  = { "Healer's Duckbills"  } },
        { head  = "Theophany Cap",       body  = "Theophany Bliaut",
          hands = "Theophany Mitts",     legs  = "Theophany Pantaloons",
          feet  = "Theophany Duckbills" }),

    BLM = set('BLM',
        { head  = { "Wizard's Petasos" },
          body  = { "Wizard's Coat"    },
          hands = { "Wizard's Gloves"  },
          legs  = { "Wizard's Tonban"  },
          feet  = { "Wizard's Sabots"  } },
        { head  = "Spaekona's Petasos", body  = "Spaekona's Coat",
          hands = "Spaekona's Gloves",  legs  = "Spaekona's Tonban",
          feet  = "Spaekona's Sabots" }),

    RDM = set('RDM',
        { head  = { "Warlock's Chapeau" },
          body  = { "Warlock's Tabard"  },
          hands = { "Warlock's Gloves"  },
          legs  = { "Warlock's Tights"  },
          feet  = { "Warlock's Boots"   } },
        { head  = "Atrophy Chapeau",  body  = "Atrophy Tabard",
          hands = "Atrophy Gloves",   legs  = "Atrophy Tights",
          feet  = "Atrophy Boots" }),

    THF = set('THF',
        { head  = { "Rogue's Bonnet"    },
          body  = { "Rogue's Vest"      },
          hands = { "Rogue's Armlets"   },
          legs  = { "Rogue's Culottes"  },
          feet  = { "Rogue's Poulaines" } },
        { head  = "Pillager's Bonnet",   body  = "Pillager's Vest",
          hands = "Pillager's Armlets",  legs  = "Pillager's Culottes",
          feet  = "Pillager's Poulaines" }),

    PLD = set('PLD',
        { head  = { "Gallant Coronet"  },
          body  = { "Gallant Surcoat"  },
          hands = { "Gallant Gauntlets" },
          legs  = { "Gallant Breeches" },
          feet  = { "Gallant Leggings" } },
        { head  = "Reverence Coronet",   body  = "Reverence Surcoat",
          hands = "Reverence Gauntlets", legs  = "Reverence Breeches",
          feet  = "Reverence Leggings" }),

    DRK = set('DRK',
        { head  = { "Chaos Burgeonet" },
          body  = { "Chaos Cuirass"   },
          hands = { "Chaos Gauntlets" },
          legs  = { "Chaos Flanchard" },
          feet  = { "Chaos Sollerets" } },
        { head  = "Ignominy Burgeonet", body  = "Ignominy Cuirass",
          hands = "Ignominy Gauntlets", legs  = "Ignominy Flanchard",
          feet  = "Ignominy Sollerets" }),

    BST = set('BST',
        { head  = { "Beast Helm"     },
          body  = { "Beast Jackcoat" },
          hands = { "Beast Gloves"   },
          legs  = { "Beast Trousers" },
          feet  = { "Beast Gaiters"  } },
        { head  = "Totemic Helm",     body  = "Totemic Jackcoat",
          hands = "Totemic Gloves",   legs  = "Totemic Trousers",
          feet  = "Totemic Gaiters" }),

    BRD = set('BRD',
        { head  = { "Choral Roundlet"   },
          body  = { "Choral Justaucorps", "Choral Just.", "Choral Justau." },
          hands = { "Choral Cuffs"      },
          legs  = { "Choral Cannions"   },
          feet  = { "Choral Slippers"   } },
        { head  = "Brioso Roundlet",   body  = "Brioso Justaucorps",
          hands = "Brioso Cuffs",      legs  = "Brioso Cannions",
          feet  = "Brioso Slippers" }),

    RNG = set('RNG',
        { head  = { "Hunter's Beret"   },
          body  = { "Hunter's Jerkin"  },
          hands = { "Hunter's Bracers" },
          legs  = { "Hunter's Braccae" },
          feet  = { "Hunter's Socks"   } },
        { head  = "Orion Beret",   body  = "Orion Jerkin",
          hands = "Orion Bracers", legs  = "Orion Braccae",
          feet  = "Orion Socks" }),

    SAM = set('SAM',
        { head  = { "Myochin Kabuto"   },
          body  = { "Myochin Domaru"   },
          hands = { "Myochin Kote"     },
          legs  = { "Myochin Haidate"  },
          feet  = { "Myochin Sune-Ate" } },
        { head  = "Wakido Kabuto",   body  = "Wakido Domaru",
          hands = "Wakido Kote",     legs  = "Wakido Haidate",
          feet  = "Wakido Sune-Ate" }),

    NIN = set('NIN',
        { head  = { "Ninja Hatsuburi", "Ninja Hatsu." },
          body  = { "Ninja Chainmail", "Ninja Chain." },
          hands = { "Ninja Tekko"    },
          legs  = { "Ninja Hakama"   },
          feet  = { "Ninja Kyahan"   } },
        { head  = "Hachiya Hatsuburi", body  = "Hachiya Chainmail",
          hands = "Hachiya Tekko",     legs  = "Hachiya Hakama",
          feet  = "Hachiya Kyahan" }),

    DRG = set('DRG',
        { head  = { "Drachen Armet"  },
          body  = { "Drachen Mail"   },
          hands = { "Drachen Finger Gauntlets", "Drachen F. G.", "Dra. Fin." },
          legs  = { "Drachen Brais"  },
          feet  = { "Drachen Greaves" } },
        { head  = "Vishap Armet",   body  = "Vishap Mail",
          hands = "Vishap Finger Gauntlets", legs  = "Vishap Brais",
          feet  = "Vishap Greaves" }),

    SMN = set('SMN',
        { head  = { "Evoker's Horn"     },
          body  = { "Evoker's Doublet"  },
          hands = { "Evoker's Bracers"  },
          legs  = { "Evoker's Spats"    },
          feet  = { "Evoker's Pigaches" } },
        { head  = "Convoker's Horn",   body  = "Convoker's Doublet",
          hands = "Convoker's Bracers", legs  = "Convoker's Spats",
          feet  = "Convoker's Pigaches" }),

    BLU = set('BLU',
        { head  = { "Magus Keffiyeh"  },
          body  = { "Magus Jubbah"    },
          hands = { "Magus Bazubands" },
          legs  = { "Magus Shalwar"   },
          feet  = { "Magus Charuqs"   } },
        { head  = "Assimilator's Keffiyeh", body  = "Assimilator's Jubbah",
          hands = "Assimilator's Bazubands", legs  = "Assimilator's Shalwar",
          feet  = "Assimilator's Charuqs" }),

    COR = set('COR',
        { head  = { "Corsair's Tricorne" },
          body  = { "Corsair's Frac"     },
          hands = { "Corsair's Gants"    },
          legs  = { "Corsair's Trews"    },
          feet  = { "Corsair's Bottes"   } },
        { head  = "Laksamana's Tricorne", body  = "Laksamana's Frac",
          hands = "Laksamana's Gants",    legs  = "Laksamana's Trews",
          feet  = "Laksamana's Bottes" }),

    PUP = set('PUP',
        { head  = { "Puppetry Taj"        },
          body  = { "Puppetry Tobe"       },
          hands = { "Puppetry Dastanas"   },
          legs  = { "Puppetry Churidars"  },
          feet  = { "Puppetry Babouches"  } },
        { head  = "Foire Taj",       body  = "Foire Tobe",
          hands = "Foire Dastanas",  legs  = "Foire Churidars",
          feet  = "Foire Babouches" }),

    DNC = set('DNC',
        { head  = { "Dancer's Tiara"     },
          body  = { "Dancer's Casaque"   },
          hands = { "Dancer's Bangles"   },
          legs  = { "Dancer's Tights"    },
          feet  = { "Dancer's Toe Shoes" } },
        { head  = "Maxixi Tiara",     body  = "Maxixi Casaque",
          hands = "Maxixi Bangles",   legs  = "Maxixi Tights",
          feet  = "Maxixi Toe Shoes" }),

    SCH = set('SCH',
        { head  = { "Scholar's Mortarboard", "Scholar's Mortar." },
          body  = { "Scholar's Gown"   },
          hands = { "Scholar's Bracers" },
          legs  = { "Scholar's Pants"  },
          feet  = { "Scholar's Loafers" } },
        { head  = "Academic's Mortarboard", body  = "Academic's Gown",
          hands = "Academic's Bracers",     legs  = "Academic's Pants",
          feet  = "Academic's Loafers" }),

    -- GEO and RUN have no Original AF (post-Adoulin jobs introduced
    -- after the AF reforging system was already in place; they only
    -- have the Reforged AF tier).
}
