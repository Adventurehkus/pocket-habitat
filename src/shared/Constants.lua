--!strict

local Constants = {}

Constants.RESOURCES = {
	WOOD = "wood",
	STONE = "stone",
	DEWDROP = "dewdrop",
	SEED_BERRY = "seed_berry",
	SEED_FLOWER = "seed_flower",
	CROP_BERRY = "crop_berry",
	CROP_FLOWER = "crop_flower",
	BELLS = "bells",
}

Constants.PLANTS = {
	berry = {
		id = "berry",
		name = "Cozy Berry Bush",
		growthTime = 30, -- seconds
		waterNeeded = 2,
		harvestReward = { itemId = "crop_berry", min = 2, max = 4 },
		bellReward = 15,
	},
	flower = {
		id = "flower",
		name = "Sun Petal Flower",
		growthTime = 45,
		waterNeeded = 3,
		harvestReward = { itemId = "crop_flower", min = 1, max = 3 },
		bellReward = 25,
	},
}

Constants.CREATURES = {
	bunny = {
		id = "bunny",
		name = "Meadow Bunny",
		description = "A gentle fluffy creature drawn to cozy gardens.",
		requiredFlora = 1,
		requiredWater = 1,
		bellReward = 50,
	},
	sprite = {
		id = "sprite",
		name = "Dew Sprite",
		description = "A magical glowing sprite that appears near well-watered plots.",
		requiredFlora = 3,
		requiredWater = 5,
		bellReward = 100,
	},
}

Constants.UPGRADES = {
	plot_expansion = {
		id = "plot_expansion",
		name = "Garden Plot Expansion",
		description = "Unlock an additional garden plot for planting.",
		baseCost = 50,
		costMultiplier = 2.0,
		maxLevel = 4,
	},
	storage_expansion = {
		id = "storage_expansion",
		name = "Inventory Pouch",
		description = "Increase maximum inventory holding capacity.",
		baseCost = 100,
		costMultiplier = 1.5,
		maxLevel = 3,
	},
}

Constants.QUESTS = {
	q1_wood = {
		id = "q1_wood",
		title = "Gather Wood",
		description = "Collect 3 pieces of wood from wooden resource nodes.",
		targetType = "gather",
		targetItemId = "wood",
		targetCount = 3,
		rewardBells = 20,
	},
	q2_stone = {
		id = "q2_stone",
		title = "Collect Stone",
		description = "Collect 2 pieces of stone from stone nodes.",
		targetType = "gather",
		targetItemId = "stone",
		targetCount = 2,
		rewardBells = 30,
	},
	q3_plant = {
		id = "q3_plant",
		title = "Plant a Berry",
		description = "Obtain and plant a berry seed in your garden plot.",
		targetType = "plant",
		targetItemId = "seed_berry",
		targetCount = 1,
		rewardBells = 40,
	},
	q4_water = {
		id = "q4_water",
		title = "Water Plants",
		description = "Water your growing plants using dewdrops.",
		targetType = "water",
		targetCount = 2,
		rewardBells = 35,
	},
	q5_harvest = {
		id = "q5_harvest",
		title = "Harvest Crops",
		description = "Harvest a fully grown crop from your garden.",
		targetType = "harvest",
		targetCount = 1,
		rewardBells = 50,
	},
	q6_creature = {
		id = "q6_creature",
		title = "Attract a Creature",
		description = "Grow your habitat to attract your first creature!",
		targetType = "discover",
		targetCount = 1,
		rewardBells = 100,
	},
}

return Constants
