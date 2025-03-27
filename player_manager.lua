---@version 1.1.1
--[[
    File: player_manager.lua
    Description: Manage your player's state from one dynamic instance
    Author: Sonson

    TODO:
    - Add methods to remove static and dynamic locations
    - Add player_manager features
        - Prayer Management
        - Buff Management
        - Summoning Management
]]

---@class PlayerManager
---@field config PlayerManagerConfig
---@field state PlayerState
---@field playerManagementState any --TODO: fix this
---@field foodStuffs Stuff[]
---@field prayerStuffs Stuff[]
local PlayerManager = {}
PlayerManager.__index = PlayerManager

--#region luacats annotation

---@class PlayerManagerConfig
---@field overrideHealthManagement boolean | fun(): boolean
---@field overridePrayerManagement boolean | fun(): boolean
---@field overrideBuffManagement boolean | fun(): boolean
---@field overrideSummoningManagement boolean | fun(): boolean
---@field locations Locations
---@field thresholds Thresholds

---@class Thresholds
---@field healthThreshold HealthThreshold
---@field prayerThreshold PrayerThreshold

---@class HealthThreshold
---@field valueType thresholdType
---@field value number
---@field criticalValueType thresholdType
---@field criticalValue number
---@field excalThresholdType thresholdType
---@field excalThreshold number

---@class PrayerThreshold
---@field valueType thresholdType
---@field value number
---@field criticalValueType thresholdType
---@field criticalValue number
---@field shardThresholdType thresholdType
---@field shardThreshold number

---@alias thresholdType
---| "percent"
---| "current"

---@class PlayerState
---@field health {current: number, max: number, percent: number}
---@field prayer {current: number, max: number, percent: number}
---@field buffs table
---@field debuffs table
---@field adrenaline number
---@field animation number
---@field moving boolean
---@field inCombat boolean
---@field location string
---@field coords WPOINT

---@class Locations
---@field staticLocations StaticLocation[]
---@field dynamicLocations DynamicLocation[]

---@class StaticLocation
---@field name string
---@field coords {x: number, y: number, range: number}

---@class DynamicLocation
---@field name string
---@field detectionFn fun(): boolean

---@class Stuff
---@field name string
---@field id number
---@field type stuffType
---@field count number

---@alias stuffType string
---| "Potion"
---| "Jellyfish"
---| "Food"

--#endregion

local API = require("api")

--#region initialize PlayerManager

---initialize a new PlayerManager instance
---@param config PlayerManagerConfig
---@return PlayerManager
function PlayerManager.new(config)
    local self = setmetatable({}, PlayerManager)

    -- initialize config
    ---@type PlayerManagerConfig
    self.config = config or {
        locations = {
            staticLocations = {},
            dynamicLocations = {}
        },
        thresholds = {
            healthThreshold = {
                valueType = "percent",
                value = 50,
                criticalValueType = "percent",
                criticalValue = 25,
                excalThresholdType = "percent",
                excalThreshold = 75
            },
            prayerThreshold = {
                valueType = "current",
                value = 200,
                criticalValueType = "percent",
                criticalValue = 10,
                shardThresholdType = "current",
                shardThreshold = 600
            }
        },
        overrideHealthManagement = false,
        overridePrayerManagement = false,
        overrideSummoningManagement = false,
        overrideBuffManagement = false
    }

    -- initialize player state
    ---@type PlayerState
    self.state = {
        health = { current = 0, max = 0, percent = 0 },
        prayer = { current = 0, max = 0, percent = 0 },
        adrenaline = 0,
        location = "",
        coords = { x = 0, y = 0, z = 0 },
        buffs = {},
        debuffs = {},
        animation = -1,
        moving = false,
        inCombat = false,
    }

    -- initialize player management state
    self.playerManagementState = {
        lastEatTick = 0,
        lastDrinkTick = 0,
        lastMoveTick = 0,
        lastExcalTick = 0,
        lastElvenShardTick = 0
    }

    self.foodStuffs = {}
    self.prayerStuffs = {}

    return self
end

--#endregion

--#region PlayerState methods

---add a static location
---@param location StaticLocation
function PlayerManager:addStaticLocation(location)
    if not location then return end
    table.insert(self.config.locations.staticLocations, location)
end

---add a dynamic location
---@param location DynamicLocation
function PlayerManager:addDynamicLocation(location)
    if not location then return end
    table.insert(self.config.locations.dynamicLocations, location)
