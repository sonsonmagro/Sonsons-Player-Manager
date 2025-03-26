---@version 1.0.0
--[[
    File: player_state.lua
    Description: Used to keep track of your player's state from one dynamic instance
    Author: Sonson

    Changelog:
    - v1.0.0:
        - Initial Release
]]
---@class PlayerState
---@field config PlayerStateConfig
---@field locationChecker LocationChecker
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
local PlayerState = {}
PlayerState.__index = PlayerState

--#region luaCATS annotation
---@class PlayerStateConfig
---@field staticLocations StaticLocation[]
---@field dynamicLocations DynamicLocation[]

---@class StaticLocation
---@field name string
---@field coords {x:number, y:number, range:number}

---@class DynamicLocation
---@field name string
---@field detectionFn fun(): boolean
--#endregion

local API = require("api")

---initialize a new PlayerState instance
---@param config PlayerStateConfig
---@return PlayerState
function PlayerState.new(config)
    local self = setmetatable({}, PlayerState)
    --config
    self.config = config or {
        staticLocations = {},
        dynamicLocations = {}
    }
    --stats
    self.health = {current = 0, max = 0, percent = 0}
    self.prayer = {current = 0, max = 0, percent = 0}
    self.adrenaline = 0
    --locations
    self.location = ""
    self.coords = {x = 0, y = 0, z = 0}
    --buffs
    --TODO: figure out something to do with buffs and debuffs or delegate it to new BuffManager class
    self.buffs = {}
    self.debuffs = {}
    --animations
    self.animation = -1
    self.moving = false
    self.inCombat = false

    return self
end

---determines your location based on dynamic and static information
---@private
---@return string
function PlayerState:_checkLocation()
    --check dynamic locations first
    if #self.config.dynamicLocations > 0 then
        for _, loc in pairs(self.config.dynamicLocations) do
            if loc.detectionFn() then
                return loc.name
            end
        end
    end
    --check static locations
    if #self.config.staticLocations > 0 then
        for _, loc in pairs(self.config.staticLocations) do
            ---@diagnostic disable-next-line
            if API.PInArea(loc.coords.x, loc.coords.range, loc.coords.y, loc.coords.range) then
                return loc.name
            end
        end
    end
    --default value
    return "UNKNOWN"
end

---updates values in the PlayerState instance
---@private
function PlayerState:_updatePlayerState()
    --health
    local maxHp = API.GetHPMax_() or 0
    local hp = API.GetHP_() or 0
    self.health = {current = hp, max = maxHp, percent = math.floor((hp / maxHp) * 100)}
    --prayers
    local maxPrayer = API.GetPrayMax_() or 0
    local prayer = API.GetPray_() or 0
    self.prayer = {current = prayer, max = maxPrayer, percent = math.floor((prayer / maxPrayer) * 100)}
    --adrenaline
    local adrenData = API.VB_FindPSettinOrder(679) -- adrenaline vb
    self.adrenaline = adrenData and adrenData.state / 10 or 0
    --location
    self.location = self:_checkLocation()
    self.coords = API.PlayerCoord()
    --animations
    self.animation = API.ReadPlayerAnim() or -1
    self.moving = API.ReadPlayerMovin2() or false
    self.inCombat = API.LocalPlayer_IsInCombat_() or false
end

---@return table
function PlayerState:tracking()
    ---@type table
    local metrics ={
        {"Player State:", ""},
        --stats
        {"- Health", self.health.current.."/"..self.health.max.." ("..self.health.percent.."%)"},
        {"- Prayer", self.prayer.current.."/"..self.prayer.max.." ("..self.prayer.percent.."%)"},
        {"- Adrenaline", self.adrenaline},
        --location
        {"- Coordinates", string.format("(X:%s, Y:%s, Z:%s)", self.coords.x, self.coords.y, self.coords.z)},
        {"- Location", self.location},
        --animations
        {"- Animation", self.animation == 0 and "Idle" or self.animation},
        {"- Moving?", self.moving and "Yes" or "No"},
        {"- In Combat?", self.inCombat and "Yes" or "No"},
    }
    return metrics
end

function PlayerState:update()
    self:_updatePlayerState()
end

return PlayerState
