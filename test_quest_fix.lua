local QuestRules = require("src/shared/QuestRules")
local Constants = require("src/shared/Constants")

local data = {
    bells = 100,
    inventory = {},
    creatures = {
        bunny = { friendshipLevel = 3, friendshipXP = 300, totalInteractions = 10 },
        sprite = { friendshipLevel = 3, friendshipXP = 300, totalInteractions = 10 },
        leafling = { friendshipLevel = 2, friendshipXP = 200, totalInteractions = 5 }
    },
    creaturesDiscovered = { bunny = true, sprite = true, leafling = true },
    questProgress = {},
    questsCompleted = {},
    currentQuest = "q13_creature_caretaker",
    upgrades = { storage_expansion = 1 }
}

-- Current state: q13 needs 3 creatures at level 3. Currently have 2 at level 3.
-- tryClaim should fail.
local success, reason = QuestRules.tryClaim(data, "q13_creature_caretaker")
print("First attempt success:", success, "Reason:", reason)

-- Upgrade leafling to level 3.
data.creatures.leafling.friendshipLevel = 3
data.creatures.leafling.friendshipXP = 300

-- Now should succeed.
success, reason = QuestRules.tryClaim(data, "q13_creature_caretaker")
print("Second attempt success:", success, "Reason:", reason)
