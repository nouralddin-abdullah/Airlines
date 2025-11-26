--[[
    99 Night At Forest - Player Module (Initial Phase)
    This script currently ONLY initializes the UI and adds core player attribute controls.
    Scope (as requested):
      - GUI initialization with a single "Player" tab/section
      - Controls for player character attributes:
          * Speed (WalkSpeed)
          * Jump (JumpPower)
          * Noclip (disables collisions on the local character parts)
    No extra features beyond those listed are added in this phase.
]]

-- Load external UI library
local ApocLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/nouralddin-abdullah/Apoc/refs/heads/main/toasty.lua"))()

-- Services / core references (CACHED GLOBALLY FOR PERFORMANCE)
Players = game:GetService("Players")
RunService = game:GetService("RunService")
UserInputService = game:GetService("UserInputService")
ReplicatedStorage = game:GetService("ReplicatedStorage")
LocalPlayer = Players.LocalPlayer
Lighting = game:GetService("Lighting")

-- Cached remote events and workspace references (PERFORMANCE OPTIMIZATION)
RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
Workspace = workspace
WorkspaceItems = Workspace:WaitForChild("Items")
WorkspaceStructures = Workspace:WaitForChild("Structures")
WorkspaceMap = Workspace:WaitForChild("Map")

-- Global premium status (will be set to true after key validation)
isPremium = false

-- Global teleportation state control
local TeleportationControl = {
    IsBusy = false,
    CurrentItem = nil,
    StartTime = 0
}

-- Cultist transport control state
local CultistControl = {
    TransportEnabled = false,
    TeleportedCultists = {},
    LastTeleportTime = 0,
    TeleportCooldown = 1,
    Connection = nil
}

-- Night skip control state
-- World status controls grouped together to reduce scattered globals
local WorldStatusControl = {
    SmartNightSkip = {
        SkipEnabled = false,
        Connection = nil,
    },
    RespawnCapsule = {
        RechargeEnabled = false,
        Connection = nil,
    },
    StrongholdTimer = {
        TimerLabel = nil,
        UpdateConnection = nil,
        LastUpdateTime = 0,
    },
    DayNight = {
        StateLabel = nil,
        CountdownLabel = nil,
        DayCounterLabel = nil,
        CultistAttackLabel = nil,
        LastUpdateTime = 0,
    },
    AutoStun = {
        Deer = { Enabled = false, Running = false },
        Owl = { Enabled = false, Running = false },
        Ram = { Enabled = false, Running = false },
    },
}

-- Create main window
local Window = ApocLibrary:CreateWindow({
    Name = "ToastyXD Hub",
    Icon = 4483362458, -- Placeholder asset id (update if you have a custom icon)
    LoadingTitle = "99 Night Interface",
    LoadingSubtitle = "Loading script...",
    ShowText = "99NF",
    Theme = "Default",
    ToggleUIKeybind = 'K',
    DisableApocPrompts = true,
    DisableBuildWarnings = true,
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

-- Create Info tab (Important Information)
InfoTab = Window:CreateTab("Information", 4483362458)
InfoSection = InfoTab:CreateSection("Important Information")

-- Create Halloween tab
HalloweenTab = Window:CreateTab("Halloween", 4483362458)
HalloweenSection = HalloweenTab:CreateSection("Halloween Items")

-- Create Misc tab
MiscTab = Window:CreateTab("Misc", 4483362458)
MiscSection = MiscTab:CreateSection("Miscellaneous")

-- Single Player tab & section (as requested)
PlayerTab = Window:CreateTab("Player", 4483362458)
PlayerSection = PlayerTab:CreateSection("Player Settings")

-- Create Combat tab
CombatTab = Window:CreateTab("Combat", 4483362458)
CombatSection = CombatTab:CreateSection("Auto Attack")

-- Create Trees tab
TreesTab = Window:CreateTab("Trees", 4483362458)
TreesSection = TreesTab:CreateSection("Tree Cutting")

-- Create Meteors tab (placed next to Trees)
MeteorsTab = Window:CreateTab("Meteors", 4483362458)
MeteorsSection = MeteorsTab:CreateSection("Meteor Cutting")

-- Create Campfire tab
CampfireTab = Window:CreateTab("Campfire", 4483362458)
CampfireSection = CampfireTab:CreateSection("Auto Refill")

-- Create Crafting tab
CraftingTab = Window:CreateTab("Crafting", 4483362458)
CraftingSection = CraftingTab:CreateSection("Scrapper Machine")

-- Create Food tab
FoodTab = Window:CreateTab("Food", 4483362458)
FoodSection = FoodTab:CreateSection("Food Transport")

-- Create Animal Pelts tab
AnimalPeltsTab = Window:CreateTab("Animal Pelts", 4483362458)
AnimalPeltsSection = AnimalPeltsTab:CreateSection("Animal Pelts Transport")

-- Create Healing tab
HealingTab = Window:CreateTab("Healing", 4483362458)
HealingSection = HealingTab:CreateSection("Healing Items Transport")

-- Create Weapons & Ammo tab
AmmoTab = Window:CreateTab("Weapons & Ammo", 4483362458)
AmmoSection = AmmoTab:CreateSection("Weapons & Ammo Transport")

-- Create Chests tab
ChestsTab = Window:CreateTab("Chests", 4483362458)
ChestsSection = ChestsTab:CreateSection("Chest Finder")

-- Create Item Bring tab (Unified item transportation)
ItemBringTab = Window:CreateTab("Item Bring", 4483362458)
ItemBringSection = ItemBringTab:CreateSection("Unified Item Transportation")

do
    local itemsDeletorTab = Window:CreateTab("Items Delete", 4483362458)
    local _ = itemsDeletorTab:CreateSection("Workspace Cleanup")

    local dropdown
    local summaryParagraph
    local quantitySlider

    local state = {
        counts = {},
        selected = nil,
        desiredAmount = 0,
        refreshing = false,
    }

    local function gatherItemCounts()
        local results = {}
        local itemsFolder = WorkspaceItems or workspace:FindFirstChild("Items")
        if not itemsFolder then
            return results
        end

        for _, item in ipairs(itemsFolder:GetChildren()) do
            results[item.Name] = (results[item.Name] or 0) + 1
        end

        return results
    end

    local function updateSummary()
        local selectedName = state.selected
        local itemCount = (selectedName and state.counts[selectedName]) or 0

        if summaryParagraph then
            local labelName = selectedName or "No item selected"
            local content

            if selectedName then
                local plural = itemCount == 1 and "" or "s"
                content = string.format("%s: %d item%s currently in the workspace.", labelName, itemCount, plural)
            else
                content = "Select an item type to view how many copies are currently in the workspace."
            end

            summaryParagraph:Set({
                Title = "Item Count",
                Content = content
            })
        end

        if quantitySlider then
            local itemMax = math.max(itemCount, 1)
            quantitySlider.Range[1] = 0
            quantitySlider.Range[2] = itemMax

            local targetValue = state.desiredAmount or 0
            if itemCount == 0 then
                targetValue = 0
            else
                targetValue = math.clamp(math.floor(targetValue + 0.5), 1, itemCount)
            end

            state.desiredAmount = targetValue
            quantitySlider:Set(targetValue)
        end
    end

    local function refreshData(preserveSelection)
        local previousSelection = preserveSelection and state.selected or nil
        state.counts = gatherItemCounts()

        local options = {}
        for name in pairs(state.counts) do
            table.insert(options, name)
        end
        table.sort(options)

        if #options == 0 then
            options[1] = "None"
        end

        state.refreshing = true
        dropdown:Refresh(options)

        local newSelection = previousSelection
        if not newSelection or not state.counts[newSelection] then
            newSelection = nil
            for _, optionName in ipairs(options) do
                if state.counts[optionName] then
                    newSelection = optionName
                    break
                end
            end
        end

        if newSelection then
            state.selected = newSelection
            dropdown:Set(newSelection)
        else
            dropdown:Set("None")
            state.selected = nil
            state.desiredAmount = 0
        end

        state.refreshing = false

        updateSummary()
    end

    local function deleteItems(itemName, amount)
        local itemsFolder = WorkspaceItems or workspace:FindFirstChild("Items")
        if not itemsFolder then
            return 0
        end

        local removed = 0
        for _, item in ipairs(itemsFolder:GetChildren()) do
            if item.Name == itemName then
                local success = pcall(function()
                    item:Destroy()
                end)
                if success then
                    removed += 1
                end
                if removed >= amount then
                    break
                end
            end
        end

        return removed
    end

    dropdown = itemsDeletorTab:CreateDropdown({
        Name = "Item Type",
        Options = {"None"},
        CurrentOption = {"None"},
        Callback = function(options)
            if state.refreshing then
                return
            end

            local selection = options and options[1] or nil
            if selection and selection ~= "None" and state.counts[selection] then
                state.selected = selection
            else
                state.selected = nil
                state.desiredAmount = 0
            end

            updateSummary()
        end
    })

    itemsDeletorTab:CreateButton({
        Name = "🔄 Refresh Items",
        Callback = function()
            refreshData(true)
        end
    })

    summaryParagraph = itemsDeletorTab:CreateParagraph({
        Title = "Item Count",
        Content = "Select an item type to see how many copies exist."
    })

    quantitySlider = itemsDeletorTab:CreateSlider({
        Name = "Amount to Delete",
        Range = {0, 1},
        Increment = 1,
        Suffix = " items",
        CurrentValue = 0,
        Callback = function(value)
            state.desiredAmount = value
        end
    })

    itemsDeletorTab:CreateButton({
        Name = "🗑️ Delete Selected Items",
        Callback = function()
            if not state.selected then
                ApocLibrary:Notify({
                    Title = "Items Delete",
                    Content = "Choose an item type before deleting.",
                    Image = 4400697855
                })
                return
            end

            local available = state.counts[state.selected] or 0
            local amount = math.clamp(math.floor(state.desiredAmount or 0), 0, available)
            if amount <= 0 then
                ApocLibrary:Notify({
                    Title = "Items Delete",
                    Content = "Set the slider to the number of items you want to remove.",
                    Image = 4400697855
                })
                return
            end

            local removed = deleteItems(state.selected, amount)
            if removed > 0 then
                ApocLibrary:Notify({
                    Title = "Items Delete",
                    Content = string.format("Removed %d of %s.", removed, state.selected),
                    Image = 4483362748
                })
            else
                ApocLibrary:Notify({
                    Title = "Items Delete",
                    Content = "No matching items were removed.",
                    Image = 4400697855
                })
            end

            refreshData(true)
        end
    })

    refreshData(false)
end

-- Create ESP tab
ESPTab = Window:CreateTab("ESP", 4483362458)
ESPSection = ESPTab:CreateSection("Visual ESP")

-- Create Skybase tab
SkybaseTab = Window:CreateTab("Skybase", 4483362458)
SkybaseSection = SkybaseTab:CreateSection("Auto Survival")

-- Create Lost Children tab
LostChildrenTab = Window:CreateTab("Lost Children", 4483362458)
LostChildrenSection = LostChildrenTab:CreateSection("Child Rescue")

-- Create Troll tab
TrollTab = Window:CreateTab("Troll", 4483362458)
TrollSection = TrollTab:CreateSection("Chaos & Fun")

GUITap = Window:CreateTab("GUIS", 4483362458)
GUISection = GUITap:CreateSection("Independant GUI's Section")

-- Create Credits tab
CreditsTab = Window:CreateTab("Credits", 4483362458)
CreditsSection = CreditsTab:CreateSection("About Developer & Support")


-- English Translation Mappings for Display Names
DisplayTranslations = {
    -- Tree Types
    ["Every tree"] = "Every Tree",
    ["Small Tree"] = "Small Tree",
    ["Snowy Small Tree"] = "Snowy Small Tree",
    ["TreeBig1"] = "Large Tree Type 1",
    ["TreeBig2"] = "Large Tree Type 2", 
    ["TreeBig3"] = "Large Tree Type 3",
    ["All Meteor"] = "All Meteor Nodes",
    ["Meteor Node"] = "Meteor Node",
    ["Obsidiron Node"] = "Obsidiron Node",
    
    -- Refill Items
    ["All"] = "All Items",
    ["Log"] = "Log",
    ["Coal"] = "Coal",
    ["Biofuel"] = "Biofuel",
    ["Fuel Canister"] = "Fuel Canister",
    ["Oil Barrel"] = "Oil Barrel",

    -- Scrap Items
    ["Bolt"] = "Bolt",
    ["Sheet Metal"] = "Sheet Metal",
    ["Broken Fan"] = "Broken Fan",
    ["Old Radio"] = "Old Radio",
    ["Broken Microwave"] = "Broken Microwave",
    ["Tyre"] = "Tire",
    ["Metal Chair"] = "Metal Chair",
    ["Old Car Engine"] = "Old Car Engine",
    ["Washing Machine"] = "Washing Machine",
    ["Cultist Experiment"] = "Cultist Experiment",
    ["Cultist Prototype"] = "Cultist Prototype",
    ["UFO Scrap"] = "UFO Scrap",
    ["Meteor Shard"] = "Meteor Shard",
    ["Gold Shard"] = "Gold Shard",
    ["Obsidiron Ingot"] = "Obsidiron Ingot",
    
    -- Cultist Gem
    ["Cultist Gem"] = "Cultist Gem",
    
    -- Food Items
    ["All Food"] = "All Food",
    ["Cake"] = "Cake",
    ["Ribs"] = "Ribs",
    ["Steak"] = "Steak",
    ["Morsel"] = "Morsel",
    ["Carrot"] = "Carrot",
    ["Corn"] = "Corn",
    ["Pumpkin"] = "Pumpkin",
    ["Apple"] = "Apple",
    ["Chili"] = "Chili",
    ["Cooked Steak"] = "Cooked Steak",
    ["Cooked Morsel"] = "Cooked Morsel",
    ["Cooked Ribs"] = "Cooked Ribs",

    
    -- Animal Pelts
    ["Bunny Foot"] = "Bunny Foot",
    ["Wolf Pelt"] = "Wolf Pelt",
    ["Alpha Wolf Pelt"] = "Alpha Wolf Pelt",
    ["Bear Pelt"] = "Bear Pelt",
    ["Arctic Fox Pelt"] = "Arctic Fox Pelt",
    ["Polar Bear Pelt"] = "Polar Bear Pelt",
    ["Mammoth Tusk"] = "Mammoth Tusk",
    
    -- Healing Items
    ["All Healing"] = "All Healing Items",
    ["Bandage"] = "Bandage",
    ["MedKit"] = "MedKit",
    
    -- Ammo Items
    ["All Ammo"] = "All Ammo Types",
    ["Revolver Ammo"] = "Revolver Ammo",
    ["Rifle Ammo"] = "Rifle Ammo",
    ["Shotgun Ammo"] = "Shotgun Ammo",
    
    -- Weapon Items
    ["All Weapons"] = "All Weapon Types",
    ["All"] = "All",
    ["Old Axe"] = "Old Axe",
    ["Good Axe"] = "Good Axe", 
    ["Ice Axe"] = "Ice Axe",
    ["Strong Axe"] = "Strong Axe",
    ["Chainsaw"] = "Chainsaw",
    ["Spear"] = "Spear",
    ["Morningstar"] = "Morningstar",
    ["Katana"] = "Katana",
    ["Laser Sword"] = "Laser Sword",
    ["Ice Sword"] = "Ice Sword",
    ["Trident"] = "Trident",
    ["Poison Spear"] = "Poison Spear",
    ["Infernal Sword"] = "Infernal Sword",
    ["Scythe"] = "Scythe",
    ["Vampire Scythe"] = "Vampire Scythe",
    ["Cultist King Mace"] = "Cultist King Mace",
    ["Revolver"] = "Revolver",
    ["Rifle"] = "Rifle",
    ["Tactical Shotgun"] = "Tactical Shotgun",
    ["Shotgun"] = "Shotgun",
    ["Snowball"] = "Snowball",
    ["Frozen Shuriken"] = "Frozen Shuriken",
    ["Kunai"] = "Kunai",
    ["Ray Gun"] = "Ray Gun",
    ["Laser Cannon"] = "Laser Cannon",
    ["Flamethrower"] = "Flamethrower",
    ["Blowpipe"] = "Blowpipe",
    ["Crossbow"] = "Crossbow",
    ["Wildfire"] = "Wildfire",
    ["Infernal Crossbow"] = "Infernal Crossbow",
    ["Knife"] = "Knife",
    ["Dagger"] = "Dagger",
    
    -- Armor Items
    ["All Armor"] = "All Armor Types",
    ["Leather Body"] = "Leather Body Armor",
    ["Iron Body"] = "Iron Body Armor",
    ["Thorn Body"] = "Thorn Body Armor",
    ["Riot Shield"] = "Riot Shield",
    ["Alien Armor"] = "Alien Armor",
    ["Leather Helmet"] = "Leather Helmet",
    ["Iron Helmet"] = "Iron Helmet",
    ["Leather Pants"] = "Leather Pants",
    ["Iron Pants"] = "Iron Pants",
    ["Leather Shoes"] = "Leather Shoes",
    ["Iron Shoes"] = "Iron Shoes",
    
    -- Entities
    ["Cultist"] = "Cultist",
    ["Crossbow Cultist"] = "Crossbow Cultist",
    ["Juggernaut Cultist"] = "Juggernaut Cultist",
    ["Wolf"] = "Wolf",
    ["Alpha Wolf"] = "Alpha Wolf",
    ["Bear"] = "Bear",
    ["Polar Bear"] = "Polar Bear",
    ["The Deer"] = "The Deer",
    ["Alien"] = "Alien",
    ["Alien Elite"] = "Alien Elite",
    ["Arctic Fox"] = "Arctic Fox",
    ["Mammoth"] = "Mammoth",
    ["Bunny"] = "Bunny",
    ["Polar Bear"] = "Polar Bear",
    ["Hellephant"] = "Hellephant",
    
    -- Destinations
    ["Player"] = "Player",
    ["Campfire"] = "Campfire", 
    ["Scrapper"] = "Scrapper",
    ["Sack"] = "Sack",
    
    -- General Terms
    ["Enable"] = "Enable",
    ["Disable"] = "Disable",
    ["None"] = "None"
}

-- Function to get English display translation or return original if not found
local function GetDisplayText(englishText)
    return DisplayTranslations[englishText] or englishText
end

-- Function to create translated dropdown options
local function CreateTranslatedOptions(englishArray)
    local translatedArray = {}
    for i, englishItem in ipairs(englishArray) do
        translatedArray[i] = GetDisplayText(englishItem)
    end
    return translatedArray
end

-- Player attribute control state
local PlayerControl = {
    SpeedEnabled = false,
    SpeedValue = 32, -- default WalkSpeed override
    JumpEnabled = false,
    JumpValue = 50,  -- default JumpPower override
    InfiniteJump = false, -- Infinite jumps
    InfiniteJumpConnection = nil, -- Connection for infinite jump
    FlyEnabled = false, -- replaces previous Noclip
    FlySpeed = 60, -- studs/second
    OriginalsStored = false,
    OriginalWalkSpeed = nil,
    OriginalJumpPower = nil
}

-- Trap control state
local TrapControl = {
    AutoTrapEnabled = false,
    TargetPlayer = "None",
    LastTrapUpdate = 0,
    TrapUpdateCooldown = 0.5, -- Update trap position every 0.5 seconds
    OriginalTrapSizes = {}, -- Store original sensor sizes
    ActiveTraps = {}, -- Track active traps for cleanup
    -- Trap Aura state (for killing animals/cultists)
    TrapAuraEnabled = false,
    TrapAuraTarget = "All", -- Target type: All, Animal, or Cultist
    TrapAuraRange = 500, -- Range around player to search for targets
    LastTrapAuraUpdate = 0,
    TrapAuraUpdateCooldown = 0.5, -- Update trap position every 0.5 seconds
}

-- Combat control state
local CombatControl = {
    KillAuraEnabled = false,
    UltraKillEnabled = false, -- New option to attack all targets in range
    TeammateKillAuraEnabled = false,
    AuraRange = 50, -- studs - increased to 1000 as requested
    LastAuraAttack = 0,
    LastTeammateAuraAttack = 0,
    AttackCooldown = 0.5, -- Fixed axe cooldown timing
    DamageBatchSize = 6,
    BatchInterval = 0.025,
    DamageTypeId = "1_9321896061",
    LegacyDamageTypeId = "2_9303764245", -- Fallback damage id for legacy targets/players
    EquippedWeaponName = nil,
    DebugMode = false, -- Disabled debug messages
    InitialAxe = nil, -- Track the axe user had when first enabling kill aura
    CurrentAxe = nil, -- Track currently equipped axe
    WeaponType = "General Axe", -- Selected weapon type
    TargetType = "All", -- Target filtering: All, Animal, Cultist
    TeleportAboveTarget = false, -- Teleport above target when attacking
    TeleportHeight = 10, -- Height above target
    TeammateTarget = "All Players",
    TeammateToggle = nil,
    TeammateDropdown = nil,
    -- Unified axe management (shared between combat and chopping)
    AxeManager = {
        LastEquipTime = 0,
        EquipCooldown = 0.1, -- Prevent spam equipping
        CurrentlyEquipped = nil,
    },
    -- Firearm options
    InstantReloadEnabled = false,
    ReloadTime = 0,
    FireRateEnabled = false,
    FireRate = 0.05,
    -- Burn Enemies (Lava Attack) state
    BurnEnemiesEnabled = false,
    BurnTarget = "All", -- Target type: All, Animal, or Cultist
    BurnRange = 500, -- Range around player to search for targets
    LastBurnUpdate = 0,
    BurnUpdateCooldown = 3, -- Update every 3 seconds
    ActiveFireParts = {}, -- Store {FirePart, OriginalCFrame, OriginalSize, AssignedTarget}
}

-- Store original weapon values for restoration
local OriginalWeaponValues = {}

-- Firearm modification functions
local function storeOriginalValues(weapon)
    if weapon:GetAttribute("ToolName") == "Firearm" and not OriginalWeaponValues[weapon] then
        OriginalWeaponValues[weapon] = {
            ReloadTime = weapon:GetAttribute("ReloadTime"),
            FireRate = weapon:GetAttribute("FireRate")
        }
    end
end

local function patchWeapon(weapon)
    if weapon:GetAttribute("ToolName") == "Firearm" then
        storeOriginalValues(weapon)
        
        if CombatControl.InstantReloadEnabled then
            weapon:SetAttribute("ReloadTime", CombatControl.ReloadTime)
        else
            -- Restore original reload time if disabled
            local original = OriginalWeaponValues[weapon]
            if original and original.ReloadTime then
                weapon:SetAttribute("ReloadTime", original.ReloadTime)
            end
        end
        
        if CombatControl.FireRateEnabled then
            weapon:SetAttribute("FireRate", CombatControl.FireRate)
        else
            -- Restore original firerate if disabled
            local original = OriginalWeaponValues[weapon]
            if original and original.FireRate then
                weapon:SetAttribute("FireRate", original.FireRate)
            end
        end
    end
end

local function updateAllFirearms()
    local player = Players.LocalPlayer
    local inventory = player:WaitForChild("Inventory")
    
    for _, item in ipairs(inventory:GetChildren()) do
        patchWeapon(item)
    end
end

local function initializeFirearmModification()
    local player = Players.LocalPlayer
    local inventory = player:WaitForChild("Inventory")
    
    for _, item in ipairs(inventory:GetChildren()) do
        patchWeapon(item)
    end
    
    inventory.ChildAdded:Connect(function(newItem)
        patchWeapon(newItem)
    end)
end

-- Trees control state (SEPARATE from meteors)
local TreesControl = {
    ChoppingAuraEnabled = false,
    UltraChoppingEnabled = false, -- New option to chop all trees in range
    ChoppingRange = 50, -- studs
    LastChoppingAttack = 0,
    ChoppingCooldown = 0.5, -- Same cooldown as combat
    DebugMode = false, -- Disabled debug messages
    ActiveBillboards = {}, -- Track active health displays
    UltraChopCount = 3, -- Configurable count for ultra chopping (1-6)
    DamageBatchSize = 8, -- Batch size for chopping remote calls
    BatchInterval = 0, -- Delay between batches (seconds)
    TreeDamageId = "1_9321896061",
    EquippedAxeName = nil,
    TargetType = "Every tree", -- Default tree target
    CurrentTargets = {}, -- Array to track trees currently being chopped
    PlanetLogEnabled = false, -- 🪐 PLANET LOG SYSTEM
    PlanetRotationTask = nil, -- Track rotation task for stopping
    OriginalGravity = 196.2, -- Store original workspace gravity
    IceBlockDamageEnabled = false, -- Auto damage ice blocks
    IceBlockBillboards = {} -- Track ice block health displays
}

-- Meteors control state (COMPLETELY SEPARATE from trees)
local MeteorsControl = {
    MiningAuraEnabled = false,
    UltraMiningEnabled = false, -- New option to mine all meteors in range
    MiningRange = 50, -- studs
    LastMiningAttack = 0,
    MiningCooldown = 0.5, -- Same cooldown as combat
    DebugMode = false, -- Disabled debug messages
    ActiveBillboards = {}, -- Track active health displays
    UltraMineCount = 3, -- Configurable count for ultra mining (1-6)
    DamageBatchSize = 8, -- Batch size for mining remote calls
    BatchInterval = 0, -- Delay between batches (seconds)
    MeteorDamageId = "1_9321896061",
    EquippedAxeName = nil,
    TargetType = "All Meteor", -- Default meteor target
    CurrentTargets = {}, -- Array to track meteors currently being mined
}

-- Clear targets (trees/meteors)
local function ClearTargets(isMeteor)
    local control = isMeteor and MeteorsControl or TreesControl
    control.CurrentTargets = {}
    for target, billboard in pairs(control.ActiveBillboards) do
        if billboard and billboard.Parent then
            billboard:Destroy()
        end
    end
    control.ActiveBillboards = {}
end

-- Campfire control state
local CampfireControl = {
    AutoRefillEnabled = false,
    ContinuousRefillEnabled = false, -- Refill without percentage consideration
    RefillPercentage = 25, -- Percentage threshold to trigger refill
    RefillItemType = "All", -- What items to use for refilling
    TeleportDestination = "Campfire", -- Where to teleport items (default: Campfire)
    TeleportHeight = 35, -- Height for teleportation (0-50 studs)
    LastRefillCheck = 0,
    RefillCheckCooldown = 1, -- Configurable cooldown (0.5-2 seconds)
    DebugMode = false, -- Disabled debug messages
    TeleportedItems = {}, -- Track items teleported with UltimateItemTransporter
    SavedPlayerPosition = nil -- Saved position when teleporter is enabled
}



-- Crafting control state
local CraftingControl = {
    ProduceScrapEnabled = false,
    ProduceWoodEnabled = false,
    ProduceCultistGemEnabled = false,
    ProduceForestGemEnabled = false,
    ScrapItemType = "All", -- What items to use for scrap production
    WoodItemType = "All", -- What items to use for wood production (should be logs)
    CultistGemItemType = "All", -- What items to use for cultist gem production
    ForestGemItemType = "All", -- What items to use for forest gem production
    TeleportDestination = "Scrapper", -- Where to teleport items (default: Scrapper)
    TeleportHeight = 35, -- Height for teleportation (0-50 studs)
    TeleportCooldown = 15, -- Customizable teleport cooldown (default: 15 seconds)
    LastCraftingCheck = 0,
    ScrapCooldown = 1.5, -- Fixed cooldown for scrap production (3.5 seconds)
    WoodCooldown = 1.5, -- Fixed cooldown for wood production (2 seconds)
    CultistGemCooldown = 15, -- Fixed cooldown for cultist gem production (10 seconds)
    DebugMode = false, -- Disabled debug messages
    UsedItemsForCampfire = {}, -- Track items used for campfire to avoid conflicts
    UsedItemsForCrafting = {}, -- Track items used for crafting to avoid conflicts
    TeleportedItems = {}, -- Track items teleported with UltimateItemTransporter
    SkippedLockedGems = {}, -- Track gems that were skipped due to being locked (with timestamp)
    SavedPlayerPosition = nil, -- Saved position when crafting is enabled
    -- Physics-safe wood teleportation tracking
    WoodRotationAngle = 0, -- Current rotation angle for spreading wood items
    WoodOffsetRadius = 3, -- Radius for spreading wood items around scrapper
    DisabledCollisionItems = {} -- Track items with disabled collision
}

-- Food control state
local FoodControl = {
    TeleportFoodEnabled = false,
    TeleportDestination = "Player", -- "Player" or "Campfire"
    FoodItemType = "All", -- What food items to teleport
    TeleportHeight = 35, -- Height for teleportation (0-50 studs)
    LastFoodTeleport = 0,
    TeleportCooldown = 1, -- Configurable cooldown (0.5-5 seconds)
    DebugMode = false, -- Disabled debug messages
    TeleportedItems = {}, -- Track items that have been teleported to avoid re-teleporting
    SavedPlayerPosition = nil, -- Saved position when teleporter is enabled
    -- Auto Cook Pot Control
    AutoCookPotEnabled = false,
    CookPotState = {
        IsCooking = false,
        WasCooking = false,
        LastCheck = 0,
        CheckInterval = 3,
        ProcessedStews = {},
    },
    -- Chef Stove Control
    ChefStoveEnabled = false,
    ChefStoveRecipe = "Seafood Chowder",
    ChefStoveDestination = "Player",
    ChefStoveState = {
        DetectedStoves = {},
        ProcessedDishes = {},
        TotalDishesCooked = 0,
    },
    Halloween = {
        TeleportEnabled = false,
        TeleportHeight = 35,
        LastTeleport = 0,
        TeleportCooldown = 1,
        TeleportedItems = {},
        SavedPlayerPosition = nil,
        StatusLabel = nil,
        MazeEnd = {
            AutoLootChests = false,
            TeleportedChestItems = {}
        }
    },
    Invincible = {
        Enabled = false,
        LastCheck = 0
    },
    AutoCollectFlowers = {
        Enabled = false,
        LastCheck = 0
    }
}

-- Animal Pelts control state
local AnimalPeltsControl = {
    TeleportPeltsEnabled = false,
    TeleportDestination = "Player", -- "Player" or "Campfire"
    PeltItemType = "Bunny Foot", -- What pelt items to teleport
    TeleportHeight = 35, -- Height for teleportation (0-50 studs)
    LastPeltTeleport = 0,
    TeleportCooldown = 1, -- Configurable cooldown (0.5-5 seconds)
    DebugMode = false, -- Disabled debug messages
    TeleportedItems = {}, -- Track items that have been teleported to avoid re-teleporting
    SavedPlayerPosition = nil, -- Saved position when teleporter is enabled
    Taming = {
        SelectedAnimal = "Bunny",
        SearchRange = 50,
        AttemptCooldown = 0.3,
        EngageRange = {
            ["Bunny"] = 50,
            ["Wolf"] = 50,
            ["Alpha Wolf"] = 50,
            ["Bear"] = 50,
        },
        FluteVariants = {"Old Taming Flute", "Good Taming Flute", "Strong Taming Flute"},
        Remotes = {
            Neutral = RemoteEvents:WaitForChild("RequestTame_Neutral"),
            Hungry = RemoteEvents:WaitForChild("RequestTame_Hungry"),
        },
        IsBusy = false,
        ActiveTarget = nil,
        LastAttempt = 0,
        FeedOffset = 10,
        ToggleActive = false,
        ToggleHandle = nil,
        AutoTask = nil,
        ShouldRun = false,
        LastStatus = ""
    }
}

-- Meteor shard transport control state
local MeteorShardControl = {
    TeleportShardsEnabled = false,
    ShardItemType = "All", -- What shard items to teleport
    TeleportDestination = "Player", -- Where to move shards
    TeleportHeight = 35, -- Height offset when teleporting
    LastShardTeleport = 0,
    TeleportCooldown = 1, -- Configurable cooldown (0.5-5 seconds)
    DebugMode = false,
    TeleportedItems = {}, -- Track shards already teleported
    SavedPlayerPosition = nil -- Saved position when teleporter is enabled
}

-- Unified Item Bring control state (composite of all transport systems)
UnifiedBringControl = {
    Enabled = false,
    Destination = "Player",
    Height = 35,
    SelectedRefillItems = {},
    SelectedScrapItems = {},
    SelectedGems = {},
    SelectedFood = {},
    SelectedWeapons = {},
    SelectedArmor = {},
    SelectedAmmo = {},
    SelectedHealing = {},
    SelectedPelts = {},
    LastBringCheck = 0,
    BringCooldown = 1,
    TeleportedItems = {},
    Connection = nil
}

-- Healing control state
local HealingControl = {
    TeleportHealingEnabled = false,
    TeleportDestination = "Player", -- "Player" or "Campfire"
    HealingItemType = "Bandage", -- What healing items to teleport
    TeleportHeight = 35, -- Height for teleportation (0-50 studs)
    LastHealingTeleport = 0,
    TeleportCooldown = 1, -- Configurable cooldown (0.5-5 seconds)
    DebugMode = false, -- Disabled debug messages
    TeleportedItems = {}, -- Track items that have been teleported to avoid re-teleporting
    SavedPlayerPosition = nil, -- Saved position when teleporter is enabled
    -- Revival system properties integrated here
    AvailableBodies = {}, -- List of found bodies
    SelectedBody = "None", -- Currently selected body
    LastRefresh = 0 -- Last time bodies were refreshed
}

-- Ammo control state
local AmmoControl = {
    TeleportAmmoEnabled = false,
    TeleportWeaponEnabled = false, -- New weapon teleport toggle
    TeleportArmorEnabled = false, -- New armor teleport toggle
    TeleportDestination = "Player", -- "Player" only for ammo/weapons/armor
    AmmoItemType = "All", -- What ammo items to teleport
    WeaponItemType = "All", -- What weapon items to teleport
    ArmorItemType = "All", -- What armor items to teleport
    TeleportHeight = 35, -- Height for teleportation (0-50 studs)
    LastAmmoTeleport = 0,
    LastWeaponTeleport = 0, -- Separate cooldown for weapons
    LastArmorTeleport = 0, -- Separate cooldown for armor
    TeleportCooldown = 1, -- Configurable cooldown (0.5-5 seconds)
    DebugMode = false, -- Disabled debug messages
    TeleportedItems = {}, -- Track items that have been teleported to avoid re-teleporting
    TeleportedWeapons = {}, -- Track weapons that have been teleported
    TeleportedArmor = {}, -- Track armor that has been teleported
    SavedPlayerPosition = nil, -- Saved position when teleporter is enabled
    -- Weapon types (no local needed - stored in control object)
    WeaponTypes = {
        "All", "Old Axe", "Good Axe", "Ice Axe", "Strong Axe", "Chainsaw",
        "Spear", "Morningstar", "Katana", "Laser Sword", "Ice Sword", "Trident", 
        "Poison Spear", "Infernal Sword", "Cultist King Mace",
        "Revolver", "Rifle", "Tactical Shotgun", "Snowball", "Frozen Shuriken", 
        "Kunai", "Ray Gun", "Laser Cannon", "Flamethrower","Scythe", "Vampire Scythe", "Blowpipe",
        "Crossbow", "Wildfire", "Infernal Crossbow"
    },
    -- Armor types (no local needed - stored in control object)
    ArmorTypes = {
        "All", "Leather Body", "Iron Body", "Thorn Body", "Riot Shield", "Alien Armor"
    }
}

-- Chest control state
local ChestControl = {
    AutoLootEnabled = false,
    -- Store previous states for combat/chopping/mining systems
    SavedStates = {
        KillAuraEnabled = false,
        UltraKillEnabled = false,
        TeammateKillAuraEnabled = false,
        ChoppingAuraEnabled = false,
        UltraChoppingEnabled = false,
        MiningAuraEnabled = false,
        UltraMiningEnabled = false
    }
}

-- Lighting control state
local LightingControl = {
    AlwaysDayEnabled = false,
    Connection = nil,
    OriginalSettings = {},
    ColorCorrection = nil
}

-- Always Day Lighting functionality
local function initializeLighting()
    -- Find or create the ColorCorrection effect
    LightingControl.ColorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not LightingControl.ColorCorrection then
        LightingControl.ColorCorrection = Instance.new("ColorCorrectionEffect")
        LightingControl.ColorCorrection.Parent = Lighting
    end
    
    -- Store the game's original settings
    LightingControl.OriginalSettings = {
        ClockTime = Lighting.ClockTime,
        Brightness = LightingControl.ColorCorrection.Brightness,
        Saturation = LightingControl.ColorCorrection.Saturation,
        TintColor = LightingControl.ColorCorrection.TintColor,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        FogColor = Lighting.FogColor
    }
end

local function applyCustomLighting()
    local ALWAYS_DAY_SETTINGS = {
        ClockTime = 14,
        Brightness = 0.1,
        Saturation = 0.05,
        TintColor = Color3.fromRGB(255, 255, 255),
        FogStart = 2000,
        FogEnd = 10000,
        FogColor = Color3.fromRGB(195, 200, 210)
    }
    
    Lighting.ClockTime = ALWAYS_DAY_SETTINGS.ClockTime
    Lighting.FogStart = ALWAYS_DAY_SETTINGS.FogStart
    Lighting.FogEnd = ALWAYS_DAY_SETTINGS.FogEnd
    Lighting.FogColor = ALWAYS_DAY_SETTINGS.FogColor
    
    LightingControl.ColorCorrection.Enabled = true
    LightingControl.ColorCorrection.Brightness = ALWAYS_DAY_SETTINGS.Brightness
    LightingControl.ColorCorrection.Saturation = ALWAYS_DAY_SETTINGS.Saturation
    LightingControl.ColorCorrection.TintColor = ALWAYS_DAY_SETTINGS.TintColor
end

local function restoreOriginalLighting()
    local original = LightingControl.OriginalSettings
    
    Lighting.ClockTime = original.ClockTime
    Lighting.FogStart = original.FogStart
    Lighting.FogEnd = original.FogEnd
    Lighting.FogColor = original.FogColor
    
    LightingControl.ColorCorrection.Brightness = original.Brightness
    LightingControl.ColorCorrection.Saturation = original.Saturation
    LightingControl.ColorCorrection.TintColor = original.TintColor
end

local function onRenderStep()
    if LightingControl.AlwaysDayEnabled then
        applyCustomLighting()
    end
end

local function toggleAlwaysDay(enabled)
    LightingControl.AlwaysDayEnabled = enabled
    
    if enabled then
        if not LightingControl.Connection then
            LightingControl.Connection = RunService.RenderStepped:Connect(onRenderStep)
        end
    else
        if LightingControl.Connection then
            LightingControl.Connection:Disconnect()
            LightingControl.Connection = nil
        end
        restoreOriginalLighting()
    end
end

-- ESP control state
local ESPControl = {
    Enabled = false,
    ESPObjects = {}, -- Store ESP GUI objects for cleanup
    Categories = {
        Food = false,
        AnimalPelts = false,
        Healing = false,
        Ammo = false,
        Entities = false,
        Chests = false,
        Players = false
    },
    Colors = {
        Food = Color3.fromRGB(255, 165, 0), -- Orange
        AnimalPelts = Color3.fromRGB(139, 69, 19), -- Brown
        Healing = Color3.fromRGB(0, 255, 0), -- Green
        Ammo = Color3.fromRGB(255, 255, 0), -- Yellow
        Entities = Color3.fromRGB(255, 100, 100), -- Light Red
        Chests = Color3.fromRGB(255, 0, 255), -- Magenta
        Players = Color3.fromRGB(255, 0, 0) -- Red
    }
}

-- Skybase control state
local SkybaseControl = {
    GuiEnabled = false,
    PlatformModel = nil,
    SkybaseGui = nil,
    MOVE_INCREMENT = 2, -- How far the platform moves per click
    SmartAutoEatEnabled = false,
    HungerThreshold = 50, -- Default hunger threshold
    FoodSearchRange = 500, -- Default search range for food items (extended for teleportation)
    LastHungerCheck = 0,
    HungerCheckCooldown = 5, -- Check every 5 seconds to avoid spam
    -- Simple Anti-AFK variables
    AntiAfkEnabled = false,
    LastAfkAction = 0,
    AfkActionInterval = 180, -- 3 minutes between actions
    InactivityThreshold = 30, -- 30 seconds of inactivity required
    PlayerLastPosition = nil,
    PlayerLastCameraRotation = nil
}

-- Lost Children control state
local LostChildrenControl = {
    RescueEnabled = false,
    OriginalPosition = nil,
    RescuedChildren = {}, -- Track which children have been rescued
    VisitedWolves = {}, -- Track visited wolf positions and surrounding areas
    CurrentStep = "idle", -- idle, searching, rescuing, returning
    LastTeleportPosition = nil,
    TeleportCooldown = 0.2, -- Seconds between teleports (increased to 4)
    LastTeleportTime = 0,
    OriginalGravity = nil, -- Store original gravity value
    Toggle = nil, -- GUI handle
    Status = nil, -- GUI handle
    ToggleState = {
        Tree = nil,
        Meteor = nil,
        Syncing = false,
        PrepareObsidiron = nil,
        ObsidironActive = false,
    },
    ChildrenData = {
        ["Lost Child"] = {name = "Dino", tent = "TentDinoKid"},
        ["Lost Child2"] = {name = "Kraken", tent = "TentKrakenKid"}, 
        ["Lost Child3"] = {name = "Squid", tent = "TentSquidKid"},
        ["Lost Child4"] = {name = "Koala", tent = "TentKoalaKid"}
    }
}

-- Item dropdown options grouped together for reuse across transport systems
local DropdownOptions = {
    RefillItems = {
        "Log",
        "Coal",
        "Biofuel",
        "Fuel Canister",
        "Oil Barrel"
    },
    ScrapItems = {
        "All",
        "Bolt",
        "Sheet Metal", 
        "Broken Fan",
        "Old Radio",
        "Broken Microwave",
        "Tyre",
        "Metal Chair",
        "Old Car Engine",
        "Washing Machine",
        "Cultist Experiment",
        "Cultist Prototype",
        "UFO Scrap"
    },
    GemItems = {
        "Cultist Gem",
        "Gem of the Forest",
        "Gem of the Forest Fragment",
        "Meteor Shard",
        "Gold Shard",
        "Obsidiron Ingot"
    },
    FoodItems = {
        "All",
        "Cooked Food",
        "Cake", 
        "Ribs",
        "Steak",
        "Morsel",
        "Carrot",
        "Corn",
        "Pumpkin",
        "Apple",
        "Chili"
    },
    WeaponItems = {
        "Old Axe",
        "Good Axe",
        "Ice Axe",
        "Strong Axe",
        "Chainsaw",
        "Spear",
        "Morningstar",
        "Katana",
        "Laser Sword",
        "Ice Sword",
        "Trident",
        "Poison Spear",
        "Infernal Sword",
        "Scythe",
        "Vampire Scythe",
        "Cultist King Mace",
        "Revolver",
        "Rifle",
        "Tactical Shotgun",
        "Shotgun",
        "Snowball",
        "Frozen Shuriken",
        "Kunai",
        "Ray Gun",
        "Laser Cannon",
        "Flamethrower",
        "Blowpipe",
        "Crossbow",
        "Wildfire",
        "Infernal Crossbow",
        "Knife",
        "Dagger"
    },
    ArmorItems = {
        "Leather Body",
        "Iron Body",
        "Thorn Body",
        "Riot Shield",
        "Alien Armor",
        "Leather Helmet",
        "Iron Helmet",
        "Leather Pants",
        "Iron Pants",
        "Leather Shoes",
        "Iron Shoes"
    },
    AnimalPelts = {
        "Bunny Foot",
        "Wolf Pelt",
        "Alpha Wolf Pelt",
        "Bear Pelt",
        "Arctic Fox Pelt",
        "Polar Bear Pelt",
        "Mammoth Tusk"
    },
    HealingItems = {
        "Bandage",
        "MedKit"
    },
    MeteorShards = {
        "All",
        "Meteor Shard",
        "Gold Shard",
        "Obsidiron Ingot"
    },
    AmmoItems = {
        "All",
        "Revolver Ammo",
        "Rifle Ammo",
        "Shotgun Ammo",
        "Fuel Canister"
    },
    EntityTypes = {
        "Cultist",
        "Crossbow Cultist",
        "Juggernaut Cultist",
        "Wolf",
        "Alpha Wolf", 
        "Bear",
        "Polar Bear",
        "The Deer",
        "Alien",
        "Alien Elite",
        "Arctic Fox",
        "Mammoth",
        "Bunny"
    },
    Destinations = {
        Common = {
            "Player",
            "Campfire"
        },
        Campfire = {
            "Campfire",
            "Player",
            "Sack"
        }
    }
}

-- Direct axe equipping function (called before each action)
local function EquipBestAxeNow()
    -- Get player's inventory
    local inventory = LocalPlayer:FindFirstChild("Inventory")
    if not inventory then
        return false
    end
    
    -- Use cached remote events
    local equipItemRemote = RemoteEvents:FindFirstChild("EquipItemHandle")
    if not equipItemRemote then
        return false
    end
    
    -- Define axe hierarchy (best to worst)
    local axeHierarchy = {
        "Chainsaw",     -- Highest tier
        "Strong Axe",   -- High tier
        "Ice Axe",      -- Mid tier
        "Good Axe",     -- Low tier
        "Old Axe"       -- Base tier
    }
    
    local axeToUse = nil
    local axeToUseName = nil
    
    -- Find the best available axe
    for _, axeName in ipairs(axeHierarchy) do
        local axe = inventory:FindFirstChild(axeName)
        if axe then
            axeToUse = axe
            axeToUseName = axeName
            break
        end
    end
    
    if not axeToUse then
        return false -- No axe found
    end
    
    -- Always equip the axe (no caching)
    local equipSuccess = pcall(function()
        local equipArgs = {
            [1] = "FireAllClients",
            [2] = axeToUse
        }
        equipItemRemote:FireServer(unpack(equipArgs))
    end)
    
    if equipSuccess then
        CombatControl.AxeManager.CurrentlyEquipped = axeToUseName
        return true, axeToUse
    end
    
    return false
end

-- Function to locate best weapon based on weapon type without equipping
local function FindBestWeapon(weaponType)
    -- Get player's inventory
    local inventory = LocalPlayer:FindFirstChild("Inventory")
    if not inventory then
        return false
    end
    
    local weaponToUse = nil
    local weaponToUseName = nil
    
    if weaponType == "General Axe" then
        -- Use the existing axe hierarchy
        local axeHierarchy = {
            "Chainsaw",     -- Highest tier
            "Strong Axe",   -- High tier
            "Ice Axe",      -- Mid tier
            "Good Axe",     -- Low tier
            "Old Axe"       -- Base tier
        }
        
        -- Find the best available axe
        for _, axeName in ipairs(axeHierarchy) do
            local axe = inventory:FindFirstChild(axeName)
            if axe then
                weaponToUse = axe
                weaponToUseName = axeName
                break
            end
        end
    else
        -- For other weapon types, find the exact weapon
        local weapon = inventory:FindFirstChild(weaponType)
        if weapon then
            weaponToUse = weapon
            weaponToUseName = weaponType
        end
    end
    
    if weaponToUse then
        return true, weaponToUse, weaponToUseName
    end

    return false
end

-- Fly input tracking (works for both PC and Mobile)
local FlyKeys = {
    W = false,
    A = false,
    S = false,
    D = false,
    Space = false,
    LeftShift = false
}

-- Check if player is on mobile and create mobile controls (inlined creation)
do
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        -- Create mobile controls directly without extra locals (initially hidden)
        local gui = Instance.new("ScreenGui")
        gui.Name = "FlyMobileControls"
        gui.ResetOnSpawn = false
        gui.Enabled = false -- Start hidden until fly is enabled
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.3, 0, 0.3, 0)
        frame.Position = UDim2.new(0.05, 0, 0.65, 0)
        frame.BackgroundTransparency = 1
        frame.Parent = gui
        
        -- Create buttons with inline function
        local function createBtn(name, pos, txt, key)
            local btn = Instance.new("TextButton")
            btn.Name = name
            btn.Size = UDim2.new(0.3, 0, 0.3, 0)
            btn.Position = pos
            btn.Text = txt
            btn.TextScaled = true
            btn.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.BackgroundTransparency = 0.3
            btn.BorderSizePixel = 2
            btn.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
            btn.Font = Enum.Font.SourceSansBold
            btn.Parent = frame
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = btn
            
            -- Connect events inline
            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    FlyKeys[key] = true
                    btn.BackgroundTransparency = 0.1
                end
            end)
            btn.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    FlyKeys[key] = false
                    btn.BackgroundTransparency = 0.3
                end
            end)
            btn.MouseLeave:Connect(function()
                FlyKeys[key] = false
                btn.BackgroundTransparency = 0.3
            end)
            
            return btn
        end
        
        -- Movement buttons
        createBtn("W", UDim2.new(0.35, 0, 0, 0), "↑", "W")
        createBtn("A", UDim2.new(0, 0, 0.35, 0), "←", "A") 
        createBtn("S", UDim2.new(0.35, 0, 0.7, 0), "↓", "S")
        createBtn("D", UDim2.new(0.7, 0, 0.35, 0), "→", "D")
        
        -- Vertical controls frame
        local vFrame = Instance.new("Frame")
        vFrame.Size = UDim2.new(0.15, 0, 0.25, 0)
        vFrame.Position = UDim2.new(0.8, 0, 0.65, 0)
        vFrame.BackgroundTransparency = 1
        vFrame.Parent = gui
        
        -- Up button (Space)
        local upBtn = Instance.new("TextButton")
        upBtn.Size = UDim2.new(1, 0, 0.45, 0)
        upBtn.Position = UDim2.new(0, 0, 0, 0)
        upBtn.Text = "▲\nUP"
        upBtn.TextScaled = true
        upBtn.BackgroundColor3 = Color3.new(0.1, 0.3, 0.5)
        upBtn.TextColor3 = Color3.new(1, 1, 1)
        upBtn.BackgroundTransparency = 0.3
        upBtn.BorderSizePixel = 2
        upBtn.BorderColor3 = Color3.new(0.5, 0.7, 1)
        upBtn.Font = Enum.Font.SourceSansBold
        upBtn.Parent = vFrame
        Instance.new("UICorner").Parent = upBtn
        
        -- Down button (LeftShift)
        local downBtn = Instance.new("TextButton")
        downBtn.Size = UDim2.new(1, 0, 0.45, 0)
        downBtn.Position = UDim2.new(0, 0, 0.55, 0)
        downBtn.Text = "DOWN\n▼"
        downBtn.TextScaled = true
        downBtn.BackgroundColor3 = Color3.new(0.5, 0.3, 0.1)
        downBtn.TextColor3 = Color3.new(1, 1, 1)
        downBtn.BackgroundTransparency = 0.3
        downBtn.BorderSizePixel = 2
        downBtn.BorderColor3 = Color3.new(1, 0.7, 0.5)
        downBtn.Font = Enum.Font.SourceSansBold
        downBtn.Parent = vFrame
        Instance.new("UICorner").Parent = downBtn
        
        -- Connect up/down events inline
        for _, btnData in pairs({{upBtn, "Space"}, {downBtn, "LeftShift"}}) do
            btnData[1].InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    FlyKeys[btnData[2]] = true
                    btnData[1].BackgroundTransparency = 0.1
                end
            end)
            btnData[1].InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    FlyKeys[btnData[2]] = false
                    btnData[1].BackgroundTransparency = 0.3
                end
            end)
            btnData[1].MouseLeave:Connect(function()
                FlyKeys[btnData[2]] = false
                btnData[1].BackgroundTransparency = 0.3
            end)
        end
        
        -- Toggle mobile controls with fly state (inline connection to PlayerControl)
        PlayerControl.MobileGui = gui
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    -- Skip keyboard input on mobile
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return end
    
    -- Allow LeftShift even if game processed it (sprint binding) so down-fly still works
    if gpe and input.KeyCode ~= Enum.KeyCode.LeftShift then return end
    local kc = input.KeyCode
    if kc == Enum.KeyCode.W then FlyKeys.W = true
    elseif kc == Enum.KeyCode.A then FlyKeys.A = true
    elseif kc == Enum.KeyCode.S then FlyKeys.S = true
    elseif kc == Enum.KeyCode.D then FlyKeys.D = true
    elseif kc == Enum.KeyCode.Space then FlyKeys.Space = true
    elseif kc == Enum.KeyCode.LeftShift then FlyKeys.LeftShift = true end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    -- Skip keyboard input on mobile
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return end
    
    local kc = input.KeyCode
    if kc == Enum.KeyCode.W then FlyKeys.W = false
    elseif kc == Enum.KeyCode.A then FlyKeys.A = false
    elseif kc == Enum.KeyCode.S then FlyKeys.S = false
    elseif kc == Enum.KeyCode.D then FlyKeys.D = false
    elseif kc == Enum.KeyCode.Space then FlyKeys.Space = false
    elseif kc == Enum.KeyCode.LeftShift then FlyKeys.LeftShift = false end
end)

-- Store original humanoid properties (once per character spawn)
local function StoreOriginals(humanoid)
    if PlayerControl.OriginalsStored or not humanoid then return end
    PlayerControl.OriginalWalkSpeed = humanoid.WalkSpeed
    if humanoid.UseJumpPower then
        PlayerControl.OriginalJumpPower = humanoid.JumpPower
    else
        PlayerControl.OriginalJumpPower = humanoid.JumpHeight
    end
    PlayerControl.OriginalsStored = true
end

-- Apply speed if enabled
local function ApplySpeed(humanoid)
    if PlayerControl.SpeedEnabled and humanoid then
        humanoid.WalkSpeed = PlayerControl.SpeedValue
    elseif humanoid and PlayerControl.OriginalWalkSpeed then
        humanoid.WalkSpeed = PlayerControl.OriginalWalkSpeed
    end
end

-- Apply jump if enabled
local function ApplyJump(humanoid)
    if not humanoid then return end
    if PlayerControl.JumpEnabled then
        if humanoid.UseJumpPower then
            humanoid.JumpPower = PlayerControl.JumpValue
        else
            humanoid.JumpHeight = PlayerControl.JumpValue
        end
    elseif PlayerControl.OriginalJumpPower then
        if humanoid.UseJumpPower then
            humanoid.JumpPower = PlayerControl.OriginalJumpPower
        else
            humanoid.JumpHeight = PlayerControl.OriginalJumpPower
        end
    end
end

-- Get all player names for dropdown
local function GetPlayerNames(includeAllPlayers, includeNoneOption)
    local playerNames = {}

    if includeNoneOption ~= false then
        table.insert(playerNames, "None")
    end

    if includeAllPlayers then
        table.insert(playerNames, "All Players")
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerNames, player.Name)
        end
    end

    return playerNames
end

-- Find all bear traps in workspace
local function FindAllBearTraps()
    local traps = {}
    local structuresFolder = workspace:FindFirstChild("Structures")
    if not structuresFolder then
        return traps
    end
    
    for _, structure in pairs(structuresFolder:GetChildren()) do
        if structure.Name == "Bear Trap" then
            table.insert(traps, structure)
        end
    end
    
    return traps
end

-- Set trap at location
local function SetTrap(trap)
    if not trap then return false end
    
    -- Check if trap is already set
    local trapSet = trap:GetAttribute("TrapSet")
    if trapSet == true then
        return true -- Trap is already set, no need to call remote
    end
    
    -- Only call RequestSetTrap if trap is not set (TrapSet is false or nil)
    local success = pcall(function()
        local args = {[1] = trap}
        RemoteEvents.RequestSetTrap:FireServer(unpack(args))
    end)
    
    return success
end

-- Modify trap sensor size
local function ModifyTrapSensor(trap, size)
    if not trap then return end
    
    local trapSensor = trap:FindFirstChild("TrapSensor")
    if trapSensor then
        -- Store original size if not already stored
        if not TrapControl.OriginalTrapSizes[trap] then
            TrapControl.OriginalTrapSizes[trap] = trapSensor.Size
        end
        
        trapSensor.Size = size
    end
end

-- Restore trap sensor to original size
local function RestoreTrapSensor(trap)
    if not trap then return end
    
    local trapSensor = trap:FindFirstChild("TrapSensor")
    local originalSize = TrapControl.OriginalTrapSizes[trap]
    
    if trapSensor and originalSize then
        trapSensor.Size = originalSize
    end
end

-- Move trap to target player position
local function MoveTrapToPlayer(trap, targetPlayerName)
    if not trap or targetPlayerName == "None" then return false end
    
    local targetPlayer = game.Players:FindFirstChild(targetPlayerName)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    -- Get player's humanoid root part position
    local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
    
    -- Position trap exactly under player's feet (ground level)
    -- Using Y offset of -3 to place it slightly underground for better triggering
    local trapPosition = targetPosition + Vector3.new(0, -3, 0)
    
    -- Move trap to position
    if trap.PrimaryPart then
        trap:SetPrimaryPartCFrame(CFrame.new(trapPosition))
    elseif trap:FindFirstChild("Root") then
        trap.Root.CFrame = CFrame.new(trapPosition)
    end
    
    return true
end

-- Update auto trap system
local function UpdateAutoTrap()
    if not TrapControl.AutoTrapEnabled or TrapControl.TargetPlayer == "None" then
        return
    end
    
    local currentTime = tick()
    if currentTime - TrapControl.LastTrapUpdate < TrapControl.TrapUpdateCooldown then
        return
    end
    
    TrapControl.LastTrapUpdate = currentTime
    
    -- Find target player
    local targetPlayer = game.Players:FindFirstChild(TrapControl.TargetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    -- Find all bear traps
    local bearTraps = FindAllBearTraps()
    
    -- Get drag request remote
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    
    for _, trap in pairs(bearTraps) do
        -- Step 1: Check if trap is set, set it if not
        local trapSet = trap:GetAttribute("TrapSet")
        if trapSet ~= true then
            SetTrap(trap)
        end
        
        -- Step 2: Send drag request before moving
        if requestStartDragging then
            requestStartDragging:FireServer(trap)
        end
        
        -- Step 3: Set expanded sensor size and move trap
        ModifyTrapSensor(trap, Vector3.new(10, 10, 10))
        MoveTrapToPlayer(trap, TrapControl.TargetPlayer)
        
        -- Track this trap as active
        TrapControl.ActiveTraps[trap] = true
    end
end

-- Update trap aura system (for killing animals/cultists)
local function UpdateTrapAura()
    if not TrapControl.TrapAuraEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - TrapControl.LastTrapAuraUpdate < TrapControl.TrapAuraUpdateCooldown then
        return
    end
    
    TrapControl.LastTrapAuraUpdate = currentTime
    
    -- Find target entities using the same logic as Kill Aura
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        return 
    end
    
    local playerPos = char.HumanoidRootPart.Position
    local targetEntity = nil
    local closestDistance = math.huge
    
    -- Search in workspace.Characters folder
    local charactersFolder = workspace:FindFirstChild("Characters")
    if not charactersFolder then
        return
    end
    
    for _, entity in pairs(charactersFolder:GetChildren()) do
        if entity == char then continue end
        
        local humanoid = entity:FindFirstChildOfClass("Humanoid")
        local rootPart = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("Torso") or entity:FindFirstChild("UpperTorso")
        
        if humanoid and rootPart and humanoid.Health > 0 then
            local distance = (playerPos - rootPart.Position).Magnitude
            
            -- Only consider entities within the trap aura range around the player
            if distance <= TrapControl.TrapAuraRange then
                local entityName = entity.Name:lower()
                
                -- Apply target filtering based on TrapAuraTarget
                local shouldTarget = false
                if TrapControl.TrapAuraTarget == "All" then
                    -- Target everything (both animals and cultists)
                    shouldTarget = true
                elseif TrapControl.TrapAuraTarget == "Animal" then
                    -- Target everything that does NOT have "cultist" in name
                    shouldTarget = not entityName:find("cultist")
                elseif TrapControl.TrapAuraTarget == "Cultist" then
                    -- Target everything that DOES have "cultist" in name
                    shouldTarget = entityName:find("cultist") ~= nil
                end
                
                if shouldTarget and distance < closestDistance then
                    closestDistance = distance
                    targetEntity = entity
                end
            end
        end
    end
    
    -- If no target found, return
    if not targetEntity or not targetEntity:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    -- Find all bear traps
    local bearTraps = FindAllBearTraps()
    
    -- Get drag request remote
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    
    -- Get target position
    local targetPosition = targetEntity.HumanoidRootPart.Position
    local trapPosition = targetPosition + Vector3.new(0, -3, 0)
    
    for _, trap in pairs(bearTraps) do
        -- Step 1: Check if trap is set, set it if not
        local trapSet = trap:GetAttribute("TrapSet")
        if trapSet ~= true then
            SetTrap(trap)
        end
        
        -- Step 2: Send drag request before moving
        if requestStartDragging then
            requestStartDragging:FireServer(trap)
        end
        
        -- Step 3: Set expanded sensor size and move trap to target
        ModifyTrapSensor(trap, Vector3.new(10, 10, 10))
        
        -- Move trap to target position
        if trap.PrimaryPart then
            trap:SetPrimaryPartCFrame(CFrame.new(trapPosition))
        elseif trap:FindFirstChild("Root") then
            trap.Root.CFrame = CFrame.new(trapPosition)
        end
        
        -- Track this trap as active
        TrapControl.ActiveTraps[trap] = true
    end
end

-- Cleanup trap system when disabled
local function CleanupTraps()
    -- Restore all trap sensors to original size
    for trap, _ in pairs(TrapControl.ActiveTraps) do
        if trap and trap.Parent then
            RestoreTrapSensor(trap)
        end
    end
    
    -- Clear active traps
    TrapControl.ActiveTraps = {}
end

-- Find all FireParts from Lava Lakes in the map
function FindAllFireParts()
    local fireParts = {}
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return fireParts end
    
    local landmarks = mapFolder:FindFirstChild("Landmarks")
    if not landmarks then return fireParts end
    
    -- Search through ALL children and find any "Lava Lake1" or "Lava Lake2"
    for _, landmark in pairs(landmarks:GetChildren()) do
        if landmark.Name == "Lava Lake1" or landmark.Name == "Lava Lake2" then
            local firePart = landmark:FindFirstChild("FirePart")
            if firePart and firePart:IsA("BasePart") then
                -- Check if we already added this FirePart (avoid duplicates)
                local isDuplicate = false
                for _, existingPart in pairs(fireParts) do
                    if existingPart == firePart then
                        isDuplicate = true
                        break
                    end
                end
                
                if not isDuplicate then
                    table.insert(fireParts, firePart)
                end
            end
        end
    end
    
    return fireParts
end

-- Initialize FireParts for burn enemies
function InitializeFireParts()
    -- Clear any existing data
    CombatControl.ActiveFireParts = {}
    
    -- Find all FireParts
    local fireParts = FindAllFireParts()
    
    -- Store original state and resize to 5x5x5
    for _, firePart in pairs(fireParts) do
        table.insert(CombatControl.ActiveFireParts, {
            FirePart = firePart,
            OriginalCFrame = firePart.CFrame,
            OriginalSize = firePart.Size,
            AssignedTarget = nil
        })
        
        -- Resize to 5x5x5
        firePart.Size = Vector3.new(5, 5, 5)
    end
end

-- Restore FireParts to original state
function RestoreFireParts()
    for _, data in pairs(CombatControl.ActiveFireParts) do
        if data.FirePart and data.FirePart.Parent then
            -- Restore original position and size
            data.FirePart.CFrame = data.OriginalCFrame
            data.FirePart.Size = data.OriginalSize
        end
    end
    
    -- Clear the table
    CombatControl.ActiveFireParts = {}
end

-- Update burn enemies system
function UpdateBurnEnemies()
    if not CombatControl.BurnEnemiesEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - CombatControl.LastBurnUpdate < CombatControl.BurnUpdateCooldown then
        return
    end
    
    CombatControl.LastBurnUpdate = currentTime
    
    -- Get player character
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        return 
    end
    
    local playerPos = char.HumanoidRootPart.Position
    
    -- Continuously refresh FireParts collection to catch new spawns
    local currentFireParts = FindAllFireParts()
    
    -- Update ActiveFireParts with any new FireParts found
    for _, firePart in pairs(currentFireParts) do
        local alreadyTracked = false
        for _, fireData in pairs(CombatControl.ActiveFireParts) do
            if fireData.FirePart == firePart then
                alreadyTracked = true
                break
            end
        end
        
        -- Add new FirePart if not already tracked
        if not alreadyTracked then
            table.insert(CombatControl.ActiveFireParts, {
                FirePart = firePart,
                OriginalCFrame = firePart.CFrame,
                OriginalSize = firePart.Size,
                AssignedTarget = nil
            })
            
            -- Resize to 5x5x5
            firePart.Size = Vector3.new(5, 5, 5)
        end
    end
    
    -- Find all valid targets within range
    local targets = {}
    local charactersFolder = workspace:FindFirstChild("Characters")
    if not charactersFolder then
        return
    end
    
    for _, entity in pairs(charactersFolder:GetChildren()) do
        if entity == char then continue end
        
        local humanoid = entity:FindFirstChildOfClass("Humanoid")
        local rootPart = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("Torso") or entity:FindFirstChild("UpperTorso")
        
        if humanoid and rootPart and humanoid.Health > 0 then
            local distance = (playerPos - rootPart.Position).Magnitude
            
            -- Only consider entities within burn range
            if distance <= CombatControl.BurnRange then
                local entityName = entity.Name:lower()
                
                -- Apply target filtering
                local shouldTarget = false
                if CombatControl.BurnTarget == "All" then
                    shouldTarget = true
                elseif CombatControl.BurnTarget == "Animal" then
                    shouldTarget = not entityName:find("cultist")
                elseif CombatControl.BurnTarget == "Cultist" then
                    shouldTarget = entityName:find("cultist") ~= nil
                end
                
                if shouldTarget then
                    table.insert(targets, entity)
                end
            end
        end
    end
    
    -- If no FireParts initialized, initialize them
    if #CombatControl.ActiveFireParts == 0 then
        InitializeFireParts()
    end
    
    -- Get drag request remote for proper network ownership
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    
    -- If no targets, move all FireParts back to original position
    if #targets == 0 then
        for _, fireData in pairs(CombatControl.ActiveFireParts) do
            if fireData.FirePart and fireData.FirePart.Parent then
                -- Send drag request before moving
                if requestStartDragging then
                    pcall(function()
                        requestStartDragging:FireServer(fireData.FirePart)
                    end)
                end
                fireData.FirePart.CFrame = fireData.OriginalCFrame
                fireData.AssignedTarget = nil
            end
        end
        return
    end
    
    -- Distribute FireParts among targets (round-robin)
    for i, fireData in pairs(CombatControl.ActiveFireParts) do
        if fireData.FirePart and fireData.FirePart.Parent then
            -- Assign target using round-robin (cycle through targets)
            local targetIndex = ((i - 1) % #targets) + 1
            local target = targets[targetIndex]
            
            if target and target:FindFirstChild("HumanoidRootPart") then
                -- Send drag request before moving for proper network ownership
                if requestStartDragging then
                    pcall(function()
                        requestStartDragging:FireServer(fireData.FirePart)
                    end)
                end
                
                -- Move FirePart to target's CFrame directly
                fireData.FirePart.CFrame = target.HumanoidRootPart.CFrame
                fireData.AssignedTarget = target
            else
                -- Send drag request before restoring
                if requestStartDragging then
                    pcall(function()
                        requestStartDragging:FireServer(fireData.FirePart)
                    end)
                end
                
                fireData.FirePart.CFrame = fireData.OriginalCFrame
                fireData.AssignedTarget = nil
            end
        end
    end
end

-- Debug function to print messages to dev console (defined at top level)
local function DebugMsg(tag, message)
    -- Debug disabled - no output
end


-- Helper functions for item collision control
local function disableItemCollisions(item)
    local originalStates = {}
    for _, part in ipairs(item:GetDescendants()) do
        if part:IsA("BasePart") then
            originalStates[part] = part.CanCollide
            part.CanCollide = false
        end
    end
    return originalStates
end

local function restoreItemCollisions(originalStates)
    for part, canCollide in pairs(originalStates) do
        if part and part.Parent then
            part.CanCollide = canCollide
        end
    end
end

-- Simple sack helper functions using ItemBag children count
local function findPlayerInventorySack()
    local player = LocalPlayer
    local inventory = player:FindFirstChild("Inventory")
    
    if inventory then
        for _, item in pairs(inventory:GetChildren()) do
            if item.Name:find("Sack") then
                return item
            end
        end
    end
    return nil
end

local function getSackInfo()
    local sack = findPlayerInventorySack()
    if not sack then
        return 0, 0
    end
    
    local capacity = sack:GetAttribute("Capacity") or 0
    local itemBag = LocalPlayer:FindFirstChild("ItemBag")
    local currentItems = itemBag and #itemBag:GetChildren() or 0
    
    return capacity, currentItems
end

local function isSackFull()
    local capacity, currentItems = getSackInfo()
    return currentItems >= capacity
end

-- Ultimate Item Transporter Function
local function UltimateItemTransporter(targetItem, destinationPart, trackingTable, teleportCooldown, savedPlayerPosition, teleportHeight)
    -- Fire drag request FIRST
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(targetItem)
        end)
    end
    
    -- Calculate destination position
    local destinationCFrame = nil
    local height = teleportHeight or 35
    
    if destinationPart == "Player" then
        local char = LocalPlayer.Character
        destinationCFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, height, 0)
    elseif destinationPart == "MainFire" or destinationPart == "Campfire" then
        local campfire = workspace.Map.Campground.MainFire
        destinationCFrame = campfire.PrimaryPart.CFrame * CFrame.new(0, height, 0)
    elseif typeof(destinationPart) == "Instance" then
        destinationCFrame = destinationPart.PrimaryPart.CFrame * CFrame.new(0, height, 0)
    else
        return false
    end
    
    -- Simply teleport the item to destination
    targetItem.PrimaryPart.CFrame = destinationCFrame
    
    -- Stop dragging the item immediately after teleport
    local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
    if stopDragging then
        pcall(function()
            stopDragging:FireServer(targetItem)
        end)
    end
    
    return true
end

-- Chef Stove Dish Transporter - Specialized for detaching dishes from cook pot
local function ChefStoveDishTransporter(targetItem, destinationPart, teleportHeight)
    if not targetItem or not targetItem.Parent then
        return false
    end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    -- Wait 2 seconds before starting
    task.wait(2)
    
    -- Step 1: Request drag to detach from cook pot
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(targetItem)
        end)
    end
    
    -- Wait 1 second
    task.wait(1)
    
    -- Step 2: Calculate destination and teleport
    local destinationCFrame = nil
    local height = teleportHeight or 35
    
    if destinationPart == "Player" then
        destinationCFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, height, 0)
    elseif destinationPart == "MainFire" or destinationPart == "Campfire" then
        local campfire = workspace.Map.Campground.MainFire
        if campfire and campfire.PrimaryPart then
            destinationCFrame = campfire.PrimaryPart.CFrame * CFrame.new(0, height, 0)
        else
            return false
        end
    else
        return false
    end
    
    -- Teleport the dish
    if targetItem.PrimaryPart then
        targetItem.PrimaryPart.CFrame = destinationCFrame
    else
        return false
    end
    
    -- Wait 0.3 seconds
    task.wait(0.3)
    
    -- Step 3: Stop dragging
    local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
    if stopDragging then
        pcall(function()
            stopDragging:FireServer()
        end)
    end
    
    return true
end

-- Fast Scrapper Transporter Function - Optimized for high-speed item collection
local function FastScrapperTransporter(targetItem, destinationPart, trackingTable, teleportCooldown, savedPlayerPosition, teleportHeight)
    if not targetItem or not targetItem.Parent then
        return false
    end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local rootPart = char.HumanoidRootPart
    local itemPart = targetItem.PrimaryPart or targetItem:FindFirstChildOfClass("BasePart")
    
    if not itemPart then
        return false
    end
    
    -- Use provided height or default to 35
    local height = teleportHeight or 35
    local destinationCFrame = nil
    
    if destinationPart == "Player" then
        if savedPlayerPosition then
            destinationCFrame = savedPlayerPosition * CFrame.new(0, height, 0)
        else
            destinationCFrame = rootPart.CFrame * CFrame.new(0, height, 0)
        end
    elseif typeof(destinationPart) == "Instance" then
        local targetPart = nil
        if destinationPart:IsA("BasePart") then
            targetPart = destinationPart
        elseif destinationPart:IsA("Model") then
            targetPart = destinationPart.PrimaryPart or destinationPart:FindFirstChildOfClass("BasePart")
        end
        
        if targetPart then
            destinationCFrame = targetPart.CFrame * CFrame.new(0, height, 0)
        else
            return false
        end
    else
        return false
    end
    
    -- Fast teleportation - teleport item and player simultaneously
    itemPart.CFrame = destinationCFrame
    itemPart.AssemblyLinearVelocity = Vector3.zero
    itemPart.AssemblyAngularVelocity = Vector3.zero
    rootPart.CFrame = destinationCFrame * CFrame.new(0, 5, 0)
    
    -- Reduced wait time for faster processing
    task.wait(0.05)
    
    -- Send drag request immediately - optimized for speed
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(targetItem)
        end)
    end
    
    -- Use custom teleport cooldown instead of fixed value
    if trackingTable and targetItem then
        trackingTable[targetItem] = tick()
    end
    
    return true
end

-- Fast Gem Transporter Function - Optimized for gem collection with smart lock checking
local function FastGemTransporter(targetItem, destinationPart, trackingTable, teleportCooldown, savedPlayerPosition, teleportHeight)
    if not targetItem or not targetItem.Parent then
        return false
    end
    
    -- Check if gem is locked (skip if Locked attribute is true)
    if targetItem:GetAttribute("Locked") == true then
        -- Track this locked gem with timestamp for re-checking later
        CraftingControl.SkippedLockedGems[targetItem] = tick()
        return false -- Skip locked gems but remember them
    end
    
    -- Check if this gem was previously skipped due to being locked
    -- Re-check after 3 seconds in case lock status changed
    if CraftingControl.SkippedLockedGems[targetItem] then
        if tick() - CraftingControl.SkippedLockedGems[targetItem] < 3 then -- Less than 3 seconds
            -- Still within the 3-second wait period, check if it's still locked
            if targetItem:GetAttribute("Locked") == true then
                return false -- Still locked, skip for now
            else
                -- No longer locked! Remove from skipped list and proceed
                CraftingControl.SkippedLockedGems[targetItem] = nil
            end
        else
            -- More than 3 seconds have passed, remove from tracking and try again
            CraftingControl.SkippedLockedGems[targetItem] = nil
        end
    end
    
    local itemPart = targetItem.PrimaryPart or targetItem:FindFirstChildOfClass("BasePart")
    if not itemPart then
        return false
    end
    
    -- Use provided height or default to 35
    local height = teleportHeight or 35
    local destinationCFrame = nil
    
    if destinationPart == "Player" then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            destinationCFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, height, 0)
        else
            return false
        end
    elseif typeof(destinationPart) == "Instance" then
        local targetPart = nil
        if destinationPart:IsA("BasePart") then
            targetPart = destinationPart
        elseif destinationPart:IsA("Model") then
            targetPart = destinationPart.PrimaryPart or destinationPart:FindFirstChildOfClass("BasePart")
        end
        
        if targetPart then
            destinationCFrame = targetPart.CFrame * CFrame.new(0, height, 0)
        else
            return false
        end
    else
        return false
    end
    
    -- First grab request
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(targetItem)
        end)
    end
    
    task.wait(0.05)
    
    -- Teleport gem only (no player teleportation)
    itemPart.CFrame = destinationCFrame
    itemPart.AssemblyLinearVelocity = Vector3.zero
    itemPart.AssemblyAngularVelocity = Vector3.zero
    
    task.wait(0.05)
    
    -- Second grab request
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(targetItem)
        end)
    end
    
    -- Update tracking table
    if trackingTable and targetItem then
        trackingTable[targetItem] = tick()
    end
    
    return true
end

-- Physics-Safe Wood Transporter Function - Prevents wood collision conflicts at scrapper
local function PhysicsSafeWoodTransporter(targetItem, destinationPart, trackingTable, teleportCooldown, savedPlayerPosition, teleportHeight)
    if not targetItem or not targetItem.Parent then
        return false
    end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local rootPart = char.HumanoidRootPart
    local itemPart = targetItem.PrimaryPart or targetItem:FindFirstChildOfClass("BasePart")
    
    if not itemPart then
        return false
    end
    
    -- SPEED: Pre-cached height and direct CFrame calculation
    local height = teleportHeight or 35
    local destinationCFrame
    
    if destinationPart == "Player" then
        destinationCFrame = (savedPlayerPosition or rootPart.CFrame) * CFrame.new(0, height, 0)
    else
        -- Direct scrapper access - simple position above scrapper
        local targetPart = destinationPart:IsA("BasePart") and destinationPart or 
                          (destinationPart:IsA("Model") and (destinationPart.PrimaryPart or destinationPart:FindFirstChildOfClass("BasePart")))
        
        if targetPart then
            local offsetX, offsetZ = 0, 0
            if CraftingControl and destinationPart == workspace.Map.Campground.Scrapper then
                local woodOffsets = CraftingControl.WoodSquareOffsets
                if not woodOffsets then
                    woodOffsets = {
                        {x = -3.0, z = -2.6},
                        {x = 3.0, z = -2.6},
                        {x = -3.0, z = 2.6},
                        {x = 3.0, z = 2.6}
                    }
                    CraftingControl.WoodSquareOffsets = woodOffsets
                end
                CraftingControl.WoodSquareIndex = (CraftingControl.WoodSquareIndex or 0) + 1
                local index = ((CraftingControl.WoodSquareIndex - 1) % #woodOffsets) + 1
                local offsetData = woodOffsets[index]
                offsetX, offsetZ = offsetData.x, offsetData.z
            end
            destinationCFrame = targetPart.CFrame * CFrame.new(offsetX, height, offsetZ)
        else
            return false
        end
    end
    
    -- Keep collision enabled regardless of destination so scrapper behaves exactly like player
    local shouldDisableCollision = false
    local originalCanCollide = itemPart.CanCollide
    
    if shouldDisableCollision then
        itemPart.CanCollide = false
        
        -- Track this item for re-enabling collision later
        CraftingControl.DisabledCollisionItems[targetItem] = {
            part = itemPart,
            originalCanCollide = originalCanCollide,
            timestamp = tick()
        }
    end
    
    -- INSTANT drag request (ask server FIRST before teleporting)
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        requestStartDragging:FireServer(targetItem)
    end
    
    -- ULTRA FAST WOOD TELEPORTATION - MAXIMUM SPEED MODE (only AFTER server request)
    itemPart.CFrame = destinationCFrame
    itemPart.AssemblyLinearVelocity = Vector3.zero
    itemPart.AssemblyAngularVelocity = Vector3.zero
    
    -- Stop dragging after teleportation
    local requestStopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
    if requestStopDragging then
        requestStopDragging:FireServer()
    end
    
    -- INSTANT collision re-enable (only if we disabled it)
    if shouldDisableCollision and targetItem and targetItem.Parent and CraftingControl.DisabledCollisionItems[targetItem] then
        local itemData = CraftingControl.DisabledCollisionItems[targetItem]
        if itemData.part and itemData.part.Parent then
            itemData.part.CanCollide = itemData.originalCanCollide
        end
        CraftingControl.DisabledCollisionItems[targetItem] = nil
    end
    
    -- Update tracking table
    if trackingTable and targetItem then
        trackingTable[targetItem] = tick()
    end
    
    return true
end

-- Cleanup function for collision-disabled items (prevents memory leaks)
local function CleanupCollisionDisabledItems()
    local currentTime = tick()
    for item, data in pairs(CraftingControl.DisabledCollisionItems) do
        -- Clean up items that are older than 5 seconds or no longer exist
        if not item or not item.Parent or currentTime - data.timestamp > 5 then
            if data.part and data.part.Parent then
                data.part.CanCollide = data.originalCanCollide
            end
            CraftingControl.DisabledCollisionItems[item] = nil
        end
    end
end

-- Function to find cultists in workspace.Items
local function FindCultistsInItems()
    local cultists = {}
    
    for _, item in pairs(WorkspaceItems:GetChildren()) do
        -- Check if it's a cultist type we want to transport
        if item.Name == "Cultist" or item.Name == "Crossbow Cultist" then
            -- Skip if already teleported recently
            if CultistControl.TeleportedCultists[item] and 
               tick() - CultistControl.TeleportedCultists[item] < CultistControl.TeleportCooldown then
                continue
            end
            
            -- Check if cultist has HumanoidRootPart
            if item:FindFirstChild("HumanoidRootPart") then
                table.insert(cultists, item)
            end
        end
    end
    
    return cultists
end

-- Function to teleport cultist to volcano and send grab request
local function TeleportCultistToVolcano(cultist)
    if not cultist or not cultist.Parent then
        return false
    end
    
    -- Get the volcano ground destination
    local volcanoGround = workspace:FindFirstChild("Map")
    if volcanoGround then
        volcanoGround = volcanoGround:FindFirstChild("Landmarks")
        if volcanoGround then
            volcanoGround = volcanoGround:FindFirstChild("Volcano")
            if volcanoGround then
                volcanoGround = volcanoGround:FindFirstChild("Functional")
                if volcanoGround then
                    volcanoGround = volcanoGround:FindFirstChild("Ground")
                end
            end
        end
    end
    
    if not volcanoGround or not volcanoGround:IsA("BasePart") then
        return false
    end
    
    local humanoidRootPart = cultist:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return false
    end
    
    -- Teleport cultist to volcano ground with height offset
    local destinationCFrame = volcanoGround.CFrame * CFrame.new(0, 5, 0)
    humanoidRootPart.CFrame = destinationCFrame
    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
    humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
    
    -- Small delay then send grab request
    task.wait(0.1)
    
    -- Send drag request
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(cultist)
        end)
    end
    
    -- Mark cultist as teleported
    CultistControl.TeleportedCultists[cultist] = tick()
    
    return true
end

-- Main cultist transporter function
local function CultistTransporter()
    if not CultistControl.TransportEnabled then
        return
    end
    
    -- Cooldown check
    if tick() - CultistControl.LastTeleportTime < CultistControl.TeleportCooldown then
        return
    end
    
    -- Find available cultists
    local availableCultists = FindCultistsInItems()
    
    if #availableCultists > 0 then
        -- Transport first available cultist
        local cultist = availableCultists[1]
        if TeleportCultistToVolcano(cultist) then
            CultistControl.LastTeleportTime = tick()
        end
    end
    
    -- Clean up tracking table for destroyed/missing cultists
    for trackedCultist, _ in pairs(CultistControl.TeleportedCultists) do
        if not trackedCultist or not trackedCultist.Parent then
            CultistControl.TeleportedCultists[trackedCultist] = nil
        end
    end
end

-- Function to get stronghold timer text
local function GetStrongholdTimer()
    local success, timerText = pcall(function()
        local stronghold = WorkspaceMap.Landmarks:FindFirstChild("Stronghold")
        if not stronghold then return "Stronghold not found" end
        
        local functionalFolder = stronghold:FindFirstChild("Functional", true)
        if not functionalFolder then return "No functional folder" end
        
        local signTextLabel = functionalFolder:FindFirstChild("Sign", true)
            and functionalFolder.Sign:FindFirstChild("SurfaceGui", true)
            and functionalFolder.Sign.SurfaceGui:FindFirstChild("Frame", true)
            and functionalFolder.Sign.SurfaceGui.Frame:FindFirstChild("Body", true)
        
        if not signTextLabel then return "Sign not found" end
        
        return signTextLabel.ContentText or "No timer text"
    end)
    
    if success then
        return timerText
    else
        return "Error reading timer"
    end
end

-- Function to update stronghold timer label
local function UpdateStrongholdTimerLabel()
    if not WorldStatusControl.StrongholdTimer.TimerLabel then
        return
    end
    
    local currentTime = tick()
    if currentTime - WorldStatusControl.StrongholdTimer.LastUpdateTime < 1 then
        return -- Update only once per second
    end
    WorldStatusControl.StrongholdTimer.LastUpdateTime = currentTime
    
    local timerText = GetStrongholdTimer()
    local displayText = "🏰 Stronghold Timer: " .. timerText
    
    -- Update the label
    WorldStatusControl.StrongholdTimer.TimerLabel:Set(displayText)
end

-- Function to get day/night cycle information
local function GetDayNightInfo()
    local success, info = pcall(function()
        local state = Workspace:GetAttribute("State") or "Unknown"
        local secondsLeft = Workspace:GetAttribute("SecondsLeft") or 0
        local storyDayCounter = Workspace:GetAttribute("StoryDayCounter") or 0
        local cultistAttackDay = Workspace:GetAttribute("CultistAttackDay") or false
        
        return {
            state = state,
            secondsLeft = secondsLeft,
            storyDayCounter = storyDayCounter,
            cultistAttackDay = cultistAttackDay
        }
    end)
    
    if success then
        return info
    else
        return {
            state = "Error",
            secondsLeft = 0,
            storyDayCounter = 0,
            cultistAttackDay = false
        }
    end
end

-- Function to format time from seconds to MM:SS
local function FormatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%02d", minutes, secs)
end

-- Function to update day/night cycle labels
local function UpdateDayNightLabels()
    if not (WorldStatusControl.DayNight.StateLabel and WorldStatusControl.DayNight.DayCounterLabel and WorldStatusControl.DayNight.CultistAttackLabel) then
        return
    end
    
    local currentTime = tick()
    if currentTime - WorldStatusControl.DayNight.LastUpdateTime < 1 then
        return -- Update only once per second
    end
    WorldStatusControl.DayNight.LastUpdateTime = currentTime
    
    local info = GetDayNightInfo()
    
    -- Update state and countdown label
    local stateIcon = info.state == "Day" and "☀️" or (info.state == "Night" and "🌙" or "❓")
    local timeFormatted = FormatTime(info.secondsLeft)
    local stateText = stateIcon .. " " .. info.state .. " - Time Left: " .. timeFormatted
    WorldStatusControl.DayNight.StateLabel:Set(stateText)
    
    -- Update day counter label
    local dayCounterText = "📅 Story Day: " .. info.storyDayCounter
    WorldStatusControl.DayNight.DayCounterLabel:Set(dayCounterText)
    
    -- Update cultist attack day label
    local cultistIcon = info.cultistAttackDay and "✅" or "❌"
    local cultistText = "⚔️ Cultist Attack Day: " .. cultistIcon
    WorldStatusControl.DayNight.CultistAttackLabel:Set(cultistText)
end

-- Smart night skip function
local function SmartNightSkipper()
    if not WorldStatusControl.SmartNightSkip.SkipEnabled then
        return
    end
    
    -- Get current game state
    local state = Workspace:GetAttribute("State")
    local secondsLeft = Workspace:GetAttribute("SecondsLeft") or 0
    
    -- Check trigger conditions (removed cultist attack day requirement)
    if state == "Night" and secondsLeft <= 90 and secondsLeft >= 86 then
        -- Find the Temporal Accelerometer and skip night
        local temporalAccelerometer = WorkspaceStructures:FindFirstChild("Temporal Accelerometer")
        if temporalAccelerometer then
            local nightSkipRemote = RemoteEvents:FindFirstChild("RequestActivateNightSkipMachine")
            if nightSkipRemote then
                local args = {
                    [1] = temporalAccelerometer
                }
                nightSkipRemote:FireServer(unpack(args))
            end
        end
    end
end

-- Night skip function
-- Respawn capsule recharge function
local function RespawnCapsuleRecharger()
    if not WorldStatusControl.RespawnCapsule.RechargeEnabled then
        return
    end
    
    -- Find the Respawn Capsule
    local respawnCapsule = workspace.Structures:FindFirstChild("Respawn Capsule")
    if not respawnCapsule then
        return
    end
    
    -- Send respawn capsule recharge request
    local success, errorMsg = pcall(function()
        local rechargeRespawnRemote = RemoteEvents:FindFirstChild("RequestRechargeRespawnBeacon")
        if rechargeRespawnRemote then
            local args = {
                [1] = respawnCapsule
            }
            rechargeRespawnRemote:FireServer(unpack(args))
        end
    end)
    
    if not success then
        warn("Failed to recharge respawn capsule: " .. tostring(errorMsg))
    end
end

-- Simple Sack Refill Process
local function SackRefillProcess(foundItem)
    local sack = findPlayerInventorySack()
    if not sack then
        CampfireControl.AutoRefillEnabled = false
        return false
    end
    
    if isSackFull() then
        CampfireControl.AutoRefillEnabled = false
        CampfireControl.SavedPlayerPosition = nil
        return false
    end
    
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoidRootPart = character.HumanoidRootPart
    local originalPosition = CampfireControl.SavedPlayerPosition or humanoidRootPart.CFrame
    
    local rootPart = foundItem:FindFirstChild("Root") or foundItem.PrimaryPart
    if not rootPart then
        return false
    end
    
    -- Teleport player to item
    humanoidRootPart.CFrame = rootPart.CFrame + Vector3.new(0, 5, 0)
    wait(0.1)
    
    -- Bag item
    local bagStoreRemote = RemoteEvents:FindFirstChild("RequestBagStoreItem")
    if bagStoreRemote then
        pcall(function()
            bagStoreRemote:InvokeServer(sack, foundItem)
        end)
    end
    
    wait(0.3)
    
    -- Always return to original position after collecting item
    humanoidRootPart.CFrame = originalPosition
    
    -- Check if sack is now full
    if isSackFull() then
        CampfireControl.AutoRefillEnabled = false
        CampfireControl.SavedPlayerPosition = nil
    end
    
    return true
end

-- Simple Sack Crafting Process
local function SackCraftingProcess(foundItem)
    local sack = findPlayerInventorySack()
    if not sack then
        CraftingControl.ProduceScrapEnabled = false
        CraftingControl.ProduceWoodEnabled = false
        CraftingControl.ProduceCultistGemEnabled = false
        return false
    end
    
    if isSackFull() then
        CraftingControl.ProduceScrapEnabled = false
        CraftingControl.ProduceWoodEnabled = false
        CraftingControl.ProduceCultistGemEnabled = false
        CraftingControl.SavedPlayerPosition = nil
        return false
    end
    
    local player = game.Players.LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoidRootPart = character.HumanoidRootPart
    local originalPosition = CraftingControl.SavedPlayerPosition or humanoidRootPart.CFrame
    
    local rootPart = foundItem:FindFirstChild("Root") or foundItem.PrimaryPart
    if not rootPart then
        return false
    end
    
    -- Teleport player to item
    humanoidRootPart.CFrame = rootPart.CFrame + Vector3.new(0, 5, 0)
    wait(0.9)
    
    -- Bag item
    local bagStoreRemote = RemoteEvents:FindFirstChild("RequestBagStoreItem")
    if bagStoreRemote then
        pcall(function()
            bagStoreRemote:InvokeServer(sack, foundItem)
        end)
    end
    
    wait(0.9)
    
    -- Always return to original position after collecting item
    humanoidRootPart.CFrame = originalPosition
    
    -- Check if sack is now full
    if isSackFull() then
        CraftingControl.ProduceScrapEnabled = false
        CraftingControl.ProduceWoodEnabled = false
        CraftingControl.ProduceCultistGemEnabled = false
        CraftingControl.SavedPlayerPosition = nil
    end
    
    return true
end

-- Get campfire fuel percentage
local function GetCampfireFuelPercentage()
    local campfire = workspace:FindFirstChild("Map")
    if campfire then
        campfire = campfire:FindFirstChild("Campground")
        if campfire then
            campfire = campfire:FindFirstChild("MainFire")
            if campfire then
                local fuelRemaining = campfire:GetAttribute("FuelRemaining") or 0
                local fuelTarget = campfire:GetAttribute("FuelTarget") or 1
                return (fuelRemaining / fuelTarget) * 100
            end
        end
    end
    return 100 -- Default to full if can't find campfire
end



-- Find refill items in workspace
local function FindRefillItems()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return items
    end
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        local shouldAdd = false
        local itemPart = nil
        local itemType = nil
        
        -- Skip items that are being used for crafting
        if CraftingControl.UsedItemsForCrafting[item] then
            continue
        end
        
        -- Check for Log items
        local mainPart = item:FindFirstChild("Main")
        if mainPart and (item.Name:lower():find("log") or item.Name:lower():find("wood")) then
            itemPart = mainPart
            itemType = "Log"
            shouldAdd = true
        end
        
        -- Check for Coal items
        local coalPart = item:FindFirstChild("Coal")
        if coalPart then
            itemPart = coalPart
            itemType = "Coal"
            shouldAdd = true
        end
        
        -- Check for Fuel Canister items
        if mainPart and item.Name == "Fuel Canister" then
            itemPart = mainPart
            itemType = "Fuel Canister"
            shouldAdd = true
        end
        
        -- Check for Oil Barrel items
        if mainPart and item.Name == "Oil Barrel" then
            itemPart = mainPart
            itemType = "Oil Barrel"
            shouldAdd = true
        end
        
        -- Only add if we should and it matches our filter
        if shouldAdd and itemPart then
            if CampfireControl.RefillItemType == "All" or CampfireControl.RefillItemType == itemType then
                table.insert(items, {
                    Item = item,
                    Part = itemPart,
                    Type = itemType,
                    Position = itemPart.Position
                })
            end
        end
    end
    
    return items
end

-- Teleport refill item to campfire using UltimateItemTransporter
local function TeleportItemToCampfire(item, itemPart)
    local destination
    if CampfireControl.TeleportDestination == "Campfire" then
        destination = workspace.Map.Campground.MainFire
    elseif CampfireControl.TeleportDestination == "Player" then
        destination = "Player"
    elseif CampfireControl.TeleportDestination == "Sack" then
        local success = SackRefillProcess(item)
        if success then
            CampfireControl.TeleportedItems[item] = tick()
        end
        return success
    end
    
    if destination then
        local success = UltimateItemTransporter(item, destination, nil, 120, CampfireControl.SavedPlayerPosition, CampfireControl.TeleportHeight)
        if success then
            return true
        else
            return false
        end
    end
    return false
end

-- Execute campfire refill
local function UpdateCampfireRefill()
    if not CampfireControl.AutoRefillEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - CampfireControl.LastRefillCheck < CampfireControl.RefillCheckCooldown then
        return
    end
    
    CampfireControl.LastRefillCheck = currentTime
    
    -- Check fuel percentage (skip if continuous refill is enabled)
    if not CampfireControl.ContinuousRefillEnabled then
        local fuelPercentage = GetCampfireFuelPercentage()
        if fuelPercentage > CampfireControl.RefillPercentage then
            return -- No need to refill yet
        end
    end
    
    -- Find refill items
    local refillItems = FindRefillItems()
    if #refillItems == 0 then
        return -- No items available
    end
    
    -- Clean up teleported items tracking (remove items that no longer exist)
    local validTeleportedItems = {}
    for item, timestamp in pairs(CampfireControl.TeleportedItems) do
        if item.Parent and (currentTime - timestamp) < 120 then -- 30 second cooldown per item
            validTeleportedItems[item] = timestamp
        end
    end
    CampfireControl.TeleportedItems = validTeleportedItems
    
    -- Filter out already teleported items
    local availableItems = {}
    for _, itemData in ipairs(refillItems) do
        if not CampfireControl.TeleportedItems[itemData.Item] then
            table.insert(availableItems, itemData)
        end
    end
    
    -- Update refillItems to only include available items
    refillItems = availableItems
    
    if #refillItems == 0 then
        return -- No new items to teleport
    end
    
    -- Teleport the first available item to campfire
    local item = refillItems[1]
    
    -- Mark item immediately to prevent duplicate attempts
    CampfireControl.TeleportedItems[item.Item] = currentTime
    
    local success = TeleportItemToCampfire(item.Item, item.Part)
    
    if success then
        -- Use the configurable cooldown for next refill attempt
        CampfireControl.LastRefillCheck = currentTime
    else
        -- If teleport failed, remove the mark so it can be tried again
        CampfireControl.TeleportedItems[item.Item] = nil
    end
end

-- Find scrap items in workspace (avoiding conflicts with campfire)
local function FindScrapItems()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return items
    end
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        local shouldAdd = false
        local itemPart = nil
        local itemType = nil
        
        -- Check for scrap items
        local mainPart = item:FindFirstChild("Main")
        if mainPart then
            -- Check specific scrap item types
            if item.Name == "Bolt" then
                itemPart = mainPart
                itemType = "Bolt"
                shouldAdd = true
            elseif item.Name == "Sheet Metal" then
                itemPart = mainPart
                itemType = "Sheet Metal"
                shouldAdd = true
            elseif item.Name == "Broken Fan" then
                itemPart = mainPart
                itemType = "Broken Fan"
                shouldAdd = true
            elseif item.Name == "Old Radio" then
                itemPart = mainPart
                itemType = "Old Radio"
                shouldAdd = true
            elseif item.Name == "Broken Microwave" then
                itemPart = mainPart
                itemType = "Broken Microwave"
                shouldAdd = true
            elseif item.Name == "Tyre" then
                itemPart = mainPart
                itemType = "Tyre"
                shouldAdd = true
            elseif item.Name == "Metal Chair" then
                itemPart = mainPart
                itemType = "Metal Chair"
                shouldAdd = true
            elseif item.Name == "Old Car Engine" then
                itemPart = mainPart
                itemType = "Old Car Engine"
                shouldAdd = true
            elseif item.Name == "Washing Machine" then
                itemPart = mainPart
                itemType = "Washing Machine"
                shouldAdd = true
            elseif item.Name == "Cultist Experiment" then
                itemPart = mainPart
                itemType = "Cultist Experiment"
                shouldAdd = true
            elseif item.Name == "Cultist Prototype" then
                itemPart = mainPart
                itemType = "Cultist Prototype"
                shouldAdd = true
            elseif item.Name == "UFO Scrap" then
                itemPart = mainPart
                itemType = "UFO Scrap"
                shouldAdd = true
            end
        end
        
        -- Only add if we should and it matches our filter
        if shouldAdd and itemPart then
            if CraftingControl.ScrapItemType == "All" or CraftingControl.ScrapItemType == itemType then
                table.insert(items, {
                    Item = item,
                    Part = itemPart,
                    Type = itemType,
                    Position = itemPart.Position
                })
            end
        end
    end
    
    return items
end

-- ULTRA FAST Find wood items for crafting (optimized for speed)
local function FindWoodItemsForCrafting()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return items
    end
    
    -- SPEED OPTIMIZATION: Pre-check if we want "All" to skip filtering
    local needFiltering = (CraftingControl.WoodItemType ~= "All")
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        -- SPEED: Direct name check without lower() conversion first
        local itemName = item.Name
        if itemName:find("Log") or itemName:find("Wood") or itemName:lower():find("log") or itemName:lower():find("wood") then
            local mainPart = item:FindFirstChild("Main")
            if mainPart then
                -- SPEED: Skip type filtering if "All" is selected
                if not needFiltering or CraftingControl.WoodItemType == "Log" then
                    table.insert(items, {
                        Item = item,
                        Part = mainPart,
                        Type = "Log",
                        Position = mainPart.Position
                    })
                end
            end
        end
    end
    
    return items
end

-- 🪐 PLANETARY SYSTEM: Create a rotating planet with ring system using logs!
local function BringAllLogsToPlanet()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return
    end
    
    local campfire = workspace.Map.Campground.MainFire
    if not campfire then
        return
    end
    
    -- Get the Center part of MainFire to get position
    local campfireCenter = campfire:FindFirstChild("Center")
    if not campfireCenter then
        return
    end
    
    local allLogs = {}
    local logCount = 0
    
    -- STEP 1: Find ALL logs in the entire workspace
    for _, item in pairs(itemsFolder:GetChildren()) do
        local itemName = item.Name
        if itemName:find("Log") or itemName:find("Wood") or itemName:lower():find("log") or itemName:lower():find("wood") then
            local mainPart = item:FindFirstChild("Main")
            if mainPart then
                table.insert(allLogs, {
                    Item = item,
                    Part = mainPart
                })
                logCount = logCount + 1
            end
        end
    end
    
    if logCount == 0 then
        return
    end
    
    -- STEP 1.5: SEND DRAG REQUESTS TO ALL LOGS BEFORE TRANSPORT! 🎯
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        for _, logData in ipairs(allLogs) do
            requestStartDragging:FireServer(logData.Item)
        end
    end
    
    -- STEP 2: PLANETARY SYSTEM FORMATION! 🪐
    local campfirePos = campfireCenter.Position
    local planetCenter = campfirePos + Vector3.new(0, 60, 0) -- Planet center 60 studs up
    
    -- Calculate distribution: Planet core + 2 rings (REDUCED CORE)
    local planetLogs = math.floor(logCount * 0.2)  -- 20% for planet core (reduced from 40%)
    local ring1Logs = math.floor(logCount * 0.4)   -- 40% for inner ring (increased from 30%)
    local ring2Logs = logCount - planetLogs - ring1Logs -- Remaining for outer ring
    
    local currentLogIndex = 1
    
    -- PLANETARY ROTATION VARIABLES
    local planetRotationSpeed = 0.8 -- Degrees per frame for planet spin (ENABLED!)
    local ring1RotationSpeed = 1 -- Inner ring rotation speed
    local ring2RotationSpeed = 0.5 -- Outer ring rotation speed (slower)
    local planetAxis = Vector3.new(0, 1, 0) -- Y-axis rotation (like Earth)
    
    -- Store logs for continuous rotation
    local planetLogs_Array = {}
    local ring1Logs_Array = {}
    local ring2Logs_Array = {}
    
    -- STEP 3: BUILD PLANET CORE (SPHERE)
    local planetRadius = 12
    for i = 1, planetLogs do
        if currentLogIndex > logCount then break end
        
        local logData = allLogs[currentLogIndex]
        local itemPart = logData.Part
        local item = logData.Item
        
        -- Random spherical coordinates for planet surface
        local phi = math.random() * 2 * math.pi      -- Azimuth angle
        local theta = math.acos(2 * math.random() - 1) -- Polar angle (uniform distribution)
        
        local x = planetRadius * math.sin(theta) * math.cos(phi)
        local y = planetRadius * math.cos(theta) + math.random(-2, 2)
        local z = planetRadius * math.sin(theta) * math.sin(phi)
        
        local targetPosition = planetCenter + Vector3.new(x, y, z)
        
        -- DISABLE COLLISION for smoother formations
        itemPart.CanCollide = false
        
        -- Store relative position for rotation calculation
        local relativePos = Vector3.new(x, y, z)
        
        -- INSTANT TELEPORTATION with initial rotation
        itemPart.CFrame = CFrame.new(targetPosition)
        itemPart.AssemblyLinearVelocity = Vector3.zero
        itemPart.AssemblyAngularVelocity = Vector3.zero
        
        -- Store log data for rotation
        table.insert(planetLogs_Array, {
            Item = item,
            Part = itemPart,
            RelativePosition = relativePos
        })
        
        currentLogIndex = currentLogIndex + 1
    end
    
    task.wait(0.2) -- Brief pause between formations
    
    -- STEP 4: BUILD INNER RING 💍 (TILTED FOR CROSSING EFFECT)
    local ring1Radius = 25
    local ring1Thickness = 3
    local ring1Tilt = math.rad(30) -- 30 degree tilt
    for i = 1, ring1Logs do
        if currentLogIndex > logCount then break end
        
        local logData = allLogs[currentLogIndex]
        local itemPart = logData.Part
        local item = logData.Item
        
        -- Ring formation with slight thickness variation
        local angle = (i / ring1Logs) * 2 * math.pi
        local radiusVariation = math.random(-ring1Thickness, ring1Thickness)
        local currentRadius = ring1Radius + radiusVariation
        
        -- Base ring position
        local x = math.cos(angle) * currentRadius
        local y = math.random(-2, 2) -- Small vertical variation
        local z = math.sin(angle) * currentRadius
        
        -- Apply tilt rotation to create crossing rings
        local ringPos = Vector3.new(x, y, z)
        local tiltMatrix = CFrame.Angles(ring1Tilt, 0, 0)
        local tiltedPos = tiltMatrix:VectorToWorldSpace(ringPos)
        
        local targetPosition = planetCenter + tiltedPos
        
        -- DISABLE COLLISION
        itemPart.CanCollide = false
        
        -- TANGENT ROTATION (logs align with ring direction - HORIZONTAL/SLEEPING)
        local tangentRotation = CFrame.Angles(math.rad(90), angle + math.rad(90), 0) -- Laying on side
        
        -- INSTANT TELEPORTATION with proper rotation
        itemPart.CFrame = CFrame.new(targetPosition) * tiltMatrix * tangentRotation
        itemPart.AssemblyLinearVelocity = Vector3.zero
        itemPart.AssemblyAngularVelocity = Vector3.zero
        
        -- Store log data for rotation
        table.insert(ring1Logs_Array, {
            Item = item,
            Part = itemPart,
            BaseAngle = angle,
            Radius = currentRadius,
            TiltMatrix = tiltMatrix,
            HeightOffset = y
        })
        
        currentLogIndex = currentLogIndex + 1
    end
    
    task.wait(0.2) -- Brief pause between rings
    
    -- STEP 5: BUILD OUTER RING 🌌 (DIFFERENT TILT FOR CROSSING)
    local ring2Radius = 40
    local ring2Thickness = 4
    local ring2Tilt = math.rad(-45) -- -45 degree tilt (opposite direction)
    for i = 1, ring2Logs do
        if currentLogIndex > logCount then break end
        
        local logData = allLogs[currentLogIndex]
        local itemPart = logData.Part
        local item = logData.Item
        
        -- Outer ring formation with more thickness variation
        local angle = (i / ring2Logs) * 2 * math.pi
        local radiusVariation = math.random(-ring2Thickness, ring2Thickness)
        local currentRadius = ring2Radius + radiusVariation
        
        -- Base ring position
        local x = math.cos(angle) * currentRadius
        local y = math.random(-3, 3) -- Slightly more vertical variation
        local z = math.sin(angle) * currentRadius
        
        -- Apply different tilt rotation for crossing effect
        local ringPos = Vector3.new(x, y, z)
        local tiltMatrix = CFrame.Angles(ring2Tilt, 0, 0)
        local tiltedPos = tiltMatrix:VectorToWorldSpace(ringPos)
        
        local targetPosition = planetCenter + tiltedPos
        
        -- DISABLE COLLISION
        itemPart.CanCollide = false
        
        -- TANGENT ROTATION (HORIZONTAL/SLEEPING)
        local tangentRotation = CFrame.Angles(math.rad(90), angle + math.rad(90), 0) -- Laying on side
        
        -- INSTANT TELEPORTATION with proper rotation
        itemPart.CFrame = CFrame.new(targetPosition) * tiltMatrix * tangentRotation
        itemPart.AssemblyLinearVelocity = Vector3.zero
        itemPart.AssemblyAngularVelocity = Vector3.zero
        
        -- Store log data for rotation
        table.insert(ring2Logs_Array, {
            Item = item,
            Part = itemPart,
            BaseAngle = angle,
            Radius = currentRadius,
            TiltMatrix = tiltMatrix,
            HeightOffset = y
        })
        
        currentLogIndex = currentLogIndex + 1
    end
    
    -- STEP 7: START ROTATION SYSTEM! 🌍 (ALL ROTATING!)
    local planetAngle = 0
    local ring1Angle = 0
    local ring2Angle = 0
    
    -- Store rotation task for stopping later
    TreesControl.PlanetRotationTask = task.spawn(function()
        while TreesControl.PlanetLogEnabled do
            -- Update rotation angles (ALL COMPONENTS ROTATE!)
            planetAngle = planetAngle + math.rad(planetRotationSpeed)
            ring1Angle = ring1Angle + math.rad(ring1RotationSpeed)
            ring2Angle = ring2Angle + math.rad(ring2RotationSpeed)
            
            -- ROTATE PLANET CORE SPHERE
            for _, logData in ipairs(planetLogs_Array) do
                if logData.Item and logData.Item.Parent and logData.Part and logData.Part.Parent then
                    -- Rotate the relative position around Y-axis
                    local rotatedPos = CFrame.Angles(0, planetAngle, 0):VectorToWorldSpace(logData.RelativePosition)
                    local newPosition = planetCenter + rotatedPos
                    
                    -- Apply rotation to the log itself for spinning effect
                    local logRotation = CFrame.Angles(0, planetAngle, 0)
                    
                    logData.Part.CFrame = CFrame.new(newPosition) * logRotation
                    logData.Part.AssemblyLinearVelocity = Vector3.zero
                    logData.Part.AssemblyAngularVelocity = Vector3.zero
                end
            end
            
            -- Rotate inner ring logs
            for _, logData in ipairs(ring1Logs_Array) do
                if logData.Item and logData.Item.Parent and logData.Part and logData.Part.Parent then
                    local currentAngle = logData.BaseAngle + ring1Angle
                    
                    -- Calculate new ring position
                    local x = math.cos(currentAngle) * logData.Radius
                    local y = logData.HeightOffset
                    local z = math.sin(currentAngle) * logData.Radius
                    
                    local ringPos = Vector3.new(x, y, z)
                    local tiltedPos = logData.TiltMatrix:VectorToWorldSpace(ringPos)
                    local newPosition = planetCenter + tiltedPos
                    
                    -- Update rotation to match new angle (HORIZONTAL/SLEEPING)
                    local tangentRotation = CFrame.Angles(math.rad(90), currentAngle + math.rad(90), 0)
                    
                    logData.Part.CFrame = CFrame.new(newPosition) * logData.TiltMatrix * tangentRotation
                    logData.Part.AssemblyLinearVelocity = Vector3.zero
                    logData.Part.AssemblyAngularVelocity = Vector3.zero
                end
            end
            
            -- Rotate outer ring logs
            for _, logData in ipairs(ring2Logs_Array) do
                if logData.Item and logData.Item.Parent and logData.Part and logData.Part.Parent then
                    local currentAngle = logData.BaseAngle + ring2Angle
                    
                    -- Calculate new ring position
                    local x = math.cos(currentAngle) * logData.Radius
                    local y = logData.HeightOffset
                    local z = math.sin(currentAngle) * logData.Radius
                    
                    local ringPos = Vector3.new(x, y, z)
                    local tiltedPos = logData.TiltMatrix:VectorToWorldSpace(ringPos)
                    local newPosition = planetCenter + tiltedPos
                    
                    -- Update rotation to match new angle (HORIZONTAL/SLEEPING)
                    local tangentRotation = CFrame.Angles(math.rad(90), currentAngle + math.rad(90), 0)
                    
                    logData.Part.CFrame = CFrame.new(newPosition) * logData.TiltMatrix * tangentRotation
                    logData.Part.AssemblyLinearVelocity = Vector3.zero
                    logData.Part.AssemblyAngularVelocity = Vector3.zero
                end
            end
            
            task.wait(0.03) -- ~33 FPS rotation updates
        end
    end)
    
end

-- 🔥 CRAZY FUNCTION: Bring ALL logs to campfire in a massive cloud formation!
local function BringAllLogsToCloud()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return
    end
    
    local campfire = workspace.Map.Campground.MainFire
    if not campfire then
        return
    end
    
    -- Get the Center part of MainFire to get position
    local campfireCenter = campfire:FindFirstChild("Center")
    if not campfireCenter then
        return
    end
    
    local cloudHeight = 50 -- 50 studs above campfire
    local allLogs = {}
    local logCount = 0
    
    -- STEP 1: Find ALL logs in the entire workspace
    for _, item in pairs(itemsFolder:GetChildren()) do
        local itemName = item.Name
        if itemName:find("Log") or itemName:find("Wood") or itemName:lower():find("log") or itemName:lower():find("wood") then
            local mainPart = item:FindFirstChild("Main")
            if mainPart then
                table.insert(allLogs, {
                    Item = item,
                    Part = mainPart
                })
                logCount = logCount + 1
            end
        end
    end
    
    if logCount == 0 then
        return
    end
    
    -- STEP 2: Calculate CIRCULAR DOME ROOF formation 
    local campfirePos = campfireCenter.Position
    local roofBaseHeight = cloudHeight -- Base height for the roof
    
    -- STEP 3: CREATE CIRCULAR LOG ROOF - USE ALL LOGS!
    local successCount = 0
    local maxRings = 6 -- Number of circular rings to create
    local maxRadius = 25 -- Maximum radius for outer ring
    local centerHeight = roofBaseHeight + 15 -- Center is highest
    
    -- Calculate how many logs per ring to use ALL logs
    local logsPerRing = math.ceil(logCount / maxRings)
    local currentLogIndex = 1
    
    for ring = 1, maxRings do
        if currentLogIndex > logCount then break end
        
        -- Calculate ring properties
        local ringRadius = (ring / maxRings) * maxRadius
        local ringHeight = centerHeight - (ring / maxRings) * 10 -- Dome shape: center highest, edges lower
        
        -- Use ALL remaining logs or the calculated amount per ring (NO ARTIFICIAL LIMITS!)
        local logsInThisRing = math.min(logsPerRing, logCount - currentLogIndex + 1)
        local angleStep = (2 * math.pi) / logsInThisRing
        
        -- Place logs in circular formation for this ring
        for logInRing = 1, logsInThisRing do
            if currentLogIndex > logCount then break end
            
            local logData = allLogs[currentLogIndex]
            local itemPart = logData.Part
            local item = logData.Item
            
            -- Calculate circular position for this log
            local angle = (logInRing - 1) * angleStep
            local x = math.cos(angle) * ringRadius
            local z = math.sin(angle) * ringRadius
            local y = ringHeight + math.random(-2, 2) -- Small height variation for natural look
            
            local targetPosition = campfirePos + Vector3.new(x, y, z)
            
            -- INSTANT TELEPORTATION to roof formation (COLLISION ENABLED!)
            itemPart.CFrame = CFrame.new(targetPosition)
            itemPart.AssemblyLinearVelocity = Vector3.zero
            itemPart.AssemblyAngularVelocity = Vector3.zero
            
            -- Send drag request after positioning for proper item activation
            task.spawn(function()
                task.wait(0.1)
                local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
                if requestStartDragging and item and item.Parent then
                    requestStartDragging:FireServer(item)
                end
            end)
            
            successCount = successCount + 1
            currentLogIndex = currentLogIndex + 1
        end
        
        -- Small delay between rings to prevent lag
        task.wait(0.05)
    end
    
end

-- ITEM TROLL: Bring ALL items to main fire with proper spacing and batch processing
local function BringAllItemsToMainFire()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return
    end
    
    local campfire = workspace.Map.Campground.MainFire
    if not campfire then
        return
    end
    
    -- Get the Center part of MainFire to get position
    local campfireCenter = campfire:FindFirstChild("Center")
    if not campfireCenter then
        return
    end
    
    local allItems = {}
    local itemCount = 0
    
    -- STEP 1: Find ALL items in workspace (excluding Chests, Saplings, and Logs)
    for _, item in pairs(itemsFolder:GetChildren()) do
        local itemPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
        local itemName = item.Name:lower()
        
        -- Skip chests, saplings, and logs
        local shouldSkip = string.find(itemName, "chest") or 
                          string.find(itemName, "sapling") or 
                          string.find(itemName, "log")
        
        if itemPart and not shouldSkip then
            table.insert(allItems, {Item = item, Part = itemPart})
            itemCount = itemCount + 1
        end
    end
    
    if itemCount == 0 then
        return
    end
    
    -- STEP 2: Calculate positioning with more spacing
    local campfirePos = campfireCenter.Position
    local spacing = 8 -- More space between items (increased from logs)
    local itemsPerRow = math.ceil(math.sqrt(itemCount)) -- Calculate square grid
    local currentItemIndex = 1
    
    -- Get RemoteEvents for drag requests
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    
    -- STEP 3: Process items in batches of 20
    while currentItemIndex <= itemCount do
        local batchEnd = math.min(currentItemIndex + 20 - 1, itemCount) -- Process 20 items at a time
        local currentBatch = {}
        
        -- Collect current batch
        for i = currentItemIndex, batchEnd do
            table.insert(currentBatch, allItems[i])
        end
        
        -- FIRST DRAG REQUEST for current batch
        if requestStartDragging then
            for _, itemData in ipairs(currentBatch) do
                if itemData.Item and itemData.Item.Parent then
                    requestStartDragging:FireServer(itemData.Item)
                end
            end
            task.wait(0.1) -- Brief delay after drag requests
        end
        
        -- TELEPORT current batch
        for batchIndex, itemData in ipairs(currentBatch) do
            local globalIndex = currentItemIndex + batchIndex - 1
            local row = math.floor((globalIndex - 1) / itemsPerRow)
            local col = (globalIndex - 1) % itemsPerRow
            
            -- Calculate grid position with spacing
            local offsetX = (col - itemsPerRow / 2) * spacing
            local offsetZ = (row - itemsPerRow / 2) * spacing
            local offsetY = 50 + math.random(-3, 3) -- Height variation (50 studs above campfire)
            
            local targetPosition = campfirePos + Vector3.new(offsetX, offsetY, offsetZ)
            
            -- INSTANT TELEPORTATION (COLLISION ENABLED!)
            itemData.Part.CFrame = CFrame.new(targetPosition)
            itemData.Part.AssemblyLinearVelocity = Vector3.zero
            itemData.Part.AssemblyAngularVelocity = Vector3.zero
        end
        
        -- SECOND DROP REQUEST for current batch after teleportation
        local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
        if stopDragging then
            task.wait(0.1) -- Brief delay before drop
            for _, itemData in ipairs(currentBatch) do
                if itemData.Item and itemData.Item.Parent then
                    stopDragging:FireServer(itemData.Item)
                end
            end
        end
        
        -- Move to next batch
        currentItemIndex = batchEnd + 1
        
        -- Small delay between batches to prevent lag
        task.wait(0.2)
    end
end

-- Find cultist gem items for crafting (avoiding conflicts with campfire)
local function FindCultistGemItemsForCrafting()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return items
    end
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        local shouldAdd = false
        local itemPart = nil
        local itemType = nil
        
        -- Check for Cultist Gem items for crafting
        local mainPart = item:FindFirstChild("Main")
        if mainPart and item.Name == "Cultist Gem" then
            itemPart = mainPart
            itemType = "Cultist Gem"
            shouldAdd = true
        end
        
        -- Only add if we should and it matches our filter
        if shouldAdd and itemPart then
            if CraftingControl.CultistGemItemType == "All" or CraftingControl.CultistGemItemType == itemType then
                table.insert(items, {
                    Item = item,
                    Part = itemPart,
                    Type = itemType,
                    Position = itemPart.Position
                })
            end
        end
    end
    
    return items
end

-- Find Gem of the Forest items for crafting (complete gems and fragments)
local function FindForestGemItemsForCrafting()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then return items end
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        local mainPart = item:FindFirstChild("Main")
        if mainPart and (item.Name == "Gem of the Forest" or item.Name == "Gem of the Forest Fragment") then
            if CraftingControl.ForestGemItemType == "All" or CraftingControl.ForestGemItemType == item.Name then
                table.insert(items, {
                    Item = item,
                    Part = mainPart,
                    Type = item.Name,
                    Position = mainPart.Position,
                    IsFragment = item.Name == "Gem of the Forest Fragment"
                })
            end
        end
    end
    
    return items
end

-- Get player position for teleporting food items
local function GetPlayerPosition()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        -- Return position 5 studs in front of the player and 35 studs above for proper falling (matching campfire height)
        local rootPart = char.HumanoidRootPart
        local lookDirection = rootPart.CFrame.LookVector
        return rootPart.CFrame.Position + (lookDirection * 5) + Vector3.new(0, 35, 0)
    end
    return nil
end

-- Food item lookup table for O(1) performance
local FoodItemLookup = {
    ["Cake"] = "Cake",
    ["Ribs"] = "Ribs", 
    ["Steak"] = "Steak",
    ["Morsel"] = "Morsel",
    ["Carrot"] = "Carrot",
    ["Corn"] = "Corn", 
    ["Pumpkin"] = "Pumpkin",
    ["Apple"] = "Apple",
    ["Chili"] = "Chili",
    ["Cooked Steak"] = "Cooked Steak",
    ["Cooked Morsel"] = "Cooked Morsel",
    ["Cooked Ribs"] = "Cooked Ribs",
}

-- Find food items in workspace
local function FindFoodItems()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return items
    end
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        -- Skip items that have already been teleported
        if FoodControl.TeleportedItems[item] then
            continue
        end
        
        -- Fast lookup: O(1) instead of O(n) elseif chain
        local itemType = FoodItemLookup[item.Name]
        if itemType then
            local itemPart = item.PrimaryPart
            if itemPart and itemPart:IsA("BasePart") then
                local shouldInclude = false
                
                if FoodControl.FoodItemType == "All" then
                    shouldInclude = true
                elseif FoodControl.FoodItemType == "Cooked Food" then
                    -- Include ONLY cooked food items (exclude all raw items)
                    shouldInclude = (itemType and string.find(itemType, "Cooked", 1, true) ~= nil)
                elseif FoodControl.FoodItemType == itemType then
                    shouldInclude = true
                end
                
                if shouldInclude then
                    table.insert(items, {
                        Item = item,
                        Part = itemPart,
                        Type = itemType,
                        Position = itemPart.Position
                    })
                end
            end
        end
    end
    
    return items
end

-- No helper functions needed - inline destination logic where used

-- Execute food teleportation
local function UpdateFoodTeleport()
    if not FoodControl.TeleportFoodEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - FoodControl.LastFoodTeleport < FoodControl.TeleportCooldown then
        return
    end
    
    FoodControl.LastFoodTeleport = currentTime
    
    -- Clean up teleported items tracking (remove items that no longer exist)
    local validTeleportedItems = {}
    for item, timestamp in pairs(FoodControl.TeleportedItems) do
        if item.Parent and (currentTime - timestamp) < 120 then -- 30 second cooldown per item
            validTeleportedItems[item] = timestamp
        end
    end
    FoodControl.TeleportedItems = validTeleportedItems
    
    -- Debug: Count current teleported items
    local count = 0
    for _ in pairs(FoodControl.TeleportedItems) do count = count + 1 end
    
    -- Find food items
    local foodItems = FindFoodItems()
    if #foodItems == 0 then
        return -- No items available
    end
    
    -- Filter out already teleported items
    local availableItems = {}
    for _, itemData in ipairs(foodItems) do
        if not FoodControl.TeleportedItems[itemData.Item] then
            table.insert(availableItems, itemData)
        end
    end
    
    if #availableItems == 0 then
        return -- No new items to teleport
    end
    
    -- Sort by distance to player (prioritize closer items)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local playerPos = char.HumanoidRootPart.Position
        table.sort(availableItems, function(a, b)
            local distA = (playerPos - a.Position).Magnitude
            local distB = (playerPos - b.Position).Magnitude
            return distA < distB
        end)
    end
    
    -- Use UltimateItemTransporter for the closest food item
    local item = availableItems[1]
    local destination = FoodControl.TeleportDestination == "Campfire" and workspace.Map.Campground.MainFire or "Player"
    
    -- Mark item as being teleported IMMEDIATELY to prevent duplicate attempts
    FoodControl.TeleportedItems[item.Item] = currentTime
    
    local success = UltimateItemTransporter(item.Item, destination, nil, 120, FoodControl.SavedPlayerPosition, FoodControl.TeleportHeight) -- Pass nil for tracking since we handle it here
    
    if success then
        -- Use the configurable cooldown for next teleport attempt
        FoodControl.LastFoodTeleport = currentTime
    else
        -- Remove mark if teleport failed
        FoodControl.TeleportedItems[item.Item] = nil
    end
end

-- Auto Cook Pot - Thread 1: Stew Collection (watches CanTake and collects stew)
local function AutoCookPot_StewCollector()
    while FoodControl.AutoCookPotEnabled do
        local structures = Workspace:FindFirstChild("Structures")
        if structures then
            local crockPot = structures:FindFirstChild("Crock Pot")
            if crockPot then
                local canTake = crockPot:GetAttribute("CanTake")
                
                -- If CanTake is true, find and collect stew
                if canTake then
                    print("🍲 CanTake is TRUE - Looking for stew...")
                    
                    local itemsFolder = Workspace:FindFirstChild("Items")
                    local mainPart = crockPot:FindFirstChild("Main")
                    
                    if itemsFolder and mainPart then
                        -- Search for stew near the pot's Main part
                        for _, item in pairs(itemsFolder:GetChildren()) do
                            if item.Name == "Stew" and not FoodControl.CookPotState.ProcessedStews[item] then
                                local stewPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
                                if stewPart then
                                    local distance = (stewPart.Position - mainPart.Position).Magnitude
                                    
                                    -- Check if stew is near the pot (within 10 studs)
                                    if distance <= 10 then
                                        print(string.format("✅ Found stew %.1f studs from pot - Collecting!", distance))
                                        
                                        local campfire = Workspace.Map.Campground.MainFire
                                        if campfire then
                                            -- Mark as processed
                                            FoodControl.CookPotState.ProcessedStews[item] = true
                                            
                                            -- Fire drag request
                                            local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
                                            if requestStartDragging then
                                                pcall(function()
                                                    requestStartDragging:FireServer(item)
                                                end)
                                            end
                                            
                                            -- Wait for detachment
                                            wait(1)
                                            
                                            -- Teleport to campfire
                                            if item.PrimaryPart then
                                                item.PrimaryPart.CFrame = campfire.PrimaryPart.CFrame * CFrame.new(0, 5, 0)
                                                print("🔥 Stew teleported to campfire!")
                                            end
                                            
                                            wait(0.1)
                                            
                                            -- Stop dragging
                                            local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
                                            if stopDragging then
                                                pcall(function()
                                                    stopDragging:FireServer(item)
                                                end)
                                            end
                                            
                                            -- Wait before next cycle
                                            wait(3)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Check every 1 second for stew (fast response)
        wait(1)
    end
    
    print("🍲 Stew Collector Thread Stopped")
end

-- Auto Cook Pot - Thread 2: Ingredient Adder (watches ItemPlace transparency and adds food)
local function AutoCookPot_IngredientAdder()
    while FoodControl.AutoCookPotEnabled do
        local structures = Workspace:FindFirstChild("Structures")
        if structures then
            local crockPot = structures:FindFirstChild("Crock Pot")
            if crockPot then
                local cooking = crockPot:GetAttribute("Cooking")
                local ingredients = crockPot:GetAttribute("Ingredients") or 0
                
                if type(ingredients) == "string" then
                    ingredients = tonumber(ingredients) or 0
                end
                
                -- Check if any ItemPlace needs items
                local needsItems = false
                
                for _, child in pairs(crockPot:GetChildren()) do
                    if child.Name == "ItemPlace" and child:IsA("BasePart") then
                        if math.abs(child.Transparency - 0.8) < 0.01 then
                            needsItems = true
                            break
                        end
                    end
                end
                
                -- Add ingredients if needed and not cooking
                if needsItems and ingredients < 3 and not cooking then
                    print(string.format("🥕 Pot needs items (ingredients: %d) - Adding food...", ingredients))
                    
                    local touchZone = crockPot:FindFirstChild("TouchZone")
                    local itemsFolder = Workspace:FindFirstChild("Items")
                    
                    if touchZone and itemsFolder then
                        local validFoodNames = {
                            "Carrot", "Morsel", "Steak", "Ribs",
                            "Cooked Morsel", "Cooked Steak", "Cooked Ribs"
                        }
                        
                        local itemsAdded = 0
                        
                        for _, item in pairs(itemsFolder:GetChildren()) do
                            if not FoodControl.AutoCookPotEnabled then
                                return
                            end
                            
                            if table.find(validFoodNames, item.Name) then
                                local itemPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
                                if itemPart then
                                    -- Re-check before adding
                                    local currentCooking = crockPot:GetAttribute("Cooking")
                                    local currentIngredients = crockPot:GetAttribute("Ingredients") or 0
                                    if type(currentIngredients) == "string" then
                                        currentIngredients = tonumber(currentIngredients) or 0
                                    end
                                    
                                    if currentCooking or currentIngredients >= 3 then
                                        print("⚠️ Pot started cooking or is full - Stopping")
                                        break
                                    end
                                    
                                    print(string.format("➕ Adding %s to pot...", item.Name))
                                    
                                    -- Fire drag request
                                    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
                                    if requestStartDragging then
                                        pcall(function()
                                            requestStartDragging:FireServer(item)
                                        end)
                                    end
                                    
                                    -- Teleport to pot
                                    itemPart.CFrame = touchZone.CFrame * CFrame.new(0, 5, 0)
                                    
                                    -- Stop dragging
                                    local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
                                    if stopDragging then
                                        pcall(function()
                                            stopDragging:FireServer(item)
                                        end)
                                    end
                                    
                                    itemsAdded = itemsAdded + 1
                                    wait(0.5)
                                    
                                    if itemsAdded >= 3 then
                                        print("✅ Added 3 items - Waiting for cooking")
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Check every 2 seconds for ingredients (moderate response)
        wait(2)
    end
    
    print("🥕 Ingredient Adder Thread Stopped")
end

-- Auto Cook Pot Main Function (spawns both threads)
function UpdateAutoCookPot()
    -- This function is called from the main loop but doesn't do anything
    -- The threads are spawned when the toggle is turned on
end

--============================================================================--
--      [[ CHEF STOVE AUTO COOKING SYSTEM ]]
--============================================================================--

-- Get filler ingredient priority (common items first)
function GetFillerIngredient()
    local itemsFolder = WorkspaceItems
    if not itemsFolder then
        return nil
    end
    
    local fillerPriority = {
        "Carrot", "Morsel", "Berry", "Mushroom",
        "Cooked Morsel", "Cooked Carrot", "Fish"
    }
    
    for _, fillerName in ipairs(fillerPriority) do
        for _, item in pairs(itemsFolder:GetChildren()) do
            if item.Name == fillerName and item.PrimaryPart then
                return item
            end
        end
    end
    
    return nil
end

-- Detect all Chef Stoves in workspace
function DetectChefStoves()
    local structures = Workspace:FindFirstChild("Structures")
    if not structures then
        return {}
    end
    
    local stoves = {}
    for _, structure in pairs(structures:GetChildren()) do
        if structure.Name == "Chefs Station" then
            table.insert(stoves, structure)
        end
    end
    
    return stoves
end

-- Check if stove is ready for cooking (has empty slots)
function IsStoveReady(stove)
    local cooking = stove:GetAttribute("Cooking")
    if cooking then
        return false
    end
    
    local ingredients = stove:GetAttribute("Ingredients") or 0
    if type(ingredients) == "string" then
        ingredients = tonumber(ingredients) or 0
    end
    
    return ingredients < 3
end

-- Add ingredient to specific stove
function AddIngredientToStove(item, stove)
    if not item or not item.Parent or not item.PrimaryPart then
        return false
    end
    
    local touchZone = stove:FindFirstChild("TouchZone")
    if not touchZone then
        return false
    end
    
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(item)
        end)
    end
    
    task.wait(0.1)
    
    item.PrimaryPart.CFrame = touchZone.CFrame * CFrame.new(0, 5, 0)
    
    task.wait(0.1)
    
    local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
    if stopDragging then
        pcall(function()
            stopDragging:FireServer(item)
        end)
    end
    
    return true
end

-- Chef Stove Dish Collector Thread
function ChefStove_DishCollector()
    while FoodControl.ChefStoveEnabled do
        local itemsFolder = WorkspaceItems
        if itemsFolder then
            for _, item in pairs(itemsFolder:GetChildren()) do
                if not FoodControl.ChefStoveEnabled then
                    break
                end
                
                local recipeDishes = {
                    "Seafood Chowder", "Steak Dinner", "Pumpkin Soup",
                    "BBQ Ribs", "Carrot Cake", "Jar o' Jelly", "Stew"
                }
                
                local isRecipeDish = false
                for _, dishName in ipairs(recipeDishes) do
                    if item.Name == dishName then
                        isRecipeDish = true
                        break
                    end
                end
                
                if isRecipeDish and not FoodControl.ChefStoveState.ProcessedDishes[item] then
                    -- Check if dish is near any detected Chef Stove (within 15 studs)
                    local isNearStove = false
                    local itemPosition = item.PrimaryPart and item.PrimaryPart.Position
                    
                    if itemPosition and FoodControl.ChefStoveState.DetectedStoves then
                        for _, stove in pairs(FoodControl.ChefStoveState.DetectedStoves) do
                            if stove and stove.PrimaryPart then
                                local stovePosition = stove.PrimaryPart.Position
                                local distance = (itemPosition - stovePosition).Magnitude
                                
                                if distance <= 15 then
                                    isNearStove = true
                                    break
                                end
                            end
                        end
                    end
                    
                    -- Only collect if near a stove
                    if isNearStove then
                        FoodControl.ChefStoveState.ProcessedDishes[item] = true
                        
                        local destination = "Player"
                        if FoodControl.ChefStoveDestination == "Campfire" or FoodControl.ChefStoveDestination == "MainFire" then
                            destination = "MainFire"
                        end
                        
                        -- Use specialized Chef Stove dish transporter
                        local success = ChefStoveDishTransporter(item, destination, 35)
                        if success then
                            FoodControl.ChefStoveState.TotalDishesCooked = FoodControl.ChefStoveState.TotalDishesCooked + 1
                        end
                        
                        task.wait(0.2)
                    end
                end
            end
        end
        
        task.wait(1)
    end
end

-- Chef Stove Cooking Thread
function ChefStove_CookingManager()
    while FoodControl.ChefStoveEnabled do
        local stoves = DetectChefStoves()
        FoodControl.ChefStoveState.DetectedStoves = stoves
        
        if #stoves == 0 then
            task.wait(5)
        else
            for _, stove in ipairs(stoves) do
                if not FoodControl.ChefStoveEnabled then
                    break
                end
                
                if IsStoveReady(stove) then
                    local recipeData = {
                        ["Seafood Chowder"] = {Primary = "Fish", Fillers = {"any", "any"}},
                        ["Steak Dinner"] = {Primary = "Steak", Fillers = {"any", "any"}},
                        ["Pumpkin Soup"] = {Primary = "Pumpkin", Fillers = {"any", "any"}},
                        ["BBQ Ribs"] = {Primary = "Ribs", Fillers = {"any", "any"}},
                        ["Carrot Cake"] = {Primary = "Carrot", Fillers = {"Carrot", "Carrot"}},
                        ["Jar o' Jelly"] = {Primary = "Jellyfish", Fillers = {"any", "any"}}
                    }
                    
                    local recipe = recipeData[FoodControl.ChefStoveRecipe]
                    if recipe then
                        local itemsFolder = WorkspaceItems
                        if itemsFolder then
                            local primaryItem = nil
                            for _, item in pairs(itemsFolder:GetChildren()) do
                                if item.Name == recipe.Primary and item.PrimaryPart then
                                    primaryItem = item
                                    break
                                end
                            end
                            
                            if primaryItem then
                                AddIngredientToStove(primaryItem, stove)
                                task.wait(0.5)
                                
                                for i = 1, 2 do
                                    if not FoodControl.ChefStoveEnabled then
                                        break
                                    end
                                    
                                    local fillerNeeded = recipe.Fillers[i]
                                    local fillerItem = nil
                                    
                                    if fillerNeeded == "any" then
                                        fillerItem = GetFillerIngredient()
                                    else
                                        for _, item in pairs(itemsFolder:GetChildren()) do
                                            if item.Name == fillerNeeded and item.PrimaryPart then
                                                fillerItem = item
                                                break
                                            end
                                        end
                                    end
                                    
                                    if fillerItem then
                                        AddIngredientToStove(fillerItem, stove)
                                        task.wait(0.5)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            task.wait(2)
        end
    end
end

function UpdateChefStove()
    -- Called from main loop but threads handle everything
end

-- Find animal pelt items in workspace
local function FindAnimalPeltItems()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return items
    end
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        local shouldAdd = false
        local itemPart = nil
        local itemType = nil
        
        -- Skip items that have already been teleported
        if AnimalPeltsControl.TeleportedItems[item] then
            continue
        end
        
        -- Check for specific animal pelt items
        if item.Name == "Bunny Foot" then
            itemPart = item:FindFirstChild("Main") or item:FindFirstChild("Handle") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "Bunny Foot"
            shouldAdd = true
        elseif item.Name == "Wolf Pelt" then
            itemPart = item:FindFirstChild("Main") or item:FindFirstChild("Handle") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "Wolf Pelt"
            shouldAdd = true
        elseif item.Name == "Alpha Wolf Pelt" then
            itemPart = item:FindFirstChild("Main") or item:FindFirstChild("Handle") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "Alpha Wolf Pelt"
            shouldAdd = true
        elseif item.Name == "Bear Pelt" then
            itemPart = item:FindFirstChild("Main") or item:FindFirstChild("Handle") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "Bear Pelt"
            shouldAdd = true
        elseif item.Name == "Arctic Fox Pelt" then
            itemPart = item:FindFirstChild("Main") or item:FindFirstChild("Handle") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "Arctic Fox Pelt"
            shouldAdd = true
        elseif item.Name == "Polar Bear Pelt" then
            itemPart = item:FindFirstChild("Main") or item:FindFirstChild("Handle") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "Polar Bear Pelt"
            shouldAdd = true
        elseif item.Name == "Mammoth Tusk" then
            itemPart = item:FindFirstChild("Main") or item:FindFirstChild("Handle") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "Mammoth Tusk"
            shouldAdd = true
        end
        
        -- Only add if we should and it matches our filter and has a valid part
        if shouldAdd and itemPart and itemPart:IsA("BasePart") then
            if AnimalPeltsControl.PeltItemType == itemType then
                table.insert(items, {
                    Item = item,
                    Part = itemPart,
                    Type = itemType,
                    Position = itemPart.Position
                })
            end
        end
    end
    
    return items
end

local function TamingUtility(action, ...)
    local config = AnimalPeltsControl.Taming

    if action == "inventory" then
        local itemName = ...
        local inventory = LocalPlayer and LocalPlayer:FindFirstChild("Inventory")
        if inventory then
            return inventory:FindFirstChild(itemName)
        end
        return nil

    elseif action == "primary" then
        local model = ...
        if not model then
            return nil
        end

        local primary = model.PrimaryPart
        if primary and primary:IsA("BasePart") then
            return primary
        end

        local root = model:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            pcall(function()
                model.PrimaryPart = root
            end)
            return root
        end

        local fallback = model:FindFirstChild("Main") or model:FindFirstChild("Handle") or model:FindFirstChildOfClass("BasePart")
        if fallback and fallback:IsA("BasePart") then
            pcall(function()
                model.PrimaryPart = fallback
            end)
            return fallback
        end

        return nil

    elseif action == "closest" then
        local animalName, maxDistance = ...
        local charactersFolder = Workspace and Workspace:FindFirstChild("Characters")
        local char = LocalPlayer and LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")

        if not charactersFolder or not root then
            return nil
        end

        local nearestModel
        local nearestDistance = maxDistance or math.huge

        for _, entity in ipairs(charactersFolder:GetChildren()) do
            if entity.Name == animalName and not entity:GetAttribute("Tamed") then
                local primary = TamingUtility("primary", entity)
                if primary then
                    local distance = (root.Position - primary.Position).Magnitude
                    if distance <= nearestDistance then
                        nearestModel = entity
                        nearestDistance = distance
                    end
                end
            end
        end

        return nearestModel, nearestDistance

    elseif action == "foodItem" then
        local foodName, targetPart, usedItems = ...
        local itemsFolder = WorkspaceItems or Workspace:FindFirstChild("Items")
        if not itemsFolder or not foodName or foodName == "" or not targetPart then
            return nil
        end

        local chosenItem
        local closestDistance = math.huge

        for _, item in ipairs(itemsFolder:GetChildren()) do
            if item.Name == foodName and not usedItems[item] then
                local primary = TamingUtility("primary", item)
                if primary then
                    local distance = (targetPart.Position - primary.Position).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        chosenItem = item
                    end
                end
            end
        end

        if chosenItem then
            usedItems[chosenItem] = true
        end

        return chosenItem

    elseif action == "deliverFood" then
        local targetModel, foodName, usedItems = ...
        local primary = TamingUtility("primary", targetModel)
        if not primary then
            return false, "Target missing primary part"
        end

        local foodItem = TamingUtility("foodItem", foodName, primary, usedItems or {})
        if not foodItem then
            return false, string.format("Missing food: %s", foodName)
        end

        if not TamingUtility("primary", foodItem) then
            return false, string.format("Food item %s missing primary part", foodName)
        end

        local success = UltimateItemTransporter(foodItem, targetModel, nil, 2, nil, config.FeedOffset)
        if not success then
            return false, string.format("Failed to deliver %s", foodName)
        end

        task.wait(0.8)
        return true

    elseif action == "feed" then
        local targetModel = ...
        local foods = {}
        local food1 = targetModel:GetAttribute("Food1Type")
        local food2 = targetModel:GetAttribute("Food2Type")

        if typeof(food1) == "string" and food1 ~= "" then
            foods[#foods + 1] = food1
        end
        if typeof(food2) == "string" and food2 ~= "" then
            foods[#foods + 1] = food2
        end

        if #foods == 0 then
            return true
        end

        local usedItems = {}
        for _, foodName in ipairs(foods) do
            local delivered, message = TamingUtility("deliverFood", targetModel, foodName, usedItems)
            if not delivered then
                return false, message
            end
        end

        task.wait(0.45)
        return true

    elseif action == "remotes" then
        local targetModel, flute = ...
        local remotes = config.Remotes
        if not remotes or not remotes.Neutral or not remotes.Hungry then
            return false, "Missing taming remotes"
        end

        local okNeutral, neutralErr = pcall(function()
            remotes.Neutral:FireServer(targetModel, flute)
        end)
        if not okNeutral then
            return false, neutralErr or "Failed to send neutral request"
        end

        task.wait(0.2)

        local okHungry, hungryErr = pcall(function()
            remotes.Hungry:FireServer(targetModel, flute)
        end)
        if not okHungry then
            return false, hungryErr or "Failed to send hungry request"
        end

        return true

    elseif action == "process" then
        local targetModel = ...
        local flute
        local fluteOptions = config.FluteVariants

        if fluteOptions then
            for _, fluteName in ipairs(fluteOptions) do
                flute = TamingUtility("inventory", fluteName)
                if flute then
                    break
                end
            end
        else
            flute = TamingUtility("inventory", "Old Taming Flute")
        end

        if not flute then
            return false, "No taming flute found in inventory"
        end

        if not TamingUtility("primary", targetModel) then
            return false, "Target missing primary part"
        end

        if not config.ShouldRun then
            return false, "Taming inactive"
        end

        while true do
            if not config.ShouldRun then
                return false, "Taming stopped"
            end

            if not targetModel.Parent then
                return false, "Target is no longer available"
            end

            if targetModel:GetAttribute("Tamed") then
                return true, "Taming completed"
            end

            local currentState = targetModel:GetAttribute("CurrentTamingState") or "Neutral"

            if currentState == "Hungry" then
                local fed, feedMessage = TamingUtility("feed", targetModel)
                if not fed then
                    return false, feedMessage
                end
            else
                local remoteSuccess, remoteMessage = TamingUtility("remotes", targetModel, flute)
                if not remoteSuccess then
                    return false, remoteMessage
                end
            end

            task.wait(config.AttemptCooldown)

            if targetModel:GetAttribute("Tamed") then
                return true, "Taming completed"
            end
        end

    elseif action == "attempt" then
        local notify = ...
        local shouldNotify = notify ~= false

        if config.IsBusy then
            local message = "Taming already in progress."
            config.LastStatus = message
            if shouldNotify then
                ApocLibrary:Notify({
                    Title = "Taming",
                    Content = message,
                    Duration = 3,
                    Image = 4483362458
                })
            end
            return "busy", message
        end

        local selectedAnimal = config.SelectedAnimal or "Bunny"
        local targetModel, distance = TamingUtility("closest", selectedAnimal, config.SearchRange)

        if not targetModel then
            local message = string.format("No %s found within %d studs.", selectedAnimal, config.SearchRange)
            config.LastStatus = message
            if shouldNotify then
                ApocLibrary:Notify({
                    Title = "Taming",
                    Content = message,
                    Duration = 4,
                    Image = 4483362748
                })
            end
            return "no-target", message
        end

        local engageDistance = config.EngageRange[selectedAnimal] or config.EngageRange.Bunny
        if distance and distance > engageDistance then
            local message = string.format("Move within %d studs (current: %.1f).", engageDistance, distance)
            config.LastStatus = message
            if shouldNotify then
                ApocLibrary:Notify({
                    Title = "Taming",
                    Content = message,
                    Duration = 4,
                    Image = 4400697855
                })
            end
            return "out-of-range", message
        end

        config.IsBusy = true
        config.ActiveTarget = targetModel
        config.LastAttempt = tick()
        config.ShouldRun = true

        local success, message = TamingUtility("process", targetModel)

        config.IsBusy = false
        config.ActiveTarget = nil
        config.LastStatus = message or ""
        config.ShouldRun = false

        local status
        if success then
            status = "success"
        elseif message == "Taming stopped" or message == "Taming inactive" then
            status = "cancelled"
        else
            status = "error"
        end

        if shouldNotify then
            local title
            local image
            if status == "success" then
                title = "Taming Success"
                image = 4483362458
            elseif status == "cancelled" then
                title = "Taming Stopped"
                image = 4400697855
            else
                title = "Taming Failed"
                image = 4400697855
            end

            ApocLibrary:Notify({
                Title = title,
                Content = message or (status == "success" and "Done" or "Unknown issue"),
                Duration = 4,
                Image = image
            })
        end

        return status, message

    elseif action == "automation" then
        local command = ...

        if command == "stop" then
            config.ToggleActive = false
            config.ShouldRun = false
            return true
        elseif command == "start" then
            if config.AutoTask then
                config.ToggleActive = true
                config.ShouldRun = true
                return true
            end

            config.ToggleActive = true
            config.ShouldRun = true

            config.AutoTask = task.spawn(function()
                local lastMessage = nil

                while config.ToggleActive do
                    local status, message = TamingUtility("attempt", false)

                    if status == "success" then
                        TamingUtility("automation", "stop")
                        if config.ToggleHandle and config.ToggleHandle.Set then
                            config.ToggleHandle:Set(false)
                        end
                        ApocLibrary:Notify({
                            Title = "Taming Success",
                            Content = message or "Taming completed",
                            Duration = 4,
                            Image = 4483362458
                        })
                        break
                    elseif status == "cancelled" then
                        break
                    elseif status == "busy" then
                        task.wait(0.2)
                    else
                        if message and message ~= lastMessage and status ~= "no-target" then
                            ApocLibrary:Notify({
                                Title = "Taming Update",
                                Content = message,
                                Duration = 4,
                                Image = 4400697855
                            })
                        end
                        lastMessage = message

                        if status == "no-target" then
                            task.wait(0.6)
                        elseif status == "out-of-range" then
                            task.wait(0.5)
                        else
                            task.wait(0.8)
                        end
                    end
                end

                config.AutoTask = nil
                config.ShouldRun = false
                config.IsBusy = false
                config.ActiveTarget = nil
                config.ToggleActive = false
            end)

            return true
        end
    end
end


local MeteorShardLookup = {
    ["Meteor Shard"] = true,
    ["Gold Shard"] = true,
    ["Obsidiron Ingot"] = true
}

local function FindMeteorShardItems()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return items
    end

    for _, item in pairs(itemsFolder:GetChildren()) do
        if not MeteorShardLookup[item.Name] then
            continue
        end

        if MeteorShardControl.TeleportedItems[item] then
            continue
        end

        local itemPart = nil
        if item:IsA("BasePart") then
            itemPart = item
        elseif item:IsA("Model") then
            itemPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
        end

        if itemPart then
            if MeteorShardControl.ShardItemType == "All" or MeteorShardControl.ShardItemType == item.Name then
                table.insert(items, {
                    Item = item,
                    Part = itemPart,
                    Position = itemPart.Position
                })
            end
        end
    end

    return items
end

local function GetMeteorShardDestination()
    if MeteorShardControl.TeleportDestination == "Player" then
        return "Player"
    elseif MeteorShardControl.TeleportDestination == "Campfire" then
        local campfire = workspace.Map and workspace.Map.Campground and workspace.Map.Campground.MainFire
        if campfire then
            return campfire
        end
    end
    return "Player"
end

local function UpdateMeteorShardTeleport()
    if not MeteorShardControl.TeleportShardsEnabled then
        return
    end

    local currentTime = tick()
    if currentTime - MeteorShardControl.LastShardTeleport < MeteorShardControl.TeleportCooldown then
        return
    end

    MeteorShardControl.LastShardTeleport = currentTime

    local validTeleported = {}
    for item, timestamp in pairs(MeteorShardControl.TeleportedItems) do
        if item.Parent and (currentTime - timestamp) < 120 then
            validTeleported[item] = timestamp
        end
    end
    MeteorShardControl.TeleportedItems = validTeleported

    local shardItems = FindMeteorShardItems()
    if #shardItems == 0 then
        return
    end

    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local playerPos = char.HumanoidRootPart.Position
        table.sort(shardItems, function(a, b)
            local distA = (playerPos - a.Position).Magnitude
            local distB = (playerPos - b.Position).Magnitude
            return distA < distB
        end)
    end

    local target = shardItems[1]
    local destination = GetMeteorShardDestination()

    MeteorShardControl.TeleportedItems[target.Item] = currentTime

    local success = UltimateItemTransporter(target.Item, destination, nil, 120, MeteorShardControl.SavedPlayerPosition, MeteorShardControl.TeleportHeight)

    if success then
        MeteorShardControl.LastShardTeleport = currentTime
    else
        MeteorShardControl.TeleportedItems[target.Item] = nil
    end
end

local function PrepareObsidironIngots()
    if LostChildrenControl.ToggleState.ObsidironActive then
        return
    end

    LostChildrenControl.ToggleState.ObsidironActive = true

    task.spawn(function()
        local success, err = pcall(function()
            local itemsFolder = WorkspaceItems or workspace:FindFirstChild("Items")
            local landmarks = WorkspaceMap and WorkspaceMap:FindFirstChild("Landmarks")
            if not itemsFolder or not landmarks then
                return
            end

            local dragRemote = RemoteEvents and RemoteEvents:FindFirstChild("RequestStartDraggingItem")

            local waterNames = {"Water Hole1 Tier2", "Water Hole1", "Water Hole Big"}
            local lavaTargets = {}
            local waterTargets = {}

            do
                local crater = landmarks:FindFirstChild("Crater_Generic")
                if crater then
                    local functional = crater:FindFirstChild("Functional")
                    if functional then
                        local lavaPart = functional:FindFirstChild("Lava", true)
                        if lavaPart and lavaPart:IsA("BasePart") then
                            table.insert(lavaTargets, lavaPart)
                        end
                    end
                end

                for _, landmark in ipairs(landmarks:GetChildren()) do
                    local lavaPart = landmark:FindFirstChild("Lava")
                    if lavaPart and lavaPart:IsA("BasePart") then
                        table.insert(lavaTargets, lavaPart)
                    elseif landmark:IsA("Model") then
                        local nestedLava = landmark:FindFirstChild("Lava", true)
                        if nestedLava and nestedLava:IsA("BasePart") then
                            table.insert(lavaTargets, nestedLava)
                        end
                    end
                end

                for _, name in ipairs(waterNames) do
                    local waterModel = landmarks:FindFirstChild(name)
                    if waterModel then
                        local waterPart = waterModel.PrimaryPart or waterModel:FindFirstChild("Water")
                        if not (waterPart and waterPart:IsA("BasePart")) then
                            waterPart = waterModel:FindFirstChildWhichIsA("BasePart")
                        end
                        if waterPart and waterPart:IsA("BasePart") then
                            table.insert(waterTargets, waterPart)
                        end
                    else
                        local descendant = landmarks:FindFirstChild(name, true)
                        if descendant then
                            local waterPart = descendant.PrimaryPart or descendant:FindFirstChild("Water")
                            if not (waterPart and waterPart:IsA("BasePart")) then
                                waterPart = descendant:FindFirstChildWhichIsA("BasePart")
                            end
                            if waterPart and waterPart:IsA("BasePart") then
                                table.insert(waterTargets, waterPart)
                            end
                        end
                    end
                end
            end

            local function getPrimaryPart(item)
                if item:IsA("BasePart") then
                    return item
                end
                if item.PrimaryPart then
                    return item.PrimaryPart
                end
                if item:IsA("Model") then
                    local part = item:FindFirstChild("PrimaryPart")
                    if part and part:IsA("BasePart") then
                        return part
                    end
                    part = item:FindFirstChildWhichIsA("BasePart")
                    if part then
                        return part
                    end
                end
                return nil
            end

            local recentEncasedMoves = {}

            local function cleanupRecentEncased()
                local now = tick()
                for item, timestamp in pairs(recentEncasedMoves) do
                    if not item.Parent or item:GetAttribute("OreState") ~= "Encased" or (now - timestamp) > 2 then
                        recentEncasedMoves[item] = nil
                    end
                end
            end

            local function getItemsByState(state)
                if state == "Encased" then
                    cleanupRecentEncased()
                end
                local matches = {}
                for _, item in ipairs(itemsFolder:GetChildren()) do
                    local oreState = item:GetAttribute("OreState")
                    if oreState == state and item.Name:find("Obsidiron") then
                        local part = getPrimaryPart(item)
                        if part then
                            if state == "Encased" and recentEncasedMoves[item] then
                                continue
                            end
                            table.insert(matches, {Item = item, Part = part})
                        end
                    end
                end
                return matches
            end

            local function moveEncased(items)
                local player = LocalPlayer
                local character = player and player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    return false
                end

                local basePosition = hrp.Position + hrp.CFrame.LookVector * 6
                local rightVector = hrp.CFrame.RightVector
                for index, data in ipairs(items) do
                    local row = math.floor((index - 1) / 4)
                    local column = (index - 1) % 4
                    local offset = rightVector * ((column - 1.5) * 4) + Vector3.new(0, 20, row * 4)
                    local targetPosition = basePosition + offset
                    if dragRemote then
                        dragRemote:FireServer(data.Item)
                    end
                    data.Part.CFrame = CFrame.new(targetPosition)
                    recentEncasedMoves[data.Item] = tick()
                end
                return true
            end

            local function moveToTargets(items, targets, heightOffset)
                if #targets == 0 then
                    return false
                end
                for index, data in ipairs(items) do
                    local anchor = targets[((index - 1) % #targets) + 1]
                    if anchor and anchor.Parent then
                        local targetPosition = anchor.Position + Vector3.new(0, heightOffset, 0)
                        if dragRemote then
                            dragRemote:FireServer(data.Item)
                        end
                        data.Part.CFrame = CFrame.new(targetPosition)
                    end
                end
                return true
            end

            local function processStage(state, handler, waitTime)
                local attempts = 0
                local completedAny = false
                while LostChildrenControl.ToggleState.ObsidironActive and attempts < 15 do
                    local batch = getItemsByState(state)
                    if #batch == 0 then
                        break
                    end
                    local handled = handler(batch)
                    if handled == false then
                        return completedAny
                    end
                    completedAny = true
                    attempts += 1
                    task.wait(waitTime)
                end
                return completedAny
            end

            local encasedHandled = processStage("Encased", moveEncased, 1)
            if not LostChildrenControl.ToggleState.ObsidironActive then return end

            if not encasedHandled then return end

            local rawHandled = processStage("Raw", function(items)
                return moveToTargets(items, lavaTargets, 5)
            end, 1.5)
            if not LostChildrenControl.ToggleState.ObsidironActive then return end

            if not rawHandled then return end

            processStage("Scalding Obsidiron Ingot", function(items)
                return moveToTargets(items, waterTargets, 3)
            end, 1.5)
        end)

        LostChildrenControl.ToggleState.ObsidironActive = false

        if LostChildrenControl.ToggleState.PrepareObsidiron then
            LostChildrenControl.ToggleState.PrepareObsidiron:Set(false)
        end

        if not success then
            warn("PrepareObsidironIngots failed:", err)
        end
    end)
end

-- Execute animal pelts teleportation
local function UpdateAnimalPeltsTeleport()
    if not AnimalPeltsControl.TeleportPeltsEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - AnimalPeltsControl.LastPeltTeleport < AnimalPeltsControl.TeleportCooldown then
        return
    end
    
    AnimalPeltsControl.LastPeltTeleport = currentTime
    
    -- Clean up teleported items tracking (remove items that no longer exist)
    local validTeleportedItems = {}
    for item, timestamp in pairs(AnimalPeltsControl.TeleportedItems) do
        if item.Parent and (currentTime - timestamp) < 120 then -- 30 second cooldown per item
            validTeleportedItems[item] = timestamp
        end
    end
    AnimalPeltsControl.TeleportedItems = validTeleportedItems
    
    -- Find animal pelt items
    local peltItems = FindAnimalPeltItems()
    if #peltItems == 0 then
        return -- No items available
    end
    
    -- Filter out already teleported items
    local availableItems = {}
    for _, itemData in ipairs(peltItems) do
        if not AnimalPeltsControl.TeleportedItems[itemData.Item] then
            table.insert(availableItems, itemData)
        end
    end
    
    if #availableItems == 0 then
        return -- No new items to teleport
    end
    
    -- Sort by distance to player (prioritize closer items)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local playerPos = char.HumanoidRootPart.Position
        table.sort(availableItems, function(a, b)
            local distA = (playerPos - a.Position).Magnitude
            local distB = (playerPos - b.Position).Magnitude
            return distA < distB
        end)
    end
    
    -- Use UltimateItemTransporter for the closest animal pelt item
    local item = availableItems[1]
    local destination = AnimalPeltsControl.TeleportDestination == "Campfire" and workspace.Map.Campground.MainFire or "Player"
    
    -- Mark item as being teleported IMMEDIATELY to prevent duplicate attempts
    AnimalPeltsControl.TeleportedItems[item.Item] = currentTime
    
    local success = UltimateItemTransporter(item.Item, destination, nil, 120, AnimalPeltsControl.SavedPlayerPosition, AnimalPeltsControl.TeleportHeight) -- Pass nil for tracking since we handle it here
    
    if success then
        -- Use the configurable cooldown for next teleport attempt
        AnimalPeltsControl.LastPeltTeleport = currentTime
    else
        -- Remove mark if teleport failed
        AnimalPeltsControl.TeleportedItems[item.Item] = nil
    end
end

-- Find healing items in workspace
local function FindHealingItems()
    local items = {}
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return items
    end
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        local shouldAdd = false
        local itemPart = nil
        local itemType = nil
        
        -- Skip items that have already been teleported
        if HealingControl.TeleportedItems[item] then
            continue
        end
        
        -- Check for specific healing items
        if item.Name == "Bandage" then
            itemPart = item:FindFirstChild("Handle") or item:FindFirstChild("Main") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "Bandage"
            shouldAdd = true
        elseif item.Name == "MedKit" then
            itemPart = item:FindFirstChild("Handle") or item:FindFirstChild("Main") or item:FindFirstChild("Meat") or item:GetChildren()[1]
            itemType = "MedKit"
            shouldAdd = true
        end
        
        -- Only add if we should and it matches our filter and has a valid part
        if shouldAdd and itemPart and itemPart:IsA("BasePart") then
            if HealingControl.HealingItemType == itemType then
                table.insert(items, {
                    Item = item,
                    Part = itemPart,
                    Type = itemType,
                    Position = itemPart.Position
                })
            end
        end
    end
    
    return items
end

-- Execute healing items teleportation
local function UpdateHealingTeleport()
    if not HealingControl.TeleportHealingEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - HealingControl.LastHealingTeleport < HealingControl.TeleportCooldown then
        return
    end
    
    HealingControl.LastHealingTeleport = currentTime
    
    -- Clean up teleported items tracking (remove items that no longer exist)
    local validTeleportedItems = {}
    for item, timestamp in pairs(HealingControl.TeleportedItems) do
        if item.Parent and (currentTime - timestamp) < 120 then -- 30 second cooldown per item
            validTeleportedItems[item] = timestamp
        end
    end
    HealingControl.TeleportedItems = validTeleportedItems
    
    -- Find healing items
    local healingItems = FindHealingItems()
    if #healingItems == 0 then
        return -- No items available
    end
    
    -- Filter out already teleported items
    local availableItems = {}
    for _, itemData in ipairs(healingItems) do
        if not HealingControl.TeleportedItems[itemData.Item] then
            table.insert(availableItems, itemData)
        end
    end
    
    if #availableItems == 0 then
        return -- No new items to teleport
    end
    
    -- Sort by distance to player (prioritize closer items)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local playerPos = char.HumanoidRootPart.Position
        table.sort(availableItems, function(a, b)
            local distA = (playerPos - a.Position).Magnitude
            local distB = (playerPos - b.Position).Magnitude
            return distA < distB
        end)
    end
    
    -- Use UltimateItemTransporter for the closest healing item
    local item = availableItems[1]
    local destination = HealingControl.TeleportDestination == "Campfire" and workspace.Map.Campground.MainFire or "Player"
    
    -- Mark item as being teleported IMMEDIATELY to prevent duplicate attempts
    HealingControl.TeleportedItems[item.Item] = currentTime
    
    local success = UltimateItemTransporter(item.Item, destination, nil, 120, HealingControl.SavedPlayerPosition, HealingControl.TeleportHeight) -- Pass nil for tracking since we handle it here
    
    if success then
        -- Use the configurable cooldown for next teleport attempt
        HealingControl.LastHealingTeleport = currentTime
    else
        -- Remove mark if teleport failed
        HealingControl.TeleportedItems[item.Item] = nil
    end
end

-- Revival system functions
local function RefreshAvailableBodies()
    local charactersFolder = workspace:FindFirstChild("Characters")
    if not charactersFolder then
        HealingControl.AvailableBodies = {"None"}
        return
    end
    
    local bodies = {"None"}
    local localPlayerName = game.Players.LocalPlayer.Name
    
    for _, bodyModel in ipairs(charactersFolder:GetChildren()) do
        if bodyModel:IsA("Model") and bodyModel.Name:find(" Body") and bodyModel.Name ~= (localPlayerName .. " Body") then
            table.insert(bodies, bodyModel.Name)
        end
    end
    
    HealingControl.AvailableBodies = bodies
    HealingControl.LastRefresh = tick()
end

local function ReviveSelectedPlayer()
    if HealingControl.SelectedBody == "None" then
        return
    end
    
    local charactersFolder = workspace:FindFirstChild("Characters")
    if not charactersFolder then
        return
    end
    
    local bodyModel = charactersFolder:FindFirstChild(HealingControl.SelectedBody)
    if not bodyModel then
        return
    end
    
    local reviveRemote = RemoteEvents:FindFirstChild("RequestRevivePlayer")
    if reviveRemote then
        reviveRemote:FireServer(bodyModel)
    end
end

-- Ammo teleport functions (same logic as healing/food)
local function FindAmmoItems()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return {}
    end
    
    local ammoItems = {}
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        -- Skip if already teleported
        if AmmoControl.TeleportedItems[item] then
            continue
        end
        
        local shouldInclude = false
        if AmmoControl.AmmoItemType == "All" then
            for _, ammoType in pairs(DropdownOptions.AmmoItems) do
                if ammoType ~= "All" and item.Name == ammoType then
                    shouldInclude = true
                    break
                end
            end
        else
            shouldInclude = (item.Name == AmmoControl.AmmoItemType)
        end
        
        if shouldInclude then
            local itemPart = nil
            if item:IsA("BasePart") then
                itemPart = item
            elseif item:IsA("Model") then
                itemPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
            end
            
            if itemPart then
                table.insert(ammoItems, {
                    Item = item,
                    Part = itemPart,
                    Position = itemPart.Position
                })
            end
        end
    end
    
    return ammoItems
end

local function UpdateAmmoTeleport()
    if not AmmoControl.TeleportAmmoEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - AmmoControl.LastAmmoTeleport < AmmoControl.TeleportCooldown then
        return
    end
    
    local ammoItems = FindAmmoItems()
    if #ammoItems == 0 then
        return
    end
    
    -- Clean up teleported items tracking (remove items that no longer exist)
    local validTeleportedItems = {}
    for item, timestamp in pairs(AmmoControl.TeleportedItems) do
        if item.Parent and (currentTime - timestamp) < 120 then -- 30 second cooldown per item
            validTeleportedItems[item] = timestamp
        end
    end
    AmmoControl.TeleportedItems = validTeleportedItems
    
    -- Filter out already teleported items
    local availableItems = {}
    for _, itemData in ipairs(ammoItems) do
        if not AmmoControl.TeleportedItems[itemData.Item] then
            table.insert(availableItems, itemData)
        end
    end
    
    if #availableItems == 0 then
        return -- No new items to teleport
    end
    
    -- Sort by distance to player (get closest first)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local playerPos = char.HumanoidRootPart.Position
        table.sort(availableItems, function(a, b)
            local distA = (playerPos - a.Position).Magnitude
            local distB = (playerPos - b.Position).Magnitude
            return distA < distB
        end)
    end
    
    -- Use UltimateItemTransporter for the closest ammo item
    local item = availableItems[1]
    local destination = AmmoControl.TeleportDestination == "Campfire" and workspace.Map.Campground.MainFire or "Player"
    
    -- Mark item as being teleported IMMEDIATELY to prevent duplicate attempts
    AmmoControl.TeleportedItems[item.Item] = currentTime
    
    local success = UltimateItemTransporter(item.Item, destination, nil, 120, AmmoControl.SavedPlayerPosition, AmmoControl.TeleportHeight) -- Pass nil for tracking since we handle it here
    
    if success then
        -- Use the configurable cooldown for next teleport attempt
        AmmoControl.LastAmmoTeleport = currentTime
    else
        -- Remove mark if teleport failed
        AmmoControl.TeleportedItems[item.Item] = nil
    end
end

-- Weapon teleport functions (same logic as ammo)
local function FindWeaponItems()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return {}
    end
    
    local weaponItems = {}
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        -- Skip if already teleported
        if AmmoControl.TeleportedWeapons[item] then
            continue
        end
        
        local shouldInclude = false
        if AmmoControl.WeaponItemType == "All" then
            for _, weaponType in pairs(AmmoControl.WeaponTypes) do
                if weaponType ~= "All" and item.Name == weaponType then
                    shouldInclude = true
                    break
                end
            end
        else
            shouldInclude = (item.Name == AmmoControl.WeaponItemType)
        end
        
        if shouldInclude then
            local itemPart = nil
            if item:IsA("BasePart") then
                itemPart = item
            elseif item:IsA("Model") then
                itemPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
            end
            
            if itemPart then
                table.insert(weaponItems, {
                    Item = item,
                    Part = itemPart,
                    Distance = 0 -- Will be calculated later
                })
            end
        end
    end
    
    return weaponItems
end

local function UpdateWeaponTeleport()
    if not AmmoControl.TeleportWeaponEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - AmmoControl.LastWeaponTeleport < AmmoControl.TeleportCooldown then
        return
    end
    
    local weaponItems = FindWeaponItems()
    if #weaponItems == 0 then
        return
    end
    
    -- Clean up teleported weapons tracking
    local validTeleportedWeapons = {}
    for item, timestamp in pairs(AmmoControl.TeleportedWeapons) do
        if item and item.Parent then
            validTeleportedWeapons[item] = timestamp
        end
    end
    AmmoControl.TeleportedWeapons = validTeleportedWeapons
    
    -- Filter out already teleported weapons
    local availableItems = {}
    for _, itemData in ipairs(weaponItems) do
        if not AmmoControl.TeleportedWeapons[itemData.Item] then
            table.insert(availableItems, itemData)
        end
    end
    
    if #availableItems == 0 then
        return
    end
    
    -- Sort by distance to player
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local playerPos = char.HumanoidRootPart.Position
        for _, itemData in ipairs(availableItems) do
            itemData.Distance = (itemData.Part.Position - playerPos).Magnitude
        end
        table.sort(availableItems, function(a, b) return a.Distance < b.Distance end)
    end
    
    -- Use UltimateItemTransporter for the closest weapon
    local item = availableItems[1]
    local destination = AmmoControl.TeleportDestination == "Campfire" and workspace.Map.Campground.MainFire or "Player"
    
    -- Mark weapon as being teleported IMMEDIATELY
    AmmoControl.TeleportedWeapons[item.Item] = currentTime
    
    local success = UltimateItemTransporter(item.Item, destination, nil, 120, AmmoControl.SavedPlayerPosition, AmmoControl.TeleportHeight)
    
    if success then
        AmmoControl.LastWeaponTeleport = currentTime
    else
        AmmoControl.TeleportedWeapons[item.Item] = nil
    end
end

-- Armor teleport functions (same logic as weapons)
local function FindArmorItems()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return {}
    end
    
    local armorItems = {}
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        -- Skip if already teleported
        if AmmoControl.TeleportedArmor[item] then
            continue
        end
        
        local shouldInclude = false
        if AmmoControl.ArmorItemType == "All" then
            for _, armorType in pairs(AmmoControl.ArmorTypes) do
                if armorType ~= "All" and item.Name == armorType then
                    shouldInclude = true
                    break
                end
            end
        else
            shouldInclude = (item.Name == AmmoControl.ArmorItemType)
        end
        
        if shouldInclude then
            local itemPart = nil
            if item:IsA("BasePart") then
                itemPart = item
            elseif item:IsA("Model") then
                itemPart = item.PrimaryPart or item:FindFirstChildOfClass("BasePart")
            end
            
            if itemPart then
                table.insert(armorItems, {
                    Item = item,
                    Part = itemPart,
                    Distance = 0 -- Will be calculated later
                })
            end
        end
    end
    
    return armorItems
end

local function UpdateArmorTeleport()
    if not AmmoControl.TeleportArmorEnabled then
        return
    end
    
    local currentTime = tick()
    if currentTime - AmmoControl.LastArmorTeleport < AmmoControl.TeleportCooldown then
        return
    end
    
    local armorItems = FindArmorItems()
    if #armorItems == 0 then
        return
    end
    
    -- Clean up teleported armor tracking
    local validTeleportedArmor = {}
    for item, timestamp in pairs(AmmoControl.TeleportedArmor) do
        if item and item.Parent then
            validTeleportedArmor[item] = timestamp
        end
    end
    AmmoControl.TeleportedArmor = validTeleportedArmor
    
    -- Filter out already teleported armor
    local availableItems = {}
    for _, itemData in ipairs(armorItems) do
        if not AmmoControl.TeleportedArmor[itemData.Item] then
            table.insert(availableItems, itemData)
        end
    end
    
    if #availableItems == 0 then
        return
    end
    
    -- Sort by distance to player
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local playerPos = char.HumanoidRootPart.Position
        for _, itemData in ipairs(availableItems) do
            itemData.Distance = (itemData.Part.Position - playerPos).Magnitude
        end
        table.sort(availableItems, function(a, b) return a.Distance < b.Distance end)
    end
    
    -- Use UltimateItemTransporter for the closest armor
    local item = availableItems[1]
    local destination = AmmoControl.TeleportDestination == "Campfire" and workspace.Map.Campground.MainFire or "Player"
    
    -- Mark armor as being teleported IMMEDIATELY
    AmmoControl.TeleportedArmor[item.Item] = currentTime
    
    local success = UltimateItemTransporter(item.Item, destination, nil, 120, AmmoControl.SavedPlayerPosition, AmmoControl.TeleportHeight)
    
    if success then
        AmmoControl.LastArmorTeleport = currentTime
    else
        AmmoControl.TeleportedArmor[item.Item] = nil
    end
end

-- Simple chest finding and teleport function
local function FindAndTeleportToChest(chestName)
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        -- Removed notification as requested
        return
    end
    
    local foundChests = {}
    
    -- Find all chests of the specified type
    for _, item in pairs(itemsFolder:GetChildren()) do
        if item.Name == chestName then
            -- Check for opened attribute - look for any attribute containing "Opened"
            local isOpened = false
            for attributeName, attributeValue in pairs(item:GetAttributes()) do
                if string.find(attributeName, "Opened") and attributeValue == true then
                    isOpened = true
                    break
                end
            end
            
            if not isOpened then
                -- Get position
                local position = Vector3.new(0, 0, 0)
                if item:IsA("BasePart") then
                    position = item.Position
                elseif item:IsA("Model") and item.PrimaryPart then
                    position = item.PrimaryPart.Position
                elseif item:IsA("Model") then
                    for _, child in pairs(item:GetChildren()) do
                        if child:IsA("BasePart") then
                            position = child.Position
                            break
                        end
                    end
                end
                
                table.insert(foundChests, {
                    Object = item,
                    Position = position
                })
            end
        end
    end
    
    if #foundChests == 0 then
        -- Removed notification as requested
        return
    end
    
    -- Sort by distance to player (get closest)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local playerPos = char.HumanoidRootPart.Position
        table.sort(foundChests, function(a, b)
            local distA = (playerPos - a.Position).Magnitude
            local distB = (playerPos - b.Position).Magnitude
            return distA < distB
        end)
        
        -- Teleport to closest chest
        local closestChest = foundChests[1]
        local targetPosition = closestChest.Position + Vector3.new(0, 5, 0)
        char.HumanoidRootPart.CFrame = CFrame.new(targetPosition)
        
        -- Auto-open chest using remote after teleporting
        task.wait(0.5) -- Small delay to ensure teleportation completes
        local success, errorMsg = pcall(function()
            local openChestRemote = RemoteEvents:FindFirstChild("RequestOpenItemChest")
            if openChestRemote then
                openChestRemote:FireServer(closestChest.Object)
            end
        end)
        if not success then
            warn("Failed to open chest: " .. tostring(errorMsg))
        end
        
        -- Removed notification as requested
    end
end

-- Auto loot chests function
local function AutoLootChests()
    if not ChestControl.AutoLootEnabled then
        return
    end
    
    -- STEP 0: Disable combat and chopping/mining systems
    -- Save current states
    ChestControl.SavedStates.KillAuraEnabled = CombatControl.KillAuraEnabled
    ChestControl.SavedStates.UltraKillEnabled = CombatControl.UltraKillEnabled
    ChestControl.SavedStates.TeammateKillAuraEnabled = CombatControl.TeammateKillAuraEnabled
    ChestControl.SavedStates.ChoppingAuraEnabled = TreesControl.ChoppingAuraEnabled
    ChestControl.SavedStates.UltraChoppingEnabled = TreesControl.UltraChoppingEnabled
    ChestControl.SavedStates.MiningAuraEnabled = MeteorsControl.MiningAuraEnabled
    ChestControl.SavedStates.UltraMiningEnabled = MeteorsControl.UltraMiningEnabled
    
    -- Disable all combat and chopping/mining systems
    CombatControl.KillAuraEnabled = false
    CombatControl.UltraKillEnabled = false
    CombatControl.TeammateKillAuraEnabled = false
    TreesControl.ChoppingAuraEnabled = false
    TreesControl.UltraChoppingEnabled = false
    MeteorsControl.MiningAuraEnabled = false
    MeteorsControl.UltraMiningEnabled = false
    
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return
    end
    
    local player = LocalPlayer
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    -- Save original player position
    local originalPosition = character.HumanoidRootPart.CFrame
    
    local availableChests = {}
    
    -- Find all unopened and unlocked chests
    for _, item in pairs(itemsFolder:GetChildren()) do
        if string.find(item.Name:lower(), "chest") then
            local isOpened = false
            local isLocked = false
            
            for attributeName, attributeValue in pairs(item:GetAttributes()) do
                if string.find(attributeName, "Opened") and attributeValue == true then
                    isOpened = true
                elseif string.find(attributeName, "Locked") and attributeValue == true then
                    isLocked = true
                end
            end
            
            if not isOpened and not isLocked then
                local position = Vector3.new(0, 0, 0)
                if item:IsA("BasePart") then
                    position = item.Position
                elseif item:IsA("Model") and item.PrimaryPart then
                    position = item.PrimaryPart.Position
                elseif item:IsA("Model") then
                    for _, child in pairs(item:GetChildren()) do
                        if child:IsA("BasePart") then
                            position = child.Position
                            break
                        end
                    end
                end
                
                table.insert(availableChests, {
                    Object = item,
                    Position = position
                })
            end
        end
    end
    
    if #availableChests == 0 then
        -- Return to original position if no chests found
        character.HumanoidRootPart.CFrame = originalPosition
        return
    end
    
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
    local openChestRemote = RemoteEvents:FindFirstChild("RequestOpenItemChest")
    
    if not requestStartDragging or not stopDragging or not openChestRemote then
        character.HumanoidRootPart.CFrame = originalPosition
        return
    end
    
    -- STEP 1: Open ALL chests first
    for _, chestData in ipairs(availableChests) do
        openChestRemote:FireServer(chestData.Object)
    end
    
    task.wait(0.5)
    
    -- Track all transported items for final stop dragging
    local allTransportedItems = {}
    
    -- Helper function to collect items around a chest position
    local function collectItemsAroundChest(chestPosition, originalPos)
        local foundItems = {}
        for _, item in pairs(itemsFolder:GetChildren()) do
            if item.PrimaryPart then
                local distance = (item.PrimaryPart.Position - chestPosition).Magnitude
                -- Exclude items that are chests themselves (Item Chest, Snow Chest, Volcanic Chest, etc.)
                local isChest = string.find(item.Name, "Item Chest") ~= nil or 
                                string.find(item.Name, "Snow Chest") ~= nil or
                                string.find(item.Name, "Volcanic Chest") ~= nil
                if distance <= 10 and not isChest then
                    table.insert(foundItems, item)
                end
            end
        end
        
        -- Drag and teleport all found items
        for _, item in ipairs(foundItems) do
            requestStartDragging:FireServer(item)
            if item.PrimaryPart then
                item.PrimaryPart.CFrame = CFrame.new(originalPos.Position + Vector3.new(0, 5, 0))
                table.insert(allTransportedItems, item)
            end
        end
        
        return #foundItems
    end
    
    -- STEP 2: Progressive chest visiting with re-checking system
    for i, chestData in ipairs(availableChests) do
        if not ChestControl.AutoLootEnabled then
            break
        end
        
        -- Teleport to current chest
        character.HumanoidRootPart.CFrame = CFrame.new(chestData.Position + Vector3.new(0, 20, 0))
        task.wait(0.1)
        
        -- Collect items around current chest
        collectItemsAroundChest(chestData.Position, originalPosition)
        
        -- PROGRESSIVE RE-CHECK: Re-check previous chest (if not first chest)
        if i > 1 then
            local previousChest = availableChests[i-1]
            collectItemsAroundChest(previousChest.Position, originalPosition)
        end
        
        task.wait(0.1) -- Keep existing timing, no extra delays
    end
    
    -- Return to original position
    character.HumanoidRootPart.CFrame = originalPosition
    
    -- FINAL SWEEP: Re-check ALL chests one more time
    for _, chestData in ipairs(availableChests) do
        collectItemsAroundChest(chestData.Position, originalPosition)
    end

    -- FINAL STEP: Stop dragging all transported items
    for _, item in ipairs(allTransportedItems) do
        stopDragging:FireServer(item)
    end

    -- Disable the auto loot after completion
    ChestControl.AutoLootEnabled = false
    
    -- Wait 2 seconds before restoring combat/chopping systems
    task.wait(2)
    
    -- Restore previous states of combat and chopping/mining systems
    CombatControl.KillAuraEnabled = ChestControl.SavedStates.KillAuraEnabled
    CombatControl.UltraKillEnabled = ChestControl.SavedStates.UltraKillEnabled
    CombatControl.TeammateKillAuraEnabled = ChestControl.SavedStates.TeammateKillAuraEnabled
    TreesControl.ChoppingAuraEnabled = ChestControl.SavedStates.ChoppingAuraEnabled
    TreesControl.UltraChoppingEnabled = ChestControl.SavedStates.UltraChoppingEnabled
    MeteorsControl.MiningAuraEnabled = ChestControl.SavedStates.MiningAuraEnabled or false
    MeteorsControl.UltraMiningEnabled = ChestControl.SavedStates.UltraMiningEnabled or false
end

-- Chest summary function
local function ShowChestSummary()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        -- Removed notification as requested
        return
    end
    
    local chestTypes = {
        "Item Chest",
        "Item Chest2", 
        "Item Chest3",
        "Item Chest4",
        "Item Chest5",
        "Item Chest6",
        "Volcanic Chest1",
        "Volcanic Chest2",
        "Snow Chest1",
        "Snow Chest2"
    }
    
    local chestCounts = {}
    local totalChests = 0
    local totalOpened = 0
    
    -- Initialize counts
    for _, chestType in pairs(chestTypes) do
        chestCounts[chestType] = {available = 0, opened = 0}
    end
    
    -- Scan all items
    for _, item in pairs(itemsFolder:GetChildren()) do
        for _, chestType in pairs(chestTypes) do
            if item.Name == chestType then
                -- Check for opened attribute - look for any attribute containing "Opened"
                local isOpened = false
                for attributeName, attributeValue in pairs(item:GetAttributes()) do
                    if string.find(attributeName, "Opened") and attributeValue == true then
                        isOpened = true
                        break
                    end
                end
                
                if isOpened then
                    chestCounts[chestType].opened = chestCounts[chestType].opened + 1
                    totalOpened = totalOpened + 1
                else
                    chestCounts[chestType].available = chestCounts[chestType].available + 1
                end
                totalChests = totalChests + 1
                break
            end
        end
    end
    
    -- Build summary message
    local summaryLines = {}
    table.insert(summaryLines, "=== CHEST SUMMARY ===")
    table.insert(summaryLines, "")
    
    for _, chestType in pairs(chestTypes) do
        local available = chestCounts[chestType].available
        local opened = chestCounts[chestType].opened
        local total = available + opened
        
        if total > 0 then
            table.insert(summaryLines, chestType .. ": " .. available .. " available, " .. opened .. " opened")
        else
            table.insert(summaryLines, chestType .. ": None found")
        end
    end
    
    table.insert(summaryLines, "")
    table.insert(summaryLines, "TOTAL: " .. (totalChests - totalOpened) .. " available / " .. totalChests .. " total")
    
    local summaryContent = table.concat(summaryLines, "\n")
    
    -- Removed notification as requested - summary content available but not displayed
end

-- Chest dropdown data storage for each chest type
local ChestDropdowns = {}
local ChestDropdownData = {}

-- Initialize chest types and their dropdown data
local ChestTypes = {
    "Item Chest",
    "Item Chest2", 
    "Item Chest3",
    "Item Chest4",
    "Item Chest5",
    "Item Chest6",
    "Snow Chest1",
    "Snow Chest2",
    "Volcanic Chest1",
    "Volcanic Chest2",
    "Snow Chest1",
    "Snow Chest2"
}

-- Initialize dropdown data for each chest type
for _, chestType in pairs(ChestTypes) do
    ChestDropdownData[chestType] = {
        Options = {"None"},
        ChestObjects = {}
    }
end

-- Function to scan and build chest dropdown options for all chest types
local function UpdateAllChestDropdowns()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        -- Removed notification as requested - no notifications needed
        return
    end
    
    -- Reset all dropdown data
    for _, chestType in pairs(ChestTypes) do
        ChestDropdownData[chestType].Options = {"None"}
        ChestDropdownData[chestType].ChestObjects = {}
    end
    
    -- Scan all items and categorize by chest type
    for _, item in pairs(itemsFolder:GetChildren()) do
        for _, chestType in pairs(ChestTypes) do
            if item.Name == chestType then
                -- Check for opened attribute - look for any attribute containing "Opened"
                local isOpened = false
                for attributeName, attributeValue in pairs(item:GetAttributes()) do
                    if string.find(attributeName, "Opened") and attributeValue == true then
                        isOpened = true
                        break
                    end
                end
                
                if not isOpened then -- Only available chests
                    -- Get position
                    local position = Vector3.new(0, 0, 0)
                    if item:IsA("BasePart") then
                        position = item.Position
                    elseif item:IsA("Model") and item.PrimaryPart then
                        position = item.PrimaryPart.Position
                    elseif item:IsA("Model") then
                        for _, child in pairs(item:GetChildren()) do
                            if child:IsA("BasePart") then
                                position = child.Position
                                break
                            end
                        end
                    end
                    
                    local optionText = string.format("[%.0f, %.0f, %.0f]", 
                        position.X, position.Y, position.Z)
                    
                    table.insert(ChestDropdownData[chestType].Options, optionText)
                    table.insert(ChestDropdownData[chestType].ChestObjects, {
                        Object = item,
                        Position = position,
                        Type = chestType
                    })
                end
                break
            end
        end
    end
    
    -- Update all actual dropdowns if they exist
    for chestType, dropdown in pairs(ChestDropdowns) do
        if dropdown then
            dropdown:Refresh(ChestDropdownData[chestType].Options)
        end
    end
    
    -- Removed notification as requested - no notifications needed
end

-- Function to teleport to selected chest from specific chest type dropdown
local function TeleportToSelectedChestByType(chestType, selectedOption)
    if selectedOption == "None" then
        return
    end
    
    -- Find the chest object based on selected option for this chest type
    local selectedChest = nil
    for _, chestData in pairs(ChestDropdownData[chestType].ChestObjects) do
        local optionText = string.format("[%.0f, %.0f, %.0f]", 
            chestData.Position.X, chestData.Position.Y, chestData.Position.Z)
        
        if optionText == selectedOption then
            selectedChest = chestData
            break
        end
    end
    
    if selectedChest and selectedChest.Object and selectedChest.Object.Parent then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local targetPosition = selectedChest.Position + Vector3.new(0, 5, 0)
            char.HumanoidRootPart.CFrame = CFrame.new(targetPosition)
            -- Removed notification as requested
            
            -- Auto-open chest using remote after teleporting
            task.wait(0.3) -- Small delay to ensure teleportation completes
            local success, errorMsg = pcall(function()
                local openChestRemote = RemoteEvents:FindFirstChild("RequestOpenItemChest")
                if openChestRemote then
                    openChestRemote:FireServer(selectedChest.Object)
                end
            end)
            if not success then
                warn("Failed to open chest: " .. tostring(errorMsg))
            end
        end
    else
        -- Refresh this specific dropdown since the chest is no longer available
        UpdateAllChestDropdowns()
    end
end

-- ========== ESP SYSTEM (ELEGANT & MODERN) ==========

-- Create elegant ESP for an object
local function CreateESP(object, text, color)
    local espFolder = workspace:FindFirstChild("ESP_Elements")
    if not espFolder then
        espFolder = Instance.new("Folder")
        espFolder.Name = "ESP_Elements"
        espFolder.Parent = workspace
    end
    
    -- Get object position
    local position = Vector3.new(0, 0, 0)
    if object:IsA("BasePart") then
        position = object.Position
    elseif object:IsA("Model") and object.PrimaryPart then
        position = object.PrimaryPart.Position
    elseif object:IsA("Model") then
        for _, child in pairs(object:GetChildren()) do
            if child:IsA("BasePart") then
                position = child.Position
                break
            end
        end
    end
    
    -- Create BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_" .. object.Name
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Parent = espFolder
    
    -- Create main frame with modern design
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    
    -- Add subtle gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0.1, 0.1, 0.1)),
        ColorSequenceKeypoint.new(1, Color3.new(0.05, 0.05, 0.05))
    })
    gradient.Rotation = 90
    gradient.Parent = frame
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Add subtle stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = frame
    
    -- Create text label
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -10, 1, 0)
    textLabel.Position = UDim2.new(0, 5, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = text
    textLabel.TextColor3 = color
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Parent = frame
    
    -- Add distance calculation (OPTIMIZED VERSION)
    local function updateDistance()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and textLabel.Parent then
            local distance = math.floor((char.HumanoidRootPart.Position - position).Magnitude)
            -- Only update text if distance actually changed to reduce GUI updates
            local newText = text .. " [" .. distance .. "m]"
            if textLabel.Text ~= newText then
                textLabel.Text = newText
            end
        end
    end
    
    -- Update distance initially
    updateDistance()
    
    -- Create attachment point
    local attachment = Instance.new("Attachment")
    attachment.Parent = object:IsA("BasePart") and object or (object:IsA("Model") and object.PrimaryPart) or object:FindFirstChildOfClass("BasePart")
    if attachment.Parent then
        billboard.Adornee = attachment.Parent
    end
    
    -- Store ESP data
    local espData = {
        Billboard = billboard,
        Object = object,
        UpdateDistance = updateDistance,
        Attachment = attachment
    }
    
    -- Add to ESP objects for management
    table.insert(ESPControl.ESPObjects, espData)
    
    return espData
end

-- Remove all ESP elements
local function ClearAllESP()
    for _, espData in pairs(ESPControl.ESPObjects) do
        if espData.Billboard and espData.Billboard.Parent then
            espData.Billboard:Destroy()
        end
    end
    ESPControl.ESPObjects = {}
    
    -- Clean up ESP folder
    local espFolder = workspace:FindFirstChild("ESP_Elements")
    if espFolder then
        espFolder:Destroy()
    end
end

-- Update ESP for specific category (OPTIMIZED VERSION - FIXED TOGGLE OFF)
local function UpdateESPCategory(category)
    local itemsFolder = workspace:FindFirstChild("Items")
    local charactersFolder = workspace:FindFirstChild("Characters")
    
    if not itemsFolder and category ~= "Players" and category ~= "Entities" then
        return
    end
    
    if category == "Entities" and not charactersFolder then
        return
    end
    
    -- First, remove all ESP for this category if it's disabled
    for i = #ESPControl.ESPObjects, 1, -1 do
        local espData = ESPControl.ESPObjects[i]
        if espData and espData.Object then
            local shouldRemove = false
            
            -- Check if this ESP belongs to the current category
            if category == "Food" then
                for _, foodType in pairs(DropdownOptions.FoodItems) do
                    if foodType ~= "All" and espData.Object.Name == foodType then
                        shouldRemove = true
                        break
                    end
                end
            elseif category == "AnimalPelts" then
                for _, peltType in pairs(DropdownOptions.AnimalPelts) do
                    if espData.Object.Name == peltType then
                        shouldRemove = true
                        break
                    end
                end
            elseif category == "Healing" then
                for _, healingType in pairs(DropdownOptions.HealingItems) do
                    if espData.Object.Name == healingType then
                        shouldRemove = true
                        break
                    end
                end
            elseif category == "Ammo" then
                for _, ammoType in pairs(DropdownOptions.AmmoItems) do
                    if ammoType ~= "All" and espData.Object.Name == ammoType then
                        shouldRemove = true
                        break
                    end
                end
            elseif category == "Entities" then
                for _, entityType in pairs(DropdownOptions.EntityTypes) do
                    if espData.Object.Name == entityType then
                        shouldRemove = true
                        break
                    end
                end
            elseif category == "Chests" then
                for _, chestType in pairs(ChestTypes) do
                    if espData.Object.Name == chestType then
                        shouldRemove = true
                        break
                    end
                end
            elseif category == "Players" then
                if espData.Object:IsA("Model") and espData.Object:FindFirstChild("Humanoid") and espData.Object ~= LocalPlayer.Character then
                    shouldRemove = true
                end
            end
            
            if shouldRemove then
                if espData.Billboard and espData.Billboard.Parent then
                    espData.Billboard:Destroy()
                end
                table.remove(ESPControl.ESPObjects, i)
            end
        end
    end
    
    -- If category is disabled, we're done (ESP removed above)
    if not ESPControl.Categories[category] then
        return
    end
    
    -- Create a set of existing ESP objects for this category to avoid duplicates
    local existingESP = {}
    for _, espData in pairs(ESPControl.ESPObjects) do
        if espData.Object and espData.Object.Parent then
            existingESP[espData.Object] = espData
        end
    end
    
    -- Clean up invalid ESP (objects that no longer exist)
    for i = #ESPControl.ESPObjects, 1, -1 do
        local espData = ESPControl.ESPObjects[i]
        if not espData.Object or not espData.Object.Parent then
            if espData.Billboard and espData.Billboard.Parent then
                espData.Billboard:Destroy()
            end
            table.remove(ESPControl.ESPObjects, i)
        end
    end
    
    if category == "Food" then
        for _, item in pairs(itemsFolder:GetChildren()) do
            if not existingESP[item] then -- Only create ESP if it doesn't exist
                for _, foodType in pairs(DropdownOptions.FoodItems) do
                    if foodType ~= "All" and item.Name == foodType then
                        CreateESP(item, "🍖 " .. foodType, ESPControl.Colors.Food)
                        break
                    end
                end
            end
        end
    elseif category == "AnimalPelts" then
        for _, item in pairs(itemsFolder:GetChildren()) do
            if not existingESP[item] then
                for _, peltType in pairs(DropdownOptions.AnimalPelts) do
                    if item.Name == peltType then
                        CreateESP(item, "🦊 " .. peltType, ESPControl.Colors.AnimalPelts)
                        break
                    end
                end
            end
        end
    elseif category == "Healing" then
        for _, item in pairs(itemsFolder:GetChildren()) do
            if not existingESP[item] then
                for _, healingType in pairs(DropdownOptions.HealingItems) do
                    if item.Name == healingType then
                        CreateESP(item, "💊 " .. healingType, ESPControl.Colors.Healing)
                        break
                    end
                end
            end
        end
    elseif category == "Ammo" then
        for _, item in pairs(itemsFolder:GetChildren()) do
            if not existingESP[item] then
                for _, ammoType in pairs(DropdownOptions.AmmoItems) do
                    if ammoType ~= "All" and item.Name == ammoType then
                        CreateESP(item, "🔫 " .. ammoType, ESPControl.Colors.Ammo)
                        break
                    end
                end
            end
        end
    elseif category == "Entities" then
        -- Entities are found in workspace.Characters folder
        local charactersFolder = workspace:FindFirstChild("Characters")
        if charactersFolder then
            for _, entity in pairs(charactersFolder:GetChildren()) do
                if entity:IsA("Model") and entity:FindFirstChild("NPC") and entity:FindFirstChild("HumanoidRootPart") and not existingESP[entity] then
                    for _, entityType in pairs(DropdownOptions.EntityTypes) do
                        if entity.Name == entityType then
                            CreateESP(entity, "👹 " .. entityType, ESPControl.Colors.Entities)
                            break
                        end
                    end
                end
            end
        end
    elseif category == "Chests" then
        for _, item in pairs(itemsFolder:GetChildren()) do
            if not existingESP[item] then
                for _, chestType in pairs(ChestTypes) do
                    if item.Name == chestType then
                        -- Check if chest is not opened
                        local isOpened = false
                        for attributeName, attributeValue in pairs(item:GetAttributes()) do
                            if string.find(attributeName, "Opened") and attributeValue == true then
                                isOpened = true
                                break
                            end
                        end
                        
                        if not isOpened then
                            CreateESP(item, "📦 " .. chestType, ESPControl.Colors.Chests)
                        end
                        break
                    end
                end
            end
        end
    elseif category == "Players" then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and not existingESP[player.Character] then
                CreateESP(player.Character, "👤 " .. player.Name, ESPControl.Colors.Players)
            end
        end
    end
end

-- Update all ESP (OPTIMIZED VERSION)
local function UpdateAllESP()
    if not ESPControl.Enabled then
        ClearAllESP()
        return
    end
    
    local currentTime = tick()
    
    -- Only update distance every frame (lightweight)
    for _, espData in pairs(ESPControl.ESPObjects) do
        if espData.UpdateDistance and espData.Billboard.Parent then
            pcall(espData.UpdateDistance)
        end
    end
    
    -- Only rescan for new/removed items every 1 second (heavy operation)
    ESPControl.LastUpdate = ESPControl.LastUpdate or 0
    if currentTime - ESPControl.LastUpdate >= 1 then
        ESPControl.LastUpdate = currentTime
        
        -- Update each category
        for category, enabled in pairs(ESPControl.Categories) do
            if enabled then
                UpdateESPCategory(category)
            end
        end
    end
end

-- ULTRA FAST Teleport crafting item to scrapper (maximum speed optimized)
local function TeleportItemToScrapper(item, itemPart)
    local destination
    if CraftingControl.TeleportDestination == "Scrapper" then
        destination = workspace.Map.Campground.Scrapper
    elseif CraftingControl.TeleportDestination == "Player" then
        destination = "Player"
    elseif CraftingControl.TeleportDestination == "Sack" then
        local success = SackCraftingProcess(item)
        if success then
            CraftingControl.TeleportedItems[item] = tick()
        end
        return success
    end
    
    if destination then
        -- SPEED: Pre-cached wood check for any destination
        local itemName = item.Name
        local isWoodItem = (itemName:find("Log") or itemName:find("Wood") or itemName:lower():find("log") or itemName:lower():find("wood"))
        
        -- SPEED: Direct function call without variable assignment
        if isWoodItem then
            -- ULTRA FAST wood teleportation (works for any destination)
            if PhysicsSafeWoodTransporter(item, destination, CraftingControl.TeleportedItems, 
                                         CraftingControl.TeleportCooldown, CraftingControl.SavedPlayerPosition, 
                                         CraftingControl.TeleportHeight) then
                return true
            end
        else
            -- Regular fast teleportation
            if FastScrapperTransporter(item, destination, CraftingControl.TeleportedItems, 
                                      CraftingControl.TeleportCooldown, CraftingControl.SavedPlayerPosition, 
                                      CraftingControl.TeleportHeight) then
                return true
            end
        end
    end
    return false
end

-- Teleport gem to destination using FastGemTransporter (optimized for gems)
local function TeleportGemToScrapper(item, itemPart)
    local destination
    if CraftingControl.TeleportDestination == "Scrapper" then
        destination = workspace.Map.Campground.Scrapper
    elseif CraftingControl.TeleportDestination == "Player" then
        destination = "Player"
    elseif CraftingControl.TeleportDestination == "Sack" then
        local success = SackCraftingProcess(item)
        if success then
            CraftingControl.TeleportedItems[item] = tick()
        end
        return success
    end
    
    if destination then
        -- Use FastGemTransporter for gems with lock checking
        local success = FastGemTransporter(
            item, 
            destination, 
            CraftingControl.TeleportedItems, 
            CraftingControl.TeleportCooldown,
            CraftingControl.SavedPlayerPosition, 
            CraftingControl.TeleportHeight
        )
        if success then
            return true
        else
            return false
        end
    end
    return false
end

-- Execute crafting operations
local function UpdateCrafting()
    if not CraftingControl.ProduceScrapEnabled and not CraftingControl.ProduceWoodEnabled and not CraftingControl.ProduceCultistGemEnabled and not CraftingControl.ProduceForestGemEnabled then
        return
    end
    
    local currentTime = tick()
    
    -- Always use the TeleportCooldown from slider for all crafting operations
    if currentTime - CraftingControl.LastCraftingCheck < CraftingControl.TeleportCooldown then
        return
    end
    
    CraftingControl.LastCraftingCheck = currentTime
    
    local success = false
    
    if CraftingControl.ProduceScrapEnabled then
        -- ESSENTIAL: Keep teleported items tracking to prevent re-teleporting same items
        local validTeleportedItems = {}
        for item, timestamp in pairs(CraftingControl.TeleportedItems) do
            if item.Parent and (tick() - timestamp) < 300 then -- Keep items marked for 5 minutes
                validTeleportedItems[item] = timestamp
            end
        end
        CraftingControl.TeleportedItems = validTeleportedItems
        
        -- Clean up skipped locked gems (remove items that no longer exist or are older than 10 minutes)
        for item, timestamp in pairs(CraftingControl.SkippedLockedGems) do
            if not item.Parent or (tick() - timestamp) >= 600 then -- Remove if item gone or older than 10 minutes
                CraftingControl.SkippedLockedGems[item] = nil
            end
        end
        
        -- Find and process scrap items
        local scrapItems = FindScrapItems()
        for _, itemData in ipairs(scrapItems) do
            if not CraftingControl.TeleportedItems[itemData.Item] then
                -- Mark item immediately to prevent duplicate attempts
                CraftingControl.TeleportedItems[itemData.Item] = currentTime
                
                -- Found available item, teleport it
                TeleportItemToScrapper(itemData.Item, itemData.Part)
                break -- Only process one item per cycle for better performance
            end
        end
    elseif CraftingControl.ProduceWoodEnabled then
        -- Special cleanup for wood scrapping to scrapper: remove timestamp after 3 seconds if log still exists
        if CraftingControl.TeleportDestination == "Scrapper" then
            local validTeleportedItems = {}
            for item, timestamp in pairs(CraftingControl.TeleportedItems) do
                if item.Parent and (tick() - timestamp) < 3 then -- Only keep logs marked for 3 seconds
                    validTeleportedItems[item] = timestamp
                end
            end
            CraftingControl.TeleportedItems = validTeleportedItems
        end
        
        -- Process one log at a time
        local woodItems = FindWoodItemsForCrafting()
        
        -- Find first available log (not already teleported)
        for _, itemData in ipairs(woodItems) do
            if not CraftingControl.TeleportedItems[itemData.Item] then
                -- Teleport the log (marking happens inside TeleportItemToScrapper or transporter functions)
                if CraftingControl.TeleportDestination == "Sack" then
                    SackCraftingProcess(itemData.Item)
                else
                    TeleportItemToScrapper(itemData.Item, itemData.Part)
                end
                break -- Only process one log per cycle
            end
        end
    elseif CraftingControl.ProduceCultistGemEnabled then
        -- ESSENTIAL: Keep teleported items tracking to prevent re-teleporting same items
        local validTeleportedItems = {}
        for item, timestamp in pairs(CraftingControl.TeleportedItems) do
            if item.Parent and (tick() - timestamp) < 10 then -- Keep items marked for 10 seconds
                validTeleportedItems[item] = timestamp
            end
        end
        CraftingControl.TeleportedItems = validTeleportedItems
        
        -- Find and process cultist gem items
        local cultistGemItems = FindCultistGemItemsForCrafting()
        for _, itemData in ipairs(cultistGemItems) do
            if not CraftingControl.TeleportedItems[itemData.Item] then
                -- Mark item immediately to prevent duplicate attempts
                CraftingControl.TeleportedItems[itemData.Item] = currentTime
                
                -- Found available gem, teleport it using FastGemTransporter
                TeleportGemToScrapper(itemData.Item, itemData.Part)
                break -- Only process one item per cycle
            end
        end
    elseif CraftingControl.ProduceForestGemEnabled then
        local validTeleportedItems = {}
        for item, timestamp in pairs(CraftingControl.TeleportedItems) do
            if item.Parent and (tick() - timestamp) < 10 then
                validTeleportedItems[item] = timestamp
            end
        end
        CraftingControl.TeleportedItems = validTeleportedItems
        
        local forestGemItems = FindForestGemItemsForCrafting()
        local fragments = {}
        
        for _, itemData in ipairs(forestGemItems) do
            if not CraftingControl.TeleportedItems[itemData.Item] then
                -- Check locked status (skip locked items)
                if itemData.Item:GetAttribute("Locked") == true then
                    CraftingControl.SkippedLockedGems[itemData.Item] = tick()
                else
                    -- Re-check previously locked items after 3 seconds
                    if CraftingControl.SkippedLockedGems[itemData.Item] then
                        if tick() - CraftingControl.SkippedLockedGems[itemData.Item] < 3 then
                            -- Still within wait period, skip
                        else
                            -- Re-check lock status
                            if itemData.Item:GetAttribute("Locked") == true then
                                CraftingControl.SkippedLockedGems[itemData.Item] = tick()
                            else
                                CraftingControl.SkippedLockedGems[itemData.Item] = nil
                                if itemData.IsFragment then
                                    table.insert(fragments, itemData)
                                else
                                    CraftingControl.TeleportedItems[itemData.Item] = currentTime
                                    TeleportGemToScrapper(itemData.Item, itemData.Part)
                                    return
                                end
                            end
                        end
                    else
                        -- Not locked, process normally
                        if itemData.IsFragment then
                            table.insert(fragments, itemData)
                        else
                            CraftingControl.TeleportedItems[itemData.Item] = currentTime
                            TeleportGemToScrapper(itemData.Item, itemData.Part)
                            return
                        end
                    end
                end
            end
        end
        
        -- Teleport all unlocked fragments to campfire using FastGemTransporter
        if #fragments > 0 then
            for _, fragmentData in ipairs(fragments) do
                CraftingControl.TeleportedItems[fragmentData.Item] = currentTime
                FastGemTransporter(fragmentData.Item, workspace.Map.Campground.MainFire, CraftingControl.TeleportedItems, CraftingControl.TeleportCooldown, CraftingControl.SavedPlayerPosition, CraftingControl.TeleportHeight)
            end
        end
    end
end

-- Forward declare functions so they can be called from StepUpdate
local UpdateKillAura
local UpdateTeammateKillAura
local UpdateChoppingAura

-- Per-step maintenance (fly + reinforce overrides so sprint system doesn't permanently override)
local function StepUpdate()
    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")

        if PlayerControl.FlyEnabled and humanoid and root then
            -- AGGRESSIVE PHYSICS OVERRIDE - Complete control
            humanoid.PlatformStand = true

            -- Disable collisions while flying (allows going through platforms)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            
            -- Create BodyVelocity for absolute control (overrides all other forces)
            local bodyVelocity = root:FindFirstChild("FlyBodyVelocity")
            if not bodyVelocity then
                bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.Name = "FlyBodyVelocity"
                bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                bodyVelocity.Parent = root
            end
            
            -- Create BodyAngularVelocity for rotation control
            local bodyAngularVelocity = root:FindFirstChild("FlyBodyAngularVelocity")
            if not bodyAngularVelocity then
                bodyAngularVelocity = Instance.new("BodyAngularVelocity")
                bodyAngularVelocity.Name = "FlyBodyAngularVelocity"
                bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
                bodyAngularVelocity.Parent = root
            end

            local cam = workspace.CurrentCamera
            local moveVec = Vector3.zero
            if cam then
                local cf = cam.CFrame
                local forward = cf.LookVector -- full look (includes pitch)
                local right = cf.RightVector
                local fScale, rScale = 0, 0
                if FlyKeys.W then fScale += 1 end
                if FlyKeys.S then fScale -= 1 end
                if FlyKeys.D then rScale += 1 end
                if FlyKeys.A then rScale -= 1 end
                if fScale ~= 0 then moveVec += forward * fScale end
                if rScale ~= 0 then moveVec += right * rScale end
            end
            -- Manual vertical overrides (Space / Shift) stack with camera aim
            if FlyKeys.Space then moveVec += Vector3.new(0,1,0) end
            if FlyKeys.LeftShift then moveVec += Vector3.new(0,-1,0) end
            if moveVec.Magnitude > 0 then
                moveVec = moveVec.Unit * PlayerControl.FlySpeed
            else
                -- COMPLETE STOP - no movement at all
                moveVec = Vector3.zero
            end
            
            -- Use BodyVelocity for absolute control (overrides gravity completely)
            bodyVelocity.Velocity = moveVec
            bodyAngularVelocity.AngularVelocity = Vector3.zero
            
            -- Also set AssemblyVelocity as backup
            root.AssemblyLinearVelocity = moveVec
            root.AssemblyAngularVelocity = Vector3.zero
        else
            if humanoid then
                humanoid.PlatformStand = false
                -- Continuous speed / jump reinforcement (handles sprint module overwriting values)
                if PlayerControl.SpeedEnabled and PlayerControl.SpeedValue and math.abs(humanoid.WalkSpeed - PlayerControl.SpeedValue) > 0.05 then
                    humanoid.WalkSpeed = PlayerControl.SpeedValue
                end
                if PlayerControl.JumpEnabled and PlayerControl.JumpValue then
                    if humanoid.UseJumpPower then
                        if math.abs(humanoid.JumpPower - PlayerControl.JumpValue) > 0.05 then
                            humanoid.JumpPower = PlayerControl.JumpValue
                        end
                    else
                        if math.abs(humanoid.JumpHeight - PlayerControl.JumpValue) > 0.05 then
                            humanoid.JumpHeight = PlayerControl.JumpValue
                        end
                    end
                end
            end
        end
        
        -- Kill Aura enforcement
        if CombatControl.KillAuraEnabled and UpdateKillAura then
            pcall(UpdateKillAura)
        end

        if CombatControl.TeammateKillAuraEnabled and UpdateTeammateKillAura then
            pcall(UpdateTeammateKillAura)
        end
        
        -- Tree Chopping enforcement
        if TreesControl.ChoppingAuraEnabled and UpdateTreeChopping then
            pcall(UpdateTreeChopping)
        end
        
        -- Ice Block Damage enforcement
        if TreesControl.IceBlockDamageEnabled then
            pcall(DamageIceBlocks)
        end
        
        -- Meteor Mining enforcement
        if MeteorsControl.MiningAuraEnabled and UpdateMeteorMining then
            pcall(UpdateMeteorMining)
        end
        
        -- Campfire Refill enforcement
        if CampfireControl.AutoRefillEnabled then
            pcall(UpdateCampfireRefill)
        end
        
        -- Crafting enforcement
        if CraftingControl.ProduceScrapEnabled or CraftingControl.ProduceWoodEnabled or CraftingControl.ProduceCultistGemEnabled or CraftingControl.ProduceForestGemEnabled then
            pcall(UpdateCrafting)
        end
        
        -- Food teleport enforcement
        if FoodControl.TeleportFoodEnabled then
            pcall(UpdateFoodTeleport)
        end
        
        -- Auto Cook Pot enforcement
        if FoodControl.AutoCookPotEnabled then
            pcall(UpdateAutoCookPot)
        end
        
        -- Chef Stove enforcement
        if FoodControl.ChefStoveEnabled then
            pcall(UpdateChefStove)
        end

        -- Invincible enforcement
        if FoodControl.Invincible.Enabled then
            UpdateInvincible()
        end
        
        -- Auto Collect Flowers enforcement
        if FoodControl.AutoCollectFlowers.Enabled then
            UpdateAutoCollectFlowers()
        end
        
        -- Animal Pelts teleport enforcement
        if AnimalPeltsControl.TeleportPeltsEnabled then
            pcall(UpdateAnimalPeltsTeleport)
        end

        -- Meteor shard teleport enforcement
        if MeteorShardControl.TeleportShardsEnabled then
            pcall(UpdateMeteorShardTeleport)
        end
        
        -- Healing teleport enforcement
        if HealingControl.TeleportHealingEnabled then
            pcall(UpdateHealingTeleport)
        end
        
        -- Ammo teleport enforcement
        if AmmoControl.TeleportAmmoEnabled then
            pcall(UpdateAmmoTeleport)
        end
        
        -- Weapon teleport enforcement
        if AmmoControl.TeleportWeaponEnabled then
            pcall(UpdateWeaponTeleport)
        end
        
        -- Armor teleport enforcement
        if AmmoControl.TeleportArmorEnabled then
            pcall(UpdateArmorTeleport)
        end
        
        -- ESP system enforcement
        if ESPControl.Enabled then
            pcall(UpdateAllESP)
        end
        
        -- Auto trap enforcement
        if TrapControl.AutoTrapEnabled then
            pcall(UpdateAutoTrap)
        end
        
        -- Trap aura enforcement
        if TrapControl.TrapAuraEnabled then
            pcall(UpdateTrapAura)
        end
        
        -- Burn enemies enforcement
        if CombatControl.BurnEnemiesEnabled then
            pcall(UpdateBurnEnemies)
        end
    end
end

-- Get Client module for damage dealing - more aggressive search
local function GetClientModule()
    -- Method 1: Direct require from PlayerScripts
    local success, client = pcall(function()
        return require(LocalPlayer.PlayerScripts.Client)
    end)
    
    if success and client then
        return client
    end
    
    -- Method 2: Search for Client in player scripts
    for _, script in pairs(LocalPlayer.PlayerScripts:GetDescendants()) do
        if script:IsA("ModuleScript") and script.Name == "Client" then
            local success2, client2 = pcall(function()
                return require(script)
            end)
            
            if success2 and client2 then
                return client2
            end
        end
    end
    
    -- Method 3: Try common game frameworks
    local commonPaths = {
        LocalPlayer.PlayerScripts.Framework,
        LocalPlayer.PlayerScripts.System,
        LocalPlayer.PlayerScripts.GameClient,
        LocalPlayer.PlayerScripts.Main,
        ReplicatedStorage.Modules,
        ReplicatedStorage.Framework,
        ReplicatedStorage.Shared
    }
    
    for _, path in pairs(commonPaths) do
        if path then
            local success3, client3 = pcall(function()
                return require(path)
            end)
            
            if success3 and client3 then
                return client3
            end
        end
    end
    
    -- Method 4: Create our own bare minimal client structure
    local customClient = {
        Events = {}
    }
    
    -- Find remote events in ReplicatedStorage
    local function findRemoteEvents()
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                customClient.Events[obj.Name] = obj
            end
        end
    end
    
    pcall(findRemoteEvents)
    
    -- Check if we found any events
    local eventCount = 0
    for _ in pairs(customClient.Events) do
        eventCount += 1
    end
    
    if eventCount > 0 then
        return customClient
    end
    
    return nil
end

-- Find hostile entities in range - simplified without debug messages
local function FindHostileEntities()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        return {} 
    end
    
    local playerPos = char.HumanoidRootPart.Position
    local entities = {}
    local entityCount = 0
    
    local searchRange = CombatControl.TeleportAboveTarget and 1000 or CombatControl.AuraRange
    
    -- Search only in workspace.Characters folder
    local charactersFolder = workspace:FindFirstChild("Characters")
    if not charactersFolder then
        return {}
    end
    
    for _, entity in pairs(charactersFolder:GetChildren()) do
        if entity == char then continue end
        
        if entity.Name:match("^Lost Child") then continue end
        if entity.Name == "Deer" or entity.Name == "Ram" or entity.Name == "Owl" or entity.Name == "Kiwi" then continue end
        
        local humanoid = entity:FindFirstChildOfClass("Humanoid")
        local rootPart = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("Torso") or entity:FindFirstChild("UpperTorso")
        
        if humanoid and rootPart and humanoid.Health > 0 then
            local distance = (playerPos - rootPart.Position).Magnitude
            if distance <= searchRange then
                -- Apply target filtering
                local shouldTarget = false
                local entityName = entity.Name:lower() -- Case-insensitive
                
                if CombatControl.TargetType == "All" then
                    shouldTarget = true
                elseif CombatControl.TargetType == "Animal" then
                    -- Target everything that does NOT have "cultist" in name
                    shouldTarget = not entityName:find("cultist")
                elseif CombatControl.TargetType == "Cultist" then
                    -- Target everything that DOES have "cultist" in name
                    shouldTarget = entityName:find("cultist") ~= nil
                end
                
                if shouldTarget then
                    local headPart = entity:FindFirstChild("Head")
                    entityCount += 1
                    table.insert(entities, {
                        Entity = entity,
                        Type = game.Players:GetPlayerFromCharacter(entity) and "Player" or "NPC",
                        Distance = distance,
                        RootPart = rootPart,
                        Head = headPart
                    })
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(entities, function(a, b) return a.Distance < b.Distance end)
    return entities
end

local function FindTeammateTargets()
    local char = LocalPlayer.Character
    if not char then
        return {}
    end

    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return {}
    end

    local selection = CombatControl.TeammateTarget or "All Players"
    local range = CombatControl.AuraRange or 0
    local targets = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if selection == "All Players" or selection == player.Name then
                local targetChar = player.Character
                local humanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
                local targetRoot = targetChar and (targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso"))

                if humanoid and targetRoot and humanoid.Health > 0 then
                    local distance = (rootPart.Position - targetRoot.Position).Magnitude
                    if distance <= range then
                        table.insert(targets, {
                            Player = player,
                            Character = targetChar,
                            RootPart = targetRoot,
                            Head = targetChar:FindFirstChild("Head"),
                            Distance = distance
                        })
                    end
                end
            end
        end
    end

    table.sort(targets, function(a, b)
        return a.Distance < b.Distance
    end)

    return targets
end

-- Create billboard GUI for health display (trees/meteors/ice blocks)
local function CreateHealthGUI(target, targetPart, isMeteor, isIceBlock)
    local guiName = isIceBlock and "IceBlockHealthGUI" or (isMeteor and "MeteorHealthGUI" or "TreeHealthGUI")
    local existingBillboard = targetPart:FindFirstChild(guiName)
    if existingBillboard then
        existingBillboard:Destroy()
    end
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = guiName
    billboardGui.Adornee = targetPart
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    
    local frame = Instance.new("Frame")
    frame.Parent = billboardGui
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Parent = frame
    healthBar.Size = UDim2.new(0.9, 0, 0.4, 0)
    healthBar.Position = UDim2.new(0.05, 0, 0.1, 0)
    healthBar.BackgroundColor3 = isIceBlock and Color3.fromRGB(0, 255, 255) or (isMeteor and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(255, 0, 0))
    healthBar.BorderSizePixel = 0
    
    local healthBg = Instance.new("Frame")
    healthBg.Parent = frame
    healthBg.Size = UDim2.new(0.9, 0, 0.4, 0)
    healthBg.Position = UDim2.new(0.05, 0, 0.1, 0)
    healthBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    healthBg.BorderSizePixel = 0
    healthBg.ZIndex = healthBar.ZIndex - 1
    
    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.Parent = frame
    healthText.Size = UDim2.new(1, 0, 0.4, 0)
    healthText.Position = UDim2.new(0, 0, 0.55, 0)
    healthText.BackgroundTransparency = 1
    healthText.Text = "100/100"
    healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
    healthText.TextScaled = true
    healthText.Font = Enum.Font.SourceSansBold
    
    billboardGui.Parent = targetPart
    
    if isIceBlock then
        TreesControl.IceBlockBillboards[target] = billboardGui
    elseif isMeteor then
        MeteorsControl.ActiveBillboards[target] = billboardGui
    else
        TreesControl.ActiveBillboards[target] = billboardGui
    end
    
    return billboardGui
end

-- Update health display (trees/meteors/ice blocks)
local function UpdateHealthGUI(target, targetPart, isMeteor, isIceBlock)
    -- Don't create new GUIs if the feature is disabled
    if isIceBlock and not TreesControl.IceBlockDamageEnabled then
        return
    end
    if isMeteor and not MeteorsControl.MiningAuraEnabled then
        return
    end
    if not isIceBlock and not isMeteor and not TreesControl.ChoppingAuraEnabled then
        return
    end
    
    local control = isIceBlock and TreesControl or (isMeteor and MeteorsControl or TreesControl)
    local billboard = isIceBlock and control.IceBlockBillboards[target] or control.ActiveBillboards[target]
    if not billboard or not billboard.Parent then
        billboard = CreateHealthGUI(target, targetPart, isMeteor, isIceBlock)
    end
    
    local currentHealth = target:GetAttribute("Health") or 0
    local maxHealth = target:GetAttribute("MaxHealth") or currentHealth
    if maxHealth <= 0 then maxHealth = 100 end
    
    local healthPercentage = math.max(0, currentHealth / maxHealth)
    
    local healthBar = billboard:FindFirstChild("Frame"):FindFirstChild("HealthBar")
    if healthBar then
        healthBar.Size = UDim2.new(0.9 * healthPercentage, 0, 0.4, 0)
        
        if isIceBlock then
            if healthPercentage > 0.6 then
                healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 255) -- Cyan
            elseif healthPercentage > 0.3 then
                healthBar.BackgroundColor3 = Color3.fromRGB(0, 150, 255) -- Light Blue
            else
                healthBar.BackgroundColor3 = Color3.fromRGB(0, 100, 200) -- Dark Blue
            end
        elseif isMeteor then
            if healthPercentage > 0.6 then
                healthBar.BackgroundColor3 = Color3.fromRGB(255, 165, 0) -- Orange
            elseif healthPercentage > 0.3 then
                healthBar.BackgroundColor3 = Color3.fromRGB(255, 100, 0) -- Dark Orange
            else
                healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
            end
        else
            if healthPercentage > 0.6 then
                healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0) -- Green
            elseif healthPercentage > 0.3 then
                healthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
            else
                healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red
            end
        end
    end
    
    local healthText = billboard:FindFirstChild("Frame"):FindFirstChild("HealthText")
    if healthText then
        healthText.Text = math.floor(currentHealth) .. "/" .. math.floor(maxHealth)
    end
    
    if currentHealth <= 0 then
        task.delay(2, function()
            if billboard and billboard.Parent then
                billboard:Destroy()
            end
            if isIceBlock then
                control.IceBlockBillboards[target] = nil
            else
                control.ActiveBillboards[target] = nil
            end
        end)
    end
end

-- Clean up billboard GUIs (trees/meteors/ice blocks)
local function CleanupGUIs(isMeteor, isIceBlock)
    if isIceBlock then
        -- Clean up ice block billboards
        for target, billboard in pairs(TreesControl.IceBlockBillboards) do
            if billboard and billboard.Parent then
                billboard:Destroy()
            end
            TreesControl.IceBlockBillboards[target] = nil
        end
    else
        -- Clean up tree/meteor billboards
        local control = isMeteor and MeteorsControl or TreesControl
        for target, billboard in pairs(control.ActiveBillboards) do
            if not target.Parent or not billboard.Parent then
                if billboard and billboard.Parent then
                    billboard:Destroy()
                end
                control.ActiveBillboards[target] = nil
            end
        end
    end
end

-- Validate and clean targets (remove dead/missing trees/meteors)
local function ValidateTargets(isMeteor)
    local control = isMeteor and MeteorsControl or TreesControl
    local validTargets = {}
    
    for _, targetData in ipairs(control.CurrentTargets) do
        local target = isMeteor and targetData.Meteor or targetData.Tree
        -- Check if target still exists and has health > 0
        if target and target.Parent and target:GetAttribute("Health") and target:GetAttribute("Health") > 0 then
            table.insert(validTargets, targetData)
        else
            -- Remove billboard for dead/missing target
            if control.ActiveBillboards[target] then
                local billboard = control.ActiveBillboards[target]
                if billboard and billboard.Parent then
                    billboard:Destroy()
                end
                control.ActiveBillboards[target] = nil
            end
        end
    end
    
    control.CurrentTargets = validTargets
end

-- Find targets in range (trees/meteors)
local function FindTargetsInRange(isMeteor)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then 
        return {} 
    end
    
    local playerPos = char.HumanoidRootPart.Position
    local targets = {}
    
    if isMeteor then
        local targetType = MeteorsControl.TargetType
        local mapFolder = workspace:FindFirstChild("Map")
        local landmarksFolder = mapFolder and mapFolder:FindFirstChild("Landmarks")
        if landmarksFolder then
            for _, landmark in pairs(landmarksFolder:GetChildren()) do
                local oreNodesFolder = landmark:FindFirstChild("OreNodes")
                if oreNodesFolder then
                    for _, node in pairs(oreNodesFolder:GetChildren()) do
                        if node:GetAttribute("Health") and (targetType == "All Meteor" or node.Name == targetType) then
                            local nodePart = node.PrimaryPart or node:FindFirstChild("Main") or node:FindFirstChild("Part") or node:FindFirstChildOfClass("BasePart")
                            if nodePart and nodePart:IsA("BasePart") then
                                local distance = (playerPos - nodePart.Position).Magnitude
                                if distance <= MeteorsControl.MiningRange then
                                    table.insert(targets, {
                                        Meteor = node,
                                        Part = nodePart,
                                        Distance = distance,
                                        Name = node.Name,
                                        Health = node:GetAttribute("Health") or 0,
                                        MaxHealth = node:GetAttribute("MaxHealth") or node:GetAttribute("Health") or 0
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        local targetType = TreesControl.TargetType
        local mapFolder = workspace:FindFirstChild("Map")
        local foliageFolder = mapFolder and mapFolder:FindFirstChild("Foliage")
        if foliageFolder then
            for _, tree in pairs(foliageFolder:GetChildren()) do
                if tree:GetAttribute("Health") then
                    local shouldTarget = false
                    if targetType == "Every tree" then
                        shouldTarget = true
                    else
                        shouldTarget = tree.Name == targetType
                    end
                    if shouldTarget then
                        local treePart = tree:FindFirstChild("Part") or tree:FindFirstChild("Trunk") or tree
                        if treePart and treePart:IsA("BasePart") then
                            local distance = (playerPos - treePart.Position).Magnitude
                            if distance <= TreesControl.ChoppingRange then
                                table.insert(targets, {
                                    Tree = tree,
                                    Part = treePart,
                                    Distance = distance,
                                    Name = tree.Name,
                                    Health = tree:GetAttribute("Health") or 0,
                                    MaxHealth = tree:GetAttribute("MaxHealth") or tree:GetAttribute("Health") or 0
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(targets, function(a, b) return a.Distance < b.Distance end)
    return targets
end

local function GetEquippedWeaponName()
    local workspaceCharacter = workspace:FindFirstChild(LocalPlayer.Name)
    if workspaceCharacter then
        local toolHandle = workspaceCharacter:FindFirstChild("ToolHandle")
        if toolHandle then
            local originalItem = toolHandle:FindFirstChild("OriginalItem")
            local originalValue = originalItem and originalItem.Value
            if originalValue and originalValue.Name then
                return originalValue.Name
            end
        end
    end

    local character = LocalPlayer.Character
    if character then
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then
            return tool.Name
        end
    end

    return nil
end

-- Execute tree chopping aura (TREES ONLY)
UpdateTreeChopping = function()
    if not TreesControl.ChoppingAuraEnabled then
        return -- Tree chopping is disabled
    end
    
    local currentTime = tick()
    if currentTime - TreesControl.LastChoppingAttack < TreesControl.ChoppingCooldown then 
        return 
    end
    
    local char = LocalPlayer.Character
    if not char then 
        return 
    end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end
    
    -- Clean up old billboard GUIs
    CleanupGUIs(false)
    
    -- Validate current targets (remove dead/missing trees)
    ValidateTargets(false)
    
    local hasWeapon, weapon, weaponName = FindBestWeapon("General Axe")
    if not hasWeapon or not weapon then
        return
    end

    local toolForDamage = weapon
    local attemptedEquip = false

    local function ensureAxeEquipped()
        if attemptedEquip then
            return
        end

        attemptedEquip = true
        local equipRemote = RemoteEvents:FindFirstChild("EquipItemHandle")
        if equipRemote then
            pcall(function()
                equipRemote:FireServer("FireAllClients", weapon)
            end)

            task.wait(0.05)

            local resolvedName = weaponName or weapon.Name
            local matchedTool = resolvedName and char:FindFirstChild(resolvedName)
            if matchedTool then
                toolForDamage = matchedTool
            else
                local fallbackTool = char:FindFirstChildOfClass("Tool")
                if fallbackTool then
                    toolForDamage = fallbackTool
                end
            end
        end
    end

    local equippedName = GetEquippedWeaponName()
    if weaponName and equippedName ~= weaponName then
        ensureAxeEquipped()
        equippedName = GetEquippedWeaponName()
    end

    TreesControl.EquippedAxeName = equippedName

    if equippedName == weaponName then
        local equippedTool = char:FindFirstChild(weaponName)
        if equippedTool then
            toolForDamage = equippedTool
        end
    end
    
    -- Determine how many targets we need
    local maxTargets = TreesControl.UltraChoppingEnabled and TreesControl.UltraChopCount or 1
    
    -- Only search for new targets if we don't have enough current targets
    if #TreesControl.CurrentTargets < maxTargets then
        local availableTrees = FindTargetsInRange(false)
        
        -- Filter out trees we're already targeting
        local newTrees = {}
        for _, treeData in ipairs(availableTrees) do
            local alreadyTargeting = false
            for _, currentTarget in ipairs(TreesControl.CurrentTargets) do
                if currentTarget.Tree == treeData.Tree then
                    alreadyTargeting = true
                    break
                end
            end
            
            if not alreadyTargeting then
                table.insert(newTrees, treeData)
            end
        end
        
        -- Add new targets up to our maximum
        local targetsNeeded = maxTargets - #TreesControl.CurrentTargets
        for i = 1, math.min(targetsNeeded, #newTrees) do
            table.insert(TreesControl.CurrentTargets, newTrees[i])
        end
    end
    
    -- If we still have no targets, return
    if #TreesControl.CurrentTargets == 0 then
        return
    end
    
    -- Get the correct remotes from ReplicatedStorage
    if not RemoteEvents then
        return
    end
    
    local toolDamageRemote = RemoteEvents:FindFirstChild("ToolDamageObject")
    if not toolDamageRemote then
        return
    end
    
    TreesControl.LastChoppingAttack = currentTime

    local function tryInvokeDamage(target, tool)
        local ok, result = pcall(function()
            return toolDamageRemote:InvokeServer(target.Tree, tool, TreesControl.TreeDamageId, rootPart.CFrame)
        end)

        return ok and result ~= false
    end

    local function chopTarget(targetData)
        task.spawn(function()
                        UpdateHealthGUI(targetData.Tree, targetData.Part, false)            if not tryInvokeDamage(targetData, weapon) then
                ensureAxeEquipped()

                if toolForDamage then
                    tryInvokeDamage(targetData, toolForDamage)
                end
            end
        end)
    end

    local batchSize = TreesControl.DamageBatchSize or 6
    local interval = TreesControl.BatchInterval or 0
    local index = 1

    while index <= #TreesControl.CurrentTargets do
        for offset = 0, batchSize - 1 do
            local targetData = TreesControl.CurrentTargets[index + offset]
            if not targetData then
                break
            end

            chopTarget(targetData)
        end

        index = index + batchSize
        if index <= #TreesControl.CurrentTargets and interval > 0 then
            task.wait(interval)
        end
    end

    task.delay(0.1, function()
        for _, targetData in ipairs(TreesControl.CurrentTargets) do
            if targetData.Tree.Parent then
                UpdateHealthGUI(targetData.Tree, targetData.Part, false)
            end
        end
    end)
end

-- Execute meteor mining aura (METEORS ONLY)
UpdateMeteorMining = function()
    if not MeteorsControl.MiningAuraEnabled then
        return -- Meteor mining is disabled
    end
    
    local currentTime = tick()
    if currentTime - MeteorsControl.LastMiningAttack < MeteorsControl.MiningCooldown then 
        return 
    end
    
    local char = LocalPlayer.Character
    if not char then 
        return 
    end
    
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end
    
    -- Clean up old meteor billboard GUIs
    CleanupGUIs(true)
    
    -- Validate current meteor targets (remove dead/missing meteors)
    ValidateTargets(true)
    
    -- Determine how many targets we need
    local maxTargets = MeteorsControl.UltraMiningEnabled and MeteorsControl.UltraMineCount or 1
    
    -- Only search for new targets if we don't have enough current targets
    if #MeteorsControl.CurrentTargets < maxTargets then
        local availableMeteors = FindTargetsInRange(true)
        
        -- Filter out meteors we're already targeting
        local newMeteors = {}
        for _, meteorData in ipairs(availableMeteors) do
            local alreadyTargeting = false
            for _, currentTarget in ipairs(MeteorsControl.CurrentTargets) do
                if currentTarget.Meteor == meteorData.Meteor then
                    alreadyTargeting = true
                    break
                end
            end
            
            if not alreadyTargeting then
                table.insert(newMeteors, meteorData)
            end
        end
        
        -- Add new targets up to our maximum
        local targetsNeeded = maxTargets - #MeteorsControl.CurrentTargets
        for i = 1, math.min(targetsNeeded, #newMeteors) do
            table.insert(MeteorsControl.CurrentTargets, newMeteors[i])
        end
    end
    
    -- If we still have no targets, return early (CRITICAL: prevents equip spam)
    if #MeteorsControl.CurrentTargets == 0 then
        return
    end
    
    -- Get the correct remotes from ReplicatedStorage
    if not RemoteEvents then
        return
    end
    
    local toolDamageRemote = RemoteEvents:FindFirstChild("ToolDamageObject")
    if not toolDamageRemote then
        return
    end
    
    -- ONLY proceed with weapon logic if we have valid targets
    local hasWeapon, weapon, weaponName = FindBestWeapon("General Axe")
    if not hasWeapon or not weapon then
        return
    end

    local toolForDamage = weapon
    local attemptedEquip = false

    local function ensureAxeEquipped()
        if attemptedEquip then
            return
        end

        attemptedEquip = true
        local equipRemote = RemoteEvents:FindFirstChild("EquipItemHandle")
        if equipRemote then
            pcall(function()
                equipRemote:FireServer("FireAllClients", weapon)
            end)

            task.wait(0.05)

            local resolvedName = weaponName or weapon.Name
            local matchedTool = resolvedName and char:FindFirstChild(resolvedName)
            if matchedTool then
                toolForDamage = matchedTool
            else
                local fallbackTool = char:FindFirstChildOfClass("Tool")
                if fallbackTool then
                    toolForDamage = fallbackTool
                end
            end
        end
    end

    local equippedName = GetEquippedWeaponName()
    if weaponName and equippedName ~= weaponName then
        ensureAxeEquipped()
        equippedName = GetEquippedWeaponName()
    end

    MeteorsControl.EquippedAxeName = equippedName

    if equippedName == weaponName then
        local equippedTool = char:FindFirstChild(weaponName)
        if equippedTool then
            toolForDamage = equippedTool
        end
    end
    
    MeteorsControl.LastMiningAttack = currentTime

    local function tryInvokeDamage(target, tool)
        local ok, result = pcall(function()
            return toolDamageRemote:InvokeServer(target.Meteor, tool, MeteorsControl.MeteorDamageId, rootPart.CFrame)
        end)

        return ok and result ~= false
    end

    local function mineTarget(targetData)
        task.spawn(function()
                        UpdateHealthGUI(targetData.Meteor, targetData.Part, true)            if not tryInvokeDamage(targetData, weapon) then
                ensureAxeEquipped()

                if toolForDamage then
                    tryInvokeDamage(targetData, toolForDamage)
                end
            end
        end)
    end

    local batchSize = MeteorsControl.DamageBatchSize or 6
    local interval = MeteorsControl.BatchInterval or 0
    local index = 1

    while index <= #MeteorsControl.CurrentTargets do
        for offset = 0, batchSize - 1 do
            local targetData = MeteorsControl.CurrentTargets[index + offset]
            if not targetData then
                break
            end

            mineTarget(targetData)
        end

        index = index + batchSize
        if index <= #MeteorsControl.CurrentTargets and interval > 0 then
            task.wait(interval)
        end
    end

    task.delay(0.1, function()
        for _, targetData in ipairs(MeteorsControl.CurrentTargets) do
            if targetData.Meteor.Parent then
                UpdateMeteorHealthGUI(targetData.Meteor, targetData.Part)
            end
        end
    end)
end

-- Auto damage ice blocks function with smart batching
DamageIceBlocks = function()
    if not TreesControl.IceBlockDamageEnabled then return end
    
    local toolDamageRemote = RemoteEvents:FindFirstChild("ToolDamageObject")
    if not toolDamageRemote then return end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    
    -- Find best axe using existing function
    local hasWeapon, weapon, weaponName = FindBestWeapon("General Axe")
    if not hasWeapon or not weapon then return end
    
    local toolForDamage = weapon
    local attemptedEquip = false
    
    local function ensureAxeEquipped()
        if attemptedEquip then return end
        attemptedEquip = true
        
        local equipRemote = RemoteEvents:FindFirstChild("EquipItemHandle")
        if equipRemote then
            pcall(function()
                equipRemote:FireServer("FireAllClients", weapon)
            end)
            
            task.wait(0.05)
            
            local resolvedName = weaponName or weapon.Name
            local matchedTool = resolvedName and character:FindFirstChild(resolvedName)
            if matchedTool then
                toolForDamage = matchedTool
            else
                local fallbackTool = character:FindFirstChildOfClass("Tool")
                if fallbackTool then
                    toolForDamage = fallbackTool
                end
            end
        end
    end
    
    local equippedName = GetEquippedWeaponName()
    if weaponName and equippedName ~= weaponName then
        ensureAxeEquipped()
        equippedName = GetEquippedWeaponName()
    end
    
    if equippedName == weaponName then
        local equippedTool = character:FindFirstChild(weaponName)
        if equippedTool then
            toolForDamage = equippedTool
        end
    end
    
    -- Function to find all ice blocks
    local function findAllIceBlocks()
        local iceBlocks = {}
        
        -- Location 1: Direct IceBlock in workspace
        for _, item in pairs(Workspace:GetChildren()) do
            if item.Name == "IceBlock" or item.Name:find("IceBlock") then
                table.insert(iceBlocks, item)
            end
        end
        
        -- Location 2: Map.Landmarks["Ice Temple"].IceBlock
        if Workspace:FindFirstChild("Map") then
            local map = Workspace.Map
            if map:FindFirstChild("Landmarks") then
                local landmarks = map.Landmarks
                if landmarks:FindFirstChild("Ice Temple") then
                    local iceTemple = landmarks["Ice Temple"]
                    for _, child in pairs(iceTemple:GetChildren()) do
                        if child.Name == "IceBlock" or child.Name:find("IceBlock") then
                            table.insert(iceBlocks, child)
                        end
                    end
                end
            end
        end
        
        -- Location 3: Items folder
        for _, item in pairs(WorkspaceItems:GetChildren()) do
            if item.Name == "IceBlock" or item.Name:find("IceBlock") then
                table.insert(iceBlocks, item)
            end
            for _, child in pairs(item:GetChildren()) do
                if child.Name == "IceBlock" or child.Name:find("IceBlock") then
                    table.insert(iceBlocks, child)
                end
            end
        end
        
        -- Location 4: Characters folder
        local charactersFolder = Workspace:FindFirstChild("Characters")
        if charactersFolder then
            for _, char in pairs(charactersFolder:GetChildren()) do
                if char.Name == "IceBlock" or char.Name:find("IceBlock") then
                    table.insert(iceBlocks, char)
                end
                for _, child in pairs(char:GetChildren()) do
                    if child.Name == "IceBlock" or child.Name:find("IceBlock") then
                        table.insert(iceBlocks, child)
                    end
                end
            end
        end
        
        return iceBlocks
    end
    
    -- Initialize tracking
    if not TreesControl.IceBlockBatch then
        TreesControl.IceBlockBatch = {}
        TreesControl.IceBlockPool = {}
        TreesControl.LastIceBlockDamage = 0
    end
    
    local currentTime = tick()
    
    -- Only damage every 0.5 seconds
    if currentTime - TreesControl.LastIceBlockDamage < 0.5 then
        return
    end
    
    TreesControl.LastIceBlockDamage = currentTime
    
    -- If batch is empty, initialize with first 20 ice blocks
    if #TreesControl.IceBlockBatch == 0 then
        local allIceBlocks = findAllIceBlocks()
        TreesControl.IceBlockPool = allIceBlocks
        
        -- Take first 20 for batch
        for i = 1, math.min(20, #allIceBlocks) do
            table.insert(TreesControl.IceBlockBatch, allIceBlocks[i])
        end
        
        -- Remove first 20 from pool
        for i = 1, math.min(20, #allIceBlocks) do
            table.remove(TreesControl.IceBlockPool, 1)
        end
    end
    
    -- Send damage to current batch
    for _, iceBlock in ipairs(TreesControl.IceBlockBatch) do
        if iceBlock and iceBlock.Parent then
            -- Find the part to attach GUI to
            local iceBlockPart = iceBlock.PrimaryPart or iceBlock:FindFirstChild("Part") or iceBlock:FindFirstChild("Main") or iceBlock:FindFirstChildOfClass("BasePart")
            
            -- Update health GUI before damage
            if iceBlockPart then
                UpdateHealthGUI(iceBlock, iceBlockPart, false, true)
            end
            
            local success = pcall(function()
                return toolDamageRemote:InvokeServer(iceBlock, toolForDamage, "1_9321896061", rootPart.CFrame)
            end)
            
            -- If damage failed, try equipping axe and retry
            if not success then
                ensureAxeEquipped()
                if toolForDamage then
                    pcall(function()
                        toolDamageRemote:InvokeServer(iceBlock, toolForDamage, "1_9321896061", rootPart.CFrame)
                    end)
                end
            end
            
            -- Update health GUI after damage
            if iceBlockPart then
                UpdateHealthGUI(iceBlock, iceBlockPart, false, true)
            end
        end
    end
    
    -- After damage, check which ice blocks still exist
    local survivingBlocks = {}
    for _, iceBlock in ipairs(TreesControl.IceBlockBatch) do
        if iceBlock and iceBlock.Parent then
            table.insert(survivingBlocks, iceBlock)
        end
    end
    
    -- Calculate how many new blocks we need
    local neededBlocks = 20 - #survivingBlocks
    
    -- Refill batch with new ice blocks from pool
    if neededBlocks > 0 then
        -- Refresh pool if empty
        if #TreesControl.IceBlockPool == 0 then
            TreesControl.IceBlockPool = findAllIceBlocks()
            
            -- Remove surviving blocks from pool
            for i = #TreesControl.IceBlockPool, 1, -1 do
                for _, surviving in ipairs(survivingBlocks) do
                    if TreesControl.IceBlockPool[i] == surviving then
                        table.remove(TreesControl.IceBlockPool, i)
                        break
                    end
                end
            end
        end
        
        -- Add new blocks to batch
        for i = 1, math.min(neededBlocks, #TreesControl.IceBlockPool) do
            table.insert(survivingBlocks, TreesControl.IceBlockPool[1])
            table.remove(TreesControl.IceBlockPool, 1)
        end
    end
    
    -- Update batch for next cycle
    TreesControl.IceBlockBatch = survivingBlocks
    
    -- If batch is empty, disable the feature (all done)
    if #TreesControl.IceBlockBatch == 0 and #TreesControl.IceBlockPool == 0 then
        TreesControl.IceBlockDamageEnabled = false
    end
end

-- Execute kill aura attack using the correct RemoteSpy structure (upgrade detection fix)
UpdateKillAura = function()
    local currentTime = tick()
    if currentTime - CombatControl.LastAuraAttack < CombatControl.AttackCooldown then 
        return 
    end

    local char = LocalPlayer.Character
    if not char then
        return
    end

    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    if not RemoteEvents then
        return
    end

    local toolDamageRemote = RemoteEvents:FindFirstChild("ToolDamageObject")
    if not toolDamageRemote then
        return
    end

    local weaponType = CombatControl.WeaponType
    local hasWeapon, weapon, weaponName = FindBestWeapon(weaponType)
    if not hasWeapon or not weapon then
        return
    end

    local toolForDamage = weapon
    local attemptedEquip = false

    local function ensureWeaponEquipped()
        if attemptedEquip then
            return
        end

        attemptedEquip = true
        local equipRemote = RemoteEvents:FindFirstChild("EquipItemHandle")
        if equipRemote then
            pcall(function()
                equipRemote:FireServer("FireAllClients", weapon)
            end)

            task.wait(0.05)

            local resolvedName = weaponName or weapon.Name
            local matchedTool = resolvedName and char:FindFirstChild(resolvedName)
            if matchedTool then
                toolForDamage = matchedTool
            else
                local fallbackTool = char:FindFirstChildOfClass("Tool")
                if fallbackTool then
                    toolForDamage = fallbackTool
                end
            end
        end
    end

    local equippedName = GetEquippedWeaponName()
    if weaponName and equippedName ~= weaponName then
        ensureWeaponEquipped()
        equippedName = GetEquippedWeaponName()
    end

    CombatControl.EquippedWeaponName = equippedName

    if equippedName == weaponName then
        local equippedTool = char:FindFirstChild(weaponName)
        if equippedTool then
            toolForDamage = equippedTool
        end
    end

    local entities = FindHostileEntities()
    if #entities == 0 then
        return
    end
    
    if CombatControl.TeleportAboveTarget and entities[1] and entities[1].RootPart then
        local targetPos = entities[1].RootPart.Position
        rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, CombatControl.TeleportHeight, 0))
    end
    
    local validEntities = {}
    for _, entityData in ipairs(entities) do
        if entityData.Distance <= CombatControl.AuraRange then
            table.insert(validEntities, entityData)
        end
    end
    
    if #validEntities == 0 then
        return
    end

    local function resolveHitCFrame(entityData)
        local head = entityData.Head
        if head and head:IsA("BasePart") then
            return head.CFrame
        end

        local entity = entityData.Entity
        if entity then
            local newHead = entity:FindFirstChild("Head")
            if newHead and newHead:IsA("BasePart") then
                entityData.Head = newHead
                return newHead.CFrame
            end

            local fallback = entityData.RootPart or entity:FindFirstChild("HumanoidRootPart")
            if fallback and fallback:IsA("BasePart") then
                return fallback.CFrame
            end
        end

        return rootPart.CFrame
    end

    local function sendDamage(entityData)
        task.spawn(function()
            if entityData.Type == "Player" then
                ensureWeaponEquipped()

                local playerHitFrame = rootPart.CFrame
                local legacyId = CombatControl.LegacyDamageTypeId or "2_9303764245"

                if toolForDamage then
                    local success = pcall(function()
                        return toolDamageRemote:InvokeServer(entityData.Entity, toolForDamage, legacyId, playerHitFrame)
                    end)

                    if success then
                        return
                    end
                end

                pcall(function()
                    toolDamageRemote:InvokeServer(entityData.Entity, weapon, legacyId, playerHitFrame)
                end)
                return
            end

            local targetFrame = resolveHitCFrame(entityData)

            local ok, result = pcall(function()
                return toolDamageRemote:InvokeServer(entityData.Entity, weapon, CombatControl.DamageTypeId, targetFrame)
            end)

            if (not ok or result == false) then
                ensureWeaponEquipped()

                if toolForDamage then
                    pcall(function()
                        toolDamageRemote:InvokeServer(entityData.Entity, toolForDamage, CombatControl.DamageTypeId, targetFrame)
                    end)
                end
            end
        end)
    end

    if CombatControl.UltraKillEnabled then
        local batchSize = CombatControl.DamageBatchSize or 6
        local interval = CombatControl.BatchInterval or 0
        local index = 1

        while index <= #validEntities do
            for offset = 0, batchSize - 1 do
                local entityData = validEntities[index + offset]
                if not entityData then
                    break
                end

                sendDamage(entityData)
            end

            index = index + batchSize
            if index <= #validEntities and interval > 0 then
                task.wait(interval)
            end
        end
    else
        sendDamage(validEntities[1])
    end

    CombatControl.LastAuraAttack = currentTime
end

UpdateTeammateKillAura = function()
    local currentTime = tick()
    if currentTime - CombatControl.LastTeammateAuraAttack < CombatControl.AttackCooldown then
        return
    end

    if CombatControl.WeaponType ~= "Flamethrower" then
        CombatControl.TeammateKillAuraEnabled = false
        if CombatControl.TeammateToggle then
            CombatControl.TeammateToggle:Set(false)
        end
        return
    end

    local char = LocalPlayer.Character
    if not char then
        return
    end

    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    if not RemoteEvents then
        return
    end

    local toolDamageRemote = RemoteEvents:FindFirstChild("ToolDamageObject")
    if not toolDamageRemote then
        return
    end

    local hasWeapon, weapon, weaponName = FindBestWeapon(CombatControl.WeaponType)
    if not hasWeapon or not weapon then
        return
    end

    local toolForDamage = weapon
    local attemptedEquip = false

    local function ensureWeaponEquipped()
        if attemptedEquip then
            return
        end

        attemptedEquip = true
        local equipRemote = RemoteEvents:FindFirstChild("EquipItemHandle")
        if equipRemote then
            pcall(function()
                equipRemote:FireServer("FireAllClients", weapon)
            end)

            task.wait(0.05)

            local resolvedName = weaponName or weapon.Name
            local matchedTool = resolvedName and char:FindFirstChild(resolvedName)
            if matchedTool then
                toolForDamage = matchedTool
            else
                local fallbackTool = char:FindFirstChildOfClass("Tool")
                if fallbackTool then
                    toolForDamage = fallbackTool
                end
            end
        end
    end

    local equippedName = GetEquippedWeaponName()
    if weaponName and equippedName ~= weaponName then
        ensureWeaponEquipped()
        equippedName = GetEquippedWeaponName()
    end

    if equippedName == weaponName then
        local equippedTool = char:FindFirstChild(weaponName)
        if equippedTool then
            toolForDamage = equippedTool
        end
    end

    CombatControl.EquippedWeaponName = equippedName

    local teammateSelection = CombatControl.TeammateTarget or "All Players"

    local targets = FindTeammateTargets()
    if #targets == 0 then
        return
    end

    local function resolveHitCFrame(targetData)
        local head = targetData.Head
        if head and head:IsA("BasePart") then
            return head.CFrame
        end

        local character = targetData.Character
        if character then
            local newHead = character:FindFirstChild("Head")
            if newHead and newHead:IsA("BasePart") then
                targetData.Head = newHead
                return newHead.CFrame
            end

            local fallback = targetData.RootPart or character:FindFirstChild("HumanoidRootPart")
            if fallback and fallback:IsA("BasePart") then
                targetData.RootPart = fallback
                return fallback.CFrame
            end
        end

        return rootPart.CFrame
    end

    local function sendDamage(targetData)
        if not targetData or not targetData.Character or not targetData.Character.Parent then
            return
        end

        task.spawn(function()
            ensureWeaponEquipped()

            local damageId = CombatControl.LegacyDamageTypeId or "2_9303764245"
            local hitFrame = rootPart.CFrame

            local function tryInvoke(tool)
                if not tool then
                    return false
                end

                local ok, result = pcall(function()
                    return toolDamageRemote:InvokeServer(targetData.Character, tool, damageId, hitFrame)
                end)

                return ok and result ~= false
            end

            if toolForDamage and tryInvoke(toolForDamage) then
                return
            end

            tryInvoke(weapon)
        end)
    end

    local processAllTargets = CombatControl.UltraKillEnabled or teammateSelection == "All Players"

    if processAllTargets then
        local batchSize = math.max(1, CombatControl.DamageBatchSize or 6)
        local interval = CombatControl.BatchInterval or 0
        local index = 1

        while index <= #targets do
            for offset = 0, batchSize - 1 do
                local targetData = targets[index + offset]
                if not targetData then
                    break
                end

                sendDamage(targetData)
            end

            index = index + batchSize
            if index <= #targets and interval > 0 then
                task.wait(interval)
            end
        end
    else
        sendDamage(targets[1])
    end

    CombatControl.LastTeammateAuraAttack = currentTime
end

-- Execute second kill aura attack (independent system)
-- Unified update for current character
local function UpdateAll()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    StoreOriginals(humanoid)
    ApplySpeed(humanoid)
    ApplyJump(humanoid)
end

-- Setup infinite jump for character
local function SetupInfiniteJump()
    -- Disconnect previous connection if exists
    if PlayerControl.InfiniteJumpConnection then
        PlayerControl.InfiniteJumpConnection:Disconnect()
        PlayerControl.InfiniteJumpConnection = nil
    end
    
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- Connect to jump request
    PlayerControl.InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
        if PlayerControl.InfiniteJump and humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

-- Character spawn handling
LocalPlayer.CharacterAdded:Connect(function(char)
    PlayerControl.OriginalsStored = false
    char:WaitForChild("Humanoid")
    task.delay(0.25, function()
        UpdateAll()
        SetupInfiniteJump()
    end)
end)

--============================================================================--
--      [[ SMART AUTO EAT FUNCTIONS ]]
--============================================================================--

-- Function to find closest food item on ground
local function findClosestFood()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then 
        return nil 
    end
    
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then 
        return nil 
    end
    
    local closestItem = nil
    local closestDist = math.huge
    
    for _, item in ipairs(itemsFolder:GetChildren()) do
        -- Check if this item is one of our target food types
        for _, foodType in ipairs({"Carrot", "Corn", "Pumpkin", "Cake", "Cooked Morsel", "Cooked Meat"}) do
            if item.Name == foodType then
                local itemPart = item:IsA("Model") and item.PrimaryPart or item
                if itemPart and itemPart:IsA("BasePart") then
                    local dist = (rootPart.Position - itemPart.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestItem = item
                    end
                end
                break
            end
        end
    end
    
    return closestItem, closestDist
end

-- Function to teleport food item to player for consumption
local function teleportFoodToPlayer(foodItem)
    if not foodItem or not foodItem.Parent then
        return false
    end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local rootPart = char.HumanoidRootPart
    local foodPart = foodItem.PrimaryPart or foodItem:FindFirstChildOfClass("BasePart")
    
    if not foodPart then
        return false
    end
    
    -- Step 1: Fire grab remote to take control of the food item
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(foodItem)
        end)
    end
    
    -- Step 2: Teleport food near player (5 studs to the side, same height)
    local targetPosition = rootPart.CFrame * CFrame.new(5, 0, 0)
    foodPart.CFrame = targetPosition
    foodPart.AssemblyLinearVelocity = Vector3.zero
    foodPart.AssemblyAngularVelocity = Vector3.zero
    -- Step 3: Brief wait for positioning
    task.wait(0.1)
    
    -- Step 4: Fire grab remote again to ensure we have control
    if requestStartDragging then
        pcall(function()
            requestStartDragging:FireServer(foodItem)
        end)
    end
    
    return true
end

-- Function to consume food item
local function consumeFood(foodItem)
    if not foodItem then 
        return false 
    end
    
    if not RemoteEvents then
        return false
    end
    
    local consumeRemote = RemoteEvents:FindFirstChild("RequestConsumeItem")
    if not consumeRemote then
        return false
    end
    
    local success, result = pcall(function()
        return consumeRemote:InvokeServer(foodItem)
    end)
    
    return success
end

-- Function to check hunger and eat if needed
local function checkHungerAndEat()
    -- First check if enabled
    if not SkybaseControl.SmartAutoEatEnabled then 
        return 
    end
    
    local currentTime = tick()
    if currentTime - SkybaseControl.LastHungerCheck < SkybaseControl.HungerCheckCooldown then
        return
    end
    SkybaseControl.LastHungerCheck = currentTime
    
    local character = LocalPlayer.Character
    
    if not character then 
        return 
    end
    
    -- Check player's hunger attribute (always check player first)
    local hungerAttribute = LocalPlayer:GetAttribute("Hunger")
    if not hungerAttribute then 
        return 
    end
    
    -- If hunger is at or below threshold, try to eat
    if hungerAttribute <= SkybaseControl.HungerThreshold then
        local foodItem, distance = findClosestFood()
        if foodItem and distance <= SkybaseControl.FoodSearchRange then
            -- Use new enhanced eating system: teleport food to player, then consume
            if teleportFoodToPlayer(foodItem) then
                task.wait(0.2) -- Brief wait to ensure food is properly positioned
                consumeFood(foodItem)
            end
        end
    end
end

-- Simple Anti-AFK system - Just move mouse and right click
function checkAntiAfk()
    if not SkybaseControl.AntiAfkEnabled then 
        return 
    end
    
    local currentTime = tick()
    
    -- Check if it's time for next anti-AFK action
    if currentTime - SkybaseControl.LastAfkAction >= SkybaseControl.AfkActionInterval then
        SkybaseControl.LastAfkAction = currentTime
        
        -- Get VirtualInputManager
        local VIM = game:GetService("VirtualInputManager")
        
        -- Move mouse to a random position (small movement)
        local randomX = math.random(-50, 50)
        local randomY = math.random(-50, 50)
        
        pcall(function()
            -- Move mouse
            VIM:SendMouseMoveEvent(randomX, randomY, game)
            wait(0.1)
            
            -- Right click down
            VIM:SendMouseButtonEvent(randomX, randomY, 1, true, game, 0)
            wait(0.05)
            
            -- Right click up
            VIM:SendMouseButtonEvent(randomX, randomY, 1, false, game, 0)
        end)
    end
end

--============================================================================--
--      [[ LOST CHILDREN FUNCTIONS ]]
--============================================================================--

-- Function to enable/disable noclip
local function setNoclip(enabled)
    local character = LocalPlayer.Character
    
    if character then
        for _, part in pairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = not enabled
            end
        end
    end
end

-- Function to check which children are already rescued
local function checkRescuedChildren()
    local rescued = {}
    local structuresFolder = workspace:FindFirstChild("Structures")
    
    if structuresFolder then
        -- Debug: List all structures
        for _, structure in pairs(structuresFolder:GetChildren()) do
        end
        
    for childName, data in pairs(LostChildrenControl.ChildrenData) do
            local tent = structuresFolder:FindFirstChild(data.tent)
            if tent then
                rescued[childName] = true
            else
                -- Try alternative tent naming patterns
                local alternativeTents = {
                    data.tent,
                    data.tent:gsub("Kid", ""),  -- Remove "Kid" suffix
                    data.tent:gsub("Tent", ""), -- Remove "Tent" prefix
                    "Tent" .. data.name,        -- Use just the child name
                    data.name .. "Tent",        -- Name + Tent
                    data.name .. "Kid",         -- Name + Kid
                }
                
                for _, altTent in pairs(alternativeTents) do
                    local foundTent = structuresFolder:FindFirstChild(altTent)
                    if foundTent then
                        rescued[childName] = true
                        break
                    end
                end
            end
        end
    end
    
    local rescueCount = 0
    for _ in pairs(rescued) do rescueCount = rescueCount + 1 end
    
    return rescued
end

-- Function to find any sack in player inventory
local function findPlayerSack()
    local inventory = LocalPlayer:FindFirstChild("Inventory")
    
    if inventory then
        for _, item in pairs(inventory:GetChildren()) do
            if item.Name:find("Sack") then
                return item
            end
        end
    end
    
    return nil
end

-- Function to check if a position has been visited or is too close to visited areas
local function isPositionVisited(position)
    for _, visitedPos in pairs(LostChildrenControl.VisitedWolves) do
        local distance = (position - visitedPos).Magnitude
        if distance < 150 then -- Mark areas within 150 studs as visited
            return true
        end
    end
    return false
end

-- Function to mark a wolf position and surrounding area as visited
local function markWolfAreaAsVisited(position)
    table.insert(LostChildrenControl.VisitedWolves, position)
    
    -- Also mark surrounding wolves and alpha wolves in the area as visited
    local charactersFolder = workspace:FindFirstChild("Characters")
    if charactersFolder then
        for _, entity in pairs(charactersFolder:GetChildren()) do
            if entity.Name == "Wolf" or entity.Name == "Alpha Wolf" then
                local humanoidRootPart = entity:FindFirstChild("HumanoidRootPart")
                if humanoidRootPart then
                    local entityPos = humanoidRootPart.Position
                    local distance = (entityPos - position).Magnitude
                    if distance < 150 then -- Mark wolves within 150 studs
                        table.insert(LostChildrenControl.VisitedWolves, entityPos)
                    end
                end
            end
        end
    end
end

-- Function to find wolves/alpha wolves for teleportation
local function findWolvesForTeleport()
    local charactersFolder = workspace:FindFirstChild("Characters")
    if not charactersFolder then return {} end
    
    local wolves = {}
    local usedPositions = {}
    
    -- Find all wolves and alpha wolves
    for _, entity in pairs(charactersFolder:GetChildren()) do
        if entity.Name == "Wolf" or entity.Name == "Alpha Wolf" then
            local humanoidRootPart = entity:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                local position = humanoidRootPart.Position
                local tooClose = false
                
                -- Check if this position has been visited
                if isPositionVisited(position) then
                    tooClose = true
                end
                
                -- Check if this wolf is too close to any previously selected wolf in this search
                for _, usedPos in pairs(usedPositions) do
                    local distance = (position - usedPos).Magnitude
                    if distance < 150 then -- Minimum 150 studs apart
                        tooClose = true
                        break
                    end
                end
                
                -- Also check distance from last teleport position
                if LostChildrenControl.LastTeleportPosition then
                    local lastDistance = (position - LostChildrenControl.LastTeleportPosition).Magnitude
                    if lastDistance < 150 then
                        tooClose = true
                    end
                end
                
                if not tooClose then
                    -- Add 50 studs height for safety
                    local safePosition = position + Vector3.new(0, 50, 0)
                    table.insert(wolves, safePosition)
                    table.insert(usedPositions, position)
                end
            end
        end
    end
    
    return wolves
end

-- Function to find lost child in workspace
local function findLostChild()
    local charactersFolder = workspace:FindFirstChild("Characters")
    if not charactersFolder then return nil end
    
    for childName, _ in pairs(LostChildrenControl.ChildrenData) do
        if not LostChildrenControl.RescuedChildren[childName] then
            local child = charactersFolder:FindFirstChild(childName)
            if child then
                return child, childName
            end
        end
    end
    
    return nil, nil
end

-- Function to teleport player to position
local function teleportPlayer(position)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    local character = player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if humanoidRootPart then
        humanoidRootPart.CFrame = CFrame.new(position)
        LostChildrenControl.LastTeleportPosition = position
        LostChildrenControl.LastTeleportTime = tick()
    end
end

-- Function to bag a child
local function bagChild(child, sack)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local bagStoreRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
    
    if bagStoreRemote then
        bagStoreRemote = bagStoreRemote:FindFirstChild("RequestBagStoreItem")
        if bagStoreRemote then
            local success = pcall(function()
                bagStoreRemote:InvokeServer(sack, child)
            end)
            return success
        end
    end
    
    return false
end

-- Function to perform rescue sequence
local function performRescueSequence()
    if not LostChildrenControl.RescueEnabled then return end
    
    local currentTime = tick()
    if currentTime - LostChildrenControl.LastTeleportTime < LostChildrenControl.TeleportCooldown then
        return -- Still in cooldown
    end
    
    -- Check if we have a sack
    local sack = findPlayerSack()
    if not sack then
        return -- No sack available
    end
    
    -- Look for any lost child
    local child, childName = findLostChild()
    
    if child then
        -- Found a child! Try to rescue
        LostChildrenControl.CurrentStep = "rescuing"
        
        -- Teleport to child first
        local childPart = child:FindFirstChild("HumanoidRootPart")
        if childPart then
            teleportPlayer(childPart.Position + Vector3.new(0, 5, 0))
            
            task.wait(1)
            
            -- Try to bag the child (skip campfire drop)
            if bagChild(child, sack) then
                -- Successfully bagged - mark as rescued and continue searching
                LostChildrenControl.RescuedChildren[childName] = true
                LostChildrenControl.CurrentStep = "searching"
            end
        end
    else
        -- No child found, do brute force teleport
        LostChildrenControl.CurrentStep = "searching"
        
        local wolves = findWolvesForTeleport()
        if #wolves > 0 then
            -- Teleport to a random wolf position
            local randomWolf = wolves[math.random(1, #wolves)]
            teleportPlayer(randomWolf)
            
            -- Mark this wolf area as visited
            markWolfAreaAsVisited(randomWolf - Vector3.new(0, 50, 0)) -- Remove the height offset for marking
            
        else
            -- No unvisited wolves found, reset visited list and try again
            LostChildrenControl.VisitedWolves = {}
            
            -- Try again with fresh wolf list
            wolves = findWolvesForTeleport()
            if #wolves > 0 then
                local randomWolf = wolves[math.random(1, #wolves)]
                teleportPlayer(randomWolf)
                markWolfAreaAsVisited(randomWolf - Vector3.new(0, 50, 0))
            end
        end
    end
end

-- Function to stop rescue process
local function stopRescueProcess()
    LostChildrenControl.RescueEnabled = false
    LostChildrenControl.CurrentStep = "returning"
    
    -- Disable noclip
    setNoclip(false)
    
    -- Restore original gravity
    if LostChildrenControl.OriginalGravity then
        workspace.Gravity = LostChildrenControl.OriginalGravity
        LostChildrenControl.OriginalGravity = nil
    end
    
    -- Return to original position
    if LostChildrenControl.OriginalPosition then
        teleportPlayer(LostChildrenControl.OriginalPosition)
        LostChildrenControl.OriginalPosition = nil
    end
    
    LostChildrenControl.CurrentStep = "idle"
end

-- Function to start rescue process
local function startRescueProcess()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local character = player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not humanoidRootPart then return end
    
    -- Save original position
    LostChildrenControl.OriginalPosition = humanoidRootPart.Position
    
    -- Save original gravity and set to 0 for flying
    LostChildrenControl.OriginalGravity = workspace.Gravity
    workspace.Gravity = 0
    
    -- Enable noclip
    setNoclip(true)
    
    -- Check which children are already rescued
    LostChildrenControl.RescuedChildren = checkRescuedChildren()
    
    -- Clear visited wolves list for fresh start
    LostChildrenControl.VisitedWolves = {}
    
    -- Start the process
    LostChildrenControl.RescueEnabled = true
    LostChildrenControl.CurrentStep = "searching"
end

-- Function to get rescue progress
local function getRescueProgress()
    local total = 0
    local rescued = 0
    
    for _ in pairs(LostChildrenControl.ChildrenData) do
        total = total + 1
    end
    
    for _ in pairs(LostChildrenControl.RescuedChildren) do
        rescued = rescued + 1
    end
    
    return rescued, total
end

-- Use Heartbeat (post-physics) so gravity doesn't cause slow descent during fly
RunService.Heartbeat:Connect(function()
    StepUpdate()
    checkHungerAndEat() -- Check hunger every frame (but with cooldown)
    checkAntiAfk() -- Check anti-AFK system
    UpdateDayNightLabels() -- Update day/night cycle info (with cooldown)
    UpdateStrongholdTimerLabel() -- Update stronghold timer (with cooldown)
    
    -- Lost Children Rescue System
    if LostChildrenControl.RescueEnabled then
        -- Check if all children are collected first
        local rescued, total = getRescueProgress()
        
        if rescued >= total then
            -- All 4 children collected! Just stop and return home
            stopRescueProcess()
            if LostChildrenControl.Toggle then
                LostChildrenControl.Toggle:Set(false)
            end
            if LostChildrenControl.Status then
                LostChildrenControl.Status.Text = "Status: All children collected! ✅"
            end
        else
            -- Still need to collect more children
            performRescueSequence()
        end
        
        -- Update GUI status (only if GUI elements exist)
        if LostChildrenControl.Status then
            local statusText = "Status: "
            if LostChildrenControl.CurrentStep == "searching" then
                statusText = statusText .. "Searching for children... (" .. rescued .. "/" .. total .. ")"
            elseif LostChildrenControl.CurrentStep == "rescuing" then
                statusText = statusText .. "Rescuing child... (" .. rescued .. "/" .. total .. ")"
            elseif LostChildrenControl.CurrentStep == "returning" then
                statusText = statusText .. "Returning to original location..."
            else
                statusText = statusText .. "Active (" .. rescued .. "/" .. total .. ")"
            end
            LostChildrenControl.Status.Text = statusText
        end
    else
        if LostChildrenControl.Status then
            LostChildrenControl.Status.Text = "Status: Inactive"
        end
    end
end)

-- Info Section Content
InfoTab:CreateLabel("📖 Please read before using:")

-- Day/Night Cycle Information Section
WorldStatusControl.DayNight.StateLabel = InfoTab:CreateLabel("☀️ Day - Time Left: Loading...")
WorldStatusControl.DayNight.DayCounterLabel = InfoTab:CreateLabel("📅 Story Day: Loading...")
WorldStatusControl.DayNight.CultistAttackLabel = InfoTab:CreateLabel("⚔️ Cultist Attack Day: Loading...")

-- Stronghold Timer Section
WorldStatusControl.StrongholdTimer.TimerLabel = InfoTab:CreateLabel("🏰 Stronghold Timer: Loading...")

InfoTab:CreateLabel("🔥 Fire Setup:")
InfoTab:CreateLabel("Make sure to upgrade your fire to maximum level.")
InfoTab:CreateLabel("Items may glitch if you teleport them from unopened")
InfoTab:CreateLabel("map areas to your location.")
InfoTab:CreateLabel("🎯 Transport Options:")
InfoTab:CreateLabel("Each transport feature has two destination options:")
InfoTab:CreateLabel("• Player: Teleports items to your location")
InfoTab:CreateLabel("• Campfire/Scrapper: Teleports to the specified station")
InfoTab:CreateLabel("Choose the option that works best for you!")
InfoTab:CreateLabel("🐛 Found issues or have ideas?")
InfoTab:CreateLabel("Join the Discord community! You can find the link")
InfoTab:CreateLabel("in the Credits section above.")
InfoTab:CreateLabel("We welcome bug reports and feature suggestions!")

--============================================================================--
--      [[ HALLOWEEN TAB CONTROLS ]]
--============================================================================--

-- Helper function: Open Halloween Chests specifically (Chest1 and Chest2)
function OpenHalloweenChests()
    local itemsFolder = WorkspaceItems
    if not itemsFolder then
        return 0
    end
    
    local openChestRemote = RemoteEvents:FindFirstChild("RequestOpenItemChest")
    if not openChestRemote then
        return 0
    end
    
    local chestsOpened = 0
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        if item.Name == "Halloween Chest1" or item.Name == "Halloween Chest2" then
            local isOpened = false
            local isLocked = false
            
            for attributeName, attributeValue in pairs(item:GetAttributes()) do
                if string.find(attributeName, "Opened") and attributeValue == true then
                    isOpened = true
                elseif string.find(attributeName, "Locked") and attributeValue == true then
                    isLocked = true
                end
            end
            
            if not isOpened and not isLocked then
                openChestRemote:FireServer(item)
                chestsOpened = chestsOpened + 1
                task.wait(0.1)
            end
        end
    end
    
    return chestsOpened
end

-- Helper function: Auto loot Halloween chest items and teleport them to player
function AutoLootHalloweenChestItems()
    if not FoodControl.Halloween.MazeEnd.AutoLootChests then
        return 0
    end
    
    local itemsFolder = WorkspaceItems
    if not itemsFolder then
        return 0
    end
    
    local player = LocalPlayer
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return 0
    end
    
    local currentTime = tick()
    local validTeleportedItems = {}
    for item, timestamp in pairs(FoodControl.Halloween.MazeEnd.TeleportedChestItems) do
        if item.Parent and (currentTime - timestamp) < 120 then
            validTeleportedItems[item] = timestamp
        end
    end
    FoodControl.Halloween.MazeEnd.TeleportedChestItems = validTeleportedItems
    
    local itemsLooted = 0
    local chestsToLoot = {"Halloween Chest1", "Halloween Chest2"}
    
    for _, item in pairs(itemsFolder:GetChildren()) do
        if not FoodControl.Halloween.MazeEnd.AutoLootChests then
            break
        end
        
        for _, chestName in ipairs(chestsToLoot) do
            if item.Name == chestName then
                local openedAttribute = item:GetAttribute("Opened")
                if openedAttribute == true and not FoodControl.Halloween.MazeEnd.TeleportedChestItems[item] then
                    for _, child in pairs(item:GetChildren()) do
                        if child:IsA("Model") and child.PrimaryPart then
                            FoodControl.Halloween.MazeEnd.TeleportedChestItems[child] = currentTime
                            
                            local success = UltimateItemTransporter(child, "Player", nil, 120, nil, 35)
                            if success then
                                itemsLooted = itemsLooted + 1
                                task.wait(0.1)
                            end
                        end
                    end
                end
            end
        end
    end
    
    return itemsLooted
end

-- Main function: Execute Maze End sequence
function ExecuteMazeEnd()
    local player = LocalPlayer
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        ApocLibrary:Notify({
            Title = "Maze End",
            Content = "Character not found!",
            Image = 4483362458
        })
        return
    end
    
    local rootPart = player.Character.HumanoidRootPart
    local character = player.Character
    
    -- Step 0: Go to Maze chest (with +10 offset)
    local mazeStuff = Workspace:FindFirstChild("HalloweenMazeStuff")
    if not mazeStuff then
        ApocLibrary:Notify({
            Title = "Maze End",
            Content = "Halloween Maze not found!",
            Image = 4483362458
        })
        return
    end
    
    local halloweenMaze = mazeStuff:FindFirstChild("HalloweenMaze")
    if not halloweenMaze then
        ApocLibrary:Notify({
            Title = "Maze End",
            Content = "Halloween Maze not found!",
            Image = 4483362458
        })
        return
    end
    
    local misc = halloweenMaze:FindFirstChild("Misc")
    if not misc then
        ApocLibrary:Notify({
            Title = "Maze End",
            Content = "Maze Misc not found!",
            Image = 4483362458
        })
        return
    end
    
    local mazeChest = misc:FindFirstChild("Halloween Maze Chest")
    if not mazeChest or not mazeChest.PrimaryPart then
        ApocLibrary:Notify({
            Title = "Maze End",
            Content = "Maze Chest not found!",
            Image = 4483362458
        })
        return
    end
    
    ApocLibrary:Notify({
        Title = "Maze End",
        Content = "Starting Maze End sequence...",
        Image = 4483362458
    })
    
    -- Teleport to maze chest with +10 offset and save this as our return position
    local mazeChestPosition = mazeChest.PrimaryPart.CFrame * CFrame.new(0, 10, 0)
    rootPart.CFrame = mazeChestPosition
    task.wait(1)
    
    -- Step 1: Open Halloween Chests
    local itemsFolder = WorkspaceItems
    if not itemsFolder then
        ApocLibrary:Notify({
            Title = "Maze End",
            Content = "Items folder not found!",
            Image = 4483362458
        })
        return
    end
    
    local openChestRemote = RemoteEvents:FindFirstChild("RequestOpenItemChest")
    if not openChestRemote then
        ApocLibrary:Notify({
            Title = "Maze End",
            Content = "Could not find chest opening remote!",
            Image = 4483362458
        })
        return
    end
    
    local chestsOpened = 0
    local availableChests = {}
    
    -- Find and open all Halloween Chest1 and Chest2
    for _, item in pairs(itemsFolder:GetChildren()) do
        if item.Name == "Halloween Chest1" or item.Name == "Halloween Chest2" then
            local isOpened = false
            local isLocked = false
            
            for attributeName, attributeValue in pairs(item:GetAttributes()) do
                if string.find(attributeName, "Opened") and attributeValue == true then
                    isOpened = true
                elseif string.find(attributeName, "Locked") and attributeValue == true then
                    isLocked = true
                end
            end
            
            if not isOpened and not isLocked then
                openChestRemote:FireServer(item)
                chestsOpened = chestsOpened + 1
                
                -- Store chest position for later looting
                local position = Vector3.new(0, 0, 0)
                if item:IsA("BasePart") then
                    position = item.Position
                elseif item:IsA("Model") and item.PrimaryPart then
                    position = item.PrimaryPart.Position
                elseif item:IsA("Model") then
                    for _, child in pairs(item:GetChildren()) do
                        if child:IsA("BasePart") then
                            position = child.Position
                            break
                        end
                    end
                end
                
                table.insert(availableChests, {
                    Object = item,
                    Position = position
                })
                
                task.wait(0.1)
            end
        end
    end
    
    task.wait(0.5)
    
    -- Step 2: Loot items from opened chests using full dragging logic
    local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
    local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
    
    if not requestStartDragging or not stopDragging then
        ApocLibrary:Notify({
            Title = "Maze End",
            Content = "Could not find dragging remotes!",
            Image = 4483362458
        })
        return
    end
    
    -- Track all transported items for final stop dragging
    local allTransportedItems = {}
    
    -- Helper function to collect items around a chest position
    local function collectItemsAroundChest(chestPosition, targetPos)
        local foundItems = {}
        for _, item in pairs(itemsFolder:GetChildren()) do
            if item.PrimaryPart then
                local distance = (item.PrimaryPart.Position - chestPosition).Magnitude
                -- Exclude items that are chests themselves
                local isChest = string.find(item.Name, "Halloween Chest1") ~= nil or 
                                string.find(item.Name, "Halloween Chest2") ~= nil or
                                string.find(item.Name, "Item Chest") ~= nil or 
                                string.find(item.Name, "Snow Chest") ~= nil or
                                string.find(item.Name, "Volcanic Chest") ~= nil
                if distance <= 10 and not isChest then
                    table.insert(foundItems, item)
                end
            end
        end
        
        -- Drag and teleport all found items
        for _, item in ipairs(foundItems) do
            requestStartDragging:FireServer(item)
            if item.PrimaryPart then
                item.PrimaryPart.CFrame = CFrame.new(targetPos.Position + Vector3.new(0, 5, 0))
                table.insert(allTransportedItems, item)
            end
        end
        
        return #foundItems
    end
    
    local itemsLooted = 0
    
    -- Progressive chest visiting with re-checking system
    for i, chestData in ipairs(availableChests) do
        -- Teleport to current chest
        character.HumanoidRootPart.CFrame = CFrame.new(chestData.Position + Vector3.new(0, 20, 0))
        task.wait(0.1)
        
        -- Collect items around current chest
        local collected = collectItemsAroundChest(chestData.Position, mazeChestPosition)
        itemsLooted = itemsLooted + collected
        
        -- PROGRESSIVE RE-CHECK: Re-check previous chest (if not first chest)
        if i > 1 then
            local previousChest = availableChests[i-1]
            local reCollected = collectItemsAroundChest(previousChest.Position, mazeChestPosition)
            itemsLooted = itemsLooted + reCollected
        end
        
        task.wait(0.1)
    end
    
    -- Return to maze chest position
    character.HumanoidRootPart.CFrame = mazeChestPosition
    
    -- FINAL SWEEP: Re-check ALL chests one more time
    for _, chestData in ipairs(availableChests) do
        local finalCollected = collectItemsAroundChest(chestData.Position, mazeChestPosition)
        itemsLooted = itemsLooted + finalCollected
    end

    -- FINAL STEP: Stop dragging all transported items
    for _, item in ipairs(allTransportedItems) do
        stopDragging:FireServer(item)
    end
    
    task.wait(0.5)

    -- Step 3: Open Halloween Maze Chest
    if openChestRemote then
        pcall(function()
            openChestRemote:FireServer(mazeChest)
        end)
    end
    
    ApocLibrary:Notify({
        Title = "Maze End",
        Content = string.format("Sequence complete!\n🎃 Chests: %d\n📦 Items: %d", 
            chestsOpened, 
            itemsLooted
        ),
        Image = 4483362458,
        Duration = 5
    })
end

function UpdateInvincible()
    if not FoodControl.Invincible.Enabled then return end
    
    local currentTime = tick()
    if currentTime - FoodControl.Invincible.LastCheck < 5 then return end
    
    FoodControl.Invincible.LastCheck = currentTime
    
    local remote = ReplicatedStorage.RemoteEvents:FindFirstChild("DamagePlayer")
    if remote then
        remote:FireServer(-math.huge)
    end
end

-- Function to open all chests (for rewards)
function OpenAllChests()
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        ApocLibrary:Notify({
            Title = "Chests",
            Content = "Items folder not found!",
            Image = 4483362458
        })
        return
    end
    
    local openChestRemote = RemoteEvents:FindFirstChild("RequestOpenItemChest")
    if not openChestRemote then
        ApocLibrary:Notify({
            Title = "Chests",
            Content = "Could not find chest opening remote!",
            Image = 4483362458
        })
        return
    end
    
    local chestsOpened = 0
    
    -- Find all unopened and unlocked chests
    for _, item in pairs(itemsFolder:GetChildren()) do
        if string.find(item.Name:lower(), "chest") then
            local isOpened = false
            local isLocked = false
            
            -- Check if chest is already opened or locked
            for attributeName, attributeValue in pairs(item:GetAttributes()) do
                if string.find(attributeName, "Opened") and attributeValue == true then
                    isOpened = true
                elseif string.find(attributeName, "Locked") and attributeValue == true then
                    isLocked = true
                end
            end
            
            -- Open chest if it's not opened and not locked
            if not isOpened and not isLocked then
                openChestRemote:FireServer(item)
                chestsOpened = chestsOpened + 1
            end
        end
    end
    
    -- Notify user
    if chestsOpened > 0 then
        ApocLibrary:Notify({
            Title = "Chests",
            Content = string.format("Opened %d chest(s), chestsOpened"),
            Image = 4483362458
        })
    else
        ApocLibrary:Notify({
            Title = "Chests",
            Content = "No available chests to open!",
            Image = 4483362458
        })
    end
end

HalloweenTab:CreateButton({
    Name = "Open All Chests",
    Callback = function()
        OpenAllChests()
    end
})

HalloweenTab:CreateButton({
    Name = "🏆 Maze End (Complete Sequence)",
    Callback = function()
        ExecuteMazeEnd()
    end
})

HalloweenTab:CreateButton({
    Name = "🎪 Complete All Carnival Games",
    Callback = function()

        local remote = ReplicatedStorage.RemoteEvents:FindFirstChild("CarnivalCompleteBasketballGallery")
        if not remote then
            ApocLibrary:Notify({
                Title = "Carnival",
                Content = "Carnival remote not found!",
                Image = 4483362458
            })
            return
        end
        
        local carnival = workspace.Map.Landmarks:FindFirstChild("Halloween Carnival")
        if not carnival then
            ApocLibrary:Notify({
                Title = "Carnival",
                Content = "Halloween Carnival not found!",
                Image = 4483362458
            })
            return
        end
        
        local games = carnival:FindFirstChild("Games")
        if not games then
            ApocLibrary:Notify({
                Title = "Carnival",
                Content = "Carnival Games not found!",
                Image = 4483362458
            })
            return
        end
        
        local completed = 0
        
        -- Basketball Hoop
        local basketballHoop = games:FindFirstChild("Basketball Hoop")
        if basketballHoop then
            pcall(function()
                remote:FireServer(basketballHoop)
                completed = completed + 1
            end)
            task.wait(0.2)
        end
        
        -- Ring Toss
        local ringToss = games:FindFirstChild("Ring Toss")
        if ringToss then
            pcall(function()
                remote:FireServer(ringToss)
                completed = completed + 1
            end)
            task.wait(0.2)
        end
        
        -- Shooting Gallery
        local shootingGallery = games:FindFirstChild("Shooting Gallery")
        if shootingGallery then
            pcall(function()
                remote:FireServer(shootingGallery)
                completed = completed + 1
            end)
            task.wait(0.2)
        end
        
        -- Maze Entrance
        local mazeEntrance = games:FindFirstChild("Maze Entrance")
        if mazeEntrance then
            pcall(function()
                remote:FireServer(mazeEntrance)
                completed = completed + 1
            end)
            task.wait(0.2)
        end
        
        ApocLibrary:Notify({
            Title = "Carnival",
            Content = string.format("Completed %d/4 carnival games!", completed),
            Image = 4483362458,
            Duration = 4
        })
    end
})

--============================================================================--
--      [[ SKYBASE FUNCTIONS ]]
--============================================================================--

-- Function to create the platform
local function createOrDeletePlatform()
    -- If platform already exists, delete it
    if SkybaseControl.PlatformModel then
        SkybaseControl.PlatformModel:Destroy()
        SkybaseControl.PlatformModel = nil
        return
    end

    local character = game.Players.LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    SkybaseControl.PlatformModel = Instance.new("Model")
    SkybaseControl.PlatformModel.Name = "CustomBuildPlatform"
    SkybaseControl.PlatformModel.Parent = workspace

    local startPosition = rootPart.CFrame * CFrame.new(0, -5, -15)

    -- Get dimensions from the GUI inputs (default to 4x4)
    local xSize = 4
    local zSize = 4
    
    if SkybaseControl.SkybaseGui and SkybaseControl.SkybaseGui.Parent then
        local xInput = SkybaseControl.SkybaseGui:FindFirstChild("MainFrame"):FindFirstChild("XInput")
        local yInput = SkybaseControl.SkybaseGui:FindFirstChild("MainFrame"):FindFirstChild("YInput")
        if xInput then xSize = tonumber(xInput.Text) or 4 end
        if yInput then zSize = tonumber(yInput.Text) or 4 end
    end

    -- Create the grid of parts
    for x = 1, xSize do
        for z = 1, zSize do
            local part = Instance.new("Part")
            part.Name = "Grass"
            part.Size = Vector3.new(4, 0.5, 4)
            part.Anchored = true
            part.CanCollide = true
            part.Color = Color3.fromRGB(83, 126, 62)
            part.Material = Enum.Material.Grass
            part.Transparency = 0.5
            
            local xOffset = (x - (xSize + 1) / 2) * 4
            local zOffset = (z - (zSize + 1) / 2) * 4
            part.CFrame = startPosition * CFrame.new(xOffset, 0, zOffset)
            part.Parent = SkybaseControl.PlatformModel
        end
    end
end

-- Function to move the platform
local function movePlatform(directionVector)
    if not SkybaseControl.PlatformModel then return end
    SkybaseControl.PlatformModel:TranslateBy(directionVector * SkybaseControl.MOVE_INCREMENT)
end

-- Function to create the improved Skybase GUI
local function createSkybaseGui()
    if SkybaseControl.SkybaseGui then return end
    
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SkybaseGui"
    screenGui.ResetOnSpawn = false
    SkybaseControl.SkybaseGui = screenGui

    -- Main Frame (draggable) - Extra small size for mobile compatibility
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 180, 0, 220)
    mainFrame.Position = UDim2.new(0.5, -90, 0.5, -110)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    -- Add drop shadow effect
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 6, 1, 6)
    shadow.Position = UDim2.new(0, -3, 0, -3)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.5
    shadow.ZIndex = mainFrame.ZIndex - 1
    shadow.Parent = mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar

    -- Fix title bar corners to only round top
    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0, 12)
    titleFix.Position = UDim2.new(0, 0, 1, -12)
    titleFix.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = titleBar

    -- Title Text
    local titleText = Instance.new("TextLabel")
    titleText.Name = "TitleText"
    titleText.Size = UDim2.new(1, -50, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "🏗️ Sky Base"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.TextScaled = true
    titleText.Font = Enum.Font.SourceSansBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    -- Close Button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.Parent = titleBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton

    -- Size Input Section
    local sizeLabel = Instance.new("TextLabel")
    sizeLabel.Name = "SizeLabel"
    sizeLabel.Size = UDim2.new(1, -20, 0, 25)
    sizeLabel.Position = UDim2.new(0, 10, 0, 50)
    sizeLabel.BackgroundTransparency = 1
    sizeLabel.Text = "📏 Platform Size:"
    sizeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    sizeLabel.TextScaled = true
    sizeLabel.Font = Enum.Font.SourceSansBold
    sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
    sizeLabel.Parent = mainFrame

    -- X Size Input
    local xInput = Instance.new("TextBox")
    xInput.Name = "XInput"
    xInput.Size = UDim2.new(0.4, -5, 0, 35)
    xInput.Position = UDim2.new(0, 10, 0, 80)
    xInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    xInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    xInput.PlaceholderText = "Width (X)"
    xInput.Text = "4"
    xInput.Font = Enum.Font.SourceSans
    xInput.TextScaled = true
    xInput.Parent = mainFrame

    local xCorner = Instance.new("UICorner")
    xCorner.CornerRadius = UDim.new(0, 6)
    xCorner.Parent = xInput

    -- Y Size Input
    local yInput = Instance.new("TextBox")
    yInput.Name = "YInput"
    yInput.Size = UDim2.new(0.4, -5, 0, 35)
    yInput.Position = UDim2.new(0.6, 5, 0, 80)
    yInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    yInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    yInput.PlaceholderText = "Length (Y)"
    yInput.Text = "4"
    yInput.Font = Enum.Font.SourceSans
    yInput.TextScaled = true
    yInput.Parent = mainFrame

    local yCorner = Instance.new("UICorner")
    yCorner.CornerRadius = UDim.new(0, 6)
    yCorner.Parent = yInput

    -- Create/Delete Platform Button
    local createButton = Instance.new("TextButton")
    createButton.Name = "CreateButton"
    createButton.Size = UDim2.new(1, -20, 0, 40)
    createButton.Position = UDim2.new(0, 10, 0, 125)
    createButton.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    createButton.Text = "🏗️ Create Platform"
    createButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    createButton.TextScaled = true
    createButton.Font = Enum.Font.SourceSansBold
    createButton.Parent = mainFrame

    local createCorner = Instance.new("UICorner")
    createCorner.CornerRadius = UDim.new(0, 8)
    createCorner.Parent = createButton

    -- Movement Controls Label
    local moveLabel = Instance.new("TextLabel")
    moveLabel.Name = "MoveLabel"
    moveLabel.Size = UDim2.new(1, -20, 0, 25)
    moveLabel.Position = UDim2.new(0, 10, 0, 175)
    moveLabel.BackgroundTransparency = 1
    moveLabel.Text = "🎮 Movement Controls:"
    moveLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    moveLabel.TextScaled = true
    moveLabel.Font = Enum.Font.SourceSansBold
    moveLabel.TextXAlignment = Enum.TextXAlignment.Left
    moveLabel.Parent = mainFrame

    -- Movement Buttons
    local function createMoveButton(name, text, position, size, color)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = size
        button.Position = position
        button.BackgroundColor3 = color
        button.Text = text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextScaled = true
        button.Font = Enum.Font.SourceSansBold
        button.Parent = mainFrame

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button

        return button
    end

    -- Movement button layout (organized grid)
    local upBtn = createMoveButton("UpButton", "⬆️ Up", UDim2.new(0.5, -40, 0, 205), UDim2.new(0, 80, 0, 25), Color3.fromRGB(70, 130, 180))
    local downBtn = createMoveButton("DownButton", "⬇️ Down", UDim2.new(0.5, -40, 0, 285), UDim2.new(0, 80, 0, 25), Color3.fromRGB(70, 130, 180))
    
    -- Left and Right buttons (middle row, left side)
    local leftBtn = createMoveButton("LeftButton", "⬅️ Left", UDim2.new(0, 10, 0, 235), UDim2.new(0, 65, 0, 25), Color3.fromRGB(100, 100, 100))
    local rightBtn = createMoveButton("RightButton", "➡️ Right", UDim2.new(0, 10, 0, 265), UDim2.new(0, 65, 0, 25), Color3.fromRGB(100, 100, 100))
    
    -- Forward and Back buttons (middle row, right side)
    local fwdBtn = createMoveButton("ForwardButton", "🔼 Forward", UDim2.new(1, -75, 0, 235), UDim2.new(0, 65, 0, 25), Color3.fromRGB(50, 150, 50))
    local backBtn = createMoveButton("BackButton", "🔽 Back", UDim2.new(1, -75, 0, 265), UDim2.new(0, 65, 0, 25), Color3.fromRGB(150, 50, 50))

    -- Info Label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, -20, 0, 30)
    infoLabel.Position = UDim2.new(0, 10, 0, 315)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "💡 Tip: Drag the window from the top bar"
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    infoLabel.TextScaled = true
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.TextWrapped = true
    infoLabel.Parent = mainFrame

    -- Connect button events
    createButton.MouseButton1Click:Connect(function()
        createOrDeletePlatform()
        -- Update button text and color
        if SkybaseControl.PlatformModel then
            createButton.Text = "🗑️ Delete Platform"
            createButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        else
            createButton.Text = "🏗️ Create Platform"
            createButton.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
        end
    end)

    -- Movement button connections
    upBtn.MouseButton1Click:Connect(function() movePlatform(Vector3.new(0, 1, 0)) end)
    downBtn.MouseButton1Click:Connect(function() movePlatform(Vector3.new(0, -1, 0)) end)
    leftBtn.MouseButton1Click:Connect(function() movePlatform(Vector3.new(-1, 0, 0)) end)
    rightBtn.MouseButton1Click:Connect(function() movePlatform(Vector3.new(1, 0, 0)) end)
    
    fwdBtn.MouseButton1Click:Connect(function()
        local lookVector = player.Character.HumanoidRootPart.CFrame.LookVector
        movePlatform(Vector3.new(lookVector.X, 0, lookVector.Z).Unit)
    end)
    
    backBtn.MouseButton1Click:Connect(function()
        local lookVector = player.Character.HumanoidRootPart.CFrame.LookVector
        movePlatform(-Vector3.new(lookVector.X, 0, lookVector.Z).Unit)
    end)

    -- Close button connection
    closeButton.MouseButton1Click:Connect(function()
        SkybaseControl.GuiEnabled = false
        screenGui:Destroy()
        SkybaseControl.SkybaseGui = nil
        -- Also delete platform when closing GUI
        if SkybaseControl.PlatformModel then
            SkybaseControl.PlatformModel:Destroy()
            SkybaseControl.PlatformModel = nil
        end
    end)

    -- Parent to PlayerGui
    screenGui.Parent = player:WaitForChild("PlayerGui")
end

-- Function to destroy Skybase GUI
local function destroySkybaseGui()
    if SkybaseControl.SkybaseGui then
        SkybaseControl.SkybaseGui:Destroy()
        SkybaseControl.SkybaseGui = nil
    end
    -- Also delete platform
    if SkybaseControl.PlatformModel then
        SkybaseControl.PlatformModel:Destroy()
        SkybaseControl.PlatformModel = nil
    end
end

-- Initialize lighting system
initializeLighting()

-- Reveal All Map Control (Tornado Spiral Method)
local RevealMapControl = {
    IsRevealing = false,
    SpiralSpeed = 150, -- studs per second (max 250)
    RadiusStep = 15, -- studs to expand per full rotation
    HeightAboveTerrain = 45, -- studs above ground
    RevealThread = nil,
    WasFlyEnabled = false -- Track if fly was already enabled before reveal
}

local function getCampfirePosition()
    local campfire = workspace.Map and workspace.Map.Campground and workspace.Map.Campground.MainFire
    if campfire and campfire:FindFirstChild("Center") then
        return campfire.Center.Position
    end
    return nil
end

local function getMapRange()
    local mapRange = workspace:GetAttribute("MapRange")
    
    if mapRange then
        if type(mapRange) == "string" then
            mapRange = tonumber(mapRange) or 145
        end
        return mapRange
    end
    
    return 145
end

local function teleportToCampfire()
    local player = game.Players.LocalPlayer
    if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local campfire = workspace.Map and workspace.Map.Campground and workspace.Map.Campground.MainFire
        if campfire and campfire:FindFirstChild("Center") then
            local campfirePosition = campfire.Center.Position
            local teleportPosition = campfirePosition + Vector3.new(0, 5, 0)
            player.Character.HumanoidRootPart.CFrame = CFrame.new(teleportPosition)
        end
    end
end

local function startRevealingMap()
    if RevealMapControl.IsRevealing then
        return
    end
    
    local player = game.Players.LocalPlayer
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local campfirePos = getCampfirePosition()
    if not campfirePos then
        return
    end
    
    local maxRadius = getMapRange()
    
    RevealMapControl.WasFlyEnabled = PlayerControl.FlyEnabled
    
    if not PlayerControl.FlyEnabled then
        PlayerControl.FlyEnabled = true
    end
    
    RevealMapControl.IsRevealing = true
    
    RevealMapControl.RevealThread = task.spawn(function()
        local hrp = player.Character.HumanoidRootPart
        local currentRadius = 10
        local currentAngle = 0
        
        while RevealMapControl.IsRevealing and currentRadius <= maxRadius do
            -- Calculate angular speed based on current radius
            -- Angular velocity (radians/sec) = Linear velocity / Radius
            local angularSpeed = RevealMapControl.SpiralSpeed / currentRadius
            
            -- Convert to degrees per frame (assuming 60 FPS)
            local degreesPerFrame = math.deg(angularSpeed) / 60
            
            -- Update angle
            currentAngle = currentAngle + degreesPerFrame
            
            -- Check if we completed a full rotation (360 degrees)
            if currentAngle >= 360 then
                currentAngle = currentAngle - 360
                currentRadius = currentRadius + RevealMapControl.RadiusStep
                
                if currentRadius > maxRadius then
                    -- Check if MapRange increased (campfire upgraded)
                    local newMaxRadius = getMapRange()
                    if newMaxRadius > maxRadius then
                        -- MapRange increased! Continue spiraling
                        maxRadius = newMaxRadius
                    else
                        -- No increase, we're done
                        break
                    end
                end
            end
            
            local angleRad = math.rad(currentAngle)
            local offsetX = math.cos(angleRad) * currentRadius
            local offsetZ = math.sin(angleRad) * currentRadius
            
            local targetPosition = campfirePos + Vector3.new(offsetX, RevealMapControl.HeightAboveTerrain, offsetZ)
            
            if hrp and hrp.Parent then
                hrp.CFrame = CFrame.new(targetPosition)
            else
                break
            end
            
            task.wait(1/60)
        end
        
        if RevealMapControl.IsRevealing then
            RevealMapControl.IsRevealing = false
            
            if not RevealMapControl.WasFlyEnabled then
                PlayerControl.FlyEnabled = false
            end
            
            -- Auto-turn off the toggle when completed
            if ApocLibrary and ApocLibrary.Flags and ApocLibrary.Flags["Misc_RevealAllMap"] then
                ApocLibrary.Flags["Misc_RevealAllMap"]:Set(false)
            end
            
            -- Teleport back to campfire
            teleportToCampfire()
        end
    end)
end

local function stopRevealingMap()
    if RevealMapControl.RevealThread then
        task.cancel(RevealMapControl.RevealThread)
        RevealMapControl.RevealThread = nil
    end
    RevealMapControl.IsRevealing = false
    
    if not RevealMapControl.WasFlyEnabled then
        PlayerControl.FlyEnabled = false
    end
    
    teleportToCampfire()
end

-- Misc GUI Controls
MiscTab:CreateLabel("After turning it off make sure to visit the campfire to restart the real time lighting")

MiscTab:CreateToggle({
    Name = "Always Day Light",
    CurrentValue = false,
    Flag = "Misc_AlwaysDayLight",
    Callback = function(v)
        toggleAlwaysDay(v)
    end
})

-- Performance Booster Section
MiscTab:CreateLabel("⚡ Performance Booster - Please note: Once you activate it, to disable you have to restart the game/server")

-- Performance Booster Control
local PerformanceBoosterControl = {
    IsActive = false,
    WorkspaceConnection = nil
}

local function optimizeObject(v)
    pcall(function()
        if not v or not v.Parent then return end
        
        if v:IsA("BasePart") then
            v.Material = "Plastic"
            v.Reflectance = 0
        elseif v:IsA("Decal") then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Lifetime = NumberRange.new(0)
        elseif v:IsA("Explosion") then
            v.BlastPressure = 1
            v.BlastRadius = 1
        end
    end)
end

local function applyGlobalSettings()
    -- Terrain Settings
    local terrain = workspace:FindFirstChildOfClass('Terrain')
    if terrain then
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
        terrain.WaterTransparency = 0
    end

    -- Lighting Settings (avoid conflict with Always Day Light)
    if not (ApocLibrary and ApocLibrary.Flags and ApocLibrary.Flags["Misc_AlwaysDayLight"] and ApocLibrary.Flags["Misc_AlwaysDayLight"].CurrentValue) then
        game:GetService("Lighting").GlobalShadows = false
    end
    game:GetService("Lighting").FogEnd = 9e9

    -- Graphics Quality Settings
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    -- Post-Processing Effects
    for i,v in pairs(game:GetService("Lighting"):GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = false
        end
    end
end

local function activatePerformanceBooster()
    if PerformanceBoosterControl.IsActive then
        return
    end
    
    PerformanceBoosterControl.IsActive = true
    
    -- Apply global settings
    applyGlobalSettings()
    
    -- Optimize existing objects
    for i, v in pairs(workspace:GetDescendants()) do
        optimizeObject(v)
    end
    
    -- Connect to optimize new objects
    PerformanceBoosterControl.WorkspaceConnection = workspace.DescendantAdded:Connect(optimizeObject)
end

MiscTab:CreateToggle({
    Name = "Performance Booster",
    CurrentValue = false,
    Flag = "Misc_PerformanceBooster",
    Callback = function(v)
        if v then
            activatePerformanceBooster()
        end
        -- Note: Cannot be disabled once activated as per requirement
    end
})

-- Instant Open Chests Section
local InstantChestsControl = {
    IsActive = false,
    WorkspaceConnection = nil
}

local function patchChestPrompt(prompt)
    if prompt:IsA("ProximityPrompt") and prompt.Name == "ProximityInteraction" then
        local ancestor = prompt:FindFirstAncestorWhichIsA("Model")
        if ancestor and string.find(ancestor.Name, "Chest") then
            if prompt.HoldDuration > 0 then
                prompt.HoldDuration = 0
            end
        end
    end
end

local function activateInstantChests()
    if InstantChestsControl.IsActive then
        return
    end
    
    InstantChestsControl.IsActive = true
    
    -- Patch existing chest prompts
    for _, descendant in ipairs(workspace:GetDescendants()) do
        patchChestPrompt(descendant)
    end
    
    -- Watch for new chest prompts
    InstantChestsControl.WorkspaceConnection = workspace.DescendantAdded:Connect(patchChestPrompt)
end

local function deactivateInstantChests()
    if InstantChestsControl.WorkspaceConnection then
        InstantChestsControl.WorkspaceConnection:Disconnect()
        InstantChestsControl.WorkspaceConnection = nil
    end
    InstantChestsControl.IsActive = false
end

MiscTab:CreateToggle({
    Name = "Instant Open Chests",
    CurrentValue = false,
    Flag = "Misc_InstantOpenChests",
    Callback = function(v)
        if v then
            activateInstantChests()
        else
            deactivateInstantChests()
        end
    end
})

-- Reveal All Map Section (Tornado Spiral)
MiscTab:CreateLabel("🌪️ Tornado Spiral Map Reveal - Spins around campfire expanding outward!")

MiscTab:CreateSlider({
    Name = "Spiral Speed",
    Range = {50, 1000},
    Increment = 10,
    Suffix = " studs/sec",
    CurrentValue = RevealMapControl.SpiralSpeed,
    Flag = "Misc_SpiralSpeed",
    Callback = function(val)
        RevealMapControl.SpiralSpeed = val
    end
})

MiscTab:CreateSlider({
    Name = "Radius Expansion",
    Range = {5, 60},
    Increment = 5,
    Suffix = " studs/rotation",
    CurrentValue = RevealMapControl.RadiusStep,
    Flag = "Misc_RadiusStep",
    Callback = function(val)
        RevealMapControl.RadiusStep = val
    end
})

MiscTab:CreateToggle({
    Name = "Reveal All Map",
    CurrentValue = false,
    Flag = "Misc_RevealAllMap",
    Callback = function(v)
        if v then
            startRevealingMap()
        else
            stopRevealingMap()
        end
    end
})

function UpdateAutoCollectFlowers()
    if not FoodControl.AutoCollectFlowers.Enabled then return end
    
    local currentTime = tick()
    if currentTime - FoodControl.AutoCollectFlowers.LastCheck < 5 then return end
    
    FoodControl.AutoCollectFlowers.LastCheck = currentTime
    
    local char = game.Players.LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local remote = ReplicatedStorage.RemoteEvents:FindFirstChild("RequestPickFlower")
    if not remote then return end
    
    for _, landmark in pairs(workspace.Map.Landmarks:GetDescendants()) do
        if not FoodControl.AutoCollectFlowers.Enabled then return end
        
        if landmark.Name == "Flower" and landmark:FindFirstChild("HRP") then
            char.HumanoidRootPart.CFrame = landmark.HRP.CFrame
            task.wait(0.1)
            remote:InvokeServer(landmark)
            task.wait(0.05)
        end
    end
end

MiscTab:CreateToggle({
    Name = "🌸 Auto Collect Flowers",
    CurrentValue = false,
    Flag = "Misc_AutoCollectFlowers",
    Callback = function(v)
        FoodControl.AutoCollectFlowers.Enabled = v
        FoodControl.AutoCollectFlowers.LastCheck = 0
    end
})

MiscTab:CreateButton({
    Name = "🪙 Collect All Coins",
    Callback = function()
        local char = game.Players.LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local playerPos = char.HumanoidRootPart.Position
        local count = 0
        for _, item in pairs(workspace.Items:GetChildren()) do
            if item.Name == "Coin Stack" and item:FindFirstChild("Main") then
                item.Main.CFrame = CFrame.new(playerPos + Vector3.new(math.random(-5,5), 2, math.random(-5,5)))
                count = count + 1
            end
        end
    end
})

MiscTab:CreateToggle({
    Name = "Invincible Mod",
    CurrentValue = false,
    Flag = "Misc_Invincible",
    Callback = function(v)
        FoodControl.Invincible.Enabled = v
        FoodControl.Invincible.LastCheck = 0
    end
})

-- Auto Clean Coins control state
local AutoCleanCoinsControl = {
    Enabled = false,
    Connection = nil,
    LastClean = 0,
    OriginalPosition = nil
}

-- Function to auto clean coins (teleport to coins and collect them)
local function autoCleanCoins()
    local currentTime = tick()
    if currentTime - AutoCleanCoinsControl.LastClean < 300 then return end -- 5 minutes = 300 seconds
    
    -- Check if Auto Stronghold is in progress - if so, wait and recheck
    -- Safe check: only check InProgress if AutoStrongholdControl exists
    if AutoStrongholdControl and AutoStrongholdControl.InProgress then
        task.wait(30) -- Wait 30 seconds and recheck
        return -- This will cause the while loop to recheck after 30 seconds
    end
    
    AutoCleanCoinsControl.LastClean = currentTime
    
    local char = game.Players.LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    -- Store original position
    if not AutoCleanCoinsControl.OriginalPosition then
        AutoCleanCoinsControl.OriginalPosition = char.HumanoidRootPart.Position
    end
    
    local playerPos = char.HumanoidRootPart.Position
    local coinsFound = {}
    
    -- Step 1: Use "Collect All Coins" function - teleport all coin stacks to player
    for _, item in pairs(workspace.Items:GetChildren()) do
        if item.Name == "Coin Stack" and item:FindFirstChild("Main") then
            item.Main.CFrame = CFrame.new(playerPos + Vector3.new(math.random(-5,5), 2, math.random(-5,5)))
            table.insert(coinsFound, item)
        end
    end
    
    if #coinsFound == 0 then
        -- No coins found, reset original position and return
        AutoCleanCoinsControl.OriginalPosition = nil
        return
    end
    
    -- Small delay for coins to settle after teleportation
    task.wait(0.5)
    
    -- Step 2: Collect all the coin stacks using RequestCollectCoints
    for _, coinStack in ipairs(coinsFound) do
        if coinStack and coinStack.Parent then
            -- Collect the coin stack using RequestCollectCoints
            local requestCollectCoints = RemoteEvents:FindFirstChild("RequestCollectCoints")
            if requestCollectCoints then
                pcall(function()
                    requestCollectCoints:InvokeServer(coinStack)
                end)
            end
            
            task.wait(0.3) -- Cooldown between collections
        end
    end
    
    -- Step 3: Return player to original position
    if AutoCleanCoinsControl.OriginalPosition then
        char.HumanoidRootPart.CFrame = CFrame.new(AutoCleanCoinsControl.OriginalPosition)
        AutoCleanCoinsControl.OriginalPosition = nil
    end
end

MiscTab:CreateToggle({
    Name = "🪙 Auto Clean Coins",
    CurrentValue = false,
    Flag = "Misc_AutoCleanCoins",
    Callback = function(v)
        AutoCleanCoinsControl.Enabled = v
        if v then
            AutoCleanCoinsControl.LastClean = 0 -- Reset timer to start immediately
            AutoCleanCoinsControl.Connection = task.spawn(function()
                while AutoCleanCoinsControl.Enabled do
                    autoCleanCoins()
                    task.wait(30) -- Check every 30 seconds, but actual execution is limited by 5-minute cooldown
                end
            end)
        else
            if AutoCleanCoinsControl.Connection then
                task.cancel(AutoCleanCoinsControl.Connection)
                AutoCleanCoinsControl.Connection = nil
            end
            AutoCleanCoinsControl.OriginalPosition = nil
        end
    end
})

-- Auto Stronghold control state
local AutoStrongholdControl = {
    Enabled = false,
    Connection = nil,
    LastCheck = 0,
    InProgress = false,
    PreStrongholdPosition = nil -- Store position before stronghold teleport
}

-- Function to collect diamonds after chest is opened
local function collectDiamonds()
    local diamondsFound = {}
    
    -- Find all diamond items in workspace
    for _, item in pairs(WorkspaceItems:GetChildren()) do
        if item.Name == "Diamond" then
            table.insert(diamondsFound, item)
        end
    end
    
    if #diamondsFound == 0 then
        return false
    end
    
    -- Collect each diamond using RequestTakeDiamonds
    for _, diamond in ipairs(diamondsFound) do
        if diamond and diamond.Parent then
            -- Send take request directly
            local requestTakeDiamonds = RemoteEvents:FindFirstChild("RequestTakeDiamonds")
            if requestTakeDiamonds then
                pcall(function()
                    requestTakeDiamonds:FireServer(diamond)
                end)
            end
            
            task.wait(0.1) -- Small delay between collections
        end
    end
    
    return true
end

-- Auto Stronghold function
local function AutoStronghold()
    if AutoStrongholdControl.InProgress then return end
    
    local currentTime = tick()
    if currentTime - AutoStrongholdControl.LastCheck < 5 then return end
    AutoStrongholdControl.LastCheck = currentTime
    
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    
    local success, result = pcall(function()
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        -- Case 1: Check if diamond chest exists and is unlocked (event completed by another user)
        local diamondChest = workspace.Items:FindFirstChild("Stronghold Diamond Chest")
        if diamondChest and (diamondChest:GetAttribute("Locked") == false or diamondChest:GetAttribute("Locked") == nil) then
            -- Check if chest is already opened using same logic as chest section
            local isOpened = false
            for attributeName, attributeValue in pairs(diamondChest:GetAttributes()) do
                if string.find(attributeName, "Opened") and attributeValue == true then
                    isOpened = true
                    break
                end
            end
            
            -- Only proceed if chest is not already opened
            if not isOpened then
            AutoStrongholdControl.InProgress = true
            
            -- Save current position before teleporting to stronghold
            AutoStrongholdControl.PreStrongholdPosition = rootPart.CFrame
            
            -- Go to loot zone and open the chest
            local stronghold = workspace.Map.Landmarks:FindFirstChild("Stronghold")
            if stronghold then
                local functionalFolder = stronghold:FindFirstChild("Functional", true)
                if functionalFolder then
                    local lootZones = functionalFolder:FindFirstChild("LootZones")
                    if lootZones and lootZones:GetChildren()[4] then
                        local finalZone = lootZones:GetChildren()[4]:FindFirstChild("Zone")
                        if finalZone then
                            rootPart.CFrame = finalZone.CFrame + Vector3.new(0, 5, 0)
                            task.wait(1)
                        end
                    end
                end
            end
            
            -- Open the diamond chest
            local openChestRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestOpenItemChest")
            openChestRemote:FireServer(diamondChest)
            
            -- Wait 1 second then collect diamonds
            task.wait(1)
            collectDiamonds()
            
            -- Return to original position before stronghold
            if AutoStrongholdControl.PreStrongholdPosition then
                rootPart.CFrame = AutoStrongholdControl.PreStrongholdPosition
                AutoStrongholdControl.PreStrongholdPosition = nil
            end
            
            AutoStrongholdControl.InProgress = false
            -- Don't disable the system - keep it running for future strongholds!
            -- AutoStrongholdControl.Enabled = false  -- REMOVED: This was causing the bug
            -- if AutoStrongholdControl.Connection then  -- REMOVED: This was disconnecting future checks
            --     AutoStrongholdControl.Connection:Disconnect()
            --     AutoStrongholdControl.Connection = nil
            -- end
            return
            end -- Close the isOpened check
        end
        
        -- Case 2: Check if event is ready to start (timer = 00s)
        local stronghold = workspace.Map.Landmarks:FindFirstChild("Stronghold")
        if not stronghold then return end
        
        local functionalFolder = stronghold:FindFirstChild("Functional", true)
        if not functionalFolder then return end
        
        local signTextLabel = functionalFolder:FindFirstChild("Sign", true)
            and functionalFolder.Sign:FindFirstChild("SurfaceGui", true)
            and functionalFolder.Sign.SurfaceGui:FindFirstChild("Frame", true)
            and functionalFolder.Sign.SurfaceGui.Frame:FindFirstChild("Body", true)
        
        if not signTextLabel then return end
        
        if signTextLabel.ContentText == "00s" then
            AutoStrongholdControl.InProgress = true
            
            -- Save current position before teleporting to stronghold
            AutoStrongholdControl.PreStrongholdPosition = rootPart.CFrame
            
            -- Trigger the event by touching the trigger zone
            local wave1Folder = functionalFolder.EnemyWaves12:FindFirstChild("Wave1")
            local triggerZone = wave1Folder and wave1Folder:FindFirstChild("TriggerZone")
            if triggerZone then
                rootPart.CFrame = triggerZone.CFrame
                task.wait(0.5) -- Small delay to ensure trigger registers
            end

            -- Teleport above the door and stay there (kill aura will handle enemies)
            local referenceDoor = functionalFolder:FindFirstChild("Floor1", true)
            referenceDoor = referenceDoor and referenceDoor:FindFirstChild("EnemySpawnDoor")
            referenceDoor = referenceDoor and referenceDoor:FindFirstChild("Door")
            referenceDoor = referenceDoor and referenceDoor:FindFirstChild("Main")
            if referenceDoor then
                rootPart.CFrame = referenceDoor.CFrame + Vector3.new(0, 25, 0)
            end

            local lootZones = functionalFolder:FindFirstChild("LootZones")
            local finalZone = nil
            if lootZones and lootZones:GetChildren()[4] then
                finalZone = lootZones:GetChildren()[4]:FindFirstChild("Zone")
            end
            
            spawn(function()
                -- Keep checking until the event completes (diamond chest unlocked)
                local diamondChest = workspace.Items:FindFirstChild("Stronghold Diamond Chest")
                if diamondChest then
                    -- Keep checking until chest is unlocked
                    repeat 
                        task.wait(0.5) 
                        diamondChest = workspace.Items:FindFirstChild("Stronghold Diamond Chest")
                    until not diamondChest or diamondChest:GetAttribute("Locked") == false or diamondChest:GetAttribute("Locked") == nil
                    
                    -- Open the chest once unlocked
                    if diamondChest then
                        if finalZone then
                            local character = player.Character
                            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
                            if humanoidRootPart then
                                humanoidRootPart.CFrame = finalZone.CFrame + Vector3.new(0, 5, 0)
                            end
                        end
                        
                        local openChestRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestOpenItemChest")
                        openChestRemote:FireServer(diamondChest)
                        
                        -- Wait 1 second then collect diamonds
                        task.wait(1)
                        collectDiamonds()

                        -- Return to original position before stronghold
                        if AutoStrongholdControl.PreStrongholdPosition then
                            local character = player.Character
                            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
                            if humanoidRootPart then
                                humanoidRootPart.CFrame = AutoStrongholdControl.PreStrongholdPosition
                            end
                            AutoStrongholdControl.PreStrongholdPosition = nil
                        end
                        
                        -- Wait 10 minutes before checking for next stronghold (timer needs time to reset)
                        task.wait(600) -- 10 minutes = 600 seconds
                    end
                    
                    -- Reset flags
                    AutoStrongholdControl.InProgress = false
                    -- Don't disable the system - keep it running for future strongholds!
                    -- AutoStrongholdControl.Enabled = false  -- REMOVED: This was causing the bug
                    -- if AutoStrongholdControl.Connection then  -- REMOVED: This was disconnecting future checks
                    --     task.cancel(AutoStrongholdControl.Connection)
                    --     AutoStrongholdControl.Connection = nil
                    -- end
                else
                    AutoStrongholdControl.InProgress = false
                end
            end)
        else
            AutoStrongholdControl.InProgress = false
        end
    end)
end

MiscTab:CreateToggle({
    Name = "🏰 Auto Stronghold",
    CurrentValue = false,
    Flag = "Misc_AutoStronghold",
    Callback = function(v)
        AutoStrongholdControl.Enabled = v
        
        if v then
            -- Start the auto stronghold loop with a spawned coroutine instead of heartbeat
            AutoStrongholdControl.Connection = task.spawn(function()
                while AutoStrongholdControl.Enabled do
                    AutoStronghold()
                    task.wait(3) -- Check every 3 seconds instead of every frame
                end
            end)
        else
            -- Stop the auto stronghold loop
            AutoStrongholdControl.Enabled = false
            if AutoStrongholdControl.Connection then
                task.cancel(AutoStrongholdControl.Connection)
                AutoStrongholdControl.Connection = nil
            end
            AutoStrongholdControl.InProgress = false
        end
    end
})

-- Fishing Always Correct Control
local FishingControl = {
    Enabled = false,
    Connection = nil,
    FishingFrame = nil
}

-- Function to make fishing minigame easy
local function makeFishingEasy()
    if not (FishingControl.FishingFrame and FishingControl.FishingFrame.Visible) then
        return
    end
    
    -- Find the success area in the fishing minigame
    local successArea = FishingControl.FishingFrame.TimingBar:FindFirstChild("SuccessArea")
    if successArea then
        -- Make the green success zone cover the entire bar (100%)
        successArea.Size = UDim2.new(1, 0, 1, 0)
        successArea.Position = UDim2.new(0, 0, 0, 0)
    end
end

-- Function to find the fishing frame
local function findFishingFrame()
    local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local interface = playerGui:FindFirstChild("Interface")
        if interface then
            return interface:FindFirstChild("FishingCatchFrame")
        end
    end
    return nil
end

-- Function to start fishing assistance
local function startFishingAssist()
    if FishingControl.Enabled then
        return
    end
    
    FishingControl.Enabled = true
    
    -- Wait for fishing frame to exist
    task.spawn(function()
        repeat task.wait(0.5) until findFishingFrame()
        FishingControl.FishingFrame = findFishingFrame()
        
        -- Listen for when the fishing minigame becomes visible
        FishingControl.FishingFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            if FishingControl.FishingFrame.Visible and FishingControl.Enabled then
                -- Start the assistance when minigame is visible
                if not FishingControl.Connection then
                    FishingControl.Connection = RunService.RenderStepped:Connect(makeFishingEasy)
                end
            else
                -- Stop assistance when minigame ends
                if FishingControl.Connection then
                    FishingControl.Connection:Disconnect()
                    FishingControl.Connection = nil
                end
            end
        end)
    end)
end

-- Function to stop fishing assistance
local function stopFishingAssist()
    FishingControl.Enabled = false
    if FishingControl.Connection then
        FishingControl.Connection:Disconnect()
        FishingControl.Connection = nil
    end
end

MiscTab:CreateToggle({
    Name = "🎣 Fishing Always Correct",
    CurrentValue = false,
    Flag = "Misc_FishingAlwaysCorrect",
    Callback = function(v)
        if v then
            startFishingAssist()
        else
            stopFishingAssist()
        end
    end
})

MiscTab:CreateToggle({
    Name = "🔥 Auto Cultist Transport",
    CurrentValue = false,
    Flag = "Misc_CultistTransport",
    Callback = function(v)
        CultistControl.TransportEnabled = v
        if v then
            -- Start the cultist transport loop with a spawned coroutine instead of heartbeat
            CultistControl.Connection = task.spawn(function()
                while CultistControl.TransportEnabled do
                    CultistTransporter()
                    task.wait(2) -- Check every 2 seconds instead of every frame
                end
            end)
        else
            -- Stop the cultist transport loop
            CultistControl.TransportEnabled = false
            if CultistControl.Connection then
                task.cancel(CultistControl.Connection)
                CultistControl.Connection = nil
            end
            -- Clear tracking table
            CultistControl.TeleportedCultists = {}
        end
    end
})

MiscTab:CreateToggle({
    Name = "🧠 Smart Auto Skip Nights",
    CurrentValue = false,
    Flag = "Misc_SmartAutoSkipNights",
    Callback = function(v)
        WorldStatusControl.SmartNightSkip.SkipEnabled = v
        if v then
            -- Start the smart night skip loop
            WorldStatusControl.SmartNightSkip.Connection = task.spawn(function()
                while WorldStatusControl.SmartNightSkip.SkipEnabled do
                    SmartNightSkipper()
                    task.wait(1) -- Check every second for precise timing
                end
            end)
        else
            -- Stop the smart night skip loop
            WorldStatusControl.SmartNightSkip.SkipEnabled = false
            if WorldStatusControl.SmartNightSkip.Connection then
                task.cancel(WorldStatusControl.SmartNightSkip.Connection)
                WorldStatusControl.SmartNightSkip.Connection = nil
            end
        end
    end
})

MiscTab:CreateToggle({
    Name = "⚡ Auto Respawn Capsule",
    CurrentValue = false,
    Flag = "Misc_AutoRespawnCapsule",
    Callback = function(v)
        WorldStatusControl.RespawnCapsule.RechargeEnabled = v
        if v then
            -- Start the respawn capsule recharge loop with 10-second interval
            WorldStatusControl.RespawnCapsule.Connection = task.spawn(function()
                while WorldStatusControl.RespawnCapsule.RechargeEnabled do
                    RespawnCapsuleRecharger()
                    task.wait(10) -- Check every 10 seconds as requested
                end
            end)
        else
            -- Stop the respawn capsule recharge loop
            WorldStatusControl.RespawnCapsule.RechargeEnabled = false
            if WorldStatusControl.RespawnCapsule.Connection then
                task.cancel(WorldStatusControl.RespawnCapsule.Connection)
                WorldStatusControl.RespawnCapsule.Connection = nil
            end
        end
    end
})

local function startAutoStun(entry, characterName)
    if entry.Running then
        return
    end

    entry.Running = true
    task.spawn(function()
        while entry.Enabled do
            local charactersFolder = workspace:FindFirstChild("Characters")
            local target = charactersFolder and charactersFolder:FindFirstChild(characterName)
            if target then
                pcall(function()
                    game:GetService("ReplicatedStorage").RemoteEvents.MonsterHitByTorch:InvokeServer(target)
                end)
            end
            task.wait(0.4)
        end
        entry.Running = false
    end)
end

MiscTab:CreateToggle({
    Name = "🦌 Auto Stun Deer",
    CurrentValue = false,
    Flag = "Misc_AutoStunDeer",
    Callback = function(v)
        local entry = WorldStatusControl.AutoStun.Deer
        entry.Enabled = v
        if v then
            startAutoStun(entry, "Deer")
        end
    end
})

MiscTab:CreateToggle({
    Name = "🦉 Auto Stun Owl",
    CurrentValue = false,
    Flag = "Misc_AutoStunOwl",
    Callback = function(v)
        local entry = WorldStatusControl.AutoStun.Owl
        entry.Enabled = v
        if v then
            startAutoStun(entry, "Owl")
        end
    end
})

MiscTab:CreateToggle({
    Name = "🐏 Auto Stun Ram",
    CurrentValue = false,
    Flag = "Misc_AutoStunRam",
    Callback = function(v)
        local entry = WorldStatusControl.AutoStun.Ram
        entry.Enabled = v
        if v then
            startAutoStun(entry, "Ram")
        end
    end
})

-- Player GUI Controls
PlayerTab:CreateToggle({
    Name = "Enable Speed",
    CurrentValue = false,
    Flag = "Player_EnableSpeed",
    Callback = function(v)
        PlayerControl.SpeedEnabled = v
        UpdateAll()
    end
})

PlayerTab:CreateSlider({
    Name = "Speed Value",
    Range = {16, 100},
    Increment = 1,
    Suffix = " speed",
    CurrentValue = PlayerControl.SpeedValue,
    Flag = "Player_SpeedValue",
    Callback = function(val)
        PlayerControl.SpeedValue = val
        if PlayerControl.SpeedEnabled then UpdateAll() end
    end
})

PlayerTab:CreateToggle({
    Name = "Enable Jump",
    CurrentValue = false,
    Flag = "Player_EnableJump",
    Callback = function(v)
        PlayerControl.JumpEnabled = v
        UpdateAll()
    end
})

PlayerTab:CreateSlider({
    Name = "Jump Power",
    Range = {25, 150},
    Increment = 1,
    Suffix = " jump",
    CurrentValue = PlayerControl.JumpValue,
    Flag = "Player_JumpValue",
    Callback = function(val)
        PlayerControl.JumpValue = val
        if PlayerControl.JumpEnabled then UpdateAll() end
    end
})

PlayerTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Flag = "Player_InfiniteJump",
    Callback = function(v)
        PlayerControl.InfiniteJump = v
    end
})

PlayerTab:CreateToggle({
    Name = "Fly Mode",
    CurrentValue = false,
    Flag = "Player_FlyMode",
    Callback = function(v)
        PlayerControl.FlyEnabled = v
        
        -- Toggle mobile controls visibility
        if PlayerControl.MobileGui then
            PlayerControl.MobileGui.Enabled = v
            -- Reset all fly keys when toggling off
            if not v then
                for key in pairs(FlyKeys) do
                    FlyKeys[key] = false
                end
            end
        end
        
        if not v then
            -- Clean up and reset when disabling
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local root = char.HumanoidRootPart
                
                -- Remove BodyVelocity objects
                local bodyVel = root:FindFirstChild("FlyBodyVelocity")
                local bodyAngVel = root:FindFirstChild("FlyBodyAngularVelocity")
                if bodyVel then bodyVel:Destroy() end
                if bodyAngVel then bodyAngVel:Destroy() end
                
                -- Reset velocities
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                
                -- Reset humanoid
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.PlatformStand = false
                end
                
                -- Re-enable collisions
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
})

PlayerTab:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 1,
    Suffix = " studs/s",
    CurrentValue = PlayerControl.FlySpeed,
    Flag = "Player_FlySpeed",
    Callback = function(val)
        PlayerControl.FlySpeed = val
    end
})

-- Important Places Teleportation
PlayerTab:CreateLabel("🗺️ Important Places Teleportation:")
PlayerTab:CreateLabel("If teleportation doesn't work, try revealing the map first as some locations may not be loaded yet.")

-- Store selected teleport location
local SelectedTeleportLocation = "Campfire"

PlayerTab:CreateDropdown({
    Name = "Teleport to Important Places",
    Options = {"Campfire", "Safe Place Underground", "Volcano Sacrifice", "Stronghold", "Fairy House", "Tool Workshop"},
    CurrentOption = {"Campfire"},
    Flag = "Player_TeleportLocation",
    Callback = function(options)
        SelectedTeleportLocation = options[1]
    end
})

-- Separate teleport button
PlayerTab:CreateButton({
    Name = "🚀 Teleport to Selected Location",
    Callback = function()
        local player = game.Players.LocalPlayer
        if not (player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then
            return
        end
        
        local destination = nil
        local locationFound = false
        
        if SelectedTeleportLocation == "Campfire" then
            local campfire = workspace.Map and workspace.Map.Campground and workspace.Map.Campground.MainFire
            if campfire and campfire:FindFirstChild("Center") then
                destination = campfire.Center.Position + Vector3.new(0, 5, 0)
                locationFound = true
            end
            
        elseif SelectedTeleportLocation == "Safe Place Underground" then
            local baseplate = workspace.Map and workspace.Map:FindFirstChild("Baseplate")
            if baseplate then
                destination = baseplate.Position + Vector3.new(0, 3, 0)
                locationFound = true
            end
            
        elseif SelectedTeleportLocation == "Volcano Sacrifice" then
            local volcano = workspace.Map and workspace.Map.Landmarks and workspace.Map.Landmarks:FindFirstChild("Volcano")
            if volcano and volcano:FindFirstChild("Functional") and volcano.Functional:FindFirstChild("Sacrifice") 
               and volcano.Functional.Sacrifice:FindFirstChild("Fuse") and volcano.Functional.Sacrifice.Fuse:FindFirstChild("Wedge") then
                destination = volcano.Functional.Sacrifice.Fuse.Wedge.Position + Vector3.new(0, 5, 0)
                locationFound = true
            end
            
        elseif SelectedTeleportLocation == "Stronghold" then
            local stronghold = workspace.Map and workspace.Map.Landmarks and workspace.Map.Landmarks:FindFirstChild("Stronghold")
            if stronghold and stronghold:FindFirstChild("Functional") and stronghold.Functional:FindFirstChild("Sign") then
                destination = stronghold.Functional.Sign.Position + Vector3.new(0, 5, 0)
                locationFound = true
            end
            
        elseif SelectedTeleportLocation == "Fairy House" then
            local fairyHouse = workspace.Map and workspace.Map.Landmarks and workspace.Map.Landmarks:FindFirstChild("Fairy House")
            if fairyHouse and fairyHouse:FindFirstChild("Fairy") and fairyHouse.Fairy:FindFirstChild("HumanoidRootPart") then
                destination = fairyHouse.Fairy.HumanoidRootPart.Position + Vector3.new(0, 5, 0)
                locationFound = true
            end
            
        elseif SelectedTeleportLocation == "Tool Workshop" then
            local toolWorkshop = workspace.Map and workspace.Map.Landmarks and workspace.Map.Landmarks:FindFirstChild("ToolWorkshop")
            if toolWorkshop and toolWorkshop:FindFirstChild("Main") then
                destination = toolWorkshop.Main.Position + Vector3.new(0, 5, 0)
                locationFound = true
            end
        end
        
        if locationFound and destination then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(destination)
            ApocLibrary:Notify({
                Title = "Teleported!",
                Content = "Successfully teleported to " .. SelectedTeleportLocation,
                Duration = 3,
                Image = 4483362458,
            })
        else
            ApocLibrary:Notify({
                Title = "Location Not Found",
                Content = "The location '" .. SelectedTeleportLocation .. "' has not loaded yet. Try revealing the map first!",
                Duration = 6.5,
                Image = 4483362458,
            })
        end
    end
})

-- Auto Trap Follow Player
PlayerTab:CreateLabel("🪤 Auto Trap Follow Player:")
PlayerTab:CreateLabel("Select a target player and enable to make all bear traps follow them.")

_G.TrapTargetDropdownRef = PlayerTab:CreateDropdown({
    Name = "Target Player",
    Options = GetPlayerNames(),
    CurrentOption = {"None"},
    Flag = "Trap_TargetPlayer",
    Callback = function(options)
        TrapControl.TargetPlayer = options[1]
    end
})

PlayerTab:CreateToggle({
    Name = "Enable Auto Trap",
    CurrentValue = false,
    Flag = "Trap_AutoTrapEnabled",
    Callback = function(v)
        TrapControl.AutoTrapEnabled = v
        
        if v then
        else
            CleanupTraps()
        end
    end
})

PlayerTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        local newOptions = GetPlayerNames()
        _G.TrapTargetDropdownRef:Refresh(newOptions)
    end
})

-- Combat GUI Controls
CombatTab:CreateToggle({
    Name = "Enable Auto Attack",
    CurrentValue = false,
    Flag = "Combat_KillAura",
    Callback = function(v)
        CombatControl.KillAuraEnabled = v
        
        if v then
        else
        end
    end
})

CombatTab:CreateDropdown({
    Name = "Weapon Type",
    Options = {
        "General Axe",
        "Spear", 
        "Morningstar",
        "Ice Sword",
        "Infernal Sword",
        "Scythe",
        "Vampire Scythe",
        "Laser Cannon",
        "Laser Sword",
        "Poison Spear",
        "Trident",
        "Flamethrower",
        "Katana",
        "Obsidiron Hammer"
    },
    CurrentOption = {"General Axe"},
    Flag = "Combat_WeaponType",
    Callback = function(options)
        CombatControl.WeaponType = options[1]

        if CombatControl.TeammateKillAuraEnabled and CombatControl.WeaponType ~= "Flamethrower" then
            CombatControl.TeammateKillAuraEnabled = false
            if CombatControl.TeammateToggle then
                CombatControl.TeammateToggle:Set(false)
            end
            ApocLibrary:Notify({
                Title = "Teammate Aura Disabled",
                Content = "Teammate kill aura only works while Flamethrower is selected.",
                Duration = 4,
                Image = 4483362458
            })
        end
    end
})

CombatTab:CreateDropdown({
    Name = "Target Type",
    Options = {"All", "Animal", "Cultist"},
    CurrentOption = {"All"},
    Flag = "Combat_TargetType",
    Callback = function(options)
        CombatControl.TargetType = options[1]
    end
})

CombatTab:CreateToggle({
    Name = "Teleport Above Target",
    CurrentValue = false,
    Flag = "Combat_TeleportAboveTarget",
    Callback = function(v)
        CombatControl.TeleportAboveTarget = v
    end
})

CombatTab:CreateSlider({
    Name = "Teleport Height",
    Range = {5, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 10,
    Flag = "Combat_TeleportHeight",
    Callback = function(val)
        CombatControl.TeleportHeight = val
    end
})

CombatTab:CreateToggle({
    Name = "Ultra Kill",
    CurrentValue = false,
    Flag = "Combat_UltraKill",
    Callback = function(v)
        CombatControl.UltraKillEnabled = v
    end
})

-- Teammate Kill Aura (Premium Feature) - Placed after Ultra Kill
if isTeammateAuraWhitelisted then
    CombatControl.TeammateToggle = CombatTab:CreateToggle({
        Name = "Teammates Kill aura (Flamethrower Required)",
        CurrentValue = false,
        Flag = "Combat_TeammateKillAura",
        Callback = function(v)
            if v then
                if CombatControl.WeaponType ~= "Flamethrower" then
                    CombatControl.TeammateKillAuraEnabled = false
                    if CombatControl.TeammateToggle then
                        CombatControl.TeammateToggle:Set(false)
                    end
                    ApocLibrary:Notify({
                        Title = "Flamethrower Required",
                        Content = "Set the weapon type to Flamethrower before enabling teammate kill aura.",
                        Duration = 4,
                        Image = 4483362458
                    })
                    return
                end
                CombatControl.LastTeammateAuraAttack = 0
            end

            CombatControl.TeammateKillAuraEnabled = v
        end
    })

    CombatControl.TeammateDropdown = CombatTab:CreateDropdown({
        Name = "Teammate Target",
        Options = GetPlayerNames(true, false),
        CurrentOption = {CombatControl.TeammateTarget},
        Flag = "Combat_TeammateTarget",
        Callback = function(options)
            local selection = options and options[1]
            if not selection or selection == "" then
                selection = "All Players"
            end
            CombatControl.TeammateTarget = selection
        end
    })

    local function RefreshTeammateDropdownOptions()
        local options = GetPlayerNames(true, false)
        if CombatControl.TeammateDropdown then
            CombatControl.TeammateDropdown:Refresh(options)

            local current = CombatControl.TeammateTarget or "All Players"
            if not table.find(options, current) then
                current = "All Players"
                CombatControl.TeammateTarget = current
            end

            if CombatControl.TeammateDropdown.Set then
                CombatControl.TeammateDropdown:Set(current)
            end
        end
    end

    RefreshTeammateDropdownOptions()

    Players.PlayerAdded:Connect(function()
        RefreshTeammateDropdownOptions()
    end)

    Players.PlayerRemoving:Connect(function(player)
        if player and CombatControl.TeammateTarget == player.Name then
            CombatControl.TeammateTarget = "All Players"
            if CombatControl.TeammateDropdown and CombatControl.TeammateDropdown.Set then
                CombatControl.TeammateDropdown:Set("All Players")
            end
        end
        RefreshTeammateDropdownOptions()
    end)
else
    CombatControl.TeammateKillAuraEnabled = false
    CombatControl.TeammateToggle = nil
    CombatControl.TeammateDropdown = nil
end

CombatTab:CreateSlider({
    Name = "Attack Range",
    Range = {5, 150}, -- Increased max range to 1000 as requested
    Increment = 5,
    Suffix = " meters",
    CurrentValue = CombatControl.AuraRange,
    Flag = "Combat_AuraRange",
    Callback = function(val)
        CombatControl.AuraRange = val
    end
})

-- Auto Bear Trap Aura
CombatTab:CreateLabel("🪤 Auto Bear Trap Aura:")
CombatTab:CreateLabel("Automatically use bear traps to kill animals or cultists within range.")

CombatTab:CreateDropdown({
    Name = "Trap Aura Target",
    Options = {"All", "Animal", "Cultist"},
    CurrentOption = {"All"},
    Flag = "Combat_TrapAuraTarget",
    Callback = function(options)
        TrapControl.TrapAuraTarget = options[1]
    end
})

CombatTab:CreateSlider({
    Name = "Trap Aura Range",
    Range = {10, 500},
    Increment = 10,
    CurrentValue = 500,
    Flag = "Combat_TrapAuraRange",
    Callback = function(v)
        TrapControl.TrapAuraRange = v
    end
})

CombatTab:CreateToggle({
    Name = "Enable Trap Aura",
    CurrentValue = false,
    Flag = "Combat_TrapAuraEnabled",
    Callback = function(v)
        TrapControl.TrapAuraEnabled = v
        
        if v then
            -- Notify user
            local targetText = TrapControl.TrapAuraTarget == "All" and "all entities" or TrapControl.TrapAuraTarget .. "s"
            ApocLibrary:Notify({
                Title = "Trap Aura Enabled",
                Content = "Bear traps will now target " .. targetText .. " within " .. TrapControl.TrapAuraRange .. " studs",
                Duration = 3,
                Image = 4483362458
            })
        else
            CleanupTraps()
        end
    end
})

-- Burn Enemies (Lava Attack)
CombatTab:CreateLabel("🔥 Burn KillAura:")

-- Check current biome and display warning if not Volcanic
do
    local currentBiome = Workspace:GetAttribute("Biome") or "Unknown"
    if currentBiome ~= "Volcanic" then
        CombatTab:CreateLabel("⚠️ This Kill aura not available in the current Biome, Only Volcanic!")
    end
end

CombatTab:CreateDropdown({
    Name = "Burn Target Type",
    Options = {"All", "Animal", "Cultist"},
    CurrentOption = {"All"},
    Flag = "Combat_BurnTarget",
    Callback = function(options)
        CombatControl.BurnTarget = options[1]
    end
})

CombatTab:CreateSlider({
    Name = "Burn Range",
    Range = {10, 500},
    Increment = 10,
    CurrentValue = 500,
    Flag = "Combat_BurnRange",
    Callback = function(v)
        CombatControl.BurnRange = v
    end
})

CombatTab:CreateToggle({
    Name = "Enable Burn Enemies",
    CurrentValue = false,
    Flag = "Combat_BurnEnemiesEnabled",
    Callback = function(v)
        CombatControl.BurnEnemiesEnabled = v
        
        if v then
            -- Initialize FireParts
            InitializeFireParts()
            
            -- Notify user about status
            local firePartCount = #CombatControl.ActiveFireParts
            local targetText = CombatControl.BurnTarget == "All" and "all entities" or CombatControl.BurnTarget .. "s"
            
            if firePartCount > 0 then
                ApocLibrary:Notify({
                    Title = "Burn Enemies Enabled",
                    Content = "Found " .. firePartCount .. " FireParts. Will burn " .. targetText .. " within " .. CombatControl.BurnRange .. " studs",
                    Duration = 4,
                    Image = 4483362458
                })
            else
                ApocLibrary:Notify({
                    Title = "No FireParts Found",
                    Content = "No lava FireParts detected. Make sure you're on Volcanic biome!",
                    Duration = 4,
                    Image = 4483362458
                })
            end
        else
            -- Restore FireParts to original state
            RestoreFireParts()
        end
    end
})

do
    -- API authentication (HWID-locked premium keys only)
    local apiUrl = "https://api.toastyhub.fun/api"
    local HttpService = game:GetService("HttpService")
    
    -- Get HWID for API validation
    local function getHWID()
        local success1, hwid1 = pcall(function()
            if gethwid then
                return gethwid()
            end
        end)
        if success1 and hwid1 and hwid1 ~= "" then
            return hwid1
        end
        
        local success2, hwid2 = pcall(function()
            local execName = getexecutorname and getexecutorname() or "Unknown"
            local clientId = game:GetService("RbxAnalyticsService"):GetClientId()
            return execName .. "_" .. clientId
        end)
        if success2 and hwid2 and hwid2 ~= "" then
            return hwid2
        end
        
        local success3, hwid3 = pcall(function()
            return game:GetService("RbxAnalyticsService"):GetClientId()
        end)
        if success3 and hwid3 and hwid3 ~= "" then
            return hwid3
        end
        
        return "FALLBACK_" .. tostring(LocalPlayer.UserId)
    end
    
    -- Load saved key from file (ONLY Premium API keys)
    local function loadSavedKey()
        -- Only check Premium API key file (NOT Lootlabs ad keys)
        if readfile and isfile and isfile("toastyxdd_api_key.txt") then
            local success, savedKey = pcall(function()
                return readfile("toastyxdd_api_key.txt")
            end)
            if success and savedKey and savedKey ~= "" then
                return savedKey
            end
        end
        
        return nil
    end
    
    -- Validate key via API backend (HWID locked, Premium keys only)
    local function validateKeyAPI(keyToValidate)
        if not keyToValidate or keyToValidate == "" then
            return false, nil
        end
        
        local hwid = getHWID()
        
        local success, response = pcall(function()
            local data = HttpService:JSONEncode({
                key = keyToValidate,
                hwid = hwid
            })
            
            local result = request({
                Url = apiUrl .. "/validate",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = data
            })
            
            return HttpService:JSONDecode(result.Body)
        end)
        
        if success and response then
            if response.success and response.data and response.data.valid then
                -- Check keyType: only "premium" keys unlock Teammate Kill Aura (NOT "ad" keys)
                local keyType = response.data.keyType
                if keyType == "ad" then
                    return false, "ad_key"
                end
                return true, keyType
            elseif response.data and response.data.message then
                return false, nil
            end
        end
        
        return false, nil
    end

    -- Try to authenticate with saved key
    local isTeammateAuraWhitelisted = false
    
    local savedKey = loadSavedKey()
    if savedKey then
        local isValid, keyType = validateKeyAPI(savedKey)
        
        if isValid then
            isTeammateAuraWhitelisted = true
            isPremium = true -- Set global premium status
        elseif keyType == "ad_key" then
            -- Lootlabs ad key detected - don't unlock premium features
            isTeammateAuraWhitelisted = false
            isPremium = false
        end
    end
end

CombatTab:CreateToggle({
    Name = "Instant Reload",
    CurrentValue = false,
    Flag = "Combat_InstantReload",
    Callback = function(v)
        CombatControl.InstantReloadEnabled = v
        if v then
            initializeFirearmModification()
        else
            updateAllFirearms() -- Restore original values when disabled
        end
    end
})

CombatTab:CreateSlider({
    Name = "Reload Time",
    Range = {0, 1.5},
    Increment = 0.1,
    Suffix = " sec",
    CurrentValue = CombatControl.ReloadTime,
    Flag = "Combat_ReloadTime",
    Callback = function(val)
        CombatControl.ReloadTime = val
        if CombatControl.InstantReloadEnabled then
            updateAllFirearms()
        end
    end
})

CombatTab:CreateToggle({
    Name = "Firerate",
    CurrentValue = false,
    Flag = "Combat_FireRate",
    Callback = function(v)
        CombatControl.FireRateEnabled = v
        if v then
            initializeFirearmModification()
        else
            updateAllFirearms() -- Restore original values when disabled
        end
    end
})

CombatTab:CreateSlider({
    Name = "Firerate Speed",
    Range = {0.05, 0.5},
    Increment = 0.01,
    Suffix = " sec",
    CurrentValue = CombatControl.FireRate,
    Flag = "Combat_FireRateSpeed",
    Callback = function(val)
        CombatControl.FireRate = val
        if CombatControl.FireRateEnabled then
            updateAllFirearms()
        end
    end
})

-- Trees GUI Controls (COMPLETELY SEPARATE)
TreesTab:CreateToggle({
    Name = "Enable Auto Tree Chopping",
    CurrentValue = false,
    Flag = "Trees_ChoppingAura",
    Callback = function(v)
        TreesControl.ChoppingAuraEnabled = v
        if not v and not TreesControl.UltraChoppingEnabled then
            ClearTargets(false)
        end
    end
})

TreesTab:CreateToggle({
    Name = "Ultra Tree Chopping",
    CurrentValue = false,
    Flag = "Trees_UltraChopping",
    Callback = function(v)
        TreesControl.UltraChoppingEnabled = v
        if not v and not TreesControl.ChoppingAuraEnabled then
            ClearTargets(false)
        end
    end
})

TreesTab:CreateSlider({
    Name = "Chopping Range",
    Range = {5, 150},
    Increment = 5,
    Suffix = " meters",
    CurrentValue = TreesControl.ChoppingRange,
    Flag = "Trees_ChoppingRange",
    Callback = function(val)
        TreesControl.ChoppingRange = val
    end
})

TreesTab:CreateDropdown({
    Name = "Target Tree Type",
    Options = CreateTranslatedOptions({"Every tree", "Small Tree", "Snowy Small Tree", "TreeBig1", "TreeBig2", "TreeBig3"}),
    CurrentOption = {GetDisplayText(TreesControl.TargetType)},
    Flag = "Trees_TargetType",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                TreesControl.TargetType = english
                ClearTargets(false)
                break
            end
        end
    end
})

TreesTab:CreateSlider({
    Name = "Ultra Chop Tree Count",
    Range = {1, 100},
    Increment = 1,
    Suffix = " trees",
    CurrentValue = TreesControl.UltraChopCount,
    Flag = "Trees_UltraCount",
    Callback = function(val)
        TreesControl.UltraChopCount = val
    end
})

TreesTab:CreateToggle({
    Name = "🧊 Auto Damage Ice Blocks",
    CurrentValue = false,
    Flag = "Trees_IceBlockDamage",
    Callback = function(v)
        TreesControl.IceBlockDamageEnabled = v
        if not v then
            -- Clean up ice block GUIs when disabled
            CleanupGUIs(false, true)
            -- Clear batch and pool
            TreesControl.IceBlockBatch = {}
            TreesControl.IceBlockPool = {}
        end
    end
})

-- Meteors GUI Controls (COMPLETELY SEPARATE)
MeteorsTab:CreateToggle({
    Name = "Enable Auto Meteor Mining",
    CurrentValue = false,
    Flag = "Meteors_MiningAura",
    Callback = function(v)
        MeteorsControl.MiningAuraEnabled = v
        if not v and not MeteorsControl.UltraMiningEnabled then
            ClearTargets(true)
        end
    end
})

MeteorsTab:CreateLabel("Shard Transporter")

MeteorsTab:CreateToggle({
    Name = "Ultra Meteor Mining",
    CurrentValue = false,
    Flag = "Meteors_UltraMining",
    Callback = function(v)
        MeteorsControl.UltraMiningEnabled = v
        if not v and not MeteorsControl.MiningAuraEnabled then
            ClearTargets(true)
        end
    end
})

MeteorsTab:CreateSlider({
    Name = "Meteor Mining Range",
    Range = {5, 150},
    Increment = 5,
    Suffix = " meters",
    CurrentValue = MeteorsControl.MiningRange,
    Flag = "Meteors_MiningRange",
    Callback = function(val)
        MeteorsControl.MiningRange = val
    end
})

MeteorsTab:CreateDropdown({
    Name = "Target Meteor Type",
    Options = CreateTranslatedOptions({"All Meteor", "Meteor Node", "Obsidiron Node"}),
    CurrentOption = {GetDisplayText(MeteorsControl.TargetType)},
    Flag = "Meteors_TargetType",
    Callback = function(options)
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                MeteorsControl.TargetType = english
                ClearTargets(true)
                break
            end
        end
    end
})

MeteorsTab:CreateSlider({
    Name = "Ultra Mine Count",
    Range = {1, 100},
    Increment = 1,
    Suffix = " nodes",
    CurrentValue = MeteorsControl.UltraMineCount,
    Flag = "Meteors_UltraCount",
    Callback = function(val)
        MeteorsControl.UltraMineCount = val
    end
})

MeteorsTab:CreateLabel("Shard Transporter")

MeteorsTab:CreateToggle({
    Name = "Enable Shard Transporter",
    CurrentValue = false,
    Flag = "Meteors_ShardTransport",
    Callback = function(v)
        MeteorShardControl.TeleportShardsEnabled = v
        if v then
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                MeteorShardControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            MeteorShardControl.TeleportedItems = {}
            MeteorShardControl.SavedPlayerPosition = nil
        end
    end
})

MeteorsTab:CreateDropdown({
    Name = "Transport To:",
    Options = CreateTranslatedOptions(DropdownOptions.Destinations.Common),
    CurrentOption = {GetDisplayText(DropdownOptions.Destinations.Common[1])},
    Flag = "Meteors_ShardDestination",
    Callback = function(options)
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                MeteorShardControl.TeleportDestination = english
                break
            end
        end
    end
})

MeteorsTab:CreateSlider({
    Name = "Teleport Height",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = MeteorShardControl.TeleportHeight,
    Flag = "Meteors_ShardHeight",
    Callback = function(val)
        MeteorShardControl.TeleportHeight = val
    end
})

MeteorsTab:CreateSlider({
    Name = "Transport Wait Time",
    Range = {0, 5},
    Increment = 0.1,
    Suffix = " seconds",
    CurrentValue = MeteorShardControl.TeleportCooldown,
    Flag = "Meteors_ShardCooldown",
    Callback = function(val)
        MeteorShardControl.TeleportCooldown = val
    end
})

MeteorsTab:CreateDropdown({
    Name = "Shard Type",
    Options = CreateTranslatedOptions(DropdownOptions.MeteorShards),
    CurrentOption = {GetDisplayText(DropdownOptions.MeteorShards[1])},
    Flag = "Meteors_ShardType",
    Callback = function(options)
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                MeteorShardControl.ShardItemType = english
                break
            end
        end
    end
})

LostChildrenControl.ToggleState.PrepareObsidiron = MeteorsTab:CreateToggle({
    Name = "Prepare Obsidiron Ingot",
    CurrentValue = false,
    Flag = "Meteors_PrepareObsidiron",
    Callback = function(v)
        if v then
            if not LostChildrenControl.ToggleState.ObsidironActive then
                PrepareObsidironIngots()
            end
        else
            LostChildrenControl.ToggleState.ObsidironActive = false
        end
    end
})

-- Campfire GUI Controls

CampfireTab:CreateDropdown({
    Name = "Transport To:",
    Options = CreateTranslatedOptions(DropdownOptions.Destinations.Campfire),
    CurrentOption = {GetDisplayText(DropdownOptions.Destinations.Campfire[1])},
    Flag = "Campfire_Destination",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                CampfireControl.TeleportDestination = english
                break
            end
        end
    end
})

CampfireTab:CreateSlider({
    Name = "Teleport Height",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 35,
    Flag = "Campfire_TeleportHeight",
    Callback = function(v)
        CampfireControl.TeleportHeight = v
    end
})

CampfireTab:CreateToggle({
    Name = "Smart Auto Refill (By %)",
    CurrentValue = false,
    Flag = "Campfire_AutoRefill",
    Callback = function(v)
        CampfireControl.AutoRefillEnabled = v
        -- Disable continuous refill if smart refill is enabled
        if v and CampfireControl.ContinuousRefillEnabled then
            CampfireControl.ContinuousRefillEnabled = false
        end
        -- Save current player position when refill is enabled
        if v then
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                CampfireControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            CampfireControl.SavedPlayerPosition = nil
        end
    end
})

CampfireTab:CreateToggle({
    Name = "Continuous Refill (Always)",
    CurrentValue = false,
    Flag = "Campfire_ContinuousRefill",
    Callback = function(v)
        CampfireControl.ContinuousRefillEnabled = v
        -- Enable auto refill if continuous is enabled, disable smart mode
        if v then
            CampfireControl.AutoRefillEnabled = true
            -- Save current player position when continuous refill is enabled
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                CampfireControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            CampfireControl.AutoRefillEnabled = false
            CampfireControl.SavedPlayerPosition = nil
        end
    end
})

CampfireTab:CreateSlider({
    Name = "Refill Wait Time",
    Range = {0, 2},
    Increment = 0.1,
    Suffix = " seconds",
    CurrentValue = CampfireControl.RefillCheckCooldown,
    Flag = "Campfire_RefillCooldown",
    Callback = function(val)
        CampfireControl.RefillCheckCooldown = val
    end
})

CampfireTab:CreateSlider({
    Name = "Refill Percentage",
    Range = {5, 95},
    Increment = 5,
    Suffix = "%",
    CurrentValue = CampfireControl.RefillPercentage,
    Flag = "Campfire_RefillPercentage",
    Callback = function(val)
        CampfireControl.RefillPercentage = val
    end
})

CampfireTab:CreateDropdown({
    Name = "Refill Item Type",
    Options = CreateTranslatedOptions({"All", "Log", "Coal", "Biofuel", "Fuel Canister", "Oil Barrel"}),
    CurrentOption = {GetDisplayText("All")},
    Flag = "Campfire_RefillType",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                CampfireControl.RefillItemType = english
                break
            end
        end
    end
})

CampfireTab:CreateLabel("🚀 Uses advanced teleportation system")
CampfireTab:CreateLabel("🎯 35 meters up, 5 meters back for perfect drop")


-- Crafting GUI Controls

CraftingTab:CreateDropdown({
    Name = "Transport To:",
    Options = CreateTranslatedOptions({"Scrapper", "Player", "Sack"}),
    CurrentOption = {GetDisplayText("Scrapper")},
    Flag = "Crafting_Destination",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                CraftingControl.TeleportDestination = english
                break
            end
        end
    end
})

CraftingTab:CreateSlider({
    Name = "Teleport Height",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 35,
    Flag = "Crafting_TeleportHeight",
    Callback = function(v)
        CraftingControl.TeleportHeight = v
    end
})

CraftingTab:CreateSlider({
    Name = "Teleport Cooldown",
    Range = {0, 2},
    Increment = 0.1,
    Suffix = " seconds",
    CurrentValue = 15,
    Flag = "Crafting_TeleportCooldown",
    Callback = function(v)
        CraftingControl.TeleportCooldown = v
    end
})

CraftingTab:CreateParagraph({
    Title = "💡 Tip:",
    Content = "Use Transport To: Player if you encounter issues with the scrapper"
})


CraftingTab:CreateToggle({
    Name = "🔩 Produce Scrap",
    CurrentValue = false,
    Flag = "Crafting_ProduceScrap",
    Callback = function(v)
        CraftingControl.ProduceScrapEnabled = v
        -- Disable other production modes if scrap is enabled
        if v then
            CraftingControl.ProduceWoodEnabled = false
            CraftingControl.ProduceCultistGemEnabled = false
            -- Save current player position when scrap production is enabled
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                CraftingControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            CraftingControl.TeleportedItems = {}
            CraftingControl.SavedPlayerPosition = nil
        end
    end
})

CraftingTab:CreateDropdown({
    Name = "Scrap Item Type",
    Options = DropdownOptions.ScrapItems,
    CurrentOption = {DropdownOptions.ScrapItems[1]},
    Flag = "Crafting_ScrapType",
    Callback = function(options)
        CraftingControl.ScrapItemType = options[1]
    end
})

CraftingTab:CreateToggle({
    Name = "🪵 Produce Wood (⚠️ Use only one option)",
    CurrentValue = false,
    Flag = "Crafting_ProduceWood",
    Callback = function(v)
        CraftingControl.ProduceWoodEnabled = v
        -- Disable other production modes if wood is enabled
        if v then
            CraftingControl.ProduceScrapEnabled = false
            CraftingControl.ProduceCultistGemEnabled = false
            -- Save current player position when wood production is enabled
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                CraftingControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            CraftingControl.TeleportedItems = {}
            CraftingControl.SavedPlayerPosition = nil
        end
    end
})

CraftingTab:CreateDropdown({
    Name = "Wood Item Type",
    Options = {"All", "Log"},
    CurrentOption = {"All"},
    Flag = "Crafting_WoodType",
    Callback = function(options)
        CraftingControl.WoodItemType = options[1]
    end
})

CraftingTab:CreateToggle({
    Name = "💎 Produce Cultist Gem (⚠️ Use only one option)",
    CurrentValue = false,
    Flag = "Crafting_ProduceCultistGem",
    Callback = function(v)
        CraftingControl.ProduceCultistGemEnabled = v
        -- Disable other production modes if cultist gem is enabled
        if v then
            CraftingControl.ProduceScrapEnabled = false
            CraftingControl.ProduceWoodEnabled = false
            -- Save current player position when cultist gem production is enabled
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                CraftingControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            CraftingControl.TeleportedItems = {}
            CraftingControl.SavedPlayerPosition = nil
        end
    end
})

CraftingTab:CreateDropdown({
    Name = "Cultist Gem Item Type",
    Options = {"All", "Cultist Gem"},
    CurrentOption = {"All"},
    Flag = "Crafting_CultistGemType",
    Callback = function(options)
        CraftingControl.CultistGemItemType = options[1]
    end
})

CraftingTab:CreateToggle({
    Name = "🌲 Produce Forest Gem (⚠️ Use only one option)",
    CurrentValue = false,
    Flag = "Crafting_ProduceForestGem",
    Callback = function(v)
        CraftingControl.ProduceForestGemEnabled = v
        if v then
            CraftingControl.ProduceScrapEnabled = false
            CraftingControl.ProduceWoodEnabled = false
            CraftingControl.ProduceCultistGemEnabled = false
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                CraftingControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            CraftingControl.TeleportedItems = {}
            CraftingControl.SavedPlayerPosition = nil
        end
    end
})

CraftingTab:CreateDropdown({
    Name = "Forest Gem Item Type",
    Options = {"All", "Gem of the Forest", "Gem of the Forest Fragment"},
    CurrentOption = {"All"},
    Flag = "Crafting_ForestGemType",
    Callback = function(options)
        CraftingControl.ForestGemItemType = options[1]
    end
})

-- Food GUI Controls
FoodTab:CreateToggle({
    Name = "Enable Food Transporter",
    CurrentValue = false,
    Flag = "Food_TeleportEnabled",
    Callback = function(v)
        FoodControl.TeleportFoodEnabled = v
        -- Save current player position when teleporter is enabled
        if v then
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                FoodControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            FoodControl.TeleportedItems = {}
            FoodControl.SavedPlayerPosition = nil
        end
    end
})

FoodTab:CreateDropdown({
    Name = "Transport To:",
    Options = CreateTranslatedOptions(DropdownOptions.Destinations.Common),
    CurrentOption = {GetDisplayText(DropdownOptions.Destinations.Common[1])},
    Flag = "Food_Destination",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                FoodControl.TeleportDestination = english
                break
            end
        end
    end
})

FoodTab:CreateSlider({
    Name = "Teleport Height",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 35,
    Flag = "Food_TeleportHeight",
    Callback = function(v)
        FoodControl.TeleportHeight = v
    end
})

FoodTab:CreateSlider({
    Name = "Transport Wait Time",
    Range = {0, 5},
    Increment = 0.1,
    Suffix = " seconds",
    CurrentValue = FoodControl.TeleportCooldown,
    Flag = "Food_TeleportCooldown",
    Callback = function(val)
        FoodControl.TeleportCooldown = val
    end
})

FoodTab:CreateDropdown({
    Name = "Food Type",
    Options = CreateTranslatedOptions(DropdownOptions.FoodItems),
    CurrentOption = {GetDisplayText(DropdownOptions.FoodItems[1])},
    Flag = "Food_ItemType",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        
        -- Direct mapping for Cooked Food since translation might be broken
        if selectedDisplay == "Cooked Food" or selectedDisplay:find("Cooked") then
            FoodControl.FoodItemType = "Cooked Food"
        else
            -- Try translation system for other options
            FoodControl.FoodItemType = selectedDisplay -- Default to direct assignment
            for english, display in pairs(DisplayTranslations) do
                if display == selectedDisplay then
                    FoodControl.FoodItemType = english
                    break
                end
            end
        end
    end
})

FoodTab:CreateToggle({
    Name = "🍲 Auto Cook Pot (Stew Maker)",
    CurrentValue = false,
    Flag = "Food_AutoCookPot",
    Callback = function(v)
        FoodControl.AutoCookPotEnabled = v
        if v then
            -- Check if Crock Pot exists
            local structures = Workspace:FindFirstChild("Structures")
            local crockPot = structures and structures:FindFirstChild("Crock Pot")
            
            if not crockPot then
                ApocLibrary:Notify({
                    Title = "Auto Cook Pot",
                    Content = "Please place a Crock Pot first!",
                    Image = 4483362748
                })
                FoodControl.AutoCookPotEnabled = false
                return
            end
            
            -- Reset state when enabling
            FoodControl.CookPotState = {
                IsCooking = false,
                WasCooking = false,
                LastCheck = 0,
                CheckInterval = 3,
                ProcessedStews = {},
            }
            
            -- Spawn both threads
            print("🚀 Starting Auto Cook Pot threads...")
            FoodControl.CookPotState.StewThread = task.spawn(AutoCookPot_StewCollector)
            FoodControl.CookPotState.IngredientThread = task.spawn(AutoCookPot_IngredientAdder)
            
            ApocLibrary:Notify({
                Title = "Auto Cook Pot",
                Content = "Auto cooking enabled! 2 threads watching pot.",
                Image = 4483362748
            })
        else
            print("🛑 Stopping Auto Cook Pot threads...")
            ApocLibrary:Notify({
                Title = "Auto Cook Pot",
                Content = "Auto cooking disabled.",
                Image = 4483362748
            })
        end
    end
})

FoodTab:CreateSection("👨‍🍳 Chef Stove Auto Cooking (Premium Only)")

FoodTab:CreateToggle({
    Name = "🍳 Auto Chef Stove (Multi-Stove)",
    CurrentValue = false,
    Flag = "Food_ChefStoveEnabled",
    Callback = function(v)
        -- Premium check
        if not isPremium then
            ApocLibrary:Notify({
                Title = "Premium Feature 🔒",
                Content = "Chef Stove Auto Cooking requires a Premium Key!\nVisit our website to get one.",
                Image = 4483362748,
                Duration = 5
            })
            FoodControl.ChefStoveEnabled = false
            return
        end
        
        FoodControl.ChefStoveEnabled = v
        if v then
            local stoves = DetectChefStoves()
            
            if #stoves == 0 then
                ApocLibrary:Notify({
                    Title = "Chef Stove",
                    Content = "No Chef Stoves found! Please place at least one.",
                    Image = 4483362748
                })
                FoodControl.ChefStoveEnabled = false
                return
            end
            
            FoodControl.ChefStoveState = {
                DetectedStoves = stoves,
                ProcessedDishes = {},
                TotalDishesCooked = 0,
            }
            
            FoodControl.ChefStoveState.DishThread = task.spawn(ChefStove_DishCollector)
            FoodControl.ChefStoveState.CookingThread = task.spawn(ChefStove_CookingManager)
            
            ApocLibrary:Notify({
                Title = "Chef Stove",
                Content = string.format("Auto cooking enabled!\nDetected %d stove(s)\nRecipe: %s", #stoves, FoodControl.ChefStoveRecipe),
                Image = 4483362748,
                Duration = 4
            })
        else
            ApocLibrary:Notify({
                Title = "Chef Stove",
                Content = string.format("Auto cooking disabled.\nTotal dishes cooked: %d", FoodControl.ChefStoveState.TotalDishesCooked),
                Image = 4483362748
            })
        end
    end
})

FoodTab:CreateDropdown({
    Name = "Recipe Selection",
    Options = {"Seafood Chowder", "Steak Dinner", "Pumpkin Soup", "BBQ Ribs", "Carrot Cake", "Jar o' Jelly"},
    CurrentOption = {"Seafood Chowder"},
    Flag = "Food_ChefRecipe",
    Callback = function(options)
        FoodControl.ChefStoveRecipe = options[1]
    end
})

FoodTab:CreateDropdown({
    Name = "Dish Destination",
    Options = {"Player", "Campfire"},
    CurrentOption = {"Player"},
    Flag = "Food_ChefDestination",
    Callback = function(options)
        FoodControl.ChefStoveDestination = options[1]
    end
})

-- Animal Pelts GUI Controls
AnimalPeltsTab:CreateToggle({
    Name = "Enable Animal Pelts Transporter",
    CurrentValue = false,
    Flag = "AnimalPelts_TeleportEnabled",
    Callback = function(v)
        AnimalPeltsControl.TeleportPeltsEnabled = v
        -- Save current player position when teleporter is enabled
        if v then
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                AnimalPeltsControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            AnimalPeltsControl.TeleportedItems = {}
            AnimalPeltsControl.SavedPlayerPosition = nil
        end
    end
})

AnimalPeltsTab:CreateDropdown({
    Name = "Transport To:",
    Options = CreateTranslatedOptions(DropdownOptions.Destinations.Common),
    CurrentOption = {GetDisplayText(DropdownOptions.Destinations.Common[1])},
    Flag = "AnimalPelts_Destination",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                AnimalPeltsControl.TeleportDestination = english
                break
            end
        end
    end
})

AnimalPeltsTab:CreateSlider({
    Name = "Teleport Height",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 35,
    Flag = "AnimalPelts_TeleportHeight",
    Callback = function(v)
        AnimalPeltsControl.TeleportHeight = v
    end
})

AnimalPeltsTab:CreateSlider({
    Name = "Transport Wait Time",
    Range = {0, 5},
    Increment = 0.1,
    Suffix = " seconds",
    CurrentValue = AnimalPeltsControl.TeleportCooldown,
    Flag = "AnimalPelts_TeleportCooldown",
    Callback = function(val)
        AnimalPeltsControl.TeleportCooldown = val
    end
})

AnimalPeltsTab:CreateDropdown({
    Name = "Animal Pelt Type",
    Options = CreateTranslatedOptions(DropdownOptions.AnimalPelts),
    CurrentOption = {GetDisplayText(DropdownOptions.AnimalPelts[1])},
    Flag = "AnimalPelts_ItemType",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                AnimalPeltsControl.PeltItemType = english
                break
            end
        end
    end
})

AnimalPeltsTab:CreateDropdown({
    Name = "Target Animal",
    Options = {"Bunny", "Wolf", "Alpha Wolf", "Bear", "Polar Bear", "Mammoth", "Hellephant"},
    CurrentOption = {AnimalPeltsControl.Taming.SelectedAnimal},
    Flag = "AnimalPelts_TamingAnimal",
    Callback = function(options)
        if options and options[1] then
            AnimalPeltsControl.Taming.SelectedAnimal = options[1]
        end
    end
})

AnimalPeltsControl.Taming.ToggleHandle = AnimalPeltsTab:CreateToggle({
    Name = "Tame Close Animal",
    CurrentValue = false,
    Flag = "AnimalPelts_TameClosest",
    Callback = function(state)
        if state then
            TamingUtility("automation", "start")
        else
            TamingUtility("automation", "stop")
        end
    end
})

-- Healing GUI Controls
HealingTab:CreateToggle({
    Name = "Enable Healing Items Transporter",
    CurrentValue = false,
    Flag = "Healing_TeleportEnabled",
    Callback = function(v)
        HealingControl.TeleportHealingEnabled = v
        -- Save current player position when teleporter is enabled
        if v then
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                HealingControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            HealingControl.TeleportedItems = {}
            HealingControl.SavedPlayerPosition = nil
        end
    end
})

HealingTab:CreateDropdown({
    Name = "Transport To:",
    Options = CreateTranslatedOptions(DropdownOptions.Destinations.Common),
    CurrentOption = {GetDisplayText(DropdownOptions.Destinations.Common[1])},
    Flag = "Healing_Destination",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                HealingControl.TeleportDestination = english
                break
            end
        end
    end
})

HealingTab:CreateSlider({
    Name = "Teleport Height",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 35,
    Flag = "Healing_TeleportHeight",
    Callback = function(v)
        HealingControl.TeleportHeight = v
    end
})

HealingTab:CreateSlider({
    Name = "Transport Wait Time",
    Range = {0, 5},
    Increment = 0.1,
    Suffix = " seconds",
    CurrentValue = HealingControl.TeleportCooldown,
    Flag = "Healing_TeleportCooldown",
    Callback = function(val)
        HealingControl.TeleportCooldown = val
    end
})

HealingTab:CreateDropdown({
    Name = "Healing Item Type",
    Options = CreateTranslatedOptions(DropdownOptions.HealingItems),
    CurrentOption = {GetDisplayText(DropdownOptions.HealingItems[1])},
    Flag = "Healing_ItemType",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                HealingControl.HealingItemType = english
                break
            end
        end
    end
})

-- Auto Safe Place Section
local AutoSafePlaceControl = {
    IsActive = false,
    HealthThreshold = 25,
    TeleportLocation = "MainFire",
    HealthCheckThread = nil
}

local function teleportToSafePlace()
    local player = game.Players.LocalPlayer
    if not (player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then
        return
    end
    
    local destination
    if AutoSafePlaceControl.TeleportLocation == "MainFire" then
        local campfire = workspace.Map and workspace.Map.Campground and workspace.Map.Campground.MainFire
        if campfire and campfire:FindFirstChild("Center") then
            destination = campfire.Center.Position + Vector3.new(0, 5, 0)
        end
    elseif AutoSafePlaceControl.TeleportLocation == "Underground" then
        local baseplate = workspace.Map and workspace.Map:FindFirstChild("Baseplate")
        if baseplate then
            destination = baseplate.Position + Vector3.new(0, 3, 0)
        end
    end
    
    if destination then
        player.Character.HumanoidRootPart.CFrame = CFrame.new(destination)
    end
end

local function startHealthMonitoring()
    if AutoSafePlaceControl.HealthCheckThread then
        return
    end
    
    AutoSafePlaceControl.HealthCheckThread = task.spawn(function()
        while AutoSafePlaceControl.IsActive do
            local player = game.Players.LocalPlayer
            if player and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid and humanoid.Health <= AutoSafePlaceControl.HealthThreshold then
                    teleportToSafePlace()
                    task.wait(2) -- Wait 2 seconds before checking again to prevent spam teleporting
                end
            end
            task.wait(0.5) -- Check health every 0.5 seconds
        end
    end)
end

local function stopHealthMonitoring()
    if AutoSafePlaceControl.HealthCheckThread then
        task.cancel(AutoSafePlaceControl.HealthCheckThread)
        AutoSafePlaceControl.HealthCheckThread = nil
    end
end

HealingTab:CreateToggle({
    Name = "Auto Safe Place",
    CurrentValue = false,
    Flag = "Healing_AutoSafePlace",
    Callback = function(v)
        AutoSafePlaceControl.IsActive = v
        if v then
            startHealthMonitoring()
        else
            stopHealthMonitoring()
        end
    end
})

HealingTab:CreateSlider({
    Name = "Health Threshold",
    Range = {1, 100},
    Increment = 1,
    Suffix = " HP",
    CurrentValue = AutoSafePlaceControl.HealthThreshold,
    Flag = "Healing_HealthThreshold",
    Callback = function(val)
        AutoSafePlaceControl.HealthThreshold = val
    end
})

HealingTab:CreateDropdown({
    Name = "Teleport Location",
    Options = {"MainFire", "Underground"},
    CurrentOption = {"MainFire"},
    Flag = "Healing_TeleportLocation",
    Callback = function(options)
        AutoSafePlaceControl.TeleportLocation = options[1]
    end
})

-- ========== REVIVAL SYSTEM CONTROLS ==========

-- Initialize bodies list
RefreshAvailableBodies()

_G.RevivalDropdownRef = HealingTab:CreateDropdown({
    Name = "💀 Available Bodies",
    Options = HealingControl.AvailableBodies,
    CurrentOption = {"None"},
    Flag = "Revival_SelectedBody",
    Callback = function(options)
        HealingControl.SelectedBody = options[1]
    end
})

HealingTab:CreateButton({
    Name = "🔄 Refresh Bodies List",
    Callback = function()
        RefreshAvailableBodies()
        -- Update dropdown options using global reference
        if _G.RevivalDropdownRef then
            _G.RevivalDropdownRef:Refresh(HealingControl.AvailableBodies)
        end
        if #HealingControl.AvailableBodies > 0 then
            HealingControl.SelectedBody = HealingControl.AvailableBodies[1]
        else
            HealingControl.SelectedBody = "None"
        end
    end
})

HealingTab:CreateButton({
    Name = "⚡ Revive Selected Player",
    Callback = function()
        ReviveSelectedPlayer()
    end
})

-- ========== AMMO TELEPORTER CONTROLS ==========

AmmoTab:CreateToggle({
    Name = "🔫 Enable Ammo Transporter",
    CurrentValue = false,
    Flag = "Ammo_EnableTeleport",
    Callback = function(v)
        AmmoControl.TeleportAmmoEnabled = v
        -- Save current player position when teleporter is enabled
        if v then
            local player = game.Players.LocalPlayer
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                AmmoControl.SavedPlayerPosition = player.Character.HumanoidRootPart.CFrame
            end
        else
            AmmoControl.TeleportedItems = {}
            AmmoControl.SavedPlayerPosition = nil
        end
    end
})

AmmoTab:CreateSlider({
    Name = "Teleport Height",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 35,
    Flag = "Ammo_TeleportHeight",
    Callback = function(v)
        AmmoControl.TeleportHeight = v
    end
})

AmmoTab:CreateSlider({
    Name = "Transport Wait Time",
    Range = {0, 5},
    Increment = 0.1,
    Suffix = " seconds",
    CurrentValue = AmmoControl.TeleportCooldown,
    Flag = "Ammo_TeleportCooldown",
    Callback = function(val)
        AmmoControl.TeleportCooldown = val
    end
})

AmmoTab:CreateDropdown({
    Name = "Ammo Type",
    Options = CreateTranslatedOptions(DropdownOptions.AmmoItems),
    CurrentOption = {GetDisplayText(DropdownOptions.AmmoItems[1])},
    Flag = "Ammo_ItemType",
    Callback = function(options)
        -- Convert display selection back to English for code logic
        local selectedDisplay = options[1]
        for english, display in pairs(DisplayTranslations) do
            if display == selectedDisplay then
                AmmoControl.AmmoItemType = english
                break
            end
        end
    end
})

-- Weapon Controls
AmmoTab:CreateToggle({
    Name = "⚔️ Enable Weapon Transporter",
    CurrentValue = false,
    Flag = "Weapon_EnableTeleport",
    Callback = function(v)
        AmmoControl.TeleportWeaponEnabled = v
        if not v then
            AmmoControl.TeleportedWeapons = {}
        end
    end
})

AmmoTab:CreateDropdown({
    Name = "Weapon Type",
    Options = AmmoControl.WeaponTypes,
    CurrentOption = {AmmoControl.WeaponTypes[1]},
    Flag = "Weapon_ItemType",
    Callback = function(options)
        AmmoControl.WeaponItemType = options[1]
    end
})

-- Armor Controls
AmmoTab:CreateToggle({
    Name = "🛡️ Enable Armor Transporter",
    CurrentValue = false,
    Flag = "Armor_EnableTeleport",
    Callback = function(v)
        AmmoControl.TeleportArmorEnabled = v
        if not v then
            AmmoControl.TeleportedArmor = {}
        end
    end
})

AmmoTab:CreateDropdown({
    Name = "Armor Type",
    Options = AmmoControl.ArmorTypes,
    CurrentOption = {AmmoControl.ArmorTypes[1]},
    Flag = "Armor_ItemType",
    Callback = function(options)
        AmmoControl.ArmorItemType = options[1]
    end
})

-- Create dropdowns for each chest type
for _, chestType in pairs(ChestTypes) do
    ChestDropdowns[chestType] = ChestsTab:CreateDropdown({
        Name = chestType,
        Options = {"None"},
        CurrentOption = {"None"},
        Flag = "ChestSelector_" .. chestType:gsub(" ", "_"), -- Create unique flag for each dropdown
        Callback = function(options)
            TeleportToSelectedChestByType(chestType, options[1])
        end
    })
end

-- Manual refresh button for all chest dropdowns
ChestsTab:CreateButton({
    Name = "🔄 Update All Chest Lists",
    Callback = function()
        UpdateAllChestDropdowns()
    end
})

-- Auto loot chests button
ChestsTab:CreateButton({
    Name = "🏴‍☠️ Auto Loot Chests",
    Callback = function()
        ChestControl.AutoLootEnabled = true
        task.spawn(AutoLootChests)
    end
})

--============================================================================--
--      [[ ITEM BRING TAB CONTROLS (UNIFIED ITEM TRANSPORTATION) ]]
--============================================================================--

-- Unified Item Bringing Function
function UpdateUnifiedItemBring()
    if not UnifiedBringControl.Enabled then return end
    
    local currentTime = tick()
    if currentTime - UnifiedBringControl.LastBringCheck < UnifiedBringControl.BringCooldown then return end
    UnifiedBringControl.LastBringCheck = currentTime
    
    local player = LocalPlayer
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local itemsFolder = WorkspaceItems
    if not itemsFolder then return end
    
    local destPos = player.Character.HumanoidRootPart.Position
    if UnifiedBringControl.Destination == "Campfire" then
        local campfire = WorkspaceMap and WorkspaceMap.Campground and WorkspaceMap.Campground.MainFire
        if campfire and campfire:FindFirstChild("Center") then
            destPos = campfire.Center.Position
        end
    end
    
    -- Helper to check if item matches any selected category
    local function tryBringItem(item)
        if UnifiedBringControl.TeleportedItems[item] then return false end
        local itemName = item.Name
        
        -- Check Refill Items
        for _, selected in ipairs(UnifiedBringControl.SelectedRefillItems) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        -- Check Scrap Items
        for _, selected in ipairs(UnifiedBringControl.SelectedScrapItems) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        -- Check Gems
        for _, selected in ipairs(UnifiedBringControl.SelectedGems) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        -- Check Food
        for _, selected in ipairs(UnifiedBringControl.SelectedFood) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        -- Check Weapons
        for _, selected in ipairs(UnifiedBringControl.SelectedWeapons) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        -- Check Armor
        for _, selected in ipairs(UnifiedBringControl.SelectedArmor) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        -- Check Ammo
        for _, selected in ipairs(UnifiedBringControl.SelectedAmmo) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        -- Check Healing
        for _, selected in ipairs(UnifiedBringControl.SelectedHealing) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        -- Check Pelts
        for _, selected in ipairs(UnifiedBringControl.SelectedPelts) do
            if itemName == selected then
                local success = UltimateItemTransporter(item, UnifiedBringControl.Destination, UnifiedBringControl.TeleportedItems, UnifiedBringControl.BringCooldown, nil, UnifiedBringControl.Height)
                if success then
                    UnifiedBringControl.TeleportedItems[item] = currentTime
                    return true
                end
            end
        end
        
        return false
    end
    
    -- Process all items in workspace
    for _, item in pairs(itemsFolder:GetChildren()) do
        if not UnifiedBringControl.Enabled then break end
        tryBringItem(item)
    end
    
    -- Clean up old teleported items
    local validItems = {}
    for item, timestamp in pairs(UnifiedBringControl.TeleportedItems) do
        if item.Parent and (currentTime - timestamp) < 120 then
            validItems[item] = timestamp
        end
    end
    UnifiedBringControl.TeleportedItems = validItems
end

-- Master Toggle
ItemBringTab:CreateToggle({
    Name = "🎁 Enable Item Bringing",
    CurrentValue = false,
    Flag = "ItemBring_Enabled",
    Callback = function(v)
        UnifiedBringControl.Enabled = v
        if v then
            UnifiedBringControl.TeleportedItems = {}
            if not UnifiedBringControl.Connection then
                UnifiedBringControl.Connection = RunService.Heartbeat:Connect(UpdateUnifiedItemBring)
            end
        else
            if UnifiedBringControl.Connection then
                UnifiedBringControl.Connection:Disconnect()
                UnifiedBringControl.Connection = nil
            end
            UnifiedBringControl.TeleportedItems = {}
        end
    end
})

-- Destination Dropdown
ItemBringTab:CreateDropdown({
    Name = "Transport To:",
    Options = {"Player", "Campfire"},
    CurrentOption = {"Player"},
    Flag = "ItemBring_Destination",
    Callback = function(options)
        UnifiedBringControl.Destination = options[1]
    end
})

-- Height Slider
ItemBringTab:CreateSlider({
    Name = "Teleport Height",
    Range = {0, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 35,
    Flag = "ItemBring_Height",
    Callback = function(v)
        UnifiedBringControl.Height = v
    end
})

-- Refill Items Dropdown
ItemBringTab:CreateDropdown({
    Name = "🔥 Refill Items",
    Options = DropdownOptions.RefillItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Refill",
    Callback = function(options)
        UnifiedBringControl.SelectedRefillItems = options
    end
})

-- Scrap Items Dropdown
ItemBringTab:CreateDropdown({
    Name = "🔩 Scrap Items",
    Options = DropdownOptions.ScrapItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Scrap",
    Callback = function(options)
        UnifiedBringControl.SelectedScrapItems = options
    end
})

-- Gems Dropdown
ItemBringTab:CreateDropdown({
    Name = "💎 Gems & Shards",
    Options = DropdownOptions.GemItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Gems",
    Callback = function(options)
        UnifiedBringControl.SelectedGems = options
    end
})

-- Food Items Dropdown
ItemBringTab:CreateDropdown({
    Name = "🍖 Food Items",
    Options = DropdownOptions.FoodItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Food",
    Callback = function(options)
        UnifiedBringControl.SelectedFood = options
    end
})

-- Weapons Dropdown
ItemBringTab:CreateDropdown({
    Name = "⚔️ Weapons",
    Options = DropdownOptions.WeaponItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Weapons",
    Callback = function(options)
        UnifiedBringControl.SelectedWeapons = options
    end
})

-- Armor Dropdown
ItemBringTab:CreateDropdown({
    Name = "🛡️ Armor",
    Options = DropdownOptions.ArmorItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Armor",
    Callback = function(options)
        UnifiedBringControl.SelectedArmor = options
    end
})

-- Ammo Dropdown
ItemBringTab:CreateDropdown({
    Name = "🔫 Ammo",
    Options = DropdownOptions.AmmoItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Ammo",
    Callback = function(options)
        UnifiedBringControl.SelectedAmmo = options
    end
})

-- Healing Items Dropdown
ItemBringTab:CreateDropdown({
    Name = "💊 Healing Items",
    Options = DropdownOptions.HealingItems,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Healing",
    Callback = function(options)
        UnifiedBringControl.SelectedHealing = options
    end
})

-- Animal Pelts Dropdown
ItemBringTab:CreateDropdown({
    Name = "🦊 Animal Pelts",
    Options = DropdownOptions.AnimalPelts,
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "ItemBring_Pelts",
    Callback = function(options)
        UnifiedBringControl.SelectedPelts = options
    end
})

-- ========== ESP GUI CONTROLS (ELEGANT & MODERN) ==========

-- Master ESP Toggle
ESPTab:CreateToggle({
    Name = "🔍 Enable ESP",
    CurrentValue = false,
    Flag = "ESP_Master",
    Callback = function(Value)
        ESPControl.Enabled = Value
        if not Value then
            ClearAllESP()
        else
            UpdateAllESP()
        end
    end
})

-- Individual Color Pickers for Each Category
ESPTab:CreateColorPicker({
    Name = "🍖 Food Color",
    Color = ESPControl.Colors.Food,
    Flag = "ESP_FoodColor",
    Callback = function(Value)
        ESPControl.Colors.Food = Value
        -- Update existing food ESP colors
        for _, espData in pairs(ESPControl.ESPObjects) do
            if espData.Billboard and espData.Billboard:FindFirstChild("Frame") and string.find(espData.Billboard.Frame.TextLabel.Text, "🍖") then
                local frame = espData.Billboard.Frame
                if frame:FindFirstChild("UIStroke") then
                    frame.UIStroke.Color = Value
                end
                if frame:FindFirstChild("TextLabel") then
                    frame.TextLabel.TextColor3 = Value
                end
            end
        end
    end
})

ESPTab:CreateColorPicker({
    Name = "🦊 Animal Pelts Color",
    Color = ESPControl.Colors.AnimalPelts,
    Flag = "ESP_AnimalPeltsColor",
    Callback = function(Value)
        ESPControl.Colors.AnimalPelts = Value
        -- Update existing animal pelts ESP colors
        for _, espData in pairs(ESPControl.ESPObjects) do
            if espData.Billboard and espData.Billboard:FindFirstChild("Frame") and string.find(espData.Billboard.Frame.TextLabel.Text, "🦊") then
                local frame = espData.Billboard.Frame
                if frame:FindFirstChild("UIStroke") then
                    frame.UIStroke.Color = Value
                end
                if frame:FindFirstChild("TextLabel") then
                    frame.TextLabel.TextColor3 = Value
                end
            end
        end
    end
})

ESPTab:CreateColorPicker({
    Name = "💊 Healing Color",
    Color = ESPControl.Colors.Healing,
    Flag = "ESP_HealingColor",
    Callback = function(Value)
        ESPControl.Colors.Healing = Value
        -- Update existing healing ESP colors
        for _, espData in pairs(ESPControl.ESPObjects) do
            if espData.Billboard and espData.Billboard:FindFirstChild("Frame") and string.find(espData.Billboard.Frame.TextLabel.Text, "💊") then
                local frame = espData.Billboard.Frame
                if frame:FindFirstChild("UIStroke") then
                    frame.UIStroke.Color = Value
                end
                if frame:FindFirstChild("TextLabel") then
                    frame.TextLabel.TextColor3 = Value
                end
            end
        end
    end
})

ESPTab:CreateColorPicker({
    Name = "🔫 Ammo Color",
    Color = ESPControl.Colors.Ammo,
    Flag = "ESP_AmmoColor",
    Callback = function(Value)
        ESPControl.Colors.Ammo = Value
        -- Update existing ammo ESP colors
        for _, espData in pairs(ESPControl.ESPObjects) do
            if espData.Billboard and espData.Billboard:FindFirstChild("Frame") and string.find(espData.Billboard.Frame.TextLabel.Text, "🔫") then
                local frame = espData.Billboard.Frame
                if frame:FindFirstChild("UIStroke") then
                    frame.UIStroke.Color = Value
                end
                if frame:FindFirstChild("TextLabel") then
                    frame.TextLabel.TextColor3 = Value
                end
            end
        end
    end
})

ESPTab:CreateColorPicker({
    Name = "👹 Entities Color",
    Color = ESPControl.Colors.Entities,
    Flag = "ESP_EntitiesColor",
    Callback = function(Value)
        ESPControl.Colors.Entities = Value
        -- Update existing entities ESP colors
        for _, espData in pairs(ESPControl.ESPObjects) do
            if espData.Billboard and espData.Billboard:FindFirstChild("Frame") and string.find(espData.Billboard.Frame.TextLabel.Text, "👹") then
                local frame = espData.Billboard.Frame
                if frame:FindFirstChild("UIStroke") then
                    frame.UIStroke.Color = Value
                end
                if frame:FindFirstChild("TextLabel") then
                    frame.TextLabel.TextColor3 = Value
                end
            end
        end
    end
})

ESPTab:CreateColorPicker({
    Name = "📦 Chests Color",
    Color = ESPControl.Colors.Chests,
    Flag = "ESP_ChestsColor",
    Callback = function(Value)
        ESPControl.Colors.Chests = Value
        -- Update existing chests ESP colors
        for _, espData in pairs(ESPControl.ESPObjects) do
            if espData.Billboard and espData.Billboard:FindFirstChild("Frame") and string.find(espData.Billboard.Frame.TextLabel.Text, "📦") then
                local frame = espData.Billboard.Frame
                if frame:FindFirstChild("UIStroke") then
                    frame.UIStroke.Color = Value
                end
                if frame:FindFirstChild("TextLabel") then
                    frame.TextLabel.TextColor3 = Value
                end
            end
        end
    end
})

ESPTab:CreateColorPicker({
    Name = "👤 Players Color",
    Color = ESPControl.Colors.Players,
    Flag = "ESP_PlayersColor",
    Callback = function(Value)
        ESPControl.Colors.Players = Value
        -- Update existing players ESP colors
        for _, espData in pairs(ESPControl.ESPObjects) do
            if espData.Billboard and espData.Billboard:FindFirstChild("Frame") and string.find(espData.Billboard.Frame.TextLabel.Text, "👤") then
                local frame = espData.Billboard.Frame
                if frame:FindFirstChild("UIStroke") then
                    frame.UIStroke.Color = Value
                end
                if frame:FindFirstChild("TextLabel") then
                    frame.TextLabel.TextColor3 = Value
                end
            end
        end
    end
})

-- Category Toggles
ESPTab:CreateToggle({
    Name = "🍖 Food",
    CurrentValue = false,
    Flag = "ESP_Food",
    Callback = function(Value)
        ESPControl.Categories.Food = Value
        if ESPControl.Enabled then
            UpdateESPCategory("Food")
        end
    end
})

ESPTab:CreateToggle({
    Name = "🦊 Animal Pelts",
    CurrentValue = false,
    Flag = "ESP_AnimalPelts",
    Callback = function(Value)
        ESPControl.Categories.AnimalPelts = Value
        if ESPControl.Enabled then
            UpdateESPCategory("AnimalPelts")
        end
    end
})

ESPTab:CreateToggle({
    Name = "💊 Healing Items",
    CurrentValue = false,
    Flag = "ESP_Healing",
    Callback = function(Value)
        ESPControl.Categories.Healing = Value
        if ESPControl.Enabled then
            UpdateESPCategory("Healing")
        end
    end
})

ESPTab:CreateToggle({
    Name = "🔫 Ammo",
    CurrentValue = false,
    Flag = "ESP_Ammo",
    Callback = function(Value)
        ESPControl.Categories.Ammo = Value
        if ESPControl.Enabled then
            UpdateESPCategory("Ammo")
        end
    end
})

ESPTab:CreateToggle({
    Name = "👹 Entities",
    CurrentValue = false,
    Flag = "ESP_Entities",
    Callback = function(Value)
        ESPControl.Categories.Entities = Value
        if ESPControl.Enabled then
            UpdateESPCategory("Entities")
        end
    end
})

ESPTab:CreateToggle({
    Name = "📦 Chests",
    CurrentValue = false,
    Flag = "ESP_Chests",
    Callback = function(Value)
        ESPControl.Categories.Chests = Value
        if ESPControl.Enabled then
            UpdateESPCategory("Chests")
        end
    end
})

ESPTab:CreateToggle({
    Name = "👤 Players",
    CurrentValue = false,
    Flag = "ESP_Players",
    Callback = function(Value)
        ESPControl.Categories.Players = Value
        if ESPControl.Enabled then
            UpdateESPCategory("Players")
        end
    end
})

-- Utility Buttons
ESPTab:CreateButton({
    Name = "🔄 Update All ESP",
    Callback = function()
        if ESPControl.Enabled then
            ClearAllESP()
            UpdateAllESP()
        end
    end
})

ESPTab:CreateButton({
    Name = "🧹 Clear All ESP",
    Callback = function()
        ClearAllESP()
    end
})

-- ========== SKYBASE GUI CONTROLS ==========

SkybaseTab:CreateToggle({
    Name = "🏗️ Show Skybase Interface",
    CurrentValue = false,
    Flag = "Skybase_ShowGui",
    Callback = function(v)
        SkybaseControl.GuiEnabled = v
        if v then
            createSkybaseGui()
        else
            destroySkybaseGui()
        end
    end
})

SkybaseTab:CreateToggle({
    Name = "🍽️ Smart Auto Eating",
    CurrentValue = false,
    Flag = "Skybase_SmartAutoEat",
    Callback = function(v)
        SkybaseControl.SmartAutoEatEnabled = v
    end
})

SkybaseTab:CreateSlider({
    Name = "🎯 Hunger Threshold for Eating",
    Range = {20, 150},
    Increment = 5,
    Suffix = "points",
    CurrentValue = 50,
    Flag = "Skybase_HungerThreshold",
    Callback = function(v)
        SkybaseControl.HungerThreshold = v
    end
})

SkybaseTab:CreateSlider({
    Name = "🔍 Food Search Range",
    Range = {50, 1000},
    Increment = 25,
    Suffix = "studs",
    CurrentValue = 500,
    Flag = "Skybase_FoodSearchRange",
    Callback = function(v)
        SkybaseControl.FoodSearchRange = v
    end
})

SkybaseTab:CreateToggle({
    Name = "⚡ Simple Anti-AFK (Mouse Move + Right Click)",
    CurrentValue = false,
    Flag = "Skybase_AntiAfk",
    Callback = function(v)
        SkybaseControl.AntiAfkEnabled = v
        if v then
            SkybaseControl.LastAfkAction = tick()
        end
    end
})

SkybaseTab:CreateLabel("To get maximum benefit, build a base in the sky")
SkybaseTab:CreateLabel("Then bring crop fields, try to get a large quantity and place them all on the base")
SkybaseTab:CreateLabel("🍎 Enable smart eating feature and set hunger to 100-150 as you prefer")
SkybaseTab:CreateLabel("Then go to your bed and sleep peacefully  ")
SkybaseTab:CreateLabel("❤️ Happy gaming!")

-- Lost Children Controls
LostChildrenControl.Toggle = LostChildrenTab:CreateToggle({
    Name = "Enable Lost Children Rescue",
    CurrentValue = false,
    Flag = "RescueChildrenToggle",
    Callback = function(value)
        if value then
            startRescueProcess()
        else
            stopRescueProcess()
        end
    end
})

LostChildrenControl.Status = LostChildrenTab:CreateLabel("Status: Inactive")

LostChildrenTab:CreateLabel("ℹ️ How it works:")
LostChildrenTab:CreateLabel("• Make sure the fire is at maximum level")
LostChildrenTab:CreateLabel("• Make sure the sack has 4 empty spaces")
LostChildrenTab:CreateLabel("• Don't worry if it starts moving alone, it's searching for them")
LostChildrenTab:CreateLabel("• After collecting all children, it will return to your location")

-- Saplings control state (shared between GUI and Manual planting)
local SaplingsControl = {
    GUI = nil,
    GUIProxy = nil,  -- Separate proxy for GUI planting
    ManualProxy = nil,  -- Separate proxy for Manual planting
    -- Saplings God Mode state
    GodMode = {
        Enabled = false,
        Points = {},
        Visuals = {},
        FreeCamEnabled = false,
        OriginalCameraType = nil,
        OriginalCameraSubject = nil,
        CameraConnection = nil,
        InputConnection = nil,
        RotationConnection = nil,
        MouseButtonConnection = nil,
        MouseButtonEndConnection = nil,
        DrawingEnabled = false,
        TargetSurfaceMode = "Ground Only", -- "Ground Only" or "Any Surface"
        CameraPosition = nil,
        CameraRotation = Vector2.new(0, 0),
        MovementSpeed = 1,
        GUI = nil,
        MouseDown = false,
        LastDrawTime = 0,
        DrawCooldown = 0.05,
        LastMousePosition = nil,
        RightMouseDown = false,
        MobileMode = "camera",
        MobileTouchActive = false,
        LastTouchPosition = nil,
        CurrentTouchPosition = nil,
    }
}

local function getNil(name, class)
    for _, inst in ipairs(getnilinstances()) do
        if inst.ClassName == class and inst.Name == name then
            return inst
        end
    end
end

local function ensureSaplingProxy(controlKey)
    -- controlKey is either "GUIProxy" or "ManualProxy" to prevent conflicts
    -- Always clear the cached proxy to ensure we get a fresh sapling each time
    SaplingsControl[controlKey] = nil

    -- Try to find existing sapling in nil (already removed from workspace)
    local existing = getNil("Sapling", "Model")
    if existing then
        -- Verify it's valid and unused before using
        local isValid = pcall(function() return existing.Parent end)
        if isValid and existing.Parent == nil then
            -- Additional check: make sure it hasn't been used already
            local hasValidParts = existing:FindFirstChild("Handle") or existing:FindFirstChildWhichIsA("BasePart")
            if hasValidParts then
                SaplingsControl[controlKey] = existing
                return existing
            end
        end
    end

    -- Find a new sapling in workspace and remove it
    local itemsFolder = workspace:FindFirstChild("Items")
    if not itemsFolder then
        return nil
    end

    for _, item in ipairs(itemsFolder:GetChildren()) do
        if item:IsA("Model") and item.Name == "Sapling" then
            -- Verify it's valid before using
            local isValid = pcall(function() return item.Parent end)
            if isValid then
                -- Additional check: make sure it has the required parts
                local hasValidParts = item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart")
                if hasValidParts then
                    item.Parent = nil
                    SaplingsControl[controlKey] = item
                    return item
                end
            end
        end
    end

    -- Last resort: try getNil again for any available sapling
    local fallback = getNil("Sapling", "Model")
    if fallback then
        local isValid = pcall(function() return fallback.Parent end)
        if isValid and fallback.Parent == nil then
            local hasValidParts = fallback:FindFirstChild("Handle") or fallback:FindFirstChildWhichIsA("BasePart")
            if hasValidParts then
                SaplingsControl[controlKey] = fallback
                return fallback
            end
        end
    end
    
    return nil
end

-- ========== SAPLINGS GOD MODE FUNCTIONS ==========

-- Composite all God Mode functions into the control table
SaplingsControl.GodMode.createVisual = function(position)
    local part = Instance.new("Part")
    part.Name = "SaplingGodDot"
    part.Size = Vector3.new(2, 2, 2)
    part.Shape = Enum.PartType.Ball
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(0, 255, 0)
    part.Anchored = true
    part.CanCollide = false
    part.CFrame = CFrame.new(position)
    part.Parent = workspace
    
    table.insert(SaplingsControl.GodMode.Visuals, part)
    return part
end

SaplingsControl.GodMode.clearVisuals = function()
    for _, visual in ipairs(SaplingsControl.GodMode.Visuals) do
        if visual and visual.Parent then
            visual:Destroy()
        end
    end
    SaplingsControl.GodMode.Visuals = {}
end

SaplingsControl.GodMode.addPoint = function(position)
    table.insert(SaplingsControl.GodMode.Points, position)
    SaplingsControl.GodMode.createVisual(position)
end

SaplingsControl.GodMode.clearPoints = function()
    SaplingsControl.GodMode.Points = {}
    SaplingsControl.GodMode.clearVisuals()
end

SaplingsControl.GodMode.enableFreeCam = function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local player = Players.LocalPlayer
    local camera = workspace.CurrentCamera
    local character = player.Character
    
    if not character then return end
    
    local godMode = SaplingsControl.GodMode
    if godMode.FreeCamEnabled then return end
    
    -- Save original camera state
    godMode.OriginalCameraType = camera.CameraType
    godMode.OriginalCameraSubject = camera.CameraSubject
    
    -- Set camera to scriptable
    camera.CameraType = Enum.CameraType.Scriptable
    godMode.CameraPosition = camera.CFrame.Position
    godMode.CameraRotation = Vector2.new(0, 0)
    
    -- Anchor character
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.Anchored = true
    end
    
    godMode.FreeCamEnabled = true
    
    -- Track right mouse button state
    godMode.RightMouseDown = false
    
    -- Mouse button tracking
    godMode.MouseButtonConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if not godMode.FreeCamEnabled then return end
        if processed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            godMode.RightMouseDown = true
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        end
    end)
    
    godMode.MouseButtonEndConnection = UserInputService.InputEnded:Connect(function(input)
        if not godMode.FreeCamEnabled then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            godMode.RightMouseDown = false
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end)
    
    -- Camera movement loop
    godMode.CameraConnection = RunService.RenderStepped:Connect(function(dt)
        if not godMode.FreeCamEnabled then return end
        
        local moveVector = Vector3.new(0, 0, 0)
        local speed = 50 * godMode.MovementSpeed
        
        -- WASD movement (support both keyboard and mobile FlyKeys)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or FlyKeys.W then
            moveVector = moveVector + Vector3.new(0, 0, 1)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or FlyKeys.S then
            moveVector = moveVector + Vector3.new(0, 0, -1)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or FlyKeys.A then
            moveVector = moveVector + Vector3.new(-1, 0, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or FlyKeys.D then
            moveVector = moveVector + Vector3.new(1, 0, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or FlyKeys.Space then
            moveVector = moveVector + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or FlyKeys.LeftShift then
            moveVector = moveVector + Vector3.new(0, -1, 0)
        end
        
        -- Apply movement relative to camera orientation
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit
            local cameraCFrame = camera.CFrame
            local moveWorld = (cameraCFrame.RightVector * moveVector.X) + 
                             (cameraCFrame.UpVector * moveVector.Y) + 
                             (cameraCFrame.LookVector * moveVector.Z)
            godMode.CameraPosition = godMode.CameraPosition + (moveWorld * speed * dt)
        end
        
        -- Apply rotation
        local rotX = math.rad(godMode.CameraRotation.X)
        local rotY = math.rad(godMode.CameraRotation.Y)
        
        camera.CFrame = CFrame.new(godMode.CameraPosition) * 
                       CFrame.Angles(0, rotY, 0) * 
                       CFrame.Angles(rotX, 0, 0)
    end)
    
    -- Mouse input for rotation (separate RenderStepped for camera rotation)
    godMode.RotationConnection = RunService.RenderStepped:Connect(function()
        if not godMode.FreeCamEnabled then return end
        
        if godMode.RightMouseDown then
            local delta = UserInputService:GetMouseDelta()
            if delta.Magnitude > 0 then
                godMode.CameraRotation = godMode.CameraRotation + Vector2.new(-delta.Y * 0.4, -delta.X * 0.4)
                godMode.CameraRotation = Vector2.new(
                    math.clamp(godMode.CameraRotation.X, -89, 89),
                    godMode.CameraRotation.Y % 360
                )
            end
        end
    end)
end

SaplingsControl.GodMode.disableFreeCam = function()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local camera = workspace.CurrentCamera
    local character = player.Character
    
    local godMode = SaplingsControl.GodMode
    if not godMode.FreeCamEnabled then return end
    
    -- Restore camera
    if godMode.OriginalCameraType then
        camera.CameraType = godMode.OriginalCameraType
    end
    if godMode.OriginalCameraSubject then
        camera.CameraSubject = godMode.OriginalCameraSubject
    end
    
    -- Restore mouse behavior
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    
    -- Unanchor character
    if character then
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            rootPart.Anchored = false
        end
    end
    
    -- Disconnect connections
    if godMode.CameraConnection then
        godMode.CameraConnection:Disconnect()
        godMode.CameraConnection = nil
    end
    if godMode.InputConnection then
        godMode.InputConnection:Disconnect()
        godMode.InputConnection = nil
    end
    if godMode.RotationConnection then
        godMode.RotationConnection:Disconnect()
        godMode.RotationConnection = nil
    end
    if godMode.MouseButtonConnection then
        godMode.MouseButtonConnection:Disconnect()
        godMode.MouseButtonConnection = nil
    end
    if godMode.MouseButtonEndConnection then
        godMode.MouseButtonEndConnection:Disconnect()
        godMode.MouseButtonEndConnection = nil
    end
    
    godMode.FreeCamEnabled = false
    godMode.RightMouseDown = false
end

SaplingsControl.GodMode.handleDrawing = function()
    local UserInputService = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")
    local camera = workspace.CurrentCamera
    local godMode = SaplingsControl.GodMode
    
    if not godMode.DrawingEnabled then return end
    
    local currentTime = tick()
    if currentTime - godMode.LastDrawTime < godMode.DrawCooldown then return end
    
    -- Get mouse/touch position
    local screenPos
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    
    if isMobile and godMode.CurrentTouchPosition then
        -- For touch, add GUI inset since touch position excludes the top bar
        local guiInset = GuiService:GetGuiInset()
        screenPos = Vector2.new(
            godMode.CurrentTouchPosition.X,
            godMode.CurrentTouchPosition.Y + guiInset.Y
        )
    else
        local mousePos = UserInputService:GetMouseLocation()
        screenPos = Vector2.new(mousePos.X, mousePos.Y)
    end
    
    -- Only draw if mouse/touch has moved
    if godMode.LastMousePosition then
        local distance = (screenPos - godMode.LastMousePosition).Magnitude
        if distance < 5 then return end -- Hasn't moved enough (increased threshold for better spacing)
    end
    
    godMode.LastMousePosition = screenPos
    
    -- Create ray from screen position (no GUI inset needed for touch)
    local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
    
    if godMode.TargetSurfaceMode == "Ground Only" then
        -- Only hit ground
        local ground = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ground")
        if ground then
            raycastParams.FilterDescendantsInstances = {ground}
        else
            return
        end
    else
        -- Hit any surface in Map
        local map = workspace:FindFirstChild("Map")
        if map then
            raycastParams.FilterDescendantsInstances = {map}
        else
            return
        end
    end
    
    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if result then
        SaplingsControl.GodMode.addPoint(result.Position)
        godMode.LastDrawTime = currentTime
    end
end

SaplingsControl.GodMode.plantAllPoints = function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local plantRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestPlantItem")
    local godMode = SaplingsControl.GodMode
    
    if #godMode.Points == 0 then
        return
    end
    
    task.spawn(function()
        -- Get sapling proxy once for all planting
        local saplingProxy = ensureSaplingProxy("GUIProxy")
        if not saplingProxy then
            warn("Unable to locate sapling proxy for planting.")
            if ApocLibrary then
                ApocLibrary:Notify({
                    Title = "Saplings God",
                    Content = "Failed to get sapling proxy!",
                    Duration = 3,
                    Image = 4400697855,
                })
            end
            return
        end
        
        local totalPoints = #godMode.Points
        local planted = 0
        local batchSize = 10
        
        -- Process in batches of 10 like Saplings GUI
        for i = 1, totalPoints, batchSize do
            if not godMode.Enabled then break end
            
            -- Dispatch batch of 10 requests simultaneously
            for j = 0, math.min(batchSize - 1, totalPoints - i) do
                local index = i + j
                local position = godMode.Points[index]
                
                if position then
                    task.spawn(function()
                        if not godMode.Enabled then return end
                        local result = plantRemote:InvokeServer(saplingProxy, position)
                        if result then
                            planted = planted + 1
                        end
                    end)
                end
            end
            
            -- Small wait between batches only
            if i + batchSize <= totalPoints then
                task.wait(0.05)
            end
        end
        
        -- Wait a bit for all spawned tasks to complete
        task.wait(0.3)
        
        -- Clear after planting
        godMode.clearPoints()
        
        if ApocLibrary then
            ApocLibrary:Notify({
                Title = "Saplings God",
                Content = string.format("Successfully planted %d/%d saplings!", planted, totalPoints),
                Duration = 4,
                Image = 4483362458,
            })
        end
        
        -- Cleanup proxy
        if saplingProxy then
            if saplingProxy.Parent then saplingProxy.Parent = nil end
            pcall(function() saplingProxy:Destroy() end)
        end
        SaplingsControl.GUIProxy = nil
    end)
end

-- =================================================

-- Function to create the Saplings GUI directly
local function createSaplingsGUI()
    if SaplingsGUI then return end -- Already created
    
    -- Saplings GUI Variables and Configuration
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    
    -- Get a reference to the map's ground
    local groundPart = workspace:WaitForChild("Map"):WaitForChild("Ground")
    
    -- Configuration
    local CONFIG = {
        SHAPES = {"Square", "Circle", "Star", "Custom Text"},
        DEFAULT_SHAPE = "Square",
        DEFAULT_SIZE = 40, 
        MIN_SIZE = 10,
        MAX_SIZE = 200,
        DEFAULT_SPACING = 8,
        MIN_SPACING = 2,
        MAX_SPACING = 20,
        DEFAULT_HEIGHT_OFFSET = 0.5,
        MIN_HEIGHT_OFFSET = 0,
        MAX_HEIGHT_OFFSET = 50,
        HIGHLIGHT_COLOR = Color3.fromRGB(120, 255, 120)
    }
    
    -- Enhanced UI Theme
    local THEME = {
        COLORS = {
            PRIMARY = Color3.fromRGB(64, 128, 255),
            PRIMARY_HOVER = Color3.fromRGB(74, 138, 255),
            SECONDARY = Color3.fromRGB(45, 45, 50),
            BACKGROUND = Color3.fromRGB(25, 25, 30),
            SURFACE = Color3.fromRGB(35, 35, 40),
            SUCCESS = Color3.fromRGB(76, 175, 80),
            SUCCESS_HOVER = Color3.fromRGB(86, 185, 90),
            WARNING = Color3.fromRGB(255, 152, 0),
            WARNING_HOVER = Color3.fromRGB(255, 162, 20),
            DANGER = Color3.fromRGB(244, 67, 54),
            DANGER_HOVER = Color3.fromRGB(254, 77, 64),
            TEXT = Color3.fromRGB(255, 255, 255),
            TEXT_SECONDARY = Color3.fromRGB(200, 200, 200),
            ACCENT = Color3.fromRGB(156, 39, 176)
        }
    }
    
    -- Script state variables
    local currentShape, currentSize, currentSpacing, currentHeightOffset = CONFIG.DEFAULT_SHAPE, CONFIG.DEFAULT_SIZE, CONFIG.DEFAULT_SPACING, CONFIG.DEFAULT_HEIGHT_OFFSET
    local customText = "TOASTY" -- Default custom text
    local plantLocation = "Campfire" -- Default planting location ("Campfire" or "Player")
    local shapePoints, highlightParts, isPlanting, guiElements = {}, {}, false, {}
    local previewDebounceThread, DEBOUNCE_TIME = nil, 0.2
    
    -- Core functions
    local function getCenterPoint() 
        if plantLocation == "Player" then
            -- Use player position
            return player.Character and player.Character.PrimaryPart.Position or Vector3.zero
        else
            -- Use campfire position (default)
            local fireCenter = workspace.Map and workspace.Map.Campground and workspace.Map.Campground.MainFire and workspace.Map.Campground.MainFire.Center
            if fireCenter then 
                return fireCenter.Position 
            else 
                return player.Character and player.Character.PrimaryPart.Position or Vector3.zero 
            end 
        end
    end
    
    local function clearHighlights() 
        -- Clear tracked highlights
        for _, part in ipairs(highlightParts) do 
            if part and part.Parent then
                part:Destroy() 
            end
        end
        highlightParts = {} 
        
        -- Also clear any remaining PlantingHighlight parts in workspace (safety measure)
        for _, part in pairs(workspace:GetChildren()) do
            if part.Name == "PlantingHighlight" then
                part:Destroy()
            end
        end
    end
    
    local function clearShape() 
        clearHighlights()
        shapePoints = {}
        isPlanting = false  -- Also stop any ongoing planting
        if guiElements.ProgressLabel then 
            guiElements.ProgressLabel.Text = "Progress: N/A" 
        end
    end
    
    local function createHighlight(position, index) 
        local highlight = Instance.new("Part")
        highlight.Name = "PlantingHighlight"
        highlight.Shape = Enum.PartType.Ball
        highlight.Size = Vector3.new(3, 3, 3)
        highlight.Anchored = true
        highlight.CanCollide = false
        highlight.Color = CONFIG.HIGHLIGHT_COLOR
        highlight.Material = Enum.Material.Neon
        highlight.Transparency = 0.6
        highlight.CFrame = CFrame.new(position)
        highlight.Parent = workspace
        
        -- Add to highlights array for proper tracking
        table.insert(highlightParts, highlight)
    end
    
    -- Helper function to convert text to dot pattern
    local function textToPattern(text)
        -- 5x7 dot matrix font patterns for letters
        local patterns = {
            A = {{0,1,1,1,0},{1,0,0,0,1},{1,1,1,1,1},{1,0,0,0,1},{1,0,0,0,1}},
            B = {{1,1,1,1,0},{1,0,0,0,1},{1,1,1,1,0},{1,0,0,0,1},{1,1,1,1,0}},
            C = {{0,1,1,1,0},{1,0,0,0,1},{1,0,0,0,0},{1,0,0,0,1},{0,1,1,1,0}},
            D = {{1,1,1,1,0},{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{1,1,1,1,0}},
            E = {{1,1,1,1,1},{1,0,0,0,0},{1,1,1,1,0},{1,0,0,0,0},{1,1,1,1,1}},
            F = {{1,1,1,1,1},{1,0,0,0,0},{1,1,1,1,0},{1,0,0,0,0},{1,0,0,0,0}},
            G = {{0,1,1,1,0},{1,0,0,0,0},{1,0,1,1,1},{1,0,0,0,1},{0,1,1,1,0}},
            H = {{1,0,0,0,1},{1,0,0,0,1},{1,1,1,1,1},{1,0,0,0,1},{1,0,0,0,1}},
            I = {{1,1,1,1,1},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0},{1,1,1,1,1}},
            J = {{0,0,0,1,1},{0,0,0,0,1},{0,0,0,0,1},{1,0,0,0,1},{0,1,1,1,0}},
            K = {{1,0,0,0,1},{1,0,0,1,0},{1,1,1,0,0},{1,0,0,1,0},{1,0,0,0,1}},
            L = {{1,0,0,0,0},{1,0,0,0,0},{1,0,0,0,0},{1,0,0,0,0},{1,1,1,1,1}},
            M = {{1,0,0,0,1},{1,1,0,1,1},{1,0,1,0,1},{1,0,0,0,1},{1,0,0,0,1}},
            N = {{1,0,0,0,1},{1,1,0,0,1},{1,0,1,0,1},{1,0,0,1,1},{1,0,0,0,1}},
            O = {{0,1,1,1,0},{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{0,1,1,1,0}},
            P = {{1,1,1,1,0},{1,0,0,0,1},{1,1,1,1,0},{1,0,0,0,0},{1,0,0,0,0}},
            Q = {{0,1,1,1,0},{1,0,0,0,1},{1,0,1,0,1},{1,0,0,1,0},{0,1,1,0,1}},
            R = {{1,1,1,1,0},{1,0,0,0,1},{1,1,1,1,0},{1,0,0,1,0},{1,0,0,0,1}},
            S = {{0,1,1,1,1},{1,0,0,0,0},{0,1,1,1,0},{0,0,0,0,1},{1,1,1,1,0}},
            T = {{1,1,1,1,1},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0}},
            U = {{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{0,1,1,1,0}},
            V = {{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0}},
            W = {{1,0,0,0,1},{1,0,0,0,1},{1,0,1,0,1},{1,1,0,1,1},{1,0,0,0,1}},
            X = {{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0},{0,1,0,1,0},{1,0,0,0,1}},
            Y = {{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0}},
            Z = {{1,1,1,1,1},{0,0,0,1,0},{0,0,1,0,0},{0,1,0,0,0},{1,1,1,1,1}},
            [" "] = {{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0}}
        }
        
        local result = {}
        for i = 1, #text do
            local char = text:sub(i, i):upper()
            if patterns[char] then
                table.insert(result, patterns[char])
            end
        end
        return result
    end
    
    local function previewShape(forceUpdate)
        -- Check if any planting is in progress by looking at existing planted points
        local plantedCount = 0
        for _, pointData in ipairs(shapePoints) do
            if pointData.isPlanted then
                plantedCount = plantedCount + 1
            end
        end
        
        -- Clear highlights in these cases:
        -- 1. Force update (from sliders/dropdown) - always clear highlights but preserve planted points data
        -- 2. No planting in progress AND no planted points (safe to clear everything)
        if forceUpdate then
            -- For force updates (slider/dropdown changes), always clear highlights
            clearHighlights()
            if plantedCount == 0 then
                -- If no planting progress, clear everything
                shapePoints = {}
            else
                -- If there's planting progress, preserve shapePoints but clear highlights
            end
        elseif not isPlanting and plantedCount == 0 then
            clearShape()
        elseif isPlanting or plantedCount > 0 then
            return
        end
        
        local centerPoint = getCenterPoint()
        local pointsToCalculate = {}
        
        if currentShape == "Square" then
            local halfWidth = currentSize / 2
            local numPointsPerSide = math.floor((halfWidth * 2) / currentSpacing)
            for i = 0, numPointsPerSide do
                local pos = -halfWidth + (i * currentSpacing)
                table.insert(pointsToCalculate, centerPoint + Vector3.new(pos, 50, halfWidth))
                table.insert(pointsToCalculate, centerPoint + Vector3.new(pos, 50, -halfWidth))
                if i > 0 and i < numPointsPerSide then 
                    table.insert(pointsToCalculate, centerPoint + Vector3.new(halfWidth, 50, pos))
                    table.insert(pointsToCalculate, centerPoint + Vector3.new(-halfWidth, 50, pos)) 
                end
            end
        elseif currentShape == "Circle" then
            local radius = currentSize
            local circumference = 2 * math.pi * radius
            local numPoints = math.floor(circumference / currentSpacing)
            for i = 1, numPoints do 
                local angle = (i / numPoints) * 2 * math.pi
                local x = radius * math.cos(angle)
                local z = radius * math.sin(angle)
                table.insert(pointsToCalculate, centerPoint + Vector3.new(x, 50, z)) 
            end
        elseif currentShape == "Star" then
            local outerRadius = currentSize
            local innerRadius = outerRadius / 2
            local numPoints = 5
            for i = 0, (numPoints * 2) - 1 do 
                local radius = (i % 2 == 0) and outerRadius or innerRadius
                local angle = (i / (numPoints * 2)) * 2 * math.pi
                local x = radius * math.cos(angle - math.pi/2)
                local z = radius * math.sin(angle - math.pi/2)
                table.insert(pointsToCalculate, centerPoint + Vector3.new(x, 50, z)) 
            end
        elseif currentShape == "Custom Text" then
            -- Generate text pattern
            local textPattern = textToPattern(customText)
            if #textPattern > 0 then
                local letterWidth = 5  -- Each letter is 5 dots wide
                local letterHeight = 5 -- Each letter is 5 dots tall
                local totalWidth = (#textPattern * letterWidth + (#textPattern - 1)) * currentSpacing
                local startX = -totalWidth / 2
                
                for letterIndex, letterPattern in ipairs(textPattern) do
                    local letterOffsetX = startX + (letterIndex - 1) * (letterWidth + 1) * currentSpacing
                    
                    for row = 1, letterHeight do
                        for col = 1, letterWidth do
                            if letterPattern[row] and letterPattern[row][col] == 1 then
                                local x = letterOffsetX + (col - 1) * currentSpacing
                                local z = (row - 1) * currentSpacing - (letterHeight * currentSpacing / 2)
                                table.insert(pointsToCalculate, centerPoint + Vector3.new(x, 50, z))
                            end
                        end
                    end
                end
            end
        end
    
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Whitelist
        rayParams.FilterDescendantsInstances = {groundPart}
        
        -- If we didn't clear shapePoints (preserving planted progress), rebuild from scratch
        if forceUpdate and #shapePoints > 0 then
            -- Clear shapePoints and rebuild completely for force updates
            shapePoints = {}
        end
        
        for i, point in ipairs(pointsToCalculate) do
            local result = workspace:Raycast(point, Vector3.new(0, -100, 0), rayParams)
            if result and result.Instance then
                local groundPos = result.Position + Vector3.new(0, currentHeightOffset, 0)
                table.insert(shapePoints, {position = groundPos, status = "Empty", highlightIndex = i})
                createHighlight(groundPos, i)
            end
        end
        
        if guiElements.ProgressLabel then 
            guiElements.ProgressLabel.Text = "Progress: 0 / " .. #shapePoints 
        end
    end
    
    -- Utility functions for enhanced UI
    local function createRoundedFrame(parent, size, position, backgroundColor, cornerRadius)
        local frame = Instance.new("Frame")
        frame.Size = size
        frame.Position = position
        frame.BackgroundColor3 = backgroundColor
        frame.BorderSizePixel = 0
        frame.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, cornerRadius or 8)
        corner.Parent = frame
        
        return frame
    end
    
    local function createButton(parent, size, position, text, backgroundColor, textColor, onClick)
        local button = Instance.new("TextButton")
        button.Size = size
        button.Position = position
        button.BackgroundColor3 = backgroundColor
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = textColor
        button.Font = Enum.Font.GothamBold
        button.TextSize = 10
        button.Parent = parent
        button.Active = true  -- Ensure button is active for click detection
        button.AutoButtonColor = false  -- We'll handle color changes manually
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button
        
        -- Add hover effect
        local originalColor = backgroundColor
        button.MouseEnter:Connect(function()
            local tween = TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.new(
                math.min(1, originalColor.R + 0.1),
                math.min(1, originalColor.G + 0.1), 
                math.min(1, originalColor.B + 0.1)
            )})
            tween:Play()
        end)
        
        button.MouseLeave:Connect(function()
            local tween = TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor})
            tween:Play()
        end)
        
        if onClick then
            button.MouseButton1Click:Connect(onClick)
        end
        
        return button
    end
    
    local function createLabel(parent, size, position, text, textColor, textSize, font)
        local label = Instance.new("TextLabel")
        label.Size = size
        label.Position = position
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = textColor or THEME.COLORS.TEXT
        label.TextSize = textSize or 14
        label.Font = font or Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = parent
        return label
    end
    
    -- Create main GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SaplingPlanterEnhanced"
    screenGui.ResetOnSpawn = false
    
    -- Main container with shadow effect (Mobile-optimized size)
    local shadowFrame = createRoundedFrame(screenGui, UDim2.new(0, 180, 0, 250), UDim2.new(0, 15, 0.5, -125), Color3.fromRGB(0, 0, 0), 12)
    shadowFrame.BackgroundTransparency = 0.7
    
    local mainFrame = createRoundedFrame(screenGui, UDim2.new(0, 170, 0, 335), UDim2.new(0, 10, 0.5, -167), THEME.COLORS.BACKGROUND, 12)
    
    -- Minimize state variables
    local isMinimized = false
    local originalSize = mainFrame.Size
    local minimizedSize = UDim2.new(0, 170, 0, 40)
    
    -- Header with gradient and dragging functionality
    local headerFrame = createRoundedFrame(mainFrame, UDim2.new(1, -20, 0, 35), UDim2.new(0, 10, 0, 8), THEME.COLORS.PRIMARY, 8)
    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.COLORS.PRIMARY),
        ColorSequenceKeypoint.new(1, THEME.COLORS.ACCENT)
    })
    headerGradient.Rotation = 45
    headerGradient.Parent = headerFrame
    
    local titleLabel = createLabel(headerFrame, UDim2.new(1, -60, 1, 0), UDim2.new(0, 15, 0, 0), "🌱 Sapling Planter", THEME.COLORS.TEXT, 14, Enum.Font.GothamBold)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Minimize button
    local minimizeBtn = createButton(headerFrame, UDim2.new(0, 22, 0, 22), UDim2.new(1, -28, 0, 6), "–", THEME.COLORS.SECONDARY, THEME.COLORS.TEXT, nil)
    minimizeBtn.TextSize = 16
    minimizeBtn.Font = Enum.Font.GothamBold
    
    -- Dragging functionality (Mobile and PC compatible)
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    
    headerFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                          input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            shadowFrame.Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset + 5, mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset + 5)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    
    -- Content frame (will be hidden/shown when minimizing)
    local contentFrame = createRoundedFrame(mainFrame, UDim2.new(1, 0, 1, -35), UDim2.new(0, 0, 0, 35), Color3.fromRGB(0, 0, 0), 0)
    contentFrame.BackgroundTransparency = 1
    
    -- Minimize functionality
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        local targetSize = isMinimized and minimizedSize or originalSize
        local targetShadowSize = isMinimized and UDim2.new(0, 180, 0, 50) or UDim2.new(0, 180, 0, 250)
        
        minimizeBtn.Text = isMinimized and "+" or "–"
        contentFrame.Visible = not isMinimized
        
        local tween1 = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize})
        local tween2 = TweenService:Create(shadowFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetShadowSize})
        
        tween1:Play()
        tween2:Play()
    end)
    
    -- Shape selection section
    local shapeSection = createRoundedFrame(contentFrame, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 10), THEME.COLORS.SURFACE, 6)
    local shapeSectionLabel = createLabel(shapeSection, UDim2.new(1, -15, 0, 14), UDim2.new(0, 12, 0, 2), "Shape Configuration", THEME.COLORS.TEXT_SECONDARY, 9, Enum.Font.GothamMedium)
    
    local shapeDropdown = createRoundedFrame(shapeSection, UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 14), THEME.COLORS.SECONDARY, 4)
    local shapeLabel = createLabel(shapeDropdown, UDim2.new(1, -25, 1, 0), UDim2.new(0, 8, 0, 0), "Shape: " .. currentShape, THEME.COLORS.TEXT, 10)
    
    local shapeBtn = Instance.new("TextButton")
    shapeBtn.Size = UDim2.new(1, 0, 1, 0)
    shapeBtn.BackgroundTransparency = 1
    shapeBtn.Text = ""
    shapeBtn.Parent = shapeDropdown
    
    local dropdownIcon = createLabel(shapeDropdown, UDim2.new(0, 15, 1, 0), UDim2.new(1, -18, 0, 0), "▼", THEME.COLORS.TEXT_SECONDARY, 8)
    dropdownIcon.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Create dropdown at screen level with higher ZIndex and ScrollingFrame for better accessibility
    local shapeOptionsContainer = createRoundedFrame(screenGui, UDim2.new(0, 150, 0, 80), UDim2.new(0, 25, 0, 200), THEME.COLORS.SECONDARY, 4)
    shapeOptionsContainer.Visible = false
    shapeOptionsContainer.ClipsDescendants = true
    shapeOptionsContainer.ZIndex = 12
    shapeOptionsContainer.Active = true
    
    -- Add ScrollingFrame inside the container
    local shapeOptionsFrame = Instance.new("ScrollingFrame")
    shapeOptionsFrame.Size = UDim2.new(1, 0, 1, 0)
    shapeOptionsFrame.Position = UDim2.new(0, 0, 0, 0)
    shapeOptionsFrame.BackgroundTransparency = 1
    shapeOptionsFrame.BorderSizePixel = 0
    shapeOptionsFrame.ScrollBarThickness = 4
    shapeOptionsFrame.ScrollBarImageColor3 = THEME.COLORS.PRIMARY
    shapeOptionsFrame.ZIndex = 13
    shapeOptionsFrame.CanvasSize = UDim2.new(0, 0, 0, #CONFIG.SHAPES * 19) -- Dynamic canvas size
    shapeOptionsFrame.Parent = shapeOptionsContainer
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 1)
    listLayout.Parent = shapeOptionsFrame
    
    shapeBtn.MouseButton1Click:Connect(function() 
        shapeOptionsContainer.Visible = not shapeOptionsContainer.Visible
        dropdownIcon.Text = shapeOptionsContainer.Visible and "▲" or "▼"
        
        -- Position dropdown relative to the button
        if shapeOptionsContainer.Visible then
            local buttonPos = shapeDropdown.AbsolutePosition
            local buttonSize = shapeDropdown.AbsoluteSize
            shapeOptionsContainer.Position = UDim2.new(0, buttonPos.X, 0, buttonPos.Y + buttonSize.Y + 5)
        end
    end)
    
    -- Hide dropdown when clicking elsewhere (Mobile and PC compatible)
    local hideDropdownConnection
    hideDropdownConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
            input.UserInputType == Enum.UserInputType.Touch) and not gameProcessed then
            local inputPos
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                inputPos = UserInputService:GetMouseLocation()
            else
                inputPos = input.Position
            end
            
            local framePos = shapeOptionsContainer.AbsolutePosition
            local frameSize = shapeOptionsContainer.AbsoluteSize
            
            if shapeOptionsContainer.Visible then
                -- Check if click was inside the dropdown options
                local clickedInDropdown = (inputPos.X >= framePos.X and inputPos.X <= framePos.X + frameSize.X and
                                         inputPos.Y >= framePos.Y and inputPos.Y <= framePos.Y + frameSize.Y)
                
                -- Check if click was on the dropdown button
                local buttonPos = shapeDropdown.AbsolutePosition
                local buttonSize = shapeDropdown.AbsoluteSize
                local clickedOnButton = (inputPos.X >= buttonPos.X and inputPos.X <= buttonPos.X + buttonSize.X and
                                       inputPos.Y >= buttonPos.Y and inputPos.Y <= buttonPos.Y + buttonSize.Y)
                
                -- Only hide if clicked outside both dropdown and button
                if not clickedInDropdown and not clickedOnButton then
                    shapeOptionsContainer.Visible = false
                    dropdownIcon.Text = "▼"
                end
            end
        end
    end)
    
    for i, shapeName in ipairs(CONFIG.SHAPES) do
        local optionBtn = createButton(shapeOptionsFrame, UDim2.new(1, -12, 0, 18), UDim2.new(0, 4, 0, (i-1) * 19), shapeName, THEME.COLORS.BACKGROUND, THEME.COLORS.TEXT, function()
            currentShape = shapeName
            shapeLabel.Text = "Shape: " .. currentShape
            shapeOptionsContainer.Visible = false
            dropdownIcon.Text = "▼"
            previewShape(true)  -- Force update for shape changes
        end)
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.TextSize = 9
        optionBtn.ZIndex = 15  -- Higher z-index for better click detection
        
        -- Add explicit active area to ensure clicks are detected
        optionBtn.Active = true
        optionBtn.AutoButtonColor = false
        
        -- Add click feedback
        optionBtn.MouseButton1Down:Connect(function()
            optionBtn.BackgroundColor3 = THEME.COLORS.PRIMARY
        end)
        
        optionBtn.MouseButton1Up:Connect(function()
            optionBtn.BackgroundColor3 = THEME.COLORS.BACKGROUND
        end)
    end
    
    -- Custom Text Input Field (visible only when Custom Text shape is selected)
    local customTextSection = createRoundedFrame(contentFrame, UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 52), THEME.COLORS.SURFACE, 6)
    customTextSection.Visible = (currentShape == "Custom Text")
    
    local customTextLabel = createLabel(customTextSection, UDim2.new(1, -15, 0, 14), UDim2.new(0, 12, 0, 2), "Custom Text (letters & spaces only)", THEME.COLORS.TEXT_SECONDARY, 9, Enum.Font.GothamMedium)
    
    local textInputFrame = createRoundedFrame(customTextSection, UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 18), THEME.COLORS.BACKGROUND, 4)
    
    local textInput = Instance.new("TextBox")
    textInput.Size = UDim2.new(1, -10, 1, 0)
    textInput.Position = UDim2.new(0, 5, 0, 0)
    textInput.BackgroundTransparency = 1
    textInput.Text = customText
    textInput.TextColor3 = THEME.COLORS.TEXT
    textInput.Font = Enum.Font.GothamBold
    textInput.TextSize = 10
    textInput.PlaceholderText = "Enter text (e.g., TOASTY)"
    textInput.PlaceholderColor3 = THEME.COLORS.TEXT_SECONDARY
    textInput.ClearTextOnFocus = false
    textInput.TextXAlignment = Enum.TextXAlignment.Left
    textInput.Parent = textInputFrame
    
    textInput.FocusLost:Connect(function()
        local newText = textInput.Text:upper():gsub("[^A-Z ]", "") -- Only allow letters and spaces
        if newText == "" then
            newText = "TOASTY" -- Default if empty
        end
        customText = newText
        textInput.Text = newText
        if currentShape == "Custom Text" then
            previewShape(true)
        end
    end)
    
    -- Update custom text section visibility when shape changes
    local originalShapeBtnClick = shapeBtn.MouseButton1Click
    shapeBtn.MouseButton1Click:Connect(function()
        task.wait(0.1) -- Wait for shape to update
        customTextSection.Visible = (currentShape == "Custom Text")
    end)
    
    for _, optionBtn in ipairs(shapeOptionsFrame:GetChildren()) do
        if optionBtn:IsA("TextButton") then
            local originalClick = optionBtn.MouseButton1Click
            optionBtn.MouseButton1Click:Connect(function()
                task.wait(0.1) -- Wait for shape to update
                customTextSection.Visible = (currentShape == "Custom Text")
            end)
        end
    end
    
    -- Plant Location Dropdown
    local locationSection = createRoundedFrame(contentFrame, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 97), THEME.COLORS.SURFACE, 6)
    local locationSectionLabel = createLabel(locationSection, UDim2.new(1, -15, 0, 14), UDim2.new(0, 12, 0, 2), "Plant Location", THEME.COLORS.TEXT_SECONDARY, 9, Enum.Font.GothamMedium)
    
    local locationDropdown = createRoundedFrame(locationSection, UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 14), THEME.COLORS.SECONDARY, 4)
    local locationLabel = createLabel(locationDropdown, UDim2.new(1, -25, 1, 0), UDim2.new(0, 8, 0, 0), "Location: " .. plantLocation, THEME.COLORS.TEXT, 10)
    
    local locationBtn = Instance.new("TextButton")
    locationBtn.Size = UDim2.new(1, 0, 1, 0)
    locationBtn.BackgroundTransparency = 1
    locationBtn.Text = ""
    locationBtn.Parent = locationDropdown
    
    local locationDropdownIcon = createLabel(locationDropdown, UDim2.new(0, 15, 1, 0), UDim2.new(1, -18, 0, 0), "▼", THEME.COLORS.TEXT_SECONDARY, 8)
    locationDropdownIcon.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Create location dropdown container
    local locationOptionsContainer = createRoundedFrame(screenGui, UDim2.new(0, 150, 0, 40), UDim2.new(0, 25, 0, 300), THEME.COLORS.SECONDARY, 4)
    locationOptionsContainer.Visible = false
    locationOptionsContainer.ClipsDescendants = true
    locationOptionsContainer.ZIndex = 12
    locationOptionsContainer.Active = true
    
    local locationOptionsFrame = Instance.new("Frame")
    locationOptionsFrame.Size = UDim2.new(1, 0, 1, 0)
    locationOptionsFrame.Position = UDim2.new(0, 0, 0, 0)
    locationOptionsFrame.BackgroundTransparency = 1
    locationOptionsFrame.BorderSizePixel = 0
    locationOptionsFrame.Parent = locationOptionsContainer
    
    local locationListLayout = Instance.new("UIListLayout")
    locationListLayout.Padding = UDim.new(0, 1)
    locationListLayout.Parent = locationOptionsFrame
    
    locationBtn.MouseButton1Click:Connect(function()
        locationOptionsContainer.Visible = not locationOptionsContainer.Visible
        locationDropdownIcon.Text = locationOptionsContainer.Visible and "▲" or "▼"
        
        if locationOptionsContainer.Visible then
            local buttonPos = locationDropdown.AbsolutePosition
            local buttonSize = locationDropdown.AbsoluteSize
            locationOptionsContainer.Position = UDim2.new(0, buttonPos.X, 0, buttonPos.Y + buttonSize.Y + 5)
        end
    end)
    
    -- Location options
    local locationOptions = {"Campfire", "Player"}
    for i, locationName in ipairs(locationOptions) do
        local optionBtn = createButton(locationOptionsFrame, UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, (i-1) * 19), locationName, THEME.COLORS.BACKGROUND, THEME.COLORS.TEXT, function()
            plantLocation = locationName
            locationLabel.Text = "Location: " .. plantLocation
            locationOptionsContainer.Visible = false
            locationDropdownIcon.Text = "▼"
            previewShape(true) -- Update preview with new location
        end)
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.TextSize = 9
        optionBtn.ZIndex = 15
        optionBtn.Active = true
        optionBtn.AutoButtonColor = false
        
        optionBtn.MouseButton1Down:Connect(function()
            optionBtn.BackgroundColor3 = THEME.COLORS.PRIMARY
        end)
        
        optionBtn.MouseButton1Up:Connect(function()
            optionBtn.BackgroundColor3 = THEME.COLORS.BACKGROUND
        end)
    end
    
    -- Hide location dropdown when clicking elsewhere
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
            input.UserInputType == Enum.UserInputType.Touch) and not gameProcessed then
            local inputPos
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                inputPos = UserInputService:GetMouseLocation()
            else
                inputPos = input.Position
            end
            
            local framePos = locationOptionsContainer.AbsolutePosition
            local frameSize = locationOptionsContainer.AbsoluteSize
            
            if locationOptionsContainer.Visible then
                local clickedInDropdown = (inputPos.X >= framePos.X and inputPos.X <= framePos.X + frameSize.X and
                                         inputPos.Y >= framePos.Y and inputPos.Y <= framePos.Y + frameSize.Y)
                
                local buttonPos = locationDropdown.AbsolutePosition
                local buttonSize = locationDropdown.AbsoluteSize
                local clickedOnButton = (inputPos.X >= buttonPos.X and inputPos.X <= buttonPos.X + buttonSize.X and
                                       inputPos.Y >= buttonPos.Y and inputPos.Y <= buttonPos.Y + buttonSize.Y)
                
                if not clickedInDropdown and not clickedOnButton then
                    locationOptionsContainer.Visible = false
                    locationDropdownIcon.Text = "▼"
                end
            end
        end
    end)
    
    -- Enhanced slider creation function (Mobile-optimized)
    local function createEnhancedSlider(parent, text, yPos, min, max, default, suffix)
        local sliderFrame = createRoundedFrame(parent, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, yPos), THEME.COLORS.SURFACE, 6)
        
        local label = createLabel(sliderFrame, UDim2.new(1, -15, 0, 12), UDim2.new(0, 8, 0, 2), text, THEME.COLORS.TEXT_SECONDARY, 9, Enum.Font.GothamMedium)
        local valueLabel = createLabel(sliderFrame, UDim2.new(0, 50, 0, 12), UDim2.new(1, -58, 0, 2), default .. (suffix or ""), THEME.COLORS.TEXT, 9, Enum.Font.GothamBold)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        
        local track = createRoundedFrame(sliderFrame, UDim2.new(1, -16, 0, 5), UDim2.new(0, 8, 0, 20), THEME.COLORS.BACKGROUND, 3)
        local progress = createRoundedFrame(track, UDim2.new((default - min) / (max - min), 0, 1, 0), UDim2.new(0, 0, 0, 0), THEME.COLORS.PRIMARY, 3)
        
        local handle = Instance.new("TextButton")
        handle.Size = UDim2.new(0, 12, 0, 12)
        handle.Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6)
        handle.BackgroundColor3 = THEME.COLORS.TEXT
        handle.BorderSizePixel = 0
        handle.Text = ""
        handle.Parent = track
        
        local handleCorner = Instance.new("UICorner")
        handleCorner.CornerRadius = UDim.new(1, 0)
        handleCorner.Parent = handle
        
        local isSliderDragging = false
        
        -- Handle both mouse and touch input for mobile compatibility
        local function startDragging()
            isSliderDragging = true 
            handle.BackgroundColor3 = THEME.COLORS.PRIMARY
        end
        
        local function stopDragging()
            isSliderDragging = false
            handle.BackgroundColor3 = THEME.COLORS.TEXT
        end
        
        -- Mouse events (PC)
        handle.MouseButton1Down:Connect(startDragging)
        
        -- Touch events (Mobile)
        handle.TouchTap:Connect(startDragging)
        
        -- Allow clicking on track to move slider (Mobile-friendly)
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                local trackWidth = track.AbsoluteSize.X
                local trackX = track.AbsolutePosition.X
                local clickX = input.Position.X
                local handleX = math.clamp(clickX - trackX, 0, trackWidth)
                
                local percentage = handleX / trackWidth
                handle.Position = UDim2.new(percentage, -6, 0.5, -6)
                progress.Size = UDim2.new(percentage, 0, 1, 0)
                
                local value = min + (max - min) * percentage
                if suffix == " studs" then
                    value = math.floor(value)
                    valueLabel.Text = value .. suffix
                    if text == "Dimension" then
                        currentSize = value
                    elseif text == "Spacing" then
                        currentSpacing = value
                    end
                else
                    value = math.floor(value * 10) / 10
                    valueLabel.Text = string.format("%.1f", value) .. suffix
                    currentHeightOffset = value
                end
                
                -- Trigger preview update
                if previewDebounceThread then
                    task.cancel(previewDebounceThread)
                end
                previewDebounceThread = task.delay(DEBOUNCE_TIME, function()
                    previewShape(true)
                end)
                
                startDragging()
            end
        end)
        
        -- Universal input end detection
        UserInputService.InputEnded:Connect(function(input) 
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then 
                stopDragging()
            end 
        end)
        
        local updateValue = function(input)
            if not isSliderDragging then return end
            local trackWidth = track.AbsoluteSize.X
            local trackX = track.AbsolutePosition.X
            
            -- Handle both mouse and touch input
            local inputX
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                inputX = input.Position.X
            elseif input.UserInputType == Enum.UserInputType.Touch then
                inputX = input.Position.X
            else
                return
            end
            
            local handleX = math.clamp(inputX - trackX, 0, trackWidth)
            
            local percentage = handleX / trackWidth
            handle.Position = UDim2.new(percentage, -6, 0.5, -6)
            progress.Size = UDim2.new(percentage, 0, 1, 0)
            
            local value = min + (max - min) * percentage
            return value, valueLabel, suffix
        end
        
        return updateValue
    end
    
    -- Create enhanced sliders (Mobile-optimized spacing)
    local updateSize = createEnhancedSlider(contentFrame, "Dimension", 135, CONFIG.MIN_SIZE, CONFIG.MAX_SIZE, CONFIG.DEFAULT_SIZE, " studs")
    local updateSpacing = createEnhancedSlider(contentFrame, "Spacing", 175, CONFIG.MIN_SPACING, CONFIG.MAX_SPACING, CONFIG.DEFAULT_SPACING, " studs") 
    local updateHeight = createEnhancedSlider(contentFrame, "Height Offset", 215, CONFIG.MIN_HEIGHT_OFFSET, CONFIG.MAX_HEIGHT_OFFSET, CONFIG.DEFAULT_HEIGHT_OFFSET, " units")
    
    -- Handle slider updates (Support both mouse and touch)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            local valueChanged = false
            
            local newSize, sizeLabel, sizeSuffix = updateSize(input)
            if newSize and currentSize ~= math.floor(newSize) then
                currentSize = math.floor(newSize)
                sizeLabel.Text = currentSize .. (sizeSuffix or "")
                valueChanged = true
            end
            
            local newSpacing, spacingLabel, spacingSuffix = updateSpacing(input)
            if newSpacing and currentSpacing ~= math.floor(newSpacing) then
                currentSpacing = math.floor(newSpacing)
                spacingLabel.Text = currentSpacing .. (spacingSuffix or "")
                valueChanged = true
            end
            
            local newHeight, heightLabel, heightSuffix = updateHeight(input)
            if newHeight and currentHeightOffset ~= newHeight then
                currentHeightOffset = math.floor(newHeight * 10) / 10
                heightLabel.Text = string.format("%.1f", currentHeightOffset) .. (heightSuffix or "")
                valueChanged = true
            end
            
            if valueChanged then
                if previewDebounceThread then
                    task.cancel(previewDebounceThread)
                end
                previewDebounceThread = task.delay(DEBOUNCE_TIME, function()
                    previewShape(true)  -- Force update for slider changes
                end)
            end
        end
    end)
    
    -- Action buttons section (Mobile-optimized)
    local buttonSection = createRoundedFrame(contentFrame, UDim2.new(1, -20, 0, 50), UDim2.new(0, 10, 0, 255), THEME.COLORS.SURFACE, 6)
    
    local previewBtn = createButton(buttonSection, UDim2.new(0.48, 0, 0, 20), UDim2.new(0, 8, 0, 5), "🔍 Preview", THEME.COLORS.PRIMARY, THEME.COLORS.TEXT, previewShape)
    local clearBtn = createButton(buttonSection, UDim2.new(0.48, 0, 0, 20), UDim2.new(0.52, 0, 0, 5), "🗑️ Clear", THEME.COLORS.DANGER, THEME.COLORS.TEXT, clearShape)
    
    -- Progress display (Mobile-optimized)
    local progressFrame = createRoundedFrame(buttonSection, UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 29), THEME.COLORS.BACKGROUND, 4)
    local progressLabel = createLabel(progressFrame, UDim2.new(1, -12, 1, 0), UDim2.new(0, 12, 0, 0), "Progress: N/A", THEME.COLORS.TEXT, 9, Enum.Font.GothamMedium)
    progressLabel.TextXAlignment = Enum.TextXAlignment.Center
    guiElements.ProgressLabel = progressLabel
    
    -- Plant/Stop buttons (Mobile-optimized)
    local plantBtn = createButton(contentFrame, UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 309), "🌱 Start Planting", THEME.COLORS.SUCCESS, THEME.COLORS.TEXT, nil)
    local stopBtn = createButton(contentFrame, UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 309), "⏹️ Stop Planting", THEME.COLORS.WARNING, THEME.COLORS.TEXT, nil)
    stopBtn.Visible = false
    
    local function setButtons(canPlant) 
        plantBtn.Visible = canPlant
        stopBtn.Visible = not canPlant
        previewBtn.AutoButtonColor = canPlant
        clearBtn.AutoButtonColor = canPlant
    end
    
    stopBtn.MouseButton1Click:Connect(function() 
        isPlanting = false
    end)
    
    -- Planting logic
    plantBtn.MouseButton1Click:Connect(function() 
        if #shapePoints == 0 then 
            warn("Please preview a shape.") 
            return 
        end
        if isPlanting then 
            warn("Already planting.") 
            return 
        end
        
        isPlanting = true
        setButtons(false)
        
        task.spawn(function() 
            local plantRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("RequestPlantItem")
            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            
            if not rootPart then 
                warn("Character not found.")
                isPlanting = false
                setButtons(true)
                return 
            end
            
            local saplingProxy = ensureSaplingProxy("GUIProxy")
            if not saplingProxy then
                warn("Unable to locate sapling proxy for planting.")
                SaplingsControl.GUIProxy = nil
                isPlanting = false
                setButtons(true)
                return
            end

            guiElements.SaplingProxy = saplingProxy

            local plantedCount = 0
            for _, pointData in ipairs(shapePoints) do
                if pointData.status == "Planted" then
                    plantedCount = plantedCount + 1
                end
            end

            guiElements.ProgressLabel.Text = "Progress: " .. plantedCount .. " / " .. #shapePoints

            local totalPoints = #shapePoints
            local activeRequests = 0
            local batchPoints = {}

            local function clearBatch()
                for i = #batchPoints, 1, -1 do
                    batchPoints[i] = nil
                end
            end

            local function updateProgress()
                guiElements.ProgressLabel.Text = "Progress: " .. plantedCount .. " / " .. totalPoints
            end

            local function dispatchPoint(pointData)
                activeRequests = activeRequests + 1
                task.spawn(function()
                    if not isPlanting then
                        activeRequests = activeRequests - 1
                        return
                    end

                    local result = plantRemote:InvokeServer(saplingProxy, pointData.position)

                    if result then
                        pointData.status = "Planted"
                        plantedCount = plantedCount + 1
                        updateProgress()

                        local highlight = highlightParts[pointData.highlightIndex]
                        if highlight then
                            highlight:Destroy()
                        end
                        highlightParts[pointData.highlightIndex] = nil
                    end

                    activeRequests = activeRequests - 1
                end)
            end

            local function flushBatch()
                if #batchPoints == 0 or not isPlanting then
                    clearBatch()
                    return
                end

                for _, point in ipairs(batchPoints) do
                    if not isPlanting then
                        break
                    end
                    dispatchPoint(point)
                end

                clearBatch()
            end

            updateProgress()

            for _, pointData in ipairs(shapePoints) do
                if not isPlanting then
                    break
                end

                if pointData.status == "Empty" then
                    batchPoints[#batchPoints + 1] = pointData
                    if #batchPoints == 10 then
                        flushBatch()
                    end
                end
            end

            flushBatch()

            while activeRequests > 0 do
                task.wait()
            end
            
            if guiElements.SaplingProxy then
                if guiElements.SaplingProxy.Parent then
                    guiElements.SaplingProxy.Parent = nil
                end
                guiElements.SaplingProxy:Destroy()
                guiElements.SaplingProxy = nil
            end
            SaplingsControl.GUIProxy = nil

            isPlanting = false
            setButtons(true)
        end) 
    end)
    
    -- Parent to PlayerGui
    screenGui.Parent = player:WaitForChild("PlayerGui")
    SaplingsGUI = screenGui
end

-- Function to destroy the Saplings GUI
local function destroySaplingsGUI()
    if SaplingsGUI then
        -- Clear any existing highlights first
        for _, part in ipairs(workspace:GetChildren()) do
            if part.Name == "PlantingHighlight" then
                part:Destroy()
            end
        end
        
        SaplingsGUI:Destroy()
        SaplingsGUI = nil
    end
end

-- Manual planting at feet - simple control table like everything else
local ManualPlantControl = {
    InputValue = "",
    IsPlanting = false,
    JobThread = nil
}

-- Startup notifications
task.defer(function()
    task.wait(2)
    if ApocLibrary and ApocLibrary.Notify then
        ApocLibrary:Notify({
            Title = "Range Adjustment",
            Content = "Recent game updates capped kill aura and chopping aura range at 90 studs.",
            Duration = 6,
            Image = 4483362458,
        })
        ApocLibrary:Notify({
            Title = "INFINITY WOOD",
            Content = "GO TO GUIS TAB -> PUT A NUMBER 50-100 and plant at feet. Make sure 1 sapling exists on map first!",
            Duration = 8,
            Image = 4483362458,
        })
    end
end)

GUITap:CreateParagraph({
    Title = "⚠️ Planting Load Warning",
    Content = "Keep batches 50-100 saplings max. Higher numbers cause severe lag!",
})

GUITap:CreateParagraph({
    Title = "🌱 Requirement",
    Content = "At least 1 sapling must exist on the map before planting.",
})

GUITap:CreateInput({
    Name = "Manual Sapling Amount",
    CurrentValue = "",
    PlaceholderText = "Enter count (50-100)",
    RemoveTextAfterFocusLost = false,
    Flag = "GUI_SaplingFeetAmount",
    Callback = function(text)
        ManualPlantControl.InputValue = text or ""
    end,
})

-- ========== SAPLINGS GOD MODE ==========

GUITap:CreateToggle({
    Name = "🎨 Saplings God Mode",
    CurrentValue = false,
    Flag = "SaplingsGodModeToggle",
    Callback = function(enabled)
        local godMode = SaplingsControl.GodMode
        
        if enabled then
            -- Enable God Mode
            godMode.Enabled = true
            
            -- Automatically enable Free Cam
            godMode.enableFreeCam()
            godMode.DrawingEnabled = true
            
            -- Check if mobile
            local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
            
            -- Show fly controls if mobile
            if isMobile and PlayerControl.MobileGui then
                PlayerControl.MobileGui.Enabled = true
            end
            
            -- Create custom GUI
            local Players = game:GetService("Players")
            local UserInputService = game:GetService("UserInputService")
            local player = Players.LocalPlayer
            local playerGui = player:WaitForChild("PlayerGui")
            
            local screenGui = Instance.new("ScreenGui")
            screenGui.Name = "SaplingsGodGUI"
            screenGui.ResetOnSpawn = false
            screenGui.Parent = playerGui
            godMode.GUI = screenGui
            
            -- Main frame - adjust height for mobile buttons
            local frameHeight = isMobile and 200 or 210
            local mainFrame = Instance.new("Frame")
            mainFrame.Name = "MainFrame"
            mainFrame.Size = UDim2.new(0, 280, 0, frameHeight)
            mainFrame.Position = UDim2.new(0.5, -140, 0.5, -frameHeight/2)
            mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
            mainFrame.BorderSizePixel = 0
            mainFrame.Parent = screenGui
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = mainFrame
            
            -- Title
            local title = Instance.new("TextLabel")
            title.Name = "Title"
            title.Size = UDim2.new(1, -20, 0, 35)
            title.Position = UDim2.new(0, 10, 0, 10)
            title.BackgroundTransparency = 1
            title.Text = "🎨 Saplings God Mode - Active"
            title.TextColor3 = Color3.fromRGB(0, 255, 0)
            title.TextSize = 16
            title.Font = Enum.Font.GothamBold
            title.TextXAlignment = Enum.TextXAlignment.Center
            title.Parent = mainFrame
            
            -- Surface Mode Toggle (moved up since no instructions)
            local surfaceBtn = Instance.new("TextButton")
            surfaceBtn.Name = "SurfaceButton"
            surfaceBtn.Size = UDim2.new(1, -20, 0, 32)
            surfaceBtn.Position = UDim2.new(0, 10, 0, 50)
            surfaceBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
            surfaceBtn.Text = "🎯 Target: Ground Only"
            surfaceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            surfaceBtn.TextSize = 13
            surfaceBtn.Font = Enum.Font.GothamBold
            surfaceBtn.Parent = mainFrame
            
            local surfaceCorner = Instance.new("UICorner")
            surfaceCorner.CornerRadius = UDim.new(0, 6)
            surfaceCorner.Parent = surfaceBtn
            
            surfaceBtn.MouseButton1Click:Connect(function()
                if godMode.TargetSurfaceMode == "Ground Only" then
                    godMode.TargetSurfaceMode = "Any Surface"
                    surfaceBtn.Text = "🎯 Target: Any Surface"
                else
                    godMode.TargetSurfaceMode = "Ground Only"
                    surfaceBtn.Text = "🎯 Target: Ground Only"
                end
            end)
            
            -- Mobile-specific controls
            local yOffset = 87
            if isMobile then
                -- Camera Move Mode Button
                local cameraModeBtn = Instance.new("TextButton")
                cameraModeBtn.Name = "CameraModeButton"
                cameraModeBtn.Size = UDim2.new(0.48, 0, 0, 32)
                cameraModeBtn.Position = UDim2.new(0, 10, 0, 87)
                cameraModeBtn.BackgroundColor3 = Color3.fromRGB(64, 128, 255)
                cameraModeBtn.Text = "📹 Camera"
                cameraModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                cameraModeBtn.TextSize = 13
                cameraModeBtn.Font = Enum.Font.GothamBold
                cameraModeBtn.Parent = mainFrame
                
                local cameraModeCorner = Instance.new("UICorner")
                cameraModeCorner.CornerRadius = UDim.new(0, 6)
                cameraModeCorner.Parent = cameraModeBtn
                
                -- Drawing Mode Button
                local drawModeBtn = Instance.new("TextButton")
                drawModeBtn.Name = "DrawModeButton"
                drawModeBtn.Size = UDim2.new(0.48, 0, 0, 32)
                drawModeBtn.Position = UDim2.new(0.52, 0, 0, 87)
                drawModeBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
                drawModeBtn.Text = "✏️ Draw"
                drawModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                drawModeBtn.TextSize = 13
                drawModeBtn.Font = Enum.Font.GothamBold
                drawModeBtn.Parent = mainFrame
                
                local drawModeCorner = Instance.new("UICorner")
                drawModeCorner.CornerRadius = UDim.new(0, 6)
                drawModeCorner.Parent = drawModeBtn
                
                -- Toggle between camera and drawing mode
                godMode.MobileMode = "camera" -- Start in camera mode
                godMode.MobileTouchActive = false
                
                local function updateMobileButtons()
                    if godMode.MobileMode == "camera" then
                        cameraModeBtn.BackgroundColor3 = Color3.fromRGB(255, 152, 0)
                        drawModeBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
                    else
                        cameraModeBtn.BackgroundColor3 = Color3.fromRGB(64, 128, 255)
                        drawModeBtn.BackgroundColor3 = Color3.fromRGB(255, 152, 0)
                    end
                end
                
                cameraModeBtn.MouseButton1Click:Connect(function()
                    godMode.MobileMode = "camera"
                    updateMobileButtons()
                end)
                
                drawModeBtn.MouseButton1Click:Connect(function()
                    godMode.MobileMode = "draw"
                    updateMobileButtons()
                end)
                
                updateMobileButtons()
                yOffset = 124
            end
            
            -- Points counter
            local pointsLabel = Instance.new("TextLabel")
            pointsLabel.Name = "PointsLabel"
            pointsLabel.Size = UDim2.new(1, -20, 0, 22)
            pointsLabel.Position = UDim2.new(0, 10, 0, yOffset)
            pointsLabel.BackgroundTransparency = 1
            pointsLabel.Text = "Points: 0"
            pointsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            pointsLabel.TextSize = 14
            pointsLabel.Font = Enum.Font.GothamBold
            pointsLabel.TextXAlignment = Enum.TextXAlignment.Center
            pointsLabel.Parent = mainFrame
            
            -- Clear button
            local clearBtn = Instance.new("TextButton")
            clearBtn.Name = "ClearButton"
            clearBtn.Size = UDim2.new(0.48, 0, 0, 32)
            clearBtn.Position = UDim2.new(0, 10, 0, yOffset + 27)
            clearBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
            clearBtn.Text = "🗑️ Clear"
            clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            clearBtn.TextSize = 13
            clearBtn.Font = Enum.Font.GothamBold
            clearBtn.Parent = mainFrame
            
            local clearCorner = Instance.new("UICorner")
            clearCorner.CornerRadius = UDim.new(0, 6)
            clearCorner.Parent = clearBtn
            
            clearBtn.MouseButton1Click:Connect(function()
                godMode.clearPoints()
                pointsLabel.Text = "Points: 0"
            end)
            
            -- Plant button
            local plantBtn = Instance.new("TextButton")
            plantBtn.Name = "PlantButton"
            plantBtn.Size = UDim2.new(0.48, 0, 0, 32)
            plantBtn.Position = UDim2.new(0.52, 0, 0, yOffset + 27)
            plantBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
            plantBtn.Text = "🌱 Plant All"
            plantBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            plantBtn.TextSize = 13
            plantBtn.Font = Enum.Font.GothamBold
            plantBtn.Parent = mainFrame
            
            local plantCorner = Instance.new("UICorner")
            plantCorner.CornerRadius = UDim.new(0, 6)
            plantCorner.Parent = plantBtn
            
            plantBtn.MouseButton1Click:Connect(function()
                if #godMode.Points == 0 then
                    if ApocLibrary then
                        ApocLibrary:Notify({
                            Title = "Saplings God",
                            Content = "No points marked! Draw some positions first.",
                            Duration = 3,
                            Image = 4400697855,
                        })
                    end
                    return
                end
                
                godMode.plantAllPoints()
                
                if ApocLibrary then
                    ApocLibrary:Notify({
                        Title = "Saplings God",
                        Content = string.format("Planting %d saplings...", #godMode.Points),
                        Duration = 3,
                        Image = 4483362458,
                    })
                end
            end)
            
            -- Make frame draggable
            local dragging, dragInput, dragStart, startPos
            
            mainFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = mainFrame.Position
                    
                    input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                            dragging = false
                        end
                    end)
                end
            end)
            
            mainFrame.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    dragInput = input
                end
            end)
            
            UserInputService.InputChanged:Connect(function(input)
                if input == dragInput and dragging then
                    local delta = input.Position - dragStart
                    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
            
            -- Mouse input handling for drawing
            godMode.MouseConnection = UserInputService.InputBegan:Connect(function(input, processed)
                if processed then return end
                
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    godMode.MouseDown = true
                elseif input.UserInputType == Enum.UserInputType.Touch then
                    -- Handle touch for mobile
                    if isMobile then
                        godMode.MobileTouchActive = true
                        godMode.CurrentTouchPosition = input.Position
                        godMode.LastTouchPosition = input.Position
                    end
                end
            end)
            
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    godMode.MouseDown = false
                elseif input.UserInputType == Enum.UserInputType.Touch then
                    if isMobile then
                        godMode.MobileTouchActive = false
                        godMode.CurrentTouchPosition = nil
                        godMode.LastTouchPosition = nil
                    end
                end
            end)
            
            -- Mobile touch movement handling
            if isMobile then
                UserInputService.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch and godMode.MobileTouchActive then
                        godMode.CurrentTouchPosition = input.Position
                        
                        if godMode.MobileMode == "camera" then
                            -- Camera rotation mode
                            if godMode.LastTouchPosition then
                                local delta = input.Position - godMode.LastTouchPosition
                                godMode.CameraRotation = godMode.CameraRotation + Vector2.new(-delta.Y * 0.2, -delta.X * 0.2)
                                godMode.CameraRotation = Vector2.new(
                                    math.clamp(godMode.CameraRotation.X, -89, 89),
                                    godMode.CameraRotation.Y % 360
                                )
                                godMode.LastTouchPosition = input.Position
                            end
                        end
                    end
                end)
            end
            
            -- Drawing loop
            game:GetService("RunService").RenderStepped:Connect(function()
                if godMode.Enabled and godMode.DrawingEnabled then
                    if isMobile then
                        -- Mobile: only draw when in draw mode and touching
                        if godMode.MobileMode == "draw" and godMode.MobileTouchActive then
                            godMode.handleDrawing()
                        end
                    else
                        -- PC: draw when mouse button is down
                        if godMode.MouseDown then
                            godMode.handleDrawing()
                        end
                    end
                end
                
                -- Update points counter
                if godMode.GUI then
                    pointsLabel.Text = string.format("Points: %d", #godMode.Points)
                end
            end)
            
            if ApocLibrary then
                ApocLibrary:Notify({
                    Title = "Saplings God Mode",
                    Content = "Free Cam enabled! Start drawing sapling positions.",
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        else
            -- Disable God Mode
            godMode.Enabled = false
            godMode.DrawingEnabled = false
            
            -- Hide fly controls if mobile
            local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
            if isMobile and PlayerControl.MobileGui then
                PlayerControl.MobileGui.Enabled = false
            end
            
            -- Clear all points and visuals
            godMode.clearPoints()
            
            -- Disable Free Cam
            if godMode.FreeCamEnabled then
                godMode.disableFreeCam()
            end
            
            -- Disconnect mouse input if exists
            if godMode.MouseConnection then
                godMode.MouseConnection:Disconnect()
                godMode.MouseConnection = nil
            end
            
            -- Destroy custom GUI if exists
            if godMode.GUI then
                godMode.GUI:Destroy()
                godMode.GUI = nil
            end
            
            if ApocLibrary then
                ApocLibrary:Notify({
                    Title = "Saplings God Mode",
                    Content = "God Mode disabled",
                    Duration = 3,
                    Image = 4483362458,
                })
            end
        end
    end,
})

-- ========================================

GUITap:CreateButton({
    Name = "🔄 Reset Sapling System",
    Callback = function()
        -- Stop any active planting
        if ManualPlantControl.IsPlanting then
            ManualPlantControl.IsPlanting = false
        end
        if ManualPlantControl.JobThread then
            task.cancel(ManualPlantControl.JobThread)
            ManualPlantControl.JobThread = nil
        end
        
        -- Clear cached sapling proxy
        if _G.__SaplingProxy then
            pcall(function()
                if _G.__SaplingProxy.Parent then
                    _G.__SaplingProxy.Parent = nil
                end
                _G.__SaplingProxy:Destroy()
            end)
            _G.__SaplingProxy = nil
        end
        
        -- Reset control state
        ManualPlantControl.IsPlanting = false
        ManualPlantControl.JobThread = nil
        
        if ApocLibrary then
            ApocLibrary:Notify({
                Title = "Sapling System",
                Content = "System reset complete. Ready for next planting.",
                Duration = 3,
                Image = 4483362458,
            })
        end
    end,
})

GUITap:CreateButton({
    Name = "Plant Saplings At Feet",
    Callback = function()
        if ManualPlantControl.IsPlanting then
            ManualPlantControl.IsPlanting = false
            if ApocLibrary then
                ApocLibrary:Notify({
                    Title = "Sapling Planter",
                    Content = "Stopping...",
                    Duration = 3,
                    Image = 4400697855,
                })
            end
            return
        end

        local amount = tonumber(ManualPlantControl.InputValue)
        if not amount or amount <= 0 then
            if ApocLibrary then
                ApocLibrary:Notify({
                    Title = "Sapling Planter",
                    Content = "Enter a valid number greater than 0",
                    Duration = 3,
                    Image = 4400697855,
                })
            end
            return
        end

        ManualPlantControl.IsPlanting = true
        amount = math.floor(amount)
        
        if ApocLibrary then
            ApocLibrary:Notify({
                Title = "Sapling Planter",
                Content = string.format("Planting %d saplings. Click again to stop.", amount),
                Duration = 4,
                Image = 4483362458,
            })
        end

        ManualPlantControl.JobThread = task.spawn(function()
            local player = game.Players.LocalPlayer
            local char = player.Character or player.CharacterAdded:Wait()
            local root = char:FindFirstChild("HumanoidRootPart")
            
            if not root then
                ManualPlantControl.IsPlanting = false
                if ApocLibrary then
                    ApocLibrary:Notify({
                        Title = "Sapling Planter",
                        Content = "Character not ready",
                        Duration = 3,
                        Image = 4400697855,
                    })
                end
                return
            end

            local proxy = ensureSaplingProxy("ManualProxy")
            if not proxy then
                ManualPlantControl.IsPlanting = false
                if ApocLibrary then
                    ApocLibrary:Notify({
                        Title = "Sapling Planter",
                        Content = "No sapling found on map",
                        Duration = 3,
                        Image = 4400697855,
                    })
                end
                return
            end

            -- Ground position via raycast
            local centerPos = root.Position
            local ground = workspace.Map and workspace.Map.Ground
            if ground then
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Whitelist
                rayParams.FilterDescendantsInstances = {ground}
                local result = workspace:Raycast(root.Position + Vector3.new(0, 100, 0), Vector3.new(0, -250, 0), rayParams)
                if result then
                    centerPos = result.Position + Vector3.new(0, 0.5, 0)
                end
            end

            local plantRemote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("RequestPlantItem")
            local planted = 0
            
            -- 2x2 grid pattern around player: spacing between saplings
            local spacing = 4
            local positions = {
                centerPos + Vector3.new(-spacing, 0, -spacing),  -- Back-left
                centerPos + Vector3.new(spacing, 0, -spacing),   -- Back-right
                centerPos + Vector3.new(-spacing, 0, spacing),   -- Front-left
                centerPos + Vector3.new(spacing, 0, spacing)     -- Front-right
            }
            
            -- Plant saplings in batches of 10 across 2x2 grid
            local batchSize = 10
            for i = 1, amount, batchSize do
                if not ManualPlantControl.IsPlanting then break end
                
                -- Plant 10 saplings at once
                for j = 0, math.min(batchSize - 1, amount - i) do
                    local pos = positions[(((i + j) - 1) % 4) + 1]
                    task.spawn(function()
                        plantRemote:InvokeServer(proxy, pos)
                    end)
                    planted = planted + 1
                end
                
                task.wait(0.1) -- Small delay between batches
            end

            -- Cleanup
            if proxy then
                if proxy.Parent then proxy.Parent = nil end
                proxy:Destroy()
            end
            SaplingsControl.ManualProxy = nil

            ManualPlantControl.IsPlanting = false
            if ApocLibrary then
                ApocLibrary:Notify({
                    Title = "Sapling Planter",
                    Content = string.format("Planted %d saplings", planted),
                    Duration = 4,
                    Image = 4483362458,
                })
            end
        end)
    end,
})

GUITap:CreateToggle({
    Name = "Saplings Planter GUI",
    CurrentValue = false,
    Flag = "GUI_SaplingsEnabled",
    Callback = function(v)
        if v then
            createSaplingsGUI()
        else
            destroySaplingsGUI()
        end
    end
})

-- ========== FOOD TEXT SHAPING GUI ==========
GUITap:CreateLabel("🍕 Food Text Shaping - Troll with Style!")

-- Food Text Control State
FoodTextControl = {
    GUI = nil,
    IsShaping = false,
    ShapingThread = nil,
    Highlights = {},
    FoodItems = {},
    ClaimedFoods = {},
    SelectedFoodType = "All"
}

-- Function to create the Food Text Shaping GUI
function createFoodTextGUI()
    print("🍕 createFoodTextGUI called!")
    if FoodTextControl.GUI then 
        print("⚠️ GUI already exists!")
        return 
    end
    
    print("✅ Creating Food Text GUI...")
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    
    local CONFIG = {
        DEFAULT_TEXT = "TROLL",
        DEFAULT_SPACING = 8,
        MIN_SPACING = 2,
        MAX_SPACING = 20,
        DEFAULT_HEIGHT = 60,
        MIN_HEIGHT = 10,
        MAX_HEIGHT = 200,
        DEFAULT_ROTATION_X = 0,
        DEFAULT_ROTATION_Y = 0,
        HIGHLIGHT_COLOR = Color3.fromRGB(255, 200, 100)
    }
    
    local THEME = {
        PRIMARY = Color3.fromRGB(255, 128, 64),
        BACKGROUND = Color3.fromRGB(25, 25, 30),
        SURFACE = Color3.fromRGB(35, 35, 40),
        TEXT = Color3.fromRGB(255, 255, 255)
    }
    
    local currentText, currentSpacing, currentHeight, currentRotationX, currentRotationY = CONFIG.DEFAULT_TEXT, CONFIG.DEFAULT_SPACING, CONFIG.DEFAULT_HEIGHT, CONFIG.DEFAULT_ROTATION_X, CONFIG.DEFAULT_ROTATION_Y
    local textPattern = {}
    
    local function textToPattern(text)
        local patterns = {
            A = {{0,1,1,1,0},{1,0,0,0,1},{1,1,1,1,1},{1,0,0,0,1},{1,0,0,0,1}},
            B = {{1,1,1,1,0},{1,0,0,0,1},{1,1,1,1,0},{1,0,0,0,1},{1,1,1,1,0}},
            C = {{0,1,1,1,0},{1,0,0,0,1},{1,0,0,0,0},{1,0,0,0,1},{0,1,1,1,0}},
            D = {{1,1,1,1,0},{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{1,1,1,1,0}},
            E = {{1,1,1,1,1},{1,0,0,0,0},{1,1,1,1,0},{1,0,0,0,0},{1,1,1,1,1}},
            F = {{1,1,1,1,1},{1,0,0,0,0},{1,1,1,1,0},{1,0,0,0,0},{1,0,0,0,0}},
            G = {{0,1,1,1,0},{1,0,0,0,0},{1,0,1,1,1},{1,0,0,0,1},{0,1,1,1,0}},
            H = {{1,0,0,0,1},{1,0,0,0,1},{1,1,1,1,1},{1,0,0,0,1},{1,0,0,0,1}},
            I = {{1,1,1,1,1},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0},{1,1,1,1,1}},
            J = {{0,0,0,1,1},{0,0,0,0,1},{0,0,0,0,1},{1,0,0,0,1},{0,1,1,1,0}},
            K = {{1,0,0,0,1},{1,0,0,1,0},{1,1,1,0,0},{1,0,0,1,0},{1,0,0,0,1}},
            L = {{1,0,0,0,0},{1,0,0,0,0},{1,0,0,0,0},{1,0,0,0,0},{1,1,1,1,1}},
            M = {{1,0,0,0,1},{1,1,0,1,1},{1,0,1,0,1},{1,0,0,0,1},{1,0,0,0,1}},
            N = {{1,0,0,0,1},{1,1,0,0,1},{1,0,1,0,1},{1,0,0,1,1},{1,0,0,0,1}},
            O = {{0,1,1,1,0},{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{0,1,1,1,0}},
            P = {{1,1,1,1,0},{1,0,0,0,1},{1,1,1,1,0},{1,0,0,0,0},{1,0,0,0,0}},
            Q = {{0,1,1,1,0},{1,0,0,0,1},{1,0,1,0,1},{1,0,0,1,0},{0,1,1,0,1}},
            R = {{1,1,1,1,0},{1,0,0,0,1},{1,1,1,1,0},{1,0,0,1,0},{1,0,0,0,1}},
            S = {{0,1,1,1,1},{1,0,0,0,0},{0,1,1,1,0},{0,0,0,0,1},{1,1,1,1,0}},
            T = {{1,1,1,1,1},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0}},
            U = {{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{0,1,1,1,0}},
            V = {{1,0,0,0,1},{1,0,0,0,1},{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0}},
            W = {{1,0,0,0,1},{1,0,0,0,1},{1,0,1,0,1},{1,1,0,1,1},{1,0,0,0,1}},
            X = {{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0},{0,1,0,1,0},{1,0,0,0,1}},
            Y = {{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0},{0,0,1,0,0},{0,0,1,0,0}},
            Z = {{1,1,1,1,1},{0,0,0,1,0},{0,0,1,0,0},{0,1,0,0,0},{1,1,1,1,1}},
            [" "] = {{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0},{0,0,0,0,0}}
        }
        
        local result = {}
        for i = 1, #text do
            local char = text:sub(i, i):upper()
            if patterns[char] then
                table.insert(result, patterns[char])
            end
        end
        return result
    end
    
    local function clearHighlights()
        for _, h in ipairs(FoodTextControl.Highlights) do
            pcall(function() h:Destroy() end)
        end
        FoodTextControl.Highlights = {}
    end
    
    local function getCenterPoint()
        local campfire = workspace.Map and workspace.Map.Campground and workspace.Map.Campground.MainFire
        if campfire and campfire:FindFirstChild("Center") then
            return campfire.Center.Position + Vector3.new(0, currentHeight, 0)
        end
        return Vector3.new(0, currentHeight, 0)
    end
    
    local function previewText()
        clearHighlights()
        textPattern = textToPattern(currentText)
        
        if #textPattern == 0 then return end
        
        local centerPoint = getCenterPoint()
        local letterWidth, letterHeight = 5, 5
        local totalWidth = (#textPattern * letterWidth + (#textPattern - 1)) * currentSpacing
        local startX = -totalWidth / 2
        
        for letterIndex, letterPattern in ipairs(textPattern) do
            local letterOffsetX = startX + (letterIndex - 1) * (letterWidth + 1) * currentSpacing
            
            for row = 1, letterHeight do
                for col = 1, letterWidth do
                    if letterPattern[row] and letterPattern[row][col] == 1 then
                        local x = letterOffsetX + (col - 1) * currentSpacing
                        local z = (row - 1) * currentSpacing - (letterHeight * currentSpacing / 2)
                        
                        local pos = centerPoint + Vector3.new(x, 0, z)
                        
                        -- Apply rotations
                        local rotatedPos = pos - centerPoint
                        local angleX, angleY = math.rad(currentRotationX), math.rad(currentRotationY)
                        
                        -- Rotate X
                        local y1, z1 = rotatedPos.Y * math.cos(angleX) - rotatedPos.Z * math.sin(angleX), rotatedPos.Y * math.sin(angleX) + rotatedPos.Z * math.cos(angleX)
                        -- Rotate Y
                        local x2, z2 = rotatedPos.X * math.cos(angleY) + z1 * math.sin(angleY), -rotatedPos.X * math.sin(angleY) + z1 * math.cos(angleY)
                        
                        pos = centerPoint + Vector3.new(x2, y1, z2)
                        
                        local highlight = Instance.new("Part")
                        highlight.Size = Vector3.new(2, 0.5, 2)
                        highlight.Position = pos
                        highlight.Anchored = true
                        highlight.CanCollide = false
                        highlight.Material = Enum.Material.Neon
                        highlight.Color = CONFIG.HIGHLIGHT_COLOR
                        highlight.Transparency = 0.3
                        highlight.Parent = workspace
                        table.insert(FoodTextControl.Highlights, highlight)
                    end
                end
            end
        end
    end
    
    local function collectFoodItems()
        FoodTextControl.FoodItems = {}
        itemsFolder = WorkspaceItems or workspace:FindFirstChild("Items")
        if not itemsFolder then 
            print("⚠️ No Items folder found in workspace!")
            return 
        end
        
        selectedType = FoodTextControl.SelectedFoodType
        print("🔍 Searching for food items (" .. selectedType .. ") in Items folder...")
        
        -- Food item lookup based on actual game items
        FoodItemLookup = {
            ["Berry"] = "Berry",
            ["Cake"] = "Cake",
            ["Ribs"] = "Ribs", 
            ["Steak"] = "Steak",
            ["Morsel"] = "Morsel",
            ["Carrot"] = "Carrot",
            ["Corn"] = "Corn", 
            ["Pumpkin"] = "Pumpkin",
            ["Apple"] = "Apple",
            ["Chili"] = "Chili",
            ["Cooked Steak"] = "Cooked Food",
            ["Cooked Morsel"] = "Cooked Food",
            ["Cooked Ribs"] = "Cooked Food",
        }
        
        -- Temporary table to group items by type when "All" is selected
        tempGroupedItems = {}
        
        for _, item in pairs(itemsFolder:GetChildren()) do
            itemPart = item.PrimaryPart or item:FindFirstChild("Main") or item:FindFirstChildOfClass("BasePart")
            if itemPart then
                itemType = FoodItemLookup[item.Name]
                if itemType then
                    shouldCollect = false
                    
                    -- Filter by selected food type
                    if selectedType == "All" then
                        shouldCollect = true
                    elseif selectedType == "Cooked Food" then
                        shouldCollect = (itemType == "Cooked Food")
                    elseif selectedType == itemType then
                        shouldCollect = true
                    end
                    
                    if shouldCollect then
                        if selectedType == "All" then
                            -- Group by type
                            if not tempGroupedItems[itemType] then
                                tempGroupedItems[itemType] = {}
                            end
                            table.insert(tempGroupedItems[itemType], item)
                        else
                            -- Single type, just add directly
                            table.insert(FoodTextControl.FoodItems, item)
                        end
                        print("✅ Found food item:", item.Name)
                    end
                end
            end
        end
        
        -- If "All" was selected, add grouped items in order by type
        if selectedType == "All" then
            for _, foodType in ipairs({"Berry", "Cake", "Ribs", "Steak", "Morsel", "Carrot", "Corn", "Pumpkin", "Apple", "Chili", "Cooked Food"}) do
                if tempGroupedItems[foodType] then
                    for _, item in ipairs(tempGroupedItems[foodType]) do
                        table.insert(FoodTextControl.FoodItems, item)
                    end
                end
            end
        end
        
        print("📊 Total food items collected:", #FoodTextControl.FoodItems)
    end
    
    local function claimFoodAuthority()
        FoodTextControl.ClaimedFoods = {}
        collectFoodItems()
        
        local requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
        if requestStartDragging then
            for _, food in ipairs(FoodTextControl.FoodItems) do
                requestStartDragging:FireServer(food)
                table.insert(FoodTextControl.ClaimedFoods, food)
            end
        end
    end
    
    local function releaseFoodAuthority()
        local stopDragging = RemoteEvents:FindFirstChild("StopDraggingItem")
        if stopDragging then
            for _, food in ipairs(FoodTextControl.ClaimedFoods) do
                pcall(function()
                    stopDragging:FireServer(food)
                end)
            end
        end
        FoodTextControl.ClaimedFoods = {}
    end
    
    local function startShaping()
        if FoodTextControl.IsShaping then return end
        
        textPattern = textToPattern(currentText)
        if #textPattern == 0 then return end
        
        -- Collect food items first
        collectFoodItems()
        if #FoodTextControl.FoodItems == 0 then
            warn("❌ No food items found!")
            return
        end
        
        print("✅ Found " .. #FoodTextControl.FoodItems .. " food items")
        print("📤 Claiming authority on all food items...")
        
        -- Claim authority on all food items FIRST
        requestStartDragging = RemoteEvents:FindFirstChild("RequestStartDraggingItem")
        if requestStartDragging then
            for _, food in ipairs(FoodTextControl.FoodItems) do
                pcall(function()
                    requestStartDragging:FireServer(food)
                    table.insert(FoodTextControl.ClaimedFoods, food)
                    print("Claimed:", food.Name)
                end)
            end
        else
            warn("❌ RequestStartDraggingItem not found!")
            return
        end
        
        print("⏳ Waiting for authority...")
        task.wait(0.5)
        
        print("🎨 Starting to shape text...")
        FoodTextControl.IsShaping = true
        FoodTextControl.ShapingThread = task.spawn(function()
            centerPoint = getCenterPoint()
            letterWidth, letterHeight = 5, 5
            totalWidth = (#textPattern * letterWidth + (#textPattern - 1)) * currentSpacing
            startX = -totalWidth / 2
            foodIndex = 1
            
            -- Place food items in pattern
            for letterIndex, letterPattern in ipairs(textPattern) do
                if not FoodTextControl.IsShaping then break end
                
                letterOffsetX = startX + (letterIndex - 1) * (letterWidth + 1) * currentSpacing
                
                for row = 1, letterHeight do
                    for col = 1, letterWidth do
                        if not FoodTextControl.IsShaping then break end
                        
                        if letterPattern[row] and letterPattern[row][col] == 1 then
                            if foodIndex > #FoodTextControl.FoodItems then
                                foodIndex = 1
                            end
                            
                            food = FoodTextControl.FoodItems[foodIndex]
                            foodPart = food and (food.PrimaryPart or food:FindFirstChild("Main") or food:FindFirstChildOfClass("BasePart"))
                            if foodPart then
                                x = letterOffsetX + (col - 1) * currentSpacing
                                z = (row - 1) * currentSpacing - (letterHeight * currentSpacing / 2)
                                pos = centerPoint + Vector3.new(x, 0, z)
                                
                                -- Apply rotations
                                rotatedPos = pos - centerPoint
                                angleX, angleY = math.rad(currentRotationX), math.rad(currentRotationY)
                                y1, z1 = rotatedPos.Y * math.cos(angleX) - rotatedPos.Z * math.sin(angleX), rotatedPos.Y * math.sin(angleX) + rotatedPos.Z * math.cos(angleX)
                                x2, z2 = rotatedPos.X * math.cos(angleY) + z1 * math.sin(angleY), -rotatedPos.X * math.sin(angleY) + z1 * math.cos(angleY)
                                pos = centerPoint + Vector3.new(x2, y1, z2)
                                
                                -- Move and anchor the food item
                                pcall(function()
                                    foodPart.CFrame = CFrame.new(pos)
                                    foodPart.Anchored = true
                                end)
                                
                                foodIndex = foodIndex + 1
                                task.wait(0.05)
                            end
                        end
                    end
                end
            end
            
            print("Shaping complete! Food items are anchored in position.")
        end)
    end
    
    local function stopShaping()
        print("⏹️ Stopping shaping...")
        FoodTextControl.IsShaping = false
        if FoodTextControl.ShapingThread then
            task.cancel(FoodTextControl.ShapingThread)
            FoodTextControl.ShapingThread = nil
        end
        
        -- Unanchor all food items
        print("🔓 Unanchoring food items...")
        for _, food in ipairs(FoodTextControl.ClaimedFoods) do
            pcall(function()
                foodPart = food and (food.PrimaryPart or food:FindFirstChild("Main") or food:FindFirstChildOfClass("BasePart"))
                if foodPart then
                    foodPart.Anchored = false
                    print("Unanchored:", food.Name)
                end
            end)
        end
        
        -- Release authority
        print("📤 Releasing dragging authority...")
        releaseFoodAuthority()
        
        print("✅ Stopped shaping and released all food items")
    end
    
    -- Create GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FoodTextShapingGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 350, 0, 376) -- Reduced height by 20% (470 * 0.8 = 376)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -188) -- Adjusted position to keep centered
    mainFrame.BackgroundColor3 = THEME.BACKGROUND
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = false
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Title (20% smaller)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 32) -- 40 * 0.8 = 32
    title.BackgroundColor3 = THEME.PRIMARY
    title.BorderSizePixel = 0
    title.Text = "🍕 Food Text Shaping"
    title.TextColor3 = THEME.TEXT
    title.TextSize = 14 -- 18 * 0.8 ≈ 14
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10) -- 12 * 0.8 ≈ 10
    titleCorner.Parent = title
    
    -- Close button (20% smaller)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 24, 0, 24) -- 30 * 0.8 = 24
    closeBtn.Position = UDim2.new(1, -28, 0, 4) -- Adjusted position
    closeBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = THEME.TEXT
    closeBtn.TextSize = 13 -- 16 * 0.8 ≈ 13
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = title
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 8)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        destroyFoodTextGUI()
    end)
    
    -- Food Type Dropdown (20% smaller)
    local foodTypeLabel = Instance.new("TextLabel")
    foodTypeLabel.Size = UDim2.new(1, -20, 0, 16) -- 20 * 0.8 = 16
    foodTypeLabel.Position = UDim2.new(0, 10, 0, 40) -- Adjusted from 50
    foodTypeLabel.BackgroundTransparency = 1
    foodTypeLabel.Text = "Food Type:"
    foodTypeLabel.TextColor3 = THEME.TEXT
    foodTypeLabel.TextSize = 11 -- 14 * 0.8 ≈ 11
    foodTypeLabel.Font = Enum.Font.Gotham
    foodTypeLabel.TextXAlignment = Enum.TextXAlignment.Left
    foodTypeLabel.Parent = mainFrame
    
    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Size = UDim2.new(1, -20, 0, 28) -- 35 * 0.8 = 28
    dropdownFrame.Position = UDim2.new(0, 10, 0, 60) -- Adjusted from 75
    dropdownFrame.BackgroundColor3 = THEME.SURFACE
    dropdownFrame.BorderSizePixel = 0
    dropdownFrame.ClipsDescendants = false
    dropdownFrame.Parent = mainFrame
    
    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 6) -- 8 * 0.8 ≈ 6
    dropdownCorner.Parent = dropdownFrame
    
    local dropdownButton = Instance.new("TextButton")
    dropdownButton.Size = UDim2.new(1, -10, 1, 0)
    dropdownButton.Position = UDim2.new(0, 5, 0, 0)
    dropdownButton.BackgroundTransparency = 1
    dropdownButton.Text = FoodTextControl.SelectedFoodType .. " ▼"
    dropdownButton.TextColor3 = THEME.TEXT
    dropdownButton.TextSize = 11 -- 14 * 0.8 ≈ 11
    dropdownButton.Font = Enum.Font.Gotham
    dropdownButton.TextXAlignment = Enum.TextXAlignment.Left
    dropdownButton.Parent = dropdownFrame
    
    local dropdownExpanded = false
    local dropdownOptions = {"All", "Cooked Food", "Berry", "Cake", "Ribs", "Steak", "Morsel", "Carrot", "Corn", "Pumpkin", "Apple", "Chili"}
    
    -- ScrollingFrame for dropdown (max 6 items visible) - parent to screenGui so it appears on top (20% smaller)
    local dropdownList = Instance.new("ScrollingFrame")
    dropdownList.Size = UDim2.new(0, 330, 0, math.min(#dropdownOptions, 6) * 24) -- 30 * 0.8 = 24
    dropdownList.CanvasSize = UDim2.new(0, 0, 0, #dropdownOptions * 24) -- 30 * 0.8 = 24
    dropdownList.Position = UDim2.new(0.5, -165, 0.5, -100) -- Adjusted from -125
    dropdownList.BackgroundColor3 = THEME.SURFACE
    dropdownList.BorderSizePixel = 1
    dropdownList.BorderColor3 = THEME.PRIMARY
    dropdownList.ScrollBarThickness = 5 -- 6 * 0.8 ≈ 5
    dropdownList.ScrollBarImageColor3 = THEME.PRIMARY
    dropdownList.Visible = false
    dropdownList.ZIndex = 1000
    dropdownList.Parent = screenGui
    
    local dropdownListCorner = Instance.new("UICorner")
    dropdownListCorner.CornerRadius = UDim.new(0, 6) -- 8 * 0.8 ≈ 6
    dropdownListCorner.Parent = dropdownList
    
    for i, option in ipairs(dropdownOptions) do
        optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, -10, 0, 22) -- 28 * 0.8 ≈ 22
        optionBtn.Position = UDim2.new(0, 5, 0, (i - 1) * 24 + 1) -- 30 * 0.8 = 24
        optionBtn.BackgroundColor3 = THEME.SURFACE
        optionBtn.BorderSizePixel = 0
        optionBtn.Text = option
        optionBtn.TextColor3 = THEME.TEXT
        optionBtn.TextSize = 10 -- 13 * 0.8 ≈ 10
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.TextXAlignment = Enum.TextXAlignment.Left
        optionBtn.ZIndex = 1001
        optionBtn.Parent = dropdownList
        
        -- Add rounded corner to option button
        optionBtnCorner = Instance.new("UICorner")
        optionBtnCorner.CornerRadius = UDim.new(0, 5) -- 6 * 0.8 ≈ 5
        optionBtnCorner.Parent = optionBtn
        
        optionBtn.MouseButton1Click:Connect(function()
            FoodTextControl.SelectedFoodType = option
            dropdownButton.Text = option .. " ▼"
            dropdownList.Visible = false
            dropdownExpanded = false
            print("Selected food type:", option)
        end)
        
        optionBtn.MouseEnter:Connect(function()
            optionBtn.BackgroundColor3 = THEME.PRIMARY
        end)
        
        optionBtn.MouseLeave:Connect(function()
            optionBtn.BackgroundColor3 = THEME.SURFACE
        end)
    end
    
    dropdownButton.MouseButton1Click:Connect(function()
        dropdownExpanded = not dropdownExpanded
        if dropdownExpanded then
            -- Calculate absolute position based on dropdownFrame
            dropdownAbsPos = dropdownFrame.AbsolutePosition
            dropdownAbsSize = dropdownFrame.AbsoluteSize
            dropdownList.Position = UDim2.new(0, dropdownAbsPos.X, 0, dropdownAbsPos.Y + dropdownAbsSize.Y + 5)
        end
        dropdownList.Visible = dropdownExpanded
    end)
    
    -- Text input (20% smaller)
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 0, 16) -- 20 * 0.8 = 16
    textLabel.Position = UDim2.new(0, 10, 0, 96) -- Adjusted from 120
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "Text to Shape:"
    textLabel.TextColor3 = THEME.TEXT
    textLabel.TextSize = 11 -- 14 * 0.8 ≈ 11
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = mainFrame
    
    local textInput = Instance.new("TextBox")
    textInput.Size = UDim2.new(1, -20, 0, 28) -- 35 * 0.8 = 28
    textInput.Position = UDim2.new(0, 10, 0, 116) -- Adjusted from 145
    textInput.BackgroundColor3 = THEME.SURFACE
    textInput.Text = currentText
    textInput.TextColor3 = THEME.TEXT
    textInput.TextSize = 13 -- 16 * 0.8 ≈ 13
    textInput.Font = Enum.Font.Gotham
    textInput.PlaceholderText = "Enter text..."
    textInput.Parent = mainFrame
    
    local textInputCorner = Instance.new("UICorner")
    textInputCorner.CornerRadius = UDim.new(0, 6) -- 8 * 0.8 ≈ 6
    textInputCorner.Parent = textInput
    
    textInput.FocusLost:Connect(function()
        local text = textInput.Text:upper():gsub("[^A-Z ]", "")
        if #text > 0 then
            currentText = text
            textInput.Text = text
            previewText()
        end
    end)
    
    -- Spacing slider (20% smaller)
    local function createSlider(name, yPos, min, max, default, callback)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 0, 16) -- 20 * 0.8 = 16
        label.Position = UDim2.new(0, 10, 0, yPos)
        label.BackgroundTransparency = 1
        label.Text = name .. ": " .. default
        label.TextColor3 = THEME.TEXT
        label.TextSize = 11 -- 14 * 0.8 ≈ 11
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = mainFrame
        
        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(1, -20, 0, 5) -- 6 * 0.8 ≈ 5
        sliderBg.Position = UDim2.new(0, 10, 0, yPos + 20) -- Adjusted from 25
        sliderBg.BackgroundColor3 = THEME.SURFACE
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = mainFrame
        
        local sliderBgCorner = Instance.new("UICorner")
        sliderBgCorner.CornerRadius = UDim.new(1, 0)
        sliderBgCorner.Parent = sliderBg
        
        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        sliderFill.BackgroundColor3 = THEME.PRIMARY
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBg
        
        local sliderFillCorner = Instance.new("UICorner")
        sliderFillCorner.CornerRadius = UDim.new(1, 0)
        sliderFillCorner.Parent = sliderFill
        
        local dragging = false
        local function updateSlider(input)
            local relativeX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * relativeX)
            sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
            label.Text = name .. ": " .. value
            callback(value)
        end
        
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateSlider(input)
            end
        end)
        
        sliderBg.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateSlider(input)
            end
        end)
    end
    
    createSlider("Spacing", 152, CONFIG.MIN_SPACING, CONFIG.MAX_SPACING, CONFIG.DEFAULT_SPACING, function(val)
        currentSpacing = val
        previewText()
    end)
    
    createSlider("Height", 188, CONFIG.MIN_HEIGHT, CONFIG.MAX_HEIGHT, CONFIG.DEFAULT_HEIGHT, function(val)
        currentHeight = val
        previewText()
    end)
    
    createSlider("Rotate X", 224, -180, 180, CONFIG.DEFAULT_ROTATION_X, function(val)
        currentRotationX = val
        previewText()
    end)
    
    createSlider("Rotate Y", 260, -180, 180, CONFIG.DEFAULT_ROTATION_Y, function(val)
        currentRotationY = val
        previewText()
    end)
    
    -- Preview button (left side) (20% smaller)
    local previewBtn = Instance.new("TextButton")
    previewBtn.Size = UDim2.new(0.48, 0, 0, 32) -- 40 * 0.8 = 32
    previewBtn.Position = UDim2.new(0, 10, 0, 300) -- Adjusted from 375
    previewBtn.BackgroundColor3 = Color3.fromRGB(33, 150, 243)
    previewBtn.Text = "👁️ Preview"
    previewBtn.TextColor3 = THEME.TEXT
    previewBtn.TextSize = 13 -- 16 * 0.8 ≈ 13
    previewBtn.Font = Enum.Font.GothamBold
    previewBtn.Parent = mainFrame
    
    local previewBtnCorner = Instance.new("UICorner")
    previewBtnCorner.CornerRadius = UDim.new(0, 6) -- 8 * 0.8 ≈ 6
    previewBtnCorner.Parent = previewBtn
    
    previewBtn.MouseButton1Click:Connect(previewText)
    
    -- Clear button (right side) (20% smaller)
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.48, 0, 0, 32) -- 40 * 0.8 = 32
    clearBtn.Position = UDim2.new(0.52, 0, 0, 300) -- Adjusted from 375
    clearBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
    clearBtn.Text = "🗑️ Clear"
    clearBtn.TextColor3 = THEME.TEXT
    clearBtn.TextSize = 13 -- 16 * 0.8 ≈ 13
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.Parent = mainFrame
    
    local clearBtnCorner = Instance.new("UICorner")
    clearBtnCorner.CornerRadius = UDim.new(0, 6) -- 8 * 0.8 ≈ 6
    clearBtnCorner.Parent = clearBtn
    
    clearBtn.MouseButton1Click:Connect(clearHighlights)
    
    -- Shape button (20% smaller)
    local shapeBtn = Instance.new("TextButton")
    shapeBtn.Size = UDim2.new(1, -20, 0, 32) -- 40 * 0.8 = 32
    shapeBtn.Position = UDim2.new(0, 10, 0, 340) -- Adjusted from 425
    shapeBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
    shapeBtn.Text = "🍕 Start Shaping"
    shapeBtn.TextColor3 = THEME.TEXT
    shapeBtn.TextSize = 13 -- 16 * 0.8 ≈ 13
    shapeBtn.Font = Enum.Font.GothamBold
    shapeBtn.Parent = mainFrame
    
    local shapeBtnCorner = Instance.new("UICorner")
    shapeBtnCorner.CornerRadius = UDim.new(0, 6) -- 8 * 0.8 ≈ 6
    shapeBtnCorner.Parent = shapeBtn
    
    shapeBtn.MouseButton1Click:Connect(function()
        if FoodTextControl.IsShaping then
            stopShaping()
            shapeBtn.Text = "🍕 Start Shaping"
            shapeBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        else
            startShaping()
            shapeBtn.Text = "⏹️ Stop Shaping"
            shapeBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
        end
    end)
    
    -- Make draggable
    local dragging, dragInput, dragStart, startPos
    
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    title.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    FoodTextControl.GUI = screenGui
    print("✅ Food Text GUI created successfully!")
    previewText()
end

-- Function to destroy the Food Text Shaping GUI
function destroyFoodTextGUI()
    if FoodTextControl.GUI then
        if FoodTextControl.IsShaping then
            FoodTextControl.IsShaping = false
            if FoodTextControl.ShapingThread then
                task.cancel(FoodTextControl.ShapingThread)
                FoodTextControl.ShapingThread = nil
            end
        end
        
        for _, h in ipairs(FoodTextControl.Highlights) do
            pcall(function() h:Destroy() end)
        end
        FoodTextControl.Highlights = {}
        
        FoodTextControl.GUI:Destroy()
        FoodTextControl.GUI = nil
    end
end

GUITap:CreateToggle({
    Name = "🍕 Food Text Shaping GUI",
    CurrentValue = false,
    Flag = "GUI_FoodTextEnabled",
    Callback = function(v)
        print("🍕 Toggle callback fired! Value:", v)
        if v then
            print("🍕 Calling createFoodTextGUI()...")
            createFoodTextGUI()
        else
            print("🍕 Calling destroyFoodTextGUI()...")
            destroyFoodTextGUI()
        end
    end
})

-- ========== TROLL TAB CONTENT ==========

TrollTab:CreateLabel("🌪️ Chaos & Fun Features")
TrollTab:CreateLabel("Warning: These features are for fun and may cause chaos!")

TrollTab:CreateButton({
    Name = "🌪️ LOG APOCALYPSE - Bring ALL Logs to Cloud",
    Callback = function()
        BringAllLogsToCloud()
        ApocLibrary:Notify({
            Title = "🌪️ LOG APOCALYPSE INITIATED!",
            Content = "All logs are being brought to campfire cloud formation!",
            Duration = 5,
            Image = 4483362458,
        })
    end
})

TrollTab:CreateToggle({
    Name = "🪐 PLANET LOG - Rotating Planet & Rings System",
    Default = false,
    Callback = function(Value)
        TreesControl.PlanetLogEnabled = Value
        if Value then
            -- Store original gravity and set to zero
            TreesControl.OriginalGravity = workspace.Gravity
            workspace.Gravity = 0
            
            -- Start planetary system
            BringAllLogsToPlanet()
            
            ApocLibrary:Notify({
                Title = "🪐 PLANET LOG SYSTEM ACTIVATED!",
                Content = "Logs are forming a rotating planet with ring system! Gravity set to 0!",
                Duration = 6,
                Image = 4483362458,
            })
        else
            -- Restore original gravity
            workspace.Gravity = TreesControl.OriginalGravity
            
            -- Stop rotation task
            if TreesControl.PlanetRotationTask then
                task.cancel(TreesControl.PlanetRotationTask)
                TreesControl.PlanetRotationTask = nil
            end
            
            ApocLibrary:Notify({
                Title = "🪐 PLANET LOG SYSTEM DISABLED",
                Content = "Planetary rotation stopped, gravity restored to normal!",
                Duration = 4,
                Image = 4483362458,
            })
        end
    end
})

TrollTab:CreateButton({
    Name = "🎯 ITEM TROLL - Bring ALL Items to Main Fire",
    Callback = function()
        BringAllItemsToMainFire()
        ApocLibrary:Notify({
            Title = "🎯 ITEM TROLL ACTIVATED!",
            Content = "All items are being brought to main fire in batches of 20!",
            Duration = 5,
            Image = 4483362458,
        })
    end
})

-- Credits Section Content
CreditsTab:CreateLabel("Developer: Toasty")
CreditsTab:CreateLabel("Thank you for using this script!")

CreditsTab:CreateButton({
    Name = "📋 Copy Discord Link",
    Callback = function()
        setclipboard("https://discord.gg/DYNb3eHE")
        ApocLibrary:Notify({
            Title = "Discord Link Copied!",
            Content = "Discord link has been copied to clipboard",
            Duration = 3,
            Image = 4483362458,
        })
    end
})

CreditsTab:CreateLabel("Found a bug or have suggestions?")
CreditsTab:CreateLabel("Don't hesitate to report them on Discord!")
CreditsTab:CreateLabel("💡 Use Transport To: Player if the scrapper gets stuck")

-- Initial application (in case character already spawned)
task.delay(0.1, function()
    UpdateAll()
    SetupInfiniteJump()
end)

-- Initial chest dropdown population
task.delay(1, function()
    UpdateAllChestDropdowns()
end)