end

---determines your location based on dynamic and static information
---@private
---@return string
function PlayerManager:_checkLocation()
    -- check dynamic locations first
    if #self.config.locations.dynamicLocations > 0 then
        for _, loc in pairs(self.config.locations.dynamicLocations) do
            if loc.detectionFn() then
                return loc.name
            end
        end
    end

    -- check static locations
    if #self.config.locations.staticLocations > 0 then
        for _, loc in pairs(self.config.locations.staticLocations) do
            ---@diagnostic disable-next-line
            if API.PInArea(loc.coords.x, loc.coords.range, loc.coords.y, loc.coords.range) then
                return loc.name
            end
        end
    end

    -- default
    return "UNKNOWN"
end

---updates values in the PlayerState instance
---@private
function PlayerManager:_updatePlayerState()
    -- health
    local maxHp = API.GetHPMax_() or 0
    local hp = API.GetHP_() or 0
    self.state.health = {
        current = hp,
        max = maxHp,
        percent = math.floor((hp / maxHp) * 100)
    }

    -- prayers
    local maxPrayer = API.GetPrayMax_() or 0
    local prayer = API.GetPray_() or 0
    self.state.prayer = {
        current = prayer,
        max = maxPrayer,
        percent = math.floor((prayer / maxPrayer) * 100)
    }

    -- adrenaline
    local adrenData = API.VB_FindPSettinOrder(679) -- adrenaline vb
    self.state.adrenaline = adrenData and adrenData.state / 10 or 0

    -- location and coords
    self.state.location = self:_checkLocation()
    self.state.coords = API.PlayerCoord()

    -- animations
    self.state.animation = API.ReadPlayerAnim() or -1
    self.state.moving = API.ReadPlayerMovin2() or false
    self.state.inCombat = API.LocalPlayer_IsInCombat_() or false
end

--#endregion

--#region Player Management methods

---checks if the player has a specific buff
---@param buffId number
---@return Bbar | boolean
function PlayerManager:getBuff(buffId)
    return API.Buffbar_GetIDstatus(buffId, false) or false
end

---checks if the player has a specific debuff
---@param debuffId number
---@return Bbar | boolean
function PlayerManager:getDebuff(debuffId)
    return API.DeBuffbar_GetIDstatus(debuffId, false) or false
end

---sorts foods into foodstuffs table
---@param list table
---@param itemName string
---@param itemId number
---@param type stuffType
function PlayerManager._sortStuffs(list, itemName, itemId, type)
    -- check if item already exists in foodstuffs
    for _, i in ipairs(list) do
        if i.name == itemName and i.type == type then
            i.count = i.count + 1
            return
        end
    end
    -- add it if it isn't
    table.insert(list, {
        name = itemName,
        id = itemId,
        type = type,
        count = 1
    })
end

--#region health management stuff

---checks if the player has enhanced excalibur in inventory or equipped
---@private
---@return {location: string, id: number} | boolean
function PlayerManager:_hasExcalibur()
    local excalIds = {
        14632, -- enhanced excalibur
        36619, -- augmented enhanced excalibur
    }

    for _, id in ipairs(excalIds) do
        --check inventory
        if API.InvItemFound1(id) then
            return { location = "inventory", id = id }
        end
        --check off-hand
        if API.GetEquipSlot(5).itemid1 == id then
            return { location = "equipped", id = id }
        end
    end

    return false
end

---uses enchanced excalibur after checking if it exists
---@return boolean
function PlayerManager:useExcalibur()
    local currentTick = API.Get_tick()

    --do the excal check
    local hasExcalibur = self:_hasExcalibur()
    if (not hasExcalibur or self:getDebuff(14632).found or currentTick - 1 <= self.playerManagementState.lastExcalTick) then return false end

    local location, id = hasExcalibur.location, hasExcalibur.id

    if location == "inventory" then
        if API.DoAction_Inventory1(id, 0, 1, API.OFF_ACT_GeneralInterface_route) then -- default behavior
            self.playerManagementState.lastExcalTick = currentTick
        end
    elseif location == "equipped" then
        ---@diagnostic disable-next-line
        if API.DoAction_Interface(0xffffffff, 0x8f0b, 2, 1464, 15, 5, API.OFF_ACT_GeneralInterface_route) then -- default behavior
            self.playerManagementState.lastExcalTick = currentTick
        end
    end

    return false
