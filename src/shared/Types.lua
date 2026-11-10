--!strict

export type ItemId = string

export type InventoryItem = {
    id: ItemId,
    quantity: number,
}

export type PlayerData = {
    userId: number,
    bells: number,
    inventory: { [ItemId]: number },
    questsCompleted: { [string]: boolean },
    currentQuest: string?,
    creaturesDiscovered: { [string]: boolean },
    upgrades: { [string]: number },
    plots: {
        [number]: { seedId: string?, plantedTime: number, waterCount: number, stage: number },
    },
}

export type PlantDefinition = {
    id: string,
    name: string,
    growthTime: number, -- seconds
    waterNeeded: number,
    harvestReward: { itemId: string, min: number, max: number },
    bellReward: number,
}

export type CreatureDefinition = {
    id: string,
    name: string,
    description: string,
    requiredFlora: number,
    requiredWater: number,
    bellReward: number,
}

export type UpgradeDefinition = {
    id: string,
    name: string,
    description: string,
    baseCost: number,
    costMultiplier: number,
    maxLevel: number,
}

export type QuestDefinition = {
    id: string,
    title: string,
    description: string,
    targetType: string, -- "gather", "plant", "water", "harvest", "discover", "upgrade"
    targetItemId: string?,
    targetCount: number,
    rewardBells: number,
    rewardItems: { [string]: number }?,
}

return {}
