---@version 1.2.4
--[[
    File: player_manager.lua
    Description: Manage your player's state from one dynamic instance
    Author: Sonson

    TODO:
    - Add player_manager features
        - Summoning Management
        - Aura Management
]]

local debug = true

---@class PlayerManager
---@field config PlayerManagerConfig
---@field state PlayerState
---@field inventory PMInventory
---@field buffs BuffCategory
---@field timestamp Cooldowns
local PlayerManager = {}
PlayerManager.__index = PlayerManager

--#region luacats annotation

---@class PlayerManagerConfig
---@field health ThresholdSettings
---@field prayer ThresholdSettings
---@field locations Location[]?

---@class ThresholdSettings
---@field normal Threshold
---@field critical Threshold
---@field special Threshold

---@class Threshold
---@field type ThresholdType
---@field value number

---@alias ThresholdType "percent" | "current"

---@class Stat
---@field current number
---@field max number
---@field percent number

---@class Location
---@field name string
---@field coords {x: number, y: number, range: number, z?:number}?
---@field detector function?

---@class PMInventoryItem
---@field name string
---@field id number
---@field type string
---@field count number

---@class PMInventory
---@field food PMInventoryItem[]
---@field prayer PMInventoryItem[]

---@class Cooldowns
---@field eat number
---@field drink number
---@field buff number
---@field excal number
---@field shard number
---@field tele number

---@class Buff
---@field buffName string
---@field buffId number
---@field execute fun(): boolean
---@field canApply nil | boolean | fun(self):boolean
---@field toggle boolean?
---@field refreshAt number?

---@class BuffCategory
---@field managed ManagedBuff[]
---@field toggle ManagedBuff[]

---@class ManagedBuff
---@field buffName string
---@field buffId number
---@field remaining number
---@field execute fun(): boolean
---@field canApply nil | boolean | fun(self):boolean

---@class PlayerState
---@field health Stat
---@field prayer Stat
---@field adrenaline number
---@field location string
---@field orientation number
---@field coords WPOINT
---@field animation number
---@field moving boolean
---@field inCombat boolean

---@class FamiliarState
---@field name string
---@field id number
---@field remaining number seconds
---@field hasScrolls boolean
---@field scrollCount number?

--#endregion

local API = require("api")
local BUFF_INTERVAL_CHECK = 2

--#region initialize PlayerManager

---initialize a new PlayerManager instance
---@param config PlayerManagerConfig
---@return PlayerManager
function PlayerManager.new(config)
    local self = setmetatable({}, PlayerManager)

    -- initialize config
    self.config = config or {
        health = {
            normal = { type = "percent", value = 50 },
            critical = { type = "percent", value = 25 },
            special = { type = "percent", value = 75 } -- Excalibur threshold
        },
        prayer = {
            normal = { type = "current", value = 200 },
            critical = { type = "percent", value = 10 },
            special = { type = "current", value = 600 } -- Shard threshold
        },
        locations = {}
    }

    -- initialize player state
    self.state = {
        health = { current = 0, max = 0, percent = 0 },
        prayer = { current = 0, max = 0, percent = 0 },
        adrenaline = 0,
        location = "UNKNOWN",
        orientation = 999,
        coords = { x = 0, y = 0, z = 0 },
        animation = -1,
        moving = false,
        inCombat = false
    }

    -- initialize timestamps
    self.timestamp = {
        eat = 0,
        drink = 0,
        buff = 0,
        excal = 0,
        shard = 0,
        tele = 0
    }

    self.inventory = {
        food = {},
        prayer = {}
    }

    self.buffs = {
        managed = {},
        toggle = {}
    }

    return self
end

--#endregion

--#region PlayerState methods

function PlayerManager.debugLog(message)
    if debug then
        API.logDebug("[PLAYER MANAGER]: "..message)
    end
end

---determines your location based on dynamic and static information
---@private
---@return string
function PlayerManager:_determineLocation()
    for _, loc in ipairs(self.config.locations) do
        ---@diagnostic disable-next-line
        if loc.coords and API.PInArea(loc.coords.x, loc.coords.range, loc.coords.y, loc.coords.range) then
            return loc.name
        end
        if loc.detector and loc.detector() then
            return loc.name
        end
    end
    return "UNKNOWN"
end

--- Checks if the player is idle
---@return boolean
function PlayerManager:isPlayerIdle()
    return self.state.animation == 0 and not self.state.moving
end