end

---checks to make sure that the player has something they can consume to regain hp in their inventory
---@private
---@return Stuff[]
function PlayerManager:_getEdibleItems()
    local potions, jellyfish, foods = {
            "Guthix rest", "Super Guthix brew",
            "Saradomin brew", "Super Saradomin brew"
        },
        {
            "Blue blubber jellyfish", "2/3 blue blubber jellyfish", "1/3 blue blubber jellyfish",
            "Green blubber jellyfish", "2/3 green blubber jellyfish", "1/3 green blubber jellyfish",
        },
        {
            "Kebab", "Bread", "Doughnut", "Roll", "Square sandwich",
            "Crayfish", "Shrimps", "Sardine", "Herring", "Mackerel",
            "Anchovies", "Cooked chicken", "Cooked meat", "Trout", "Cod",
            "Pike", "Salmon", "Tuna", "Bass", "Lobster", "Swordfish",
            "Desert sole", "Catfish", "Monkfish", "Beltfish", "Ghostly sole",
            "Cooked eeligator", "Shark", "Sea turtle", "Great white shark", "Cavefish",
            "Manta ray", "Rocktail", "Tiger shark", "Sailfish", "Baron shark",
            "Potato with cheese", "Tuna potato", "Great maki", "Great gunkan",
            "Rocktail soup", "Sailfish soup", "Fury shark", "Primal feast"
        }

    local foodStuffs = {}
    local inventoryItems = API.ReadInvArrays33()

    -- lol
    for _, item in ipairs(inventoryItems) do
        -- check that slot is not empty and that stack size is 1
        if item.itemid1 ~= -1 and item.itemid1_size == 1 then
            local itemName = item.textitem:gsub("<col=f8d56b>", "")
            --check if its a potion
            for _, v in pairs(potions) do
                if string.find(itemName, v) then
                    self._sortStuffs(foodStuffs, itemName, item.itemid1, "Potion")
                    goto continue
                end
            end
            --check if its a jellyfish
            for _, v in pairs(jellyfish) do
                if itemName == v then
                    self._sortStuffs(foodStuffs, itemName, item.itemid1, "Jellyfish")
                    goto continue
                end
            end
            --check if its a food
            for _, v in pairs(foods) do
                if itemName == v then
                    self._sortStuffs(foodStuffs, itemName, item.itemid1, "Food")
                end
            end
            ::continue::
        end
    end

    self.foodStuffs = foodStuffs
    return foodStuffs
end

---get the number of edible items in your inventory
---@private
---@return number
function PlayerManager:_getFoodCount()
    local foodCount = 0

    for _, foodItem in pairs(self.foodStuffs) do
        foodCount = foodCount + foodItem.count
    end

    return foodCount
end

---retrieves specific type of foodstuffs
---@private
---@param type stuffType
---@return Stuff[]
function PlayerManager:_filterFoodstuffs(type)
    local filteredFoodStuffs = {}
    for _, item in ipairs(self.foodStuffs) do
        if item.type == type then
            table.insert(filteredFoodStuffs, item)
        end
    end
    return filteredFoodStuffs
end

