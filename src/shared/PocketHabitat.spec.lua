--!strict
--selene:allow(undefined_variable)

localReplicatedStorage=game:GetService("ReplicatedStorage")
localConstants=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
localShared=ReplicatedStorage:WaitForChild("Shared")
localPlantRules=require(Shared:WaitForChild("PlantRules"))
localEconomyRules=require(Shared:WaitForChild("EconomyRules"))
localResourceRules=require(Shared:WaitForChild("ResourceRules"))
localQuestRules=require(Shared:WaitForChild("QuestRules"))
localHabitatRules=require(Shared:WaitForChild("HabitatRules"))
localCharacterSpawnData=require(Shared:WaitForChild("CharacterSpawnData"))

localNOW=10_000
localBERRY_SEED=Constants.RESOURCES.SEED_BERRY
localFLOWER_SEED=Constants.RESOURCES.SEED_FLOWER
localDEWDROP=Constants.RESOURCES.DEWDROP

localfunctionmakeData():any
return{
bells=50,
inventory={
[BERRY_SEED]=2,
[FLOWER_SEED]=1,
[DEWDROP]=5,
[Constants.RESOURCES.WOOD]=8,
},
plots={
[1]={seedId=nil,plantedTime=0,waterCount=0,stage=0},
[2]={seedId=nil,plantedTime=0,waterCount=0,stage=0},
},
}
end

localfunctionvalidateInteraction(
data:any,
plotIndex:any,
action:any,
seedId:any?,
now:any?
):(any,any)
returnPlantRules.validateInteraction(data,plotIndex,action,seedId,now)
end

localfunctionplantBerry(data:any,plotIndex:number):any
localplot=data.plots[plotIndex]
plot.seedId=BERRY_SEED
plot.plantedTime=NOW-Constants.PLANTS.berry.growthTime-1
plot.waterCount=Constants.PLANTS.berry.waterNeeded
plot.stage=2
returnplot
end