--- Checks if the player is in a certain area
---@return boolean
function PlayerManager:isPlayerAtLocation(coords)
    return API.PInArea(coords.x, coords.range, coords.y, coords.range, self.state.coords.z)
end

--- Determines the direction the prayer is facing
function PlayerManager:_determineOrientation()
    local orientation = math.floor(API.calculatePlayerOrientation()) % 360
    return orientation
end

--- Returns the cardinal direction the player is facing with 45° tolerance
---@return string
function PlayerManager:getFacingDirection()
    local deg = self.state.orientation % 360  -- Normalize to 0-359
    local directions = {
        {min=338, max=22, name="North"},
        {min=23, max=67, name="Northeast"},
        {min=68, max=112, name="East"},
        {min=113, max=157, name="Southeast"},
        {min=158, max=202, name="South"},
        {min=203, max=247, name="Southwest"},
        {min=248, max=292, name="West"},
        {min=293, max=337, name="Northwest"}
    }

    -- Special case for North (wraps around 0°)
    if deg >= 338 or deg <= 22 then
        return "North"
    end

    for _, dir in ipairs(directions) do
        if deg >= dir.min and deg <= dir.max then
            return dir.name
        end
    end

    return "North" -- Fallback (should never reach here)
end

---make stat
---@param current number
---@param max number
---@return Stat
function PlayerManager:_createStat(current, max)
    return {
        current = current,
        max = max,
        percent = max > 0 and math.floor((current / max) * 100) or 0
    }
end

