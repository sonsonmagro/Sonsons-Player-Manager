# PlayerManager

A comprehensive player state and management utility providing advanced tracking, health management, and dynamic location detection.

## Features

- **Dynamic State Tracking**
  - Real-time player health, prayer, and location monitoring
  - Detailed state and inventory tracking
  - Automatic health and prayer management

- **Intelligent Item Management**
  - Automatic food and prayer potion consumption
  - One-tick eating strategies
  - Excalibur and Elven Shard usage detection

- **Flexible Configuration**
  - Configurable health and prayer thresholds
  - Static and dynamic location detection
  - Management system overrides

## Installation

Save `player_manager.lua` in your `Lua_Scripts` folder

## Usage

### Basic Initialization

```lua
local PlayerManager = require("player_manager")

-- Create a basic configuration
local config = {
    locations = {
        staticLocations = {
            {
                name = "War's Retreat",
                coords = { x = 3295, y = 10137, range = 30 }
            }
        },
        dynamicLocations = {
            {
                name = "Boss Instance",
                detectionFn = function()
                    return isInBossRoom(gateTile)  -- Custom detection logic
                end
            }
        }
    },
    thresholds = {
        healthThreshold = {
            valueType = "percent",
            value = 50,                     -- Trigger at 50% health
            criticalValueType = "current",
            criticalValue = 2000,           -- Critical threshold at 2,000 health
            excalThresholdType = "percent",
            excalThreshold = 75             -- Use Enhanced Excalibur at 75% health
        },
        prayerThreshold = {
            valueType = "percent",
            value = 30,                    -- Trigger prayer management at 30%
            criticalValueType = "current",
            criticalValue = 100,           -- Critical prayer threshold at 100 prayer points
            shardValueType = "percent",
            shardValue = 50                -- Use Elven Ritual Shard at 50% prayer
        }
    },
    overrideHealthManagement = false,
    overridePrayerManagement = false
}

local playerManager = PlayerManager.new(config)
```

### Advanced Usage

#### Continuous Monitoring

```lua
while API.Read_LoopyLoop() do
    -- Update player state and perform automatic management
    playerManager:update()
    
    -- Retrieve and process tracking metrics
    local stateMetrics = playerManager:stateTracking()
    local managementMetrics = playerManager:managementTracking()
    local foodMetrics = playerManager:foodStuffsTracking()
    local prayerMetrics = playerManager:prayerStuffsTracking()
    
    -- Custom processing or display
    API.DrawTable(stateMetrics)
    
    API.RandomSleep2(100, 30, 20)
end
```

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
playerManager:oneTickEat(playerHealth < 1000)  -- paramater is for eating food that would drain adren
playerManager:drink()                          -- drinks first available prayer restoring item
```

## Configuration Options

### Threshold Types

- `valueType`: Define thresholds as `"percent"` or `"current"`
- Supports flexible configuration for health, prayer, and special item usage

### Location Detection

- **Static Locations**: Define areas by coordinates and range
- **Dynamic Locations**: Use custom detection functions for complex scenarios

### Management Overrides

- `overrideHealthManagement`: Disable automatic health management
- `overridePrayerManagement`: Disable automatic prayer management
- Can be set as boolean or function for dynamic control

## Performance Considerations

- Call `update()` consistently for real-time state management
- Customize detection functions for efficiency
- Use tracking methods sparingly in performance-critical sections

## Changelog

### v1.1.1
* **Introduced Prayer Management**
   * Added Elven Ritual Shard detection and usage
   * Implemented comprehensive prayer item tracking
   * Developed configurable prayer management thresholds
   * Enhanced prayer potion consumption strategies
   * Added `prayerStuffsTracking()` method for detailed prayer inventory analysis
* **Added More Failsafes**

### v1.1.0
* **Health Management Overhaul**
   * Implemented automatic health recovery system
   * Added configurable health thresholds
   * Developed one-tick eating strategies
   * Integrated automatic healing item usage
   * Enhanced Excalibur detection and management
* **Location Tracking Improvements**
   * Added methods for dynamic and static location management
   * Refined location detection logic
* **New Tracking Methods**
   * Introduced `stateTracking()` for comprehensive metrics
   * Added `managementTracking()` for management insights
   * Created `foodStuffsTracking()` for detailed food inventory analysis
* **Configuration Enhancements**
   * Expanded configuration flexibility
   * Added override capabilities for health, prayer, and management systems

### v1.0.0
* Initial release of Sonson's Player State
```

## License

Developed by Sonson. See individual script for licensing details.