---eats first type of food found returns true if action taken
---@param type stuffType
---@return boolean
function PlayerManager:_eat(type)
    local item = self:_filterFoodstuffs(type)[1]
    if API.DoAction_Inventory1(item.id, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        API.RandomSleep2(30, 10, 20)
        return true
    else
        return false
    end
end

---eats all food in one tick
---@param eatBigFood boolean if true will eat food and drain some adren
function PlayerManager:oneTickEat(eatBigFood)
    local currentTick = API.Get_tick()
    --first check last drink and eat tick?
    if currentTick - 1 <= self.playerManagementState.lastEatTick then return end

    if eatBigFood then
        if #self:_filterFoodstuffs("Food") > 0 then
            if self:_eat("Food") then
                self.playerManagementState.lastEatTick = currentTick
                API.RandomSleep2(60, 10, 20)
            end
        end
    end
    if #self:_filterFoodstuffs("Jellyfish") > 0 then
        if self:_eat("Jellyfish") then
            self.playerManagementState.lastEatTick = currentTick
            API.RandomSleep2(60, 10, 20)
        end
    end

    if currentTick - 1 <= self.playerManagementState.lastDrinkTick then return false end
    if #self:_filterFoodstuffs("Potion") > 0 then
        if self:_eat("Potion") then
            self.playerManagementState.lastDrinkTick = currentTick
            API.RandomSleep2(60, 10, 20)
        end
    end
end

---manages player health
function PlayerManager:_manageHealth()
    local potions, jellyfish, food = self:_filterFoodstuffs("Potion"), self:_filterFoodstuffs("Jellyfish"),
        self:_filterFoodstuffs("Food")

    -- check thresholds
    -- excalibur thresh
    local excalThresholdType, excalThresholdValue = self.config.thresholds.healthThreshold.excalThresholdType,
        self.config.thresholds.healthThreshold.excalThreshold
    local excalThreshold = (excalThresholdType == "percent" and excalThresholdValue >= self.state.health.percent) or
    (excalThresholdType == "current" and excalThresholdValue >= self.state.health.current)
    -- general thresh
    local valueType, value = self.config.thresholds.healthThreshold.valueType,
        self.config.thresholds.healthThreshold.value
    local threshold = (valueType == "percent" and value >= self.state.health.percent) or
    (valueType == "current" and value >= self.state.health.current)
    -- critical thresh
    local criticalValueType, criticalValue = self.config.thresholds.healthThreshold.criticalValueType,
        self.config.thresholds.healthThreshold.criticalValue
    local criticalThreshold = (criticalValueType == "percent" and criticalValue >= self.state.health.percent) or
    (criticalValueType == "current" and criticalValue >= self.state.health.current)

    -- do stuff
    if excalThreshold then self:useExcalibur() end
    if threshold and #self.foodStuffs > 0 then self:oneTickEat(criticalThreshold) end
    if criticalThreshold and #self.foodStuffs == 0 then
        return -- gtfo bro
    end
end

--#endregion

--#region prayer management stuff

---checks if player has elven ritual shard in inventory
---@return boolean
function PlayerManager:_hasElvenShard()
    return API.InvItemFound1(43358)
end

---uses elven ritual shard
function PlayerManager:useElvenShard()
    local currentTick = API.Get_tick()

    --do shard check
    if not self:_hasElvenShard() or self:getDebuff(43358).found or currentTick - 1 <= self.playerManagementState.lastElvenShardTick then return end

    if API.DoAction_Inventory1(43358, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        self.playerManagementState.lastElvenShardTick = currentTick
        return true
    else
        return false
    end
end

---checks to make sure that the player has something they can consume to regain prayer in their inventory
---@private
---@return Stuff[]
function PlayerManager:_getPrayerItems()
    local potions = {
        "Prayer", "Super restore", "Sanfew",
        "Super prayer", "Spiritual prayer", "Extreme prayer",
        "Blessed flask"     -- untested
    }

    local prayerStuffs = {}
    local inventoryItems = API.ReadInvArrays33()

    -- lol
    for _, item in ipairs(inventoryItems) do
        -- check that slot is not empty and that stack size is 1
        if item.itemid1 ~= -1 and item.itemid1_size == 1 then
            local itemName = item.textitem:gsub("<col=f8d56b>", "")
            --check if its a potion (not sure if there are other types)
            for _, v in pairs(potions) do
                if string.find(itemName, v) then
                    self._sortStuffs(prayerStuffs, itemName, item.itemid1, "Potion")
                end
            end
        end
    end

    self.prayerStuffs = prayerStuffs
    return prayerStuffs
end

---get the number of prayer restoring items in your inventory
---@private
---@return number
function PlayerManager:_getPrayerItemCount()
    local prayerItem = 0

    for _, item in pairs(self.prayerStuffs) do
        prayerItem = prayerItem + item.count
    end

    return prayerItem
end

---consumes first prayer item found & returns true if action taken
---@return boolean
function PlayerManager:drink()
    local currentTick = API.Get_tick()
    if currentTick - 1 <= self.playerManagementState.lastDrinkTick then return false end

    local item = self.prayerStuffs[1]
    if API.DoAction_Inventory1(item.id, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        self.playerManagementState.lastDrinkTick = currentTick
        API.RandomSleep2(30, 10, 20)
        return true
    else
        return false
    end
end

---manages player prayer
function PlayerManager:_managePrayer()
    -- check thresholds
    -- elven ritual shard thresh
    local shardThresholdType = self.config.thresholds.prayerThreshold.shardThresholdType
    local shardThresholdValue = self.config.thresholds.prayerThreshold.shardThreshold
    local shardThreshold = (shardThresholdType == "percent" and shardThresholdValue >= self.state.prayer.percent) or
    (shardThresholdType == "current" and shardThresholdValue >= self.state.prayer.current)
    -- general thresh
    local valueType = self.config.thresholds.prayerThreshold.valueType
    local value = self.config.thresholds.prayerThreshold.value
    local threshold = (valueType == "percent" and value >= self.state.prayer.percent) or
    (valueType == "current" and value >= self.state.prayer.current)
    -- critical thresh
    local criticalValueType = self.config.thresholds.prayerThreshold.criticalValueType
    local criticalValue = self.config.thresholds.prayerThreshold.criticalValue
    local criticalThreshold = (criticalValueType == "percent" and criticalValue >= self.state.prayer.percent) or
    (criticalValueType == "current" and criticalValue >= self.state.prayer.current)

    -- do stuff
    if shardThreshold then self:useElvenShard() end
    if threshold and #self.prayerStuffs > 0 then self:drink() end
    if criticalThreshold and #self.prayerStuffs < 0 then
        return -- gtfo bro
    end
end

--#endregion

--#endregion

--#region tracking

---returns tracking metrics for the player state
---@return table
function PlayerManager:stateTracking()
    local metrics = {
        { "Player State:", "" },
        -- stats
        { "- Health",      self.state.health.current .. "/" .. self.state.health.max .. " (" .. self.state.health.percent .. "%)" },
        { "- Prayer",      self.state.prayer.current .. "/" .. self.state.prayer.max .. " (" .. self.state.prayer.percent .. "%)" },
        -- location
        { "- Coordinates", string.format("(X:%s, Y:%s, Z:%s)",
            self.state.coords.x,
            self.state.coords.y,
            self.state.coords.z) },
        { "- Location",   self.state.location },
        -- animations
        { "- Animation",  self.state.animation == 0 and "Idle" or self.state.animation },
        { "- Moving?",    self.state.moving and "Yes" or "No" },
        { "- In Combat?", self.state.inCombat and "Yes" or "No" },
    }
    return metrics
end

---returns tracking metrics for player management data
---@return table
function PlayerManager:managementTracking()
    local metrics = {
        { "Player Management:",         "" },
        -- items
        { "- Items: ",                  "" },
        { "-- Has Excalibur?",          self:_hasExcalibur() and "Yes" or "No" },
        { "-- Has Elven ritual shard?", self:_hasElvenShard() and "Yes" or "No" },
        { "-- Edible food count:",      self:_getFoodCount() }
    }
    return metrics
end

function PlayerManager:foodStuffsTracking()
    local metrics = { { "- Food Stuff:", "" } }

    if #self.foodStuffs < 1 then
        table.insert(metrics, { "-- No foods found", "" })
    else
        for _, i in ipairs(self.foodStuffs) do
            table.insert(metrics, { "-- " .. i.count .. "x " .. i.type, i.name })
        end
    end
    return metrics
end

function PlayerManager:prayerStuffsTracking()
    local metrics = { { "- Prayer Stuff:", "" } }

    if #self.prayerStuffs < 1 then
        table.insert(metrics, { "-- No prayer items found", "" })
    else
        for _, i in ipairs(self.prayerStuffs) do
            table.insert(metrics, { "-- " .. i.count .. "x " .. i.type, i.name })
        end
    end
    return metrics
end

--#endregion

---updates the player state
function PlayerManager:update()
    self:_updatePlayerState() -- refresh player data
    self:_getEdibleItems()    -- get the foodstuffs
    self:_getPrayerItems()    -- get the prayerstuffs
    -- check if we should override health management
    local overrideHealthManagement = (
        type(self.config.overrideHealthManagement) == "function" and
        function() return self.config.overrideHealthManagement() end
    ) or (
        type(self.config.overrideHealthManagement) == "boolean" and self.config.overrideHealthManagement
    ) or false
    -- do health management
    if not overrideHealthManagement then
        self:_manageHealth()
    end
    -- check if we should override prayer management
    local overridePrayerManagement = (
        type(self.config.overridePrayerManagement) == "function" and
        function() return self.config.overridePrayerManagement() end
    ) or (
        type(self.config.overridePrayerManagement) == "boolean" and self.config.overridePrayerManagement
    ) or false
    -- do prayer management
    if not overridePrayerManagement then
        self:_managePrayer()
    end
end

return PlayerManager
