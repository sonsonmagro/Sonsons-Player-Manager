# Sonson's Player State

## Overview
Sonson's Player State is a Lua script designed to track and manage a player's state in-game. It provides a comprehensive way to monitor various player attributes, including health, prayer, location, combat status, and more.


## Features
- **Health Tracking**
  - Monitor current and maximum health points
  - Calculate health percentage
- **Prayer Management**
  - Track current and maximum prayer points
  - Calculate prayer percentage
- **Location Detection**
  - Support for static and dynamic location tracking
  - Flexible location identification methods
- **Additional State Information**
  - Track player movement status
  - Monitor combat state
  - Record current animation
  - Log player coordinates
- **Metrics Reporting**
  - Generate detailed player state metrics
  - Easy-to-use tracking method

## Changelog
### v1.0.0
- Initial release of Sonson's Player State
- Core player state tracking mechanics
- Support for static and dynamic location detection
- Comprehensive metrics generation

## Usage
### Save File
Make sure to save `player_state.lua` in your `Lua_Scripts` folder.

### Import the Class
```lua
local PlayerState = require("player_state")
```

### Configuration Details
#### A. Static Locations
Define fixed locations with coordinates and detection range:
```lua
local staticLocations = {
    {
        name = "War's Retreat",
        coords = {
            x = 3295,      -- X coordinate
            y = 10137,      -- Y coordinate
            range = 30     -- Detection range
        }
    },
    {
        name = "Rasial Lobby",
        coords = {
            x = 864,
            y = 1742,
            range = 12
        }
    }
}
```

#### B. Dynamic Locations
Create custom location detection methods:
```lua
local dynamicLocations = {
    {
        name = "Rasial Instance",
        detectionFn = function()
            -- function that determines if you're in the boss encounter based on location of gate
            return isInBossRoom(gateTile) 
        end
    }
}
```

### Create PlayerState Instance
```lua
local config = {
    staticLocations = staticLocations,
    dynamicLocations = dynamicLocations
}

local playerState = PlayerState.new(config)
```

### Update and Track Player State
```lua
while API.Read_LoopyLoop() do
    -- update player state
    playerState:update()

    -- draw metrics
    local metrics = playerState:tracking()
    API.DrawTable(metrics)

    API.RandomSleep2(100, 30, 20)
end
```

## Configuration Tips
- `staticLocations`: Provide accurate coordinates for area detection
- `dynamicLocations`: Create flexible detection functions
- Call `update()` regularly to keep player state current
- Use `tracking()` to get a comprehensive snapshot of player status