--- Checks if the ability can be used from the Ability Bar
---@param ability_name string
---@return boolean
function PlayerManager:_canUseAbility(ability_name)
    return (#API.GetABs_names({ability_name}) > 0)
    and API.GetABs_names({ability_name})[1].enabled
    and (API.GetABs_names({ability_name})[1].cooldown_timer <= 1)
end

--- Uses ability from Ability Bar if it can be used.
---@param ability_name string
---@return boolean
function PlayerManager:_useAbility(ability_name)
    if PlayerManager:_canUseAbility(ability_name) then
        return API.DoAction_Ability(ability_name, 1, API.OFF_ACT_GeneralInterface_route, true)
    else return false end
end

--FIXME: add annotation and make sure its in managerprayer
--- Teleports to War's Retreat
function PlayerManager:_teleportToWars()
    local currentTick = API.Get_tick()
    if self.timestamp.tele - currentTick < 10 then
        if self:_useAbility("War's Retreat Teleport") then
            self.debugLog(string.format("Out of food or prayer items (%s | %s%%), teleporting out!", self.state.health.current, self.state.health.percent))
            self.timestamp.tele = currentTick
        end
    end
end

--- Updates values in the PlayerState instance
---@private
function PlayerManager:_updatePlayerState()
    -- health
    local maxHp, hp = API.GetHPMax_() or 0, API.GetHP_() or 0
    self.state.health = self:_createStat(hp, maxHp)

    -- prayer
    local maxPrayer, prayer = API.GetPrayMax_() or 0, API.GetPray_() or 0
    self.state.prayer = self:_createStat(prayer, maxPrayer)

    -- adrenaline
    local adrenData = API.VB_FindPSettinOrder(679) -- adrenaline vb
    self.state.adrenaline = adrenData and adrenData.state / 10 or 0

    -- position & movement
    self.state.coords = {x = API.PlayerCoord().x, y = API.PlayerCoord().y, z = API.PlayerRegion().z}
    self.state.location = self:_determineLocation()
    self.state.orientation = self:_determineOrientation()
    self.state.animation = API.ReadPlayerAnim() or -1
    self.state.moving = API.ReadPlayerMovin2() or false
    self.state.inCombat = API.GetInCombBit() or false
end
--#endregion

--#region player management methods

--#region player management helper functions

---scans inventory and categorizes health and prayer items
function PlayerManager:_scanInventoryCategory()
    -- first match wins
    local categories, rawFoods, rawPrayers = {
        {
            name = "prayer",
            patterns = {
                "Prayer", "Super restore", "Sanfew",
                "Super prayer", "Spiritual prayer", "Extreme prayer",
                "Blessed flask"
            }
        },
        {
            name = "potion",
            patterns = {
                "Guthix rest", "Super Guthix brew", "Saradomin brew"
            }
        },
        {
            name = "jellyfish",
            patterns = {
                "Blue blubber jellyfish", "2/3 blue blubber jellyfish", "1/3 blue blubber jellyfish",
                "Green blubber jellyfish", "2/3 green blubber jellyfish", "1/3 green blubber jellyfish"
            }
        },
        {
            name = "food",
            patterns = {
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
        }
    }, {}, {}

    for _, item in ipairs(API.ReadInvArrays33()) do
        if item.itemid1 == -1 or item.itemid1_size ~= 1 then goto continue end

        local cleanName = item.textitem:gsub("<col=f8d56b>", "")
        local matchedType = nil

        for _, category in ipairs(categories) do
            for _, pattern in ipairs(category.patterns) do
                if cleanName:find(pattern) then
                    matchedType = category.name
                    goto match_found
                end
            end
        end
        ::match_found::

        if matchedType then
            local entry = {
                name = cleanName,
                id = item.itemid1,
                type = matchedType,
                count = 1
            }

            if matchedType == "prayer" then
                table.insert(rawPrayers, entry)
            else
                table.insert(rawFoods, entry)
            end
        end

        ::continue::
    end

    -- merge duplicates and update inventory
    self.inventory.food = self:_mergeDuplicates(rawFoods)
    self.inventory.prayer = self:_mergeDuplicates(rawPrayers)
end

---merges duplicate inventory entries
---@param items PMInventoryItem[]
---@return PMInventoryItem[]
function PlayerManager:_mergeDuplicates(items)
    local merged, seen = {}, {}

    for _, item in ipairs(items) do
        local key = item.id .. ":" .. item.name
        if seen[key] then
            seen[key].count = seen[key].count + 1
        else
            seen[key] = {
                name = item.name,
                id = item.id,
                type = item.type,
                count = 1
            }
            table.insert(merged, seen[key])
        end
    end

    return merged
end

---get the number of edible items in your inventory
---@private
---@param table PMInventoryItem[]
---@return number
function PlayerManager:_getItemCount(table)
    local itemCount = 0
    for _, item in pairs(table) do
        itemCount = itemCount + item.count
    end
    return itemCount
end

---retrieves specific type of foodstuffs
---@private
---@param type string
---@return PMInventoryItem[]
function PlayerManager:_filterFoodItems(type)
    local filteredFoodItems = {}
    for _, item in ipairs(self.inventory.food) do
        if item.type == type then
            table.insert(filteredFoodItems, item)
        end
    end
    return filteredFoodItems
end

---@private
---@param resource "health" | "prayer"
---@param thresholdType "normal" | "critical" | "special"
---@return boolean
function PlayerManager:_checkThreshold(resource, thresholdType)
    local stat = self.state[resource]
    local threshold = self.config[resource][thresholdType]

    local compareValue = threshold.type == "percent"
        and stat.percent
        or stat.current

    return compareValue <= threshold.value
end

---checks if the player has a specific buff
---@param buffId number
---@return {found: boolean, remaining: number}
function PlayerManager:getBuff(buffId)
    local buff = API.Buffbar_GetIDstatus(buffId, false)
    return { found = buff.found, remaining = (buff.found and API.Bbar_ConvToSeconds(buff)) or 0 }
end

---checks if the player has a specific debuff
---@param debuffId number
---@return Bbar
function PlayerManager:getDebuff(debuffId)
    local debuff = API.DeBuffbar_GetIDstatus(debuffId, false)
    return { found = debuff.found or false, remaining = (debuff.found and API.Bbar_ConvToSeconds(debuff)) or 0 }
end

--#endregion

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
        if API.InvItemFound1(id) then -- check inventory
            return { location = "inventory", id = id }
        end
        if API.GetEquipSlot(5).itemid1 == id then -- check offhand
            return { location = "equipped", id = id }
        end
    end

    return false
end

---uses enchanced excalibur after checking if it exists
---@return boolean
function PlayerManager:useExcalibur()
    --do the excal check
    local excalibur = self:_hasExcalibur()
    if not excalibur or self:getDebuff(14632).found then return false end
    if API.Get_tick() - self.timestamp.excal < BUFF_INTERVAL_CHECK then return false end

    if excalibur.location == "inventory" then
        if API.DoAction_Inventory1(excalibur.id, 0, 1, API.OFF_ACT_GeneralInterface_route) then -- default behavior
            self.timestamp.excal = API.Get_tick()
        end
    elseif excalibur.location == "equipped" then
        ---@diagnostic disable-next-line
        if API.DoAction_Interface(0xffffffff, 0x8f0b, 2, 1464, 15, 5, API.OFF_ACT_GeneralInterface_route) then -- default behavior
            self.timestamp.excal = API.Get_tick()
        end
    end

    return false
end

---eats first type of food found returns true if action taken
---@param type string
---@return boolean
function PlayerManager:_eat(type)
    local item = self:_filterFoodItems(type)[1]
    if API.DoAction_Inventory1(item.id, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        API.RandomSleep2(60, 10, 20)
        return true
    else
        return false
    end
end

---eats all food in one tick
---@param critical boolean if true will eat food and drain some adren
function PlayerManager:oneTickEat(critical)
    local currentTick = API.Get_tick()
    --first check last drink and eat tick?
    if currentTick - self.timestamp.eat < BUFF_INTERVAL_CHECK then return end
    self.debugLog(string.format("Health is low (%s | %s%%), attempting to eat", self.state.health.current, self.state.health.percent))

    if critical then
        if #self:_filterFoodItems("food") > 0 then
            if self:_eat("food") then
                self.timestamp.eat = currentTick
                API.RandomSleep2(60, 10, 20)
            end
        end
    end
    if #self:_filterFoodItems("jellyfish") > 0 then
        if self:_eat("jellyfish") then
            self.timestamp.eat = currentTick
            API.RandomSleep2(60, 10, 20)
        end
    end
    if currentTick - 1 <= self.timestamp.drink then return false end
    if #self:_filterFoodItems("potion") > 0 then
        if self:_eat("potion") then
            self.timestamp.drink = currentTick
            API.RandomSleep2(60, 10, 20)
        end
    end
end

---manages player health
function PlayerManager:manageHealth()
    -- check thresholds
    local normalThreshold = self:_checkThreshold("health", "normal")
    local criticalThreshold = self:_checkThreshold("health", "critical")
    local specialThreshold = self:_checkThreshold("health", "special")

    -- do stuff
    if specialThreshold then self:useExcalibur() end
    if normalThreshold and #self.inventory.food > 0 then
        self:oneTickEat(criticalThreshold)
        return
    end
    
    if criticalThreshold and #self.inventory.food == 0 then
        
        self:_teleportToWars()
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
    --do shard check
    if not self:_hasElvenShard() or self:getDebuff(43358).found then return end
    if API.Get_tick() - self.timestamp.shard < BUFF_INTERVAL_CHECK then return end

    if API.DoAction_Inventory1(43358, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        self.timestamp.shard = API.Get_tick()
        return true
    else
        return false
    end
end

---consumes first prayer item found & returns true if action taken
---@return boolean
---@param potionId? number
function PlayerManager:drink(potionId)
    if API.Get_tick() - self.timestamp.drink < BUFF_INTERVAL_CHECK then return false end

    local itemId = potionId or self.inventory.prayer[1].id
    if not API.CheckInvStuff2(itemId) then return false end

    if API.DoAction_Inventory1(itemId, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        self.timestamp.drink = API.Get_tick()
        API.RandomSleep2(60, 10, 20)
        return true
    else
        return false
    end
end

---manages player prayer
function PlayerManager:managePrayer()
    -- check thresholds
    local normalThreshold = self:_checkThreshold("prayer", "normal")
    local criticalThreshold = self:_checkThreshold("prayer", "critical")
    local specialThreshold = self:_checkThreshold("prayer", "special")

    -- do stuff
    if specialThreshold then self:useElvenShard() end
    if normalThreshold and #self.inventory.prayer > 0 then
        self:drink()
        return
    end

    if criticalThreshold and #self.inventory.prayer < 0 then
        PlayerManager:_teleportToWars()
    end
end

--#endregion

--#region buff management

---manages listed buffs
---@param buffs table
function PlayerManager:manageBuffs(buffs)
    local currentTick = API.Get_tick()
    local managedBuffs, toggleBuffs = {}, {}
    local canExecute = (currentTick - self.timestamp.buff) >= BUFF_INTERVAL_CHECK

    for _, buff in pairs(buffs) do
        local allowApply = true
        if buff.canApply ~= nil then
            if type(buff.canApply) == "function" then
                allowApply = buff.canApply(self)
            elseif type(buff.canApply) == "boolean" then
                allowApply = buff.canApply
            end
        end

        local activeBuff = self:getBuff(buff.buffId)
        buff.refreshAt = buff.refreshAt or 0

        if activeBuff.found and (activeBuff.remaining >= buff.refreshAt) then
            local managedBuff = {
                buffName = buff.buffName,
                buffId = buff.buffId,
                remaining = activeBuff.remaining,
                execute = buff.execute,
                canApply = buff.canApply
            }
            table.insert(managedBuffs, managedBuff)
            if buff.toggle then
                table.insert(toggleBuffs, managedBuff)
            end
        else
            if canExecute and allowApply then
                if buff.execute() then
                    self.timestamp.buff = currentTick
                    canExecute = false
                end
            end
        end
    end

    self.buffs.toggle = toggleBuffs
    self.buffs.managed = managedBuffs
end

function PlayerManager:_untoggleBuffs()
    local currentTick = API.Get_tick()
    local canExecute = (currentTick - self.timestamp.buff) >= BUFF_INTERVAL_CHECK

    for i, toggleBuff in ipairs(self.buffs.toggle) do
        local managed = false
        for _, managedBuff in ipairs(self.buffs.managed) do
            if managedBuff.buffId == toggleBuff.buffId then
                managed = true
                break
            end
        end

        local activeBuff = self:getBuff(toggleBuff.buffId)
        local active = activeBuff.found and (toggleBuff.buffName ~= "Scripture of Ful" or activeBuff.remaining > 15)

        if managed then goto continue end
        if active then
            if canExecute then
                if toggleBuff.execute() then
                    self.timestamp.buff = currentTick
                    canExecute = false
                end
            end
        end
        ::continue::
        if not active then
            table.remove(self.buffs.toggle, i)
        end
    end
end

---@param buff Bbar
function PlayerManager:_getBuffName(buff)
    for _, managedBuff in pairs(self.buffs.managed) do
        if buff.id == managedBuff.buffId then
            return managedBuff.buffName
        end
    end
    return "UNKNOWN"
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
        { "- Adrenaline",  self.state.adrenaline },
        -- location
        { "- Location",    self.state.location },
        { "- Direction",   self:getFacingDirection().. " ("..self.state.orientation .. "°)"},
        { "- Coordinates", string.format("(%s, %s, %s)",
            self.state.coords.x,
            self.state.coords.y,
            self.state.coords.z) },
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
        { "- Items: ",                  "" },
        { "-- Has Excalibur?",          self:_hasExcalibur() and "Yes" or "No" },
        { "-- Has Elven ritual shard?", self:_hasElvenShard() and "Yes" or "No" },
        { "-- Edible food count:",      self:_getItemCount(self.inventory.food) },
        { "-- Prayer items count:",     self:_getItemCount(self.inventory.prayer) }
    }
    return metrics
end

---@return table
function PlayerManager:foodItemsTracking()
    local metrics = { { "- Food Items:", "" } }

    if #self.inventory.food < 1 then
        table.insert(metrics, { "-- No foods found", "" })
    else
        for _, i in ipairs(self.inventory.food) do
            table.insert(metrics, { "-- " .. i.count .. "x " .. i.type, i.name })
        end
    end
    return metrics
end

---@return table
function PlayerManager:prayerItemsTracking()
    local metrics = { { "- Prayer Items:", "" } }

    if #self.inventory.prayer < 1 then
        table.insert(metrics, { "-- No prayer items found", "" })
    else
        for _, i in ipairs(self.inventory.prayer) do
            table.insert(metrics, { "-- " .. i.count .. "x " .. i.type, i.name })
        end
    end
    return metrics
end

---@return table
function PlayerManager:managedBuffsTracking()
    local metrics = { { "- Managed Buffs:", "" } }

    if #self.buffs.managed < 1 then
        table.insert(metrics, { "-- No buffs found", "" })
    else
        for _, i in pairs(self.buffs.managed) do
            table.insert(metrics, { "-- " .. i.buffId .. ": " .. i.buffName, "Remaining: " .. i.remaining })
        end
    end
    return metrics
end

---@return table
function PlayerManager:activeBuffsTracking()
    local metrics = { { "- Active Buffs:", "" } }
    local activeBuffs = API.Buffbar_GetAllIDs(false)

    if #activeBuffs < 1 then
        table.insert(metrics, { "-- No buffs found", "" })
    else
        for _, i in pairs(activeBuffs) do
            table.insert(metrics,
                { "-- " .. i.id .. ": " .. self:_getBuffName(i), "Text (conv): " .. i.text .. " (" .. i.conv_text .. ")" })
        end
    end
    return metrics
end
--#endregion

---updates the player state
function PlayerManager:update()
    self:_untoggleBuffs()
    self.buffs.managed = {}
    self:_updatePlayerState()     -- refresh player data
    self:_scanInventoryCategory() -- get the inventory items
end

return PlayerManager
