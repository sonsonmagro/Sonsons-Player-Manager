# Sonson's Player Manager
## Overview
Sonson's Player Manager is an advanced Lua script designed to comprehensively track, manage, and optimize a player's in-game state. Beyond simple tracking, this script provides intelligent health management, dynamic location detection, and extensive player state monitoring.

## Features
### Health Management
- Automatic health monitoring and recovery
- Configurable health thresholds with multiple detection modes
  - Percentage-based or absolute value thresholds
- Advanced one-tick eating strategies
- Intelligent healing item usage
  - Automatic detection and prioritization of:
    - Jellies
    - Potions (Sara brew, Guthix rest)
    - Food items
- Enhanced Excalibur usage management
  - Automatic detection in inventory or equipped
  - Conditional usage based on health thresholds

### Dynamic Location Tracking
- Support for both static and dynamic location detection
- Flexible location identification methods
- Easy addition of custom location rules
- Precise coordinate-based and function-based detection
- Automatic location determination during gameplay

### Comprehensive Player State Tracking
- Detailed health monitoring
  - Current and maximum health points
  - Health percentage calculation
- Prayer point tracking
  - Current and maximum prayer points
  - Prayer percentage calculation
- Advanced state information
  - Adrenaline level tracking
  - Player movement status detection
  - Combat state monitoring
  - Current animation recording
  - Precise coordinate logging

### Advanced Inventory Management
- Automatic food and potion sorting
- Intelligent item detection and usage
- Tracking of specific utility items
  - Enhanced Excalibur
  - Elven Ritual Shard
- Comprehensive food inventory categorization
  - Potions
  - Jellies
  - Consumable foods

### Flexible Configuration
- Highly customizable health management
- Configurable thresholds for:
  - Health recovery
  - Critical health levels
  - Enhanced Excalibur usage
- Override options for management systems
- Customizable management strategies

## Tracking Capabilities
- `stateTracking()`: Comprehensive player state metrics
- `managementTracking()`: Detailed player management data
- `foodStuffsTracking()`: Granular food inventory tracking

## Usage
### Installation
Save `player_manager.lua` in your `Lua_Scripts` folder.

### Import and Configuration
```lua
local PlayerManager = require("player_state")

-- Define configuration
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
                name = "Rasial Instance",
                detectionFn = function()
                    -- Custom detection logic
                    return isInBossRoom()
                end
            }
        }
    },
    thresholds = {
        healthThreshold = {
            valueType = "percent",
            value = 50,           -- Trigger at 50% health
            criticalValueType = "percent",
            criticalValue = 25,   -- Critical threshold at 25%
            excalThresholdType = "percent",
            excalThreshold = 75   -- Use Excalibur at 75% health
        }
    },
    overrideHealthManagement = false  -- Optional override
}

-- Create PlayerManager instance
local playerManager = PlayerManager.new(config)
```

### Continuous Monitoring
```lua
while API.Read_LoopyLoop() do
    -- Update player state
    playerManager:update()

    -- Optional: Retrieve tracking metrics
    local stateMetrics = playerManager:stateTracking()
    local managementMetrics = playerManager:managementTracking()
    local foodMetrics = playerManager:foodStuffsTracking()

    -- Custom processing or display
    API.DrawTable(stateMetrics)
    
    API.RandomSleep2(100, 30, 20)
end
```

## Configuration Tips
- Use percentage or absolute value thresholds
- Create dynamic location detection functions
- Call `update()` consistently for real-time state management
- Leverage tracking methods for comprehensive insights

## Upcoming Features
- Prayer Management System
- Buff Tracking and Management
- Summoning Interaction Mechanics

## Changelog
### v1.1.0
- **Health Management Overhaul**
  - Implemented automatic health recovery system
  - Added configurable health thresholds
  - Developed one-tick eating strategies
  - Integrated automatic healing item usage
  - Enhanced Excalibur detection and management

- **Location Tracking Improvements**
  - Added methods for dynamic and static location management
  - Refined location detection logic

- **New Tracking Methods**
  - Introduced `stateTracking()` for comprehensive metrics
  - Added `managementTracking()` for management insights
  - Created `foodStuffsTracking()` for detailed food inventory analysis

- **Configuration Enhancements**
  - Expanded configuration flexibility
  - Added override capabilities for health, prayer, and management systems

### v1.0.0
- Initial release of Sonson's Player State
