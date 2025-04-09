# [v1.2.4] Sonson's Player Manager

A comprehensive player state and management utility providing advanced player state tracking, health, prayer and buff management, location detection and status handling.

## Features

- **Dynamic State Tracking**
  - Real-time player health, prayer, location and status monitoring
  - Detailed state and inventory tracking

- **Flexible Configuration**
  - Configurable health and prayer thresholds
  - Static and dynamic location detection
  - Status handling definition for simpler handling

- **Health & Prayer Management**
  - Automatic detection of food and potions in player inventory
  - Eats and drinks depending on configuration thresholds
  - [Enhanced Excalibur](https://runescape.wiki/w/Enhanced_Excalibur) and [Ancient elven ritual shard](https://runescape.wiki/w/Ancient_elven_ritual_shard) usage detection
 
- **Buff Management**
  - Automatically apply buffs based on customizable conditions
  - Toggles buffs off when no longer being managed
  - Track active buffs and their remaining duration
  
## Installation

Save `player_manager.lua` in your `Lua_Scripts` folder

## Usage

### Basic Initialization

```lua
local PlayerManager = require("player_manager")

-- Create a basic configuration
local config = {
    health = {
        normal = { type = "percent", value = 50 },
        critical = { type = "current", value = 2000 },
        special = { type = "percent", value = 65 } -- excalibur threshold
    },
    prayer = {
        normal = { type = "percent", value = 20 },
        critical = { type = "current", value = 100 },
        special = { type = "current", value = 600 } -- elven ritual shard threshold
    },
    locations = {
        { name = "Static location", coords = { x = 123, y = 456, range = 0 } },
        { name = "Dynamic location", detector = function() return customDetectionFunction() end }
    },
    statuses = {
        {
            name = "Doing specific thing",
            condition = function(self) return self.state.location == "Static Location" end,
            execute = function() doSpecificActions() end, -- what to do if these conditions are met
            priority = 1 -- highest priority wins
        },
        -- add more statuses as need be
    }
}

local playerManager = PlayerManager.new(config)
```

### Initialize Buffs

```lua
buffs = {
    {
        buffName = "Overload",
        buffId = 23725,
        refreshAt = 30, -- seconds remaining before refresh
        execute = function() 
            return API.DoAction_Inventory1(23725, 0, 1, API.OFF_ACT_GeneralInterface_route) 
        end,
        canApply = function(self) 
            return self.state.inCombat 
        end
    },
    {
        buffName = "Scripture of Ful",
        buffId = 48242,
        toggle = true, -- can be toggled off
        execute = function()
            return API.DoAction_Inventory1(48242, 0, 1, API.OFF_ACT_GeneralInterface_route)
        end
    }
}
```
#### Buff Configuration Attributes

| Attribute | Required | Type | Description |
|-----------|:--------:|:----:|-------------|
| `buffName` | Yes | `string` | The name of your buff. Used for using the appropriate ability or inventory item |
| `buffId` | Yes | `number` | Used to check against active player buffs |
| `execute` | Yes | `function` | Function called to apply the buff |
| `canApply` | No | `boolean` or `function` | Used to determine if the buff needs to be activated. Can be a static boolean or a function that returns a boolean |
| `toggle` | No | `boolean` | Boolean value that determines whether or not this buff should be re-activated to toggle off |
| `refreshAt` | No | `number` | Remaining time on buff before it should be reapplied |


### Advanced Usage

#### Continuous Monitoring

```lua
while API.Read_LoopyLoop() do
    -- Update player state and perform automatic management
    playerManager:update()
    
    -- Retrieve and process tracking metrics
    local stateMetrics = playerManager:stateTracking()
    local managedBuffs = playerManager:managedBuffsTracking()
    local activeBuffs = playerManager:activeBuffsTracking()
    local managementMetrics = playerManager:managementTracking()
    local foodMetrics = playerManager:foodStuffsTracking()
    local prayerMetrics = playerManager:prayerStuffsTracking()
    
    -- Custom processing or display
    API.DrawTable(stateMetrics)
    
    API.RandomSleep2(100, 30, 20)
end
```

**State Metrics Example**
| Player State |  |
|-----------|---------------|
| - Health | 9900/9900 (100%) |
| - Prayer | 420/990 (41%) |
| - Adrenaline | 69.0 |
| - Status | Loading last preset |
| - Location | War's Retreat |
| - Orientation | 315 |
| - Coordinates | (123, 456, 789) |
| - Animation | Idle |
| - Moving? | Yes |
| - In Combat? | No |

#### Manual Calls

```lua
-- Manually check buffs and debuffs from your main script
local buff   = playerManager:getBuff(BUFF_ID)
local debuff = playerManager:getDebuff(DEBUFF_ID)

-- Manually use Enhanced Excalibur and Elven Ritual Shard 
playerManager:useExcalibur()     -- automatically checks if in inventory or equipped
playerManager:useElvenShard()    -- also checks for debuff before attempting to use

-- Add custom locations dynamically (static and dynamic locations!)
playerManager:addStaticLocation({name = "Custom Area", coords = { x = 1234, y = 5678, range = 50 }})
playerManager:addDynamicLocation({name = "Boss Area", detectionFn = function() return interfaceExists(bossTimerInterface) end})

-- Eat food and restore prayer [no need to define what to eat or drink!]
playerManager:oneTickEat(playerHealth < 1000)  -- argument is for eating food that would drain adren
playerManager:drink()                          -- drinks first available prayer restoring item
```

## Configuration Options

### Threshold Types

- `type`: Define thresholds as `"percent"` or `"current"`
- Supports flexible configuration for health, prayer, and special item usage
- Config example for health and prayer:
   ```lua
  Config.health = {
      normal = { type = "percent", value = 50 },
      critical = { type = "current", value = 2000 },
      special = { type = "percent", value = 65 } -- excalibur threshold
  }
  
  Config.prayer = {
      normal = { type = "percent", value = 20 },
      critical = { type = "current", value = 100 },
      special = { type = "current", value = 600 } -- elven ritual shard threshold
  }
  ```
   
### Location Detection

- Detects the player's location based on the provided conditions
- Locations can be dynamic or static based on how they're defined
  ```lua
  Config.locations = {
      { name = "Static Location", coords = { x = 123, y = 456, range = 20 } },
      { name = "Dynamic Location", detector = function() return customDetectionFunction() end }
  }
  ```
  
## Changelog

### v1.2.4: Removed status handling, added more methods
* **[REMOVED] Status Handler**
    - This has been removed in favor of delegating status handling to timers
* **[NEW] Added new methods**
    - `PlayerManager:isPlayerIdle()`
    - `PlayerManager:isPlayerAtLocation(coords)`
    - `PlayerManager:getFacingDirection()`
* **[FXED] War's Retreat Teleport now working as intended**

### v1.2.0: Simplified Config, Added Buff Manager and State Handler
* **[NEW]: Buff Management**
  - `playerManager:manageBuffs(buffs)` to manage the buffs you need managed
  - Supports different kinds of buffs
    - Inventory items like potions and incense
    - Abilities like prayers and pocket items
      - If defined with `toggle = true` will be toggled off if no longer being managed
- **[NEW]: Status Handler**
  - Initial implementation of built-in status handler
  - Handles actions for different statuses
  - Statuses are defined with new instance of player manager
- **[UPDATED]: Health & Prayer Management**
  ```diff
  - Config.healthOverride
  - Config.prayerOverride
  Removed in favor of users directly overriding the player manager instance
  ```
    - Config setup was changed to be simpler
      ```lua
      Config.health = {
          normal = { type = "percent", value = 50 },
          critical = { type = "current", value = 2000 },
          special = { type = "percent", value = 65 } -- excalibur threshold
      }
      
      Config.prayer = {
          normal = { type = "percent", value = 20 },
          critical = { type = "current", value = 100 },
          special = { type = "current", value = 600 } -- elven ritual shard threshold
      }
      ```
    - `playerManager:manageHealth()` and `playerManager:managePrayer` are now no longer integrated in main update method
      - To be called when needed by the user.
- **[UPDATED]: Locations Configuration and System**
  ```diff
  - Config.locations.staticLocations
  - Config.locations.dynamicLocations
  Removed in favor of all-inclusive Config.locations
  
  - playerManager:addStaticLocation()
  - playerManager:addDynamicLocation()
  Removed in favor of users directly overriding the player manager instance
  ```
  - New locations config
    ```lua
    Config.playerManager = {
        locations = {
            {
                name   = "War's Retreat",
                coords = { x = 3295, y = 10137, range = 30 }
            },
            {
                name = "Rasial's Citadel (Lobby)",
                coords = { x = 864, y = 1742, range = 12 }
            },
            {
                name = "Rasial's Citadel (Boss Room)",
                detector = function() -- checks to see if instance timer exists
                    local timer = {
                        { 861, 0, -1, -1, 0 }, { 861, 2, -1, 0, 0 },
                        { 861, 4, -1, 2,  0 }, { 861, 8, -1, 4, 0 }
                    }
                    local result = API.ScanForInterfaceTest2Get(false, timer)
                    return result and #result > 0 and #result[1].textids > 0
                end
            },
            {
                name = "Death's Office",
                detector = function() return #Utils.findAll(27299, 1, 30) > 1 end
            },
        }
    }
    ```
  
### v1.1.1
* **[NEW] Prayer Management**
   * Added Elven Ritual Shard detection and usage
   * Implemented comprehensive prayer item tracking
   * Developed configurable prayer management thresholds
   * Enhanced prayer potion consumption strategies
   * Added `prayerStuffsTracking()` method for detailed prayer inventory analysis
* **Added More Failsafes**

### v1.1.0
* **[NEW] Health Management**
   * Implemented automatic health recovery system
   * Added configurable health thresholds
   * Developed one-tick eating strategies
   * Integrated automatic healing item usage
   * Enhanced Excalibur detection and management
* **[UPDATED] Location Tracking Improvements**
   * Refined location detection logic
* **[NEW] Tracking Methods**
   * `playerManager:stateTracking()` for comprehensive metrics
   * `playerManager:managementTracking()` for management insights
   * `playerManager:foodStuffsTracking()` for detailed food inventory analysis
   * Added methods for dynamic and static location management
* **[UPDATED] Configuration Enhancements**
   * Expanded configuration flexibility
   * Added override capabilities for health, prayer, and management systems

### v1.0.0
* Initial release of Sonson's Player State