returnfunction()
describe("PlantRules—server-sideplotvalidation",function()
it("providesagatherableseednodeforeverysupportedplant",function()
localseedNodes={}
localnodeIds={}
for_,nodeinipairs(Constants.RESOURCE_NODES)do
expect(nodeIds[node.id]).to.equal(nil)
expect(string.lower(node.name)).to.equal(node.id)
expect(node.amount%1).to.equal(0)
expect(node.amount>0).to.equal(true)
expect(node.cooldownMinutes>0).to.equal(true)
nodeIds[node.id]=true
seedNodes[node.type]=true
end

forplantId,plantDefinpairs(Constants.PLANTS)do
expect(PlantRules.getPlantDef(plantDef.seedId).id).to.equal(plantId)
expect(seedNodes[plantDef.seedId]).to.equal(true)
end
end)

it("rejectsmalformed,fractional,non-positive,andinfiniteplotindices",function()
localdata=makeData()
localinvalidIndices:{any}={0,-1,1.5,math.huge,-math.huge,0/0,"1"}

for_,plotIndexinipairs(invalidIndices)do
localplan=validateInteraction(data,plotIndex,"plant",BERRY_SEED,NOW)
expect(plan).to.equal(nil)
end
end)

it("rejectsplotindicesthatdonotbelongtotheplayer'ssession",function()
localplan,reason=validateInteraction(makeData(),99,"plant",BERRY_SEED,NOW)

expect(plan).to.equal(nil)
expect(reason).to.equal("Invalidplot")
end)

it("rejectsasavedplotindexthatisnotunlockedbytheplayer'supgrades",function()
localdata=makeData()
data.plots[5]={seedId=nil,plantedTime=0,waterCount=0,stage=0}

localplan,reason=validateInteraction(data,5,"plant",BERRY_SEED,NOW)

expect(plan).to.equal(nil)
expect(reason).to.equal("Invalidplot")
end)

it("rejectsmissingormalformedplayersessiondata",function()
localplan,reason=validateInteraction(nil,1,"plant",BERRY_SEED,NOW)

expect(plan).to.equal(nil)
expect(reason).to.equal("Invalidplayerdata")
end)

it("rejectsunknownactionsandnon-stringactionvalues",function()
localdata=makeData()
localunknownPlan,unknownReason=
validateInteraction(data,1,"grant_rewards",nil,NOW)
localmalformedPlan=validateInteraction(data,1,123,nil,NOW)

expect(unknownPlan).to.equal(nil)
expect(unknownReason).to.equal(
"Invalidaction.Use'plant','water','harvest',or'harvest_or_plant'."
)
expect(malformedPlan).to.equal(nil)
end)

it(
"acceptsasupportedseedonlywhentheplayerownsapositivewholequantity",
function()
localdata=makeData()
localvalidPlan=validateInteraction(data,1,"plant",BERRY_SEED,NOW)

expect(validPlan.action).to.equal("plant")
expect(validPlan.seedId).to.equal(BERRY_SEED)

data.inventory[BERRY_SEED]=0
localemptyPlan,emptyReason=
validateInteraction(data,1,"plant",BERRY_SEED,NOW)
expect(emptyPlan).to.equal(nil)
expect(emptyReason).to.equal("Noseedsavailable")

data.inventory[BERRY_SEED]=0.5
localfractionalPlan=validateInteraction(data,1,"plant",BERRY_SEED,NOW)
expect(fractionalPlan).to.equal(nil)
end
)

it("rejectsunsupportedseedidentifiersandoccupiedplots",function()
localdata=makeData()
localinvalidSeedPlan,invalidSeedReason=
validateInteraction(data,1,"plant","admin_seed",NOW)
expect(invalidSeedPlan).to.equal(nil)
expect(invalidSeedReason).to.equal("Invalidseedtype")

data.plots[1].seedId=BERRY_SEED
localoccupiedPlan,occupiedReason=
validateInteraction(data,1,"plant",BERRY_SEED,NOW)
expect(occupiedPlan).to.equal(nil)
expect(occupiedReason).to.equal("Plotalreadyoccupied")
end)

it("choosesadeterministicownedseedforharvest_or_plantonanemptyplot",function()
localdata=makeData()
data.inventory[BERRY_SEED]=1
data.inventory[FLOWER_SEED]=1

localplan=validateInteraction(data,1,"harvest_or_plant",nil,NOW)

expect(plan.action).to.equal("plant")
expect(plan.automatic).to.equal(true)
expect(plan.seedId).to.equal(BERRY_SEED)
end)

it("doesnotautomaticallyplantwhennovalidseedsareavailable",function()
localdata=makeData()
data.inventory[BERRY_SEED]=nil
data.inventory[FLOWER_SEED]=0

localplan,reason=validateInteraction(data,1,"harvest_or_plant",nil,NOW)

expect(plan).to.equal(nil)
expect(reason).to.equal("Noseedsavailableforplanting")
end)

it("requiresaplantedvalidcropanddewdropsbeforewatering",function()
localdata=makeData()
localemptyPlan,emptyReason=validateInteraction(data,1,"water",nil,NOW)
expect(emptyPlan).to.equal(nil)
expect(emptyReason).to.equal("Nothingplantedhere")

localplot=data.plots[1]
plot.seedId=BERRY_SEED
plot.plantedTime=NOW-5
plot.waterCount=0

data.inventory[DEWDROP]=0
localdryPlan,dryReason=validateInteraction(data,1,"water",nil,NOW)
expect(dryPlan).to.equal(nil)
expect(dryReason).to.equal("Nodewdropsavailable")

data.inventory[DEWDROP]=1
localvalidPlan=validateInteraction(data,1,"water",nil,NOW)
expect(validPlan.action).to.equal("water")
expect(validPlan.plantDef.id).to.equal("berry")
end)

it("rejectswateringafullywateredormalformedplot",function()
localdata=makeData()
localplot=data.plots[1]
plot.seedId=BERRY_SEED
plot.plantedTime=NOW-5
plot.waterCount=Constants.PLANTS.berry.waterNeeded

localfullPlan,fullReason=validateInteraction(data,1,"water",nil,NOW)
expect(fullPlan).to.equal(nil)
expect(fullReason).to.equal("Alreadyfullywatered")

plot.waterCount=0.5
localmalformedPlan=validateInteraction(data,1,"water",nil,NOW)
expect(malformedPlan).to.equal(nil)
end)

it("usesonedewdropperwateringbeforethewatering-canupgrade",function()
localdata=makeData()
localplot=data.plots[1]
plot.seedId=BERRY_SEED
plot.plantedTime=NOW-5
plot.waterCount=0
data.inventory[DEWDROP]=1

localfirstWater=validateInteraction(data,1,"water",nil,NOW)
expect(firstWater.dewdropCost).to.equal(1)

plot.waterCount=1
data.inventory[DEWDROP]=0
localsecondWater,reason=validateInteraction(data,1,"water",nil,NOW)
expect(secondWater).to.equal(nil)
expect(reason).to.equal("Nodewdropsavailable")
end)

it("chargeseverysecondwateringatcanleveltwo",function()
localdata=makeData()
localplot=data.plots[1]
plot.seedId=BERRY_SEED
plot.plantedTime=NOW-5
data.upgrades={watering_can=2}
data.inventory[DEWDROP]=1

localfirstWater=validateInteraction(data,1,"water",nil,NOW)
expect(firstWater.dewdropCost).to.equal(1)

plot.waterCount=1
data.inventory[DEWDROP]=0
localsecondWater=validateInteraction(data,1,"water",nil,NOW)
expect(secondWater.dewdropCost).to.equal(0)
end)

it("chargeseverythirdwateringatcanlevelthree",function()
localdata=makeData()
localplot=data.plots[1]
plot.seedId=BERRY_SEED
plot.plantedTime=NOW-5
data.upgrades={watering_can=3}
data.inventory[DEWDROP]=1

expect(validateInteraction(data,1,"water",nil,NOW).dewdropCost).to.equal(1)
plot.waterCount=1
data.inventory[DEWDROP]=0
expect(validateInteraction(data,1,"water",nil,NOW).dewdropCost).to.equal(0)
plot.waterCount=2
expect(validateInteraction(data,1,"water",nil,NOW).dewdropCost).to.equal(0)
end)

it("rejectsaninvalidwatering-canlevel",function()
localdata=makeData()
localplot=data.plots[1]
plot.seedId=BERRY_SEED
plot.plantedTime=NOW-5
data.upgrades={watering_can=Constants.UPGRADES.watering_can.maxLevel+1}

localplan,reason=validateInteraction(data,1,"water",nil,NOW)
expect(plan).to.equal(nil)
expect(reason).to.equal("Invalidwateringcanupgrade")
end)

it(
"rejectsmalformedupgradedatainsteadoftreatingitasthebasewateringcan",
function()
localdata=makeData()
data.upgrades=false

localplan,reason=validateInteraction(data,1,"water",nil,NOW)
expect(plan).to.equal(nil)
expect(reason).to.equal("Invalidplayerdata")
end
)

it(
"requiresbothelapsedgrowthtimeandthecompletewaterrequirementtoharvest",
function()
localdata=makeData()
localplot=data.plots[1]
plot.seedId=BERRY_SEED
plot.plantedTime=NOW-Constants.PLANTS.berry.growthTime-1
plot.waterCount=Constants.PLANTS.berry.waterNeeded-1

localunderWateredPlan,underWateredReason=
validateInteraction(data,1,"harvest",nil,NOW)
expect(underWateredPlan).to.equal(nil)
expect(underWateredReason).to.equal("Plantisstillgrowing")

plot.waterCount=Constants.PLANTS.berry.waterNeeded
plot.plantedTime=NOW-1
localgrowingPlan,growingReason=validateInteraction(data,1,"harvest",nil,NOW)
expect(growingPlan).to.equal(nil)
expect(growingReason).to.equal("Plantisstillgrowing")
end
)

it(
"allowsharvestonlywhencroptiming,watering,andrewardconfigurationarevalid",
function()
localdata=makeData()
localplot=plantBerry(data,1)

localplan,reason=validateInteraction(data,1,"harvest",nil,NOW)

expect(reason).to.equal(nil)
expect(plan.action).to.equal("harvest")
expect(plan.plot).to.equal(plot)
expect(plan.plantDef.id).to.equal("berry")
end
)

it("routesharvest_or_planttoharvestforanoccupied,readyplot",function()
localdata=makeData()
plantBerry(data,1)

localplan=validateInteraction(data,1,"harvest_or_plant",nil,NOW)

expect(plan.action).to.equal("harvest")
expect(plan.plantDef.id).to.equal("berry")
end)

it("doesnotallowharvestwhenplottimestampsorgrowthstatearecorrupt",function()
localdata=makeData()
localplot=plantBerry(data,1)
plot.plantedTime=0/0

localplan=validateInteraction(data,1,"harvest",nil,NOW)
expect(plan).to.equal(nil)
end)

it("supportstheseed-to-harvestrulesforeverydefinedplant",function()
forplantId,plantDefinpairs(Constants.PLANTS)do
localplot={seedId=nil,plantedTime=0,waterCount=0,stage=0}
localdata={
inventory={
[plantDef.seedId]=1,
[DEWDROP]=plantDef.waterNeeded,
},
plots={[1]=plot},
upgrades={},
}

localplanting=validateInteraction(data,1,"plant",plantDef.seedId,NOW)
expect(planting.action).to.equal("plant")
expect(planting.plantDef.id).to.equal(plantId)
plot.seedId=planting.seedId
plot.plantedTime=NOW-plantDef.growthTime
data.inventory[plantDef.seedId]-=1

whileplot.waterCount<plantDef.waterNeededdo
localwatering=validateInteraction(data,1,"water",nil,NOW)
expect(watering.action).to.equal("water")
expect(watering.dewdropCost).to.equal(1)
data.inventory[DEWDROP]-=watering.dewdropCost
plot.waterCount+=1
end

localgrowing=validateInteraction(data,1,"harvest",nil,NOW-1)
expect(growing).to.equal(nil)

localharvest=validateInteraction(data,1,"harvest",nil,NOW)
expect(harvest.action).to.equal("harvest")
expect(harvest.plantDef.id).to.equal(plantId)
expect(harvest.plantDef.harvestReward.itemId).to.equal(
Constants.RESOURCES["CROP_"..string.upper(plantId)]
)
end
end)
end)
describe("ResourceRules—persistedcooldownvalidation",function()
it("blocksanodeuntilitssavedcooldownexpires",function()
localcooldowns={tree_1=NOW+10}

expect(ResourceRules.isReady(cooldowns,"tree_1",NOW)).to.equal(false)
expect(ResourceRules.isReady(cooldowns,"tree_1",NOW+10)).to.equal(true)
expect(ResourceRules.isReady(cooldowns,"tree_2",NOW)).to.equal(true)
end)

it("rejectsmalformedsavedcooldownidentifiersandtimestamps",function()
expect(ResourceRules.isValidCooldowns({[""]=NOW})).to.equal(false)
expect(ResourceRules.isValidCooldowns({tree_1=1.5})).to.equal(false)
expect(ResourceRules.isValidCooldowns({tree_1=math.huge})).to.equal(false)
expect(ResourceRules.isValidCooldowns({tree_1=-1})).to.equal(false)
end)
end)
describe("HabitatRules—plotexpansion",function()
it("unlocksoneadditionalplotperpurchasedexpansionlevel",function()
expect(HabitatRules.getPlotCount({})).to.equal(4)
expect(HabitatRules.getPlotCount({plot_expansion=2})).to.equal(5)
expect(HabitatRules.getPlotCount({plot_expansion=4})).to.equal(7)
end)

it("rejectsmalformedorout-of-rangeexpansionlevelsandplotindices",function()
expect(HabitatRules.getPlotCount({plot_expansion=5})).to.equal(nil)
expect(HabitatRules.getPlotCount({plot_expansion=1.5})).to.equal(nil)
expect(HabitatRules.getPlotCount({plot_expansion=false})).to.equal(nil)
expect(HabitatRules.isPlotIndexUnlocked({},4)).to.equal(true)
expect(HabitatRules.isPlotIndexUnlocked({},5)).to.equal(false)
expect(HabitatRules.isPlotIndexUnlocked({plot_expansion=2},5)).to.equal(true)
end)

it("preservesexcesssavedplotstateoutsidethecurrentlyunlockedplotset",function()
localplantedPlot={
seedId=BERRY_SEED,
plantedTime=NOW-10,
waterCount=1,
stage=1,
}
localactive,archived=HabitatRules.partitionPlotData(
{[1]=makeData().plots[1],[6]=plantedPlot},
{},
4
)

expect(active[6]).to.equal(nil)
expect(archived[6].seedId).to.equal(BERRY_SEED)
expect(archived[6].plantedTime).to.equal(NOW-10)
expect(archived[6].waterCount).to.equal(1)
end)

it("restoresarchivedplotdatawhenthatplotbecomesunlocked",function()
localarchivedPlot={seedId=BERRY_SEED,plantedTime=NOW-10}
localactive,archived=HabitatRules.partitionPlotData({},{[5]=archivedPlot},5)

expect(active[5].seedId).to.equal(BERRY_SEED)
expect(archived[5]).to.equal(nil)
end)

it(
"rejectsduplicateandunrepresentablesavedplotswithoutdiscardingeithercopy",
function()
localactive,duplicateError=HabitatRules.partitionPlotData(
{[5]={}},
{[5]={}},
5
)
localoutOfRange,rangeError=HabitatRules.partitionPlotData({[8]={}},{},4)

expect(active).to.equal(nil)
expect(duplicateError).to.equal("Duplicateplotentry")
expect(outOfRange).to.equal(nil)
expect(rangeError).to.equal("Malformedplotentry")
end
)
end)
describe("QuestRules—server-recordedactionprogress",function()
it("usesvalidatedactioncountersinsteadofthecurrentinventory",function()
localprogress={}
expect(QuestRules.recordProgress(progress,"gather","wood",2)).to.equal(true)
expect(QuestRules.recordProgress(progress,"gather","wood",1)).to.equal(true)
expect(QuestRules.isComplete(progress,{
targetType="gather",
targetItemId="wood",
targetCount=3,
})).to.equal(true)
expect(QuestRules.isComplete({},{
targetType="gather",
targetItemId="wood",
targetCount=3,
})).to.equal(false)
end)

it(
"aggregatesharvestanddiscoveryactionswhilesupportingspecificdiscoveries",
function()
localprogress={}
expect(QuestRules.recordProgress(progress,"harvest","crop_berry",2)).to.equal(
true
)
expect(QuestRules.recordProgress(progress,"harvest","crop_sunpetal",1)).to.equal(
true
)
expect(QuestRules.recordProgress(progress,"discover","bunny",1)).to.equal(true)
expect(QuestRules.recordProgress(progress,"discover","leafling",1)).to.equal(
true
)
expect(QuestRules.getProgress(progress,"harvest")).to.equal(3)
expect(QuestRules.getProgress(progress,"discover")).to.equal(2)
expect(QuestRules.getProgress(progress,"discover","leafling")).to.equal(1)
end
)

it(
"tracksplantedseedsandwateringactionsindependentlyofcurrentplotstate",
function()
localprogress={}
expect(QuestRules.recordProgress(progress,"plant","seed_berry",1)).to.equal(true)
expect(QuestRules.recordProgress(progress,"water",nil,2)).to.equal(true)
expect(QuestRules.isComplete(progress,{
targetType="plant",
targetItemId="seed_berry",
targetCount=1,
})).to.equal(true)
expect(QuestRules.getProgress(progress,"water")).to.equal(2)
end
)

it("storesupgradelevelsaslevelsratherthancumulativepurchasecounts",function()
localprogress={}
expect(QuestRules.setProgress(progress,"upgrade","plot_expansion",2)).to.equal(true)
expect(QuestRules.setProgress(progress,"upgrade","plot_expansion",3)).to.equal(true)

expect(QuestRules.getProgress(progress,"upgrade","plot_expansion")).to.equal(3)
end)

it("boundsupgradeprogresstothedefinedupgradelevel",function()
localprogress={}

expect(QuestRules.setProgress(progress,"upgrade","plot_expansion",4)).to.equal(false)
expect(QuestRules.setProgress(progress,"upgrade","unknown_upgrade",1)).to.equal(
false
)
expect(QuestRules.isValidProgress({["upgrade:plot_expansion"]=4})).to.equal(false)
expect(QuestRules.setProgress(progress,"upgrade","plot_expansion",3)).to.equal(true)
end)

it("rejectsmalformedorforgedprogressvalues",function()
localprogress={}
expect(QuestRules.recordProgress(progress,"harvest","crop_berry",0.5)).to.equal(
false
)
expect(QuestRules.recordProgress(progress,"admin","bells",100)).to.equal(false)
expect(QuestRules.isValidProgress({["gather:wood"]=-1})).to.equal(false)
expect(QuestRules.isValidProgress({["gather:wood:extra"]=1})).to.equal(false)
expect(QuestRules.isValidProgress({["quest:unknown"]=1})).to.equal(false)
expect(QuestRules.isComplete(progress,{
targetType="harvest",
targetCount=math.huge,
})).to.equal(false)
end)
end)
describe("QuestRules—completeprogressionorder",function()
it("reachesalltendefinedquestsandendsafterthefinalclaim",function()
localcompleted={}
for_,questIdinipairs(Constants.QUEST_ORDER)do
expect(Constants.QUESTS[questId]~=nil).to.equal(true)
expect(QuestRules.nextQuest(completed)).to.equal(questId)
completed[questId]=true
end
expect(QuestRules.nextQuest(completed)).to.equal(nil)
expect(Constants.QUESTS.q6_creature.rewardItems[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(
1
)
expect(Constants.QUESTS.q9_leafling.targetItemId).to.equal("leafling")
end)
end)
describe("QuestRules—objectivevalidationandatomicclaims",function()
localfunctionmakeQuestData(currentQuest:string):any
localcompleted={}
for_,questIdinipairs(Constants.QUEST_ORDER)do
ifquestId==currentQuestthen
break
end
completed[questId]=true
end
return{
bells=0,
inventory={},
upgrades={},
questsCompleted=completed,
currentQuest=currentQuest,
questProgress={},
creaturesDiscovered={},
}
end

it("doesnotclaimaharvestquestwithoutarecordedharvest",function()
localdata=makeQuestData("q5_harvest")
localclaimed,reason=QuestRules.tryClaim(data,"q5_harvest")

expect(claimed).to.equal(false)
expect(reason).to.equal("Questobjectivesnotmet")
expect(data.bells).to.equal(0)
expect(data.questsCompleted.q5_harvest).to.equal(nil)
expect(data.currentQuest).to.equal("q5_harvest")
end)

it("grantstheSunPetalseedandadvancesexactlyonce",function()
localdata=makeQuestData("q6_creature")
data.creaturesDiscovered.bunny=true
data.questProgress["discover:bunny"]=1

expect(QuestRules.tryClaim(data,"q6_creature")).to.equal(true)
expect(data.inventory[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(1)
expect(data.bells).to.equal(100)
expect(data.questsCompleted.q6_creature).to.equal(true)
expect(data.currentQuest).to.equal("q7_sunpetal")

expect(QuestRules.tryClaim(data,"q6_creature")).to.equal(false)
expect(data.inventory[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(1)
expect(data.bells).to.equal(100)
end)

it("leavesaquestunclaimedwhenitsitemrewardexceedscapacity",function()
localdata=makeQuestData("q6_creature")
data.creaturesDiscovered.bunny=true
data.questProgress["discover:bunny"]=1
data.inventory[Constants.RESOURCES.WOOD]=75
data.upgrades.storage_expansion=1

localclaimed,reason=QuestRules.tryClaim(data,"q6_creature")

expect(claimed).to.equal(false)
expect(reason).to.equal("Inventoryfull")
expect(data.inventory[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(nil)
expect(data.bells).to.equal(0)
expect(data.currentQuest).to.equal("q6_creature")
end)

it("requiresthenamedcreatureandtheactualrequiredupgradelevel",function()
localleaflingData=makeQuestData("q9_leafling")
leaflingData.creaturesDiscovered.bunny=true
expect(QuestRules.tryClaim(leaflingData,"q9_leafling")).to.equal(false)
leaflingData.creaturesDiscovered.leafling=true
expect(QuestRules.tryClaim(leaflingData,"q9_leafling")).to.equal(true)

localupgradeData=makeQuestData("q8_owned_plots")
upgradeData.upgrades.plot_expansion=2
expect(QuestRules.tryClaim(upgradeData,"q8_owned_plots")).to.equal(false)
upgradeData.upgrades.plot_expansion=3
expect(QuestRules.tryClaim(upgradeData,"q8_owned_plots")).to.equal(true)
end)
end)
describe("EconomyRules—serverinventoryrewardvalidation",function()
it("allowsitemrewardsthatfitwithintheplayer'scurrentcapacity",function()
localinventory={[Constants.RESOURCES.WOOD]=74}
localupgrades={storage_expansion=1}
localallowed,reason=
EconomyRules.canAddItem(inventory,upgrades,Constants.RESOURCES.CROP_BERRY,1)

expect(allowed).to.equal(true)
expect(reason).to.equal(nil)
end)

it("rejectsrewardsthatwouldexceedinventorycapacity",function()
localinventory={[Constants.RESOURCES.WOOD]=75}
localupgrades={storage_expansion=1}
localallowed,reason=
EconomyRules.canAddItem(inventory,upgrades,Constants.RESOURCES.CROP_BERRY,1)

expect(allowed).to.equal(false)
expect(reason).to.equal("Inventoryfull")
end)

it("usestheplayer'sstorageupgradewhencalculatingcapacity",function()
localinventory={[Constants.RESOURCES.WOOD]=99}
localupgrades={storage_expansion=2}
localallowed=
EconomyRules.canAddItem(inventory,upgrades,Constants.RESOURCES.CROP_BERRY,1)
localdenied,reason=
EconomyRules.canAddItem(inventory,upgrades,Constants.RESOURCES.CROP_BERRY,2)

expect(allowed).to.equal(true)
expect(denied).to.equal(false)
expect(reason).to.equal("Inventoryfull")
end)

it(
"rejectsmalformeditemidentifiers,quantities,inventory,andupgradestate",
function()
localupgrades={storage_expansion=1}
localbadItem=EconomyRules.canAddItem({},upgrades,"",1)
localbadAmount=EconomyRules.canAddItem({},upgrades,"crop_berry",0.5)
localbadInventory=
EconomyRules.canAddItem({wood=-1},upgrades,"crop_berry",1)
localbadUpgrade=EconomyRules.canAddItem(
{},
{storage_expansion=0},
"crop_berry",
1
)

expect(badItem).to.equal(false)
expect(badAmount).to.equal(false)
expect(badInventory).to.equal(false)
expect(badUpgrade).to.equal(false)
end
)
it("rollsbackaproductioncooldownreservationwhentherewardisrejected",function()
localcooldowns={tree_1=NOW-1}
localrewardCalls=0

localgranted,reason=ResourceRules.tryGrantReward(
cooldowns,
"tree_1",
NOW,
NOW+60,
function()
rewardCalls+=1
returnfalse
end
)

expect(granted).to.equal(false)
expect(reason).to.equal("Rewardrejected")
expect(rewardCalls).to.equal(1)
expect(cooldowns.tree_1).to.equal(NOW-1)
end)

it("doesnotgrantarewardorreserveacooldownforacooling-downnode",function()
localcooldowns={tree_1=NOW+10}
localrewardCalls=0

localgranted=ResourceRules.tryGrantReward(
cooldowns,
"tree_1",
NOW,
NOW+60,
function()
rewardCalls+=1
returntrue
end
)

expect(granted).to.equal(false)
expect(rewardCalls).to.equal(0)
expect(cooldowns.tree_1).to.equal(NOW+10)
end)
end)
describe("CharacterSpawnData—spawnserialization",function()
it("encodesVector3coordinatesasanumerictable",function()
localserialized=CharacterSpawnData.encodeVector3(Vector3.new(1,2,3))

expect(type(serialized)).to.equal("table")
expect(serialized.x).to.equal(1)
expect(serialized.y).to.equal(2)
expect(serialized.z).to.equal(3)
end)
end)
describe("Creaturemovementprofiles",function()
it("definesauniquevalidmovementprofileforeachcreature",function()
localseenModes={}
localcreatureCount=0

for_,creatureDefinpairs(Constants.CREATURES)do
localbehavior=creatureDef.behavior
creatureCount+=1

expect(type(behavior)).to.equal("table")
expect(type(behavior.mode)).to.equal("string")
expect(seenModes[behavior.mode]).to.equal(nil)
seenModes[behavior.mode]=true

expect(behavior.moveInterval>0andbehavior.moveInterval%1==0).to.equal(true)
expect(behavior.wanderRadius>0andbehavior.wanderRadius%1==0).to.equal(true)
expect(
behavior.jumpInterval==nil
or(behavior.jumpInterval>0andbehavior.jumpInterval%1==0)
).to.equal(true)
expect(behavior.hoverHeight==nilorbehavior.hoverHeight>0).to.equal(true)
end

localmodeCount=0
for_inpairs(seenModes)do
modeCount+=1
end
expect(modeCount).to.equal(creatureCount)
end)
end)

describe("ResourceRules—cooldowntransactionedgecases",function()
it("validatesreadyAttimestampmustbestrictlygreaterthannow",function()
localcooldowns={tree_1=NOW-10}
localgranted=ResourceRules.tryGrantReward(
cooldowns,
"tree_1",
NOW,
NOW,--readyAt==nowshouldfail
function()
returntrue
end
)
expect(granted).to.equal(false)
end)

it("rejectsnegativecooldowntimestamps",function()
localcooldowns={}
localgranted=ResourceRules.tryGrantReward(cooldowns,"tree_1",NOW,-1,function()
returntrue
end)
expect(granted).to.equal(false)
end)

it("rejectsnon-integercooldowntimestamps",function()
localcooldowns={}
localgranted=ResourceRules.tryGrantReward(
cooldowns,
"tree_1",
NOW,
NOW+1.5,
function()
returntrue
end
)
expect(granted).to.equal(false)
end)

it("rejectsinfinitecooldowntimestamps",function()
localcooldowns={}
localgranted=ResourceRules.tryGrantReward(
cooldowns,
"tree_1",
NOW,
math.huge,
function()
returntrue
end
)
expect(granted).to.equal(false)
end)

it("rejectsnon-functionrewardcallbacks",function()
localcooldowns={}
localgranted=ResourceRules.tryGrantReward(
cooldowns,
"tree_1",
NOW,
NOW+60,
"notafunction"::any
)
expect(granted).to.equal(false)
end)

it("rejectsnilrewardcallbacks",function()
localcooldowns={}
localgranted=ResourceRules.tryGrantReward(cooldowns,"tree_1",NOW,NOW+60,nil)
expect(granted).to.equal(false)
end)

it("handlesmultipledifferentnodecooldownsindependently",function()
localcooldowns={tree_1=NOW+10,rock_1=NOW-5}
expect(ResourceRules.isReady(cooldowns,"tree_1",NOW)).to.equal(false)
expect(ResourceRules.isReady(cooldowns,"rock_1",NOW)).to.equal(true)
end)

it("validatescooldownmapwithemptystringkeyisinvalid",function()
expect(ResourceRules.isValidCooldowns({[""]=NOW})).to.equal(false)
end)
end)

describe("EconomyRules—capacityedgecases",function()
it("calculatesbasecapacitycorrectlyatlevel1",function()
localinventory={}
localupgrades={storage_expansion=1}
localmaxCapacity=50+1*25
localallowed=EconomyRules.canAddItem(inventory,upgrades,"test",maxCapacity)
expect(allowed).to.equal(true)

localdenied=EconomyRules.canAddItem(inventory,upgrades,"test",maxCapacity+1)
expect(denied).to.equal(false)
end)

it("calculatescapacitycorrectlyatmaxstoragelevel3",function()
localinventory={}
localupgrades={storage_expansion=3}
localmaxCapacity=50+3*25
localallowed=EconomyRules.canAddItem(inventory,upgrades,"test",maxCapacity)
expect(allowed).to.equal(true)

localdenied=EconomyRules.canAddItem(inventory,upgrades,"test",maxCapacity+1)
expect(denied).to.equal(false)
end)

it("accountsforexistingitemswhencheckingcapacity",function()
localinventory={wood=60}
localupgrades={storage_expansion=1}--75capacity
localallowed=EconomyRules.canAddItem(inventory,upgrades,"stone",10)--60+10=70<=75
expect(allowed).to.equal(true)

localdenied=EconomyRules.canAddItem(inventory,upgrades,"stone",20)--60+20=80>75
expect(denied).to.equal(false)
end)

it("rejectsnon-integerquantitiesininventory",function()
localinventory={wood=1.5}
localupgrades={storage_expansion=1}
localallowed=EconomyRules.canAddItem(inventory,upgrades,"stone",1)
expect(allowed).to.equal(false)
end)

it("rejectsnegativequantitiesininventory",function()
localinventory={wood=-5}
localupgrades={storage_expansion=1}
localallowed=EconomyRules.canAddItem(inventory,upgrades,"stone",1)
expect(allowed).to.equal(false)
end)

it("rejectsnon-integerstorageupgradelevels",function()
localinventory={}
localupgrades={storage_expansion=1.5}
localallowed=EconomyRules.canAddItem(inventory,upgrades,"stone",1)
expect(allowed).to.equal(false)
end)

it("rejectsstorageupgradelevel0",function()
localinventory={}
localupgrades={storage_expansion=0}
localallowed=EconomyRules.canAddItem(inventory,upgrades,"stone",1)
expect(allowed).to.equal(false)
end)

it("rejectsnegativestorageupgradelevels",function()
localinventory={}
localupgrades={storage_expansion=-1}
localallowed=EconomyRules.canAddItem(inventory,upgrades,"stone",1)
expect(allowed).to.equal(false)
end)

it("handlesverylargeitemamountswithoutoverflow",function()
localinventory={}
localupgrades={storage_expansion=3}
localallowed=EconomyRules.canAddItem(inventory,upgrades,"test",1000000)
expect(allowed).to.equal(false)
end)
end)

describe("QuestRules—progressaggregationandvalidation",function()
it("correctlyaggregatesharvestprogressacrossdifferentcroptypes",function()
localprogress={}
QuestRules.recordProgress(progress,"harvest","crop_berry",2)
QuestRules.recordProgress(progress,"harvest","crop_flower",3)
QuestRules.recordProgress(progress,"harvest","crop_sunpetal",1)

expect(QuestRules.getProgress(progress,"harvest")).to.equal(6)
expect(QuestRules.getProgress(progress,"harvest","crop_berry")).to.equal(2)
expect(QuestRules.getProgress(progress,"harvest","crop_flower")).to.equal(3)
end)

it("handlesdiscoverprogresswithspecificandaggregatecounts",function()
localprogress={}
QuestRules.recordProgress(progress,"discover","bunny",1)
QuestRules.recordProgress(progress,"discover","sprite",1)
QuestRules.recordProgress(progress,"discover","leafling",1)
QuestRules.recordProgress(progress,"discover","tortoise",1)
QuestRules.recordProgress(progress,"discover","finch",1)

expect(QuestRules.getProgress(progress,"discover")).to.equal(5)
expect(QuestRules.getProgress(progress,"discover","bunny")).to.equal(1)
end)

it("rejectsprogresswithnon-integeramounts",function()
localprogress={}
expect(QuestRules.recordProgress(progress,"gather","wood",1.5)).to.equal(false)
expect(QuestRules.recordProgress(progress,"gather","wood",-1)).to.equal(false)
end)

it("rejectsprogresswithzeroamountforpositive-onlytargets",function()
localprogress={}
expect(QuestRules.recordProgress(progress,"gather","wood",0)).to.equal(false)
end)

it("validatesupgradeprogressagainstmaxlevelforallupgrades",function()
localprogress={}
forupgradeId,upgradeDefinpairs(Constants.UPGRADES)do
expect(QuestRules.setProgress(progress,"upgrade",upgradeId,upgradeDef.maxLevel)).to.equal(
true
)
expect(
QuestRules.setProgress(progress,"upgrade",upgradeId,upgradeDef.maxLevel+1)
).to.equal(false)
end
end)

it("rejectsunknownupgradeIDs",function()
localprogress={}
expect(QuestRules.setProgress(progress,"upgrade","nonexistent",1)).to.equal(false)
expect(QuestRules.setProgress(progress,"upgrade","",1)).to.equal(false)
end)

it("isCompletereturnsfalseforprogressonnon-existenttarget",function()
localprogress={["gather:wood"]=5}
expect(QuestRules.isComplete(progress,{
targetType="gather",
targetItemId="nonexistent",
targetCount=1,
})).to.equal(false)
end)
end)

describe("QuestRules—questcompletionandordering",function()
it("validatesallquestdefinitionshaverequiredfields",function()
for_,questIdinipairs(Constants.QUEST_ORDER)do
localquest=Constants.QUESTS[questId]
expect(quest).to.be.ok()
expect(type(quest.id)).to.equal("string")
expect(type(quest.title)).to.equal("string")
expect(type(quest.description)).to.equal("string")
expect(type(quest.targetType)).to.equal("string")
expect(QuestRules.validTargets[quest.targetType]).to.equal(true)
expect(type(quest.targetCount)).to.equal("number")
expect(quest.targetCount>0).to.equal(true)
expect(type(quest.rewardBells)).to.equal("number")
expect(quest.rewardBells>=0).to.equal(true)
end
end)

it("q6_creaturegrantssunpetalseedasitemreward",function()
localquest=Constants.QUESTS.q6_creature
expect(quest.rewardItems).to.be.ok()
expect(quest.rewardItems[Constants.RESOURCES.SEED_SUNPETAL]).to.equal(1)
end)

it("questorderprogressesthroughalltenquestssequentially",function()
localcompleted={}
localpreviousQuest=nil
for_,questIdinipairs(Constants.QUEST_ORDER)do
localcurrentQuest=QuestRules.nextQuest(completed)
expect(currentQuest).to.equal(questId)
ifpreviousQuestthen
completed[previousQuest]=true
end
previousQuest=questId
end
expect(QuestRules.nextQuest(completed)).to.equal(nil)
end)
end)

describe("HabitatRules—plotexpansionedgecases",function()
it("returnsnilformalformedupgradestable",function()
expect(HabitatRules.getPlotCount(nil)).to.equal(nil)
expect(HabitatRules.getPlotCount("notatable")).to.equal(nil)
expect(HabitatRules.getPlotCount(123)).to.equal(nil)
end)

it("handlesmissingplot_expansionkeyaslevel1",function()
expect(HabitatRules.getPlotCount({})).to.equal(4)
expect(HabitatRules.getPlotCount({other_upgrade=1})).to.equal(4)
end)

it("validatesplotindexboundscorrectlybasedonupgrades",function()
--Initiallevel1:4plots
expect(HabitatRules.isPlotIndexUnlocked({plot_expansion=1},1)).to.equal(true)
expect(HabitatRules.isPlotIndexUnlocked({plot_expansion=1},4)).to.equal(true)
expect(HabitatRules.isPlotIndexUnlocked({plot_expansion=1},5)).to.equal(false)

--Level2:5plots
expect(HabitatRules.isPlotIndexUnlocked({plot_expansion=2},5)).to.equal(true)
expect(HabitatRules.isPlotIndexUnlocked({plot_expansion=2},6)).to.equal(false)

--Level3:6plots
expect(HabitatRules.isPlotIndexUnlocked({plot_expansion=3},6)).to.equal(true)
expect(HabitatRules.isPlotIndexUnlocked({plot_expansion=3},7)).to.equal(false)
end)

it("handlesfractionalplotindices",function()
expect(HabitatRules.isPlotIndexUnlocked({},1.5)).to.equal(false)
expect(HabitatRules.isPlotIndexUnlocked({},2.0)).to.equal(true)
end)

it("partitionPlotDatarejectsindicesbeyondmaxsupported",function()
localactive,_,err=HabitatRules.partitionPlotData({[8]={}},{},4)
expect(active).to.equal(nil)
expect(err).to.equal("Malformedplotentry")
end)

it("partitionPlotDatarejectsduplicateindicesacrossactiveandarchived",function()
localactive,_,err=HabitatRules.partitionPlotData({[5]={}},{[5]={}},5)
expect(active).to.equal(nil)
expect(err).to.equal("Duplicateplotentry")
end)

it("partitionPlotDatapreservesplotdataexactly",function()
localtestPlot={
seedId="seed_berry",
plantedTime=1000,
waterCount=2,
stage=1,
}
localactive,_=HabitatRules.partitionPlotData({[5]=testPlot},{},5)
expect(active[5].seedId).to.equal(testPlot.seedId)
expect(active[5].plantedTime).to.equal(testPlot.plantedTime)
expect(active[5].waterCount).to.equal(testPlot.waterCount)
expect(active[5].stage).to.equal(testPlot.stage)
end)
end)

describe("PlantRules—seedvalidationedgecases",function()
it("getPlantDefreturnsnilfornon-seeditems",function()
expect(PlantRules.getPlantDef("wood")).to.equal(nil)
expect(PlantRules.getPlantDef("stone")).to.equal(nil)
expect(PlantRules.getPlantDef("dewdrop")).to.equal(nil)
expect(PlantRules.getPlantDef("invalid_seed")).to.equal(nil)
end)

it("getPlantDefreturnscorrectplantforallseedtypes",function()
forplantId,plantDefinpairs(Constants.PLANTS)do
localretrieved=PlantRules.getPlantDef(plantDef.seedId)
expect(retrieved).to.equal(plantDef)
expect(retrieved.id).to.equal(plantId)
end
end)

it("resolveSeedrejectsinvalidseedtypesinautomaticmode",function()
localdata={
inventory={wood=10},
plots={[1]={seedId=nil,plantedTime=0,waterCount=0,stage=0}},
upgrades={},
}
localplan,reason=
PlantRules.validateInteraction(data,1,"harvest_or_plant",nil,NOW)
expect(plan).to.equal(nil)
expect(reason).to.equal("Noseedsavailableforplanting")
end)

it("validateswaterCountboundsforeachplanttype",function()
for_,plantDefinpairs(Constants.PLANTS)do
localdata={
inventory={[plantDef.seedId]=1,dewdrop=plantDef.waterNeeded},
plots={
[1]={
seedId=plantDef.seedId,
plantedTime=NOW-plantDef.growthTime,
waterCount=0,
stage=1,
},
},
upgrades={},
}

--Waterexactlytocompletion
for_=1,plantDef.waterNeededdo
localplan=PlantRules.validateInteraction(data,1,"water",nil,NOW)
expect(plan).to.be.ok()
expect(plan.dewdropCost).to.equal(1)
data.plots[1].waterCount+=1
data.inventory.dewdrop-=1
end

--Nextwatershouldfail
localplan=PlantRules.validateInteraction(data,1,"water",nil,NOW)
expect(plan).to.equal(nil)
end
end)

it("validatesharvestrewardconfigurationforeachplant",function()
forplantId,plantDefinpairs(Constants.PLANTS)do
expect(type(plantDef.harvestReward)).to.equal("table")
expect(type(plantDef.harvestReward.itemId)).to.equal("string")
expect(plantDef.harvestReward.itemId).to.equal(
Constants.RESOURCES["CROP_"..string.upper(plantId)]
)
expect(type(plantDef.harvestReward.min)).to.equal("number")
expect(type(plantDef.harvestReward.max)).to.equal("number")
expect(plantDef.harvestReward.min>=1).to.equal(true)
expect(plantDef.harvestReward.max>=plantDef.harvestReward.min).to.equal(true)
expect(type(plantDef.bellReward)).to.equal("number")
expect(plantDef.bellReward>=1).to.equal(true)
end
end)
end)

describe("CharacterSpawnData—serializationedgecases",function()
it("decodesVector3fromarray-styletable",function()
localdecoded=CharacterSpawnData.decodeVector3({1,2,3},Vector3.zero)
expect(decoded).to.equal(Vector3.new(1,2,3))
end)

it("decodesVector3fromobject-styletable",function()
localdecoded=CharacterSpawnData.decodeVector3({x=1,y=2,z=3},Vector3.zero)
expect(decoded).to.equal(Vector3.new(1,2,3))
end)

it("decodesmixedarray/objectstyletable",function()
localdecoded=
CharacterSpawnData.decodeVector3({[1]=1,y=2,z=3},Vector3.zero)
expect(decoded).to.equal(Vector3.new(1,2,3))
end)

it("returnsfallbackforinvalidcoordinatetypes",function()
localfallback=Vector3.new(0,5,0)
expect(CharacterSpawnData.decodeVector3({x="a",y=2,z=3},fallback)).to.equal(
fallback
)
expect(CharacterSpawnData.decodeVector3({x=true,y=2,z=3},fallback)).to.equal(
fallback
)
expect(CharacterSpawnData.decodeVector3({},fallback)).to.equal(fallback)
end)

it("returnsfallbackforcoordinatesexceeding100000",function()
localfallback=Vector3.new(0,5,0)
expect(CharacterSpawnData.decodeVector3({x=100001,y=0,z=0},fallback)).to.equal(
fallback
)
expect(CharacterSpawnData.decodeVector3({x=-100001,y=0,z=0},fallback)).to.equal(
fallback
)
end)

it("returnsfallbackforNaNandinfinitecoordinates",function()
localfallback=Vector3.new(0,5,0)
expect(CharacterSpawnData.decodeVector3({x=0/0,y=0,z=0},fallback)).to.equal(
fallback
)
expect(CharacterSpawnData.decodeVector3({x=math.huge,y=0,z=0},fallback)).to.equal(
fallback
)
end)

it("encodesVector3toobjectwithx,y,zkeys",function()
localencoded=CharacterSpawnData.encodeVector3(Vector3.new(1.5,-2.5,3.7))
expect(type(encoded)).to.equal("table")
expect(encoded.x).to.equal(1.5)
expect(encoded.y).to.equal(-2.5)
expect(encoded.z).to.equal(3.7)
end)

it("round-trippreservesprecisionfortypicalvalues",function()
localoriginal=Vector3.new(12.5,6,-8)
localencoded=CharacterSpawnData.encodeVector3(original)
localdecoded=CharacterSpawnData.decodeVector3(encoded,Vector3.zero)
expect(decoded).to.equal(original)
end)
end)

describe("Constants—resourcenodeandplantconsistency",function()
it("everyresourcenodehasvalidstructure",function()
for_,nodeinipairs(Constants.RESOURCE_NODES)do
expect(type(node.id)).to.equal("string")
expect(node.id).to.equal(string.lower(node.name))
expect(type(node.type)).to.equal("string")
expect(node.amount>0andnode.amount%1==0).to.equal(true)
expect(node.cooldownMinutes>0).to.equal(true)
expect(typeof(node.position)).to.equal("Vector3")
end
end)

it("everyplanthasacorrespondingseedresourcenode",function()
localseedNodeTypes={}
for_,nodeinipairs(Constants.RESOURCE_NODES)do
ifstring.sub(node.type,1,5)=="seed_"then
seedNodeTypes[node.type]=true
end
end

for_,plantDefinpairs(Constants.PLANTS)do
expect(seedNodeTypes[plantDef.seedId]).to.equal(true)
end
end)

it("everyseedresourcenodehasacorrespondingplant",function()
for_,nodeinipairs(Constants.RESOURCE_NODES)do
ifstring.sub(node.type,1,5)=="seed_"then
localfound=false
for_,plantDefinpairs(Constants.PLANTS)do
ifplantDef.seedId==node.typethen
found=true
break
end
end
expect(found).to.equal(true)
end
end
end)

it("allcreaturedefinitionshavevalidbehaviorprofiles",function()
for_,creatureDefinpairs(Constants.CREATURES)do
expect(type(creatureDef.id)).to.equal("string")
expect(type(creatureDef.name)).to.equal("string")
expect(type(creatureDef.requiredFlora)).to.equal("number")
expect(creatureDef.requiredFlora>=0).to.equal(true)
expect(type(creatureDef.requiredWater)).to.equal("number")
expect(creatureDef.requiredWater>=0).to.equal(true)
expect(type(creatureDef.bellReward)).to.equal("number")
expect(creatureDef.bellReward>=0).to.equal(true)
expect(type(creatureDef.behavior)).to.equal("table")
expect(type(creatureDef.behavior.mode)).to.equal("string")
expect(creatureDef.behavior.moveInterval>0).to.equal(true)
expect(creatureDef.behavior.wanderRadius>0).to.equal(true)
end
end)

it("allupgradeshavevalidcostprogression",function()
for_,upgradeDefinpairs(Constants.UPGRADES)do
expect(type(upgradeDef.id)).to.equal("string")
expect(type(upgradeDef.baseCost)).to.equal("number")
expect(upgradeDef.baseCost>0).to.equal(true)
expect(type(upgradeDef.costMultiplier)).to.equal("number")
expect(upgradeDef.costMultiplier>0).to.equal(true)
expect(type(upgradeDef.maxLevel)).to.equal("number")
expect(upgradeDef.maxLevel>=1).to.equal(true)
end
end)
end)
end
