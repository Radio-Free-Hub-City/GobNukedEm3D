-------------------------------------------------------------------------------
-- Gob Nuked 'Em 3D
-- Author: Ken Buckler - Radio Free Hub City
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 1. SAVED VARIABLES & DEFAULTS
-------------------------------------------------------------------------------
local DEFAULT_TRANSFORM_MH = { scale = 2.5, facing = 3.5, posX = 0.3, posY = 0.0, posZ = -0.2 }
local DEFAULT_TRANSFORM_OH = { scale = 2.5, facing = 2.8, posX = -0.3, posY = 0.0, posZ = -0.2 }

local function GetDefaultDB()
    return {
        mh_type = "GUN",
        mh_overrides = {},
        mh_transforms = {},
        oh_type = "MELEE_1H",
        oh_overrides = {},
        oh_transforms = {},
        enableBob = false,
        bobIntensity = 1.0,
        savedZoom = 0
    }
end

GobNukedEm3DDB = GobNukedEm3DDB or GetDefaultDB()

-------------------------------------------------------------------------------
-- 2. FULLSCREEN FRAME & DUAL MODELS & TOP BUTTONS
-------------------------------------------------------------------------------
local fpFrame = CreateFrame("Frame", "GobNukedEm3DOverlay", UIParent)
fpFrame:SetAllPoints(UIParent) 
fpFrame:SetFrameStrata("BACKGROUND")
fpFrame:Hide()

local mhModel = CreateFrame("DressUpModel", nil, fpFrame)
mhModel:SetAllPoints(fpFrame)

local ohModel = CreateFrame("DressUpModel", nil, fpFrame)
ohModel:SetAllPoints(fpFrame)

-- Toggle FPS Mode Button
local toggleBtn = CreateFrame("Button", "GobNukedEm3DToggle", UIParent, "UIPanelButtonTemplate")
toggleBtn:SetSize(150, 26)
toggleBtn:SetPoint("TOP", UIParent, "TOP", -80, -30)
toggleBtn:SetText("Toggle FPS Mode")

-- Configure FPS Mode Button
local configBtn = CreateFrame("Button", "GobNukedEm3DConfigBtn", UIParent, "UIPanelButtonTemplate")
configBtn:SetSize(150, 26)
configBtn:SetPoint("LEFT", toggleBtn, "RIGHT", 10, 0)
configBtn:SetText("Configure FPS Mode")

-------------------------------------------------------------------------------
-- 3. VISIBILITY & MOUNT CAMERA ENGINE
-------------------------------------------------------------------------------
local wasMountedState = false

local function UpdateStealthAlpha()
    if not fpFrame:IsShown() then return end
    
    local isStealthed = IsStealthed() or false
    local alphaVal = isStealthed and 0.35 or 1.0

    mhModel:SetAlpha(alphaVal)
    ohModel:SetAlpha(alphaVal)
end

local function UpdateMountVisibility()
    if not fpFrame:IsShown() then return end

    local isMounted = IsMounted() or UnitInVehicle("player") or UnitOnTaxi("player") or false

    if isMounted then
        if not wasMountedState then
            wasMountedState = true
            mhModel:Hide()
            ohModel:Hide()
            -- Zoom camera out for third-person mounted viewing
            CameraZoomOut(15)
        end
    else
        if wasMountedState then
            wasMountedState = false
            mhModel:Show()
            ohModel:Show()
            -- Restore first-person zoom upon dismounting
            CameraZoomIn(50)
        end
    end
end

-------------------------------------------------------------------------------
-- 4. SAFE MOVEMENT DETECTOR & ANIMATION ENGINE
-------------------------------------------------------------------------------
local mhAnimProgress = 0
local ohAnimProgress = 0
local bobTimer = 0
local swingPattern = 1
local activeHandToggle = true

local function IsPlayerMoving()
    local success, speed = pcall(GetUnitSpeed, "player")
    if success and speed and type(speed) == "number" then
        local safeCheck = pcall(function() return speed > 0 end)
        if safeCheck then return speed > 0 end
    end
    return IsFalling() or IsMouselooking() or false
end

local function GetActiveTransforms(isMH)
    local typeKey = isMH and "mh_type" or "oh_type"
    local transformsKey = isMH and "mh_transforms" or "oh_transforms"
    local defaultRef = isMH and DEFAULT_TRANSFORM_MH or DEFAULT_TRANSFORM_OH

    local currentType = GobNukedEm3DDB[typeKey] or (isMH and "GUN" or "MELEE_1H")
    GobNukedEm3DDB[transformsKey] = GobNukedEm3DDB[transformsKey] or {}
    
    if not GobNukedEm3DDB[transformsKey][currentType] then
        GobNukedEm3DDB[transformsKey][currentType] = {
            scale = defaultRef.scale,
            facing = defaultRef.facing,
            posX = defaultRef.posX,
            posY = defaultRef.posY,
            posZ = defaultRef.posZ,
        }
    end

    return GobNukedEm3DDB[transformsKey][currentType]
end

local function ApplyTransforms()
    GobNukedEm3DDB = GobNukedEm3DDB or GetDefaultDB()
    
    local mhType = GobNukedEm3DDB.mh_type or "GUN"
    local ohType = GobNukedEm3DDB.oh_type or "MELEE_1H"

    local mhT = GetActiveTransforms(true)
    local ohT = GetActiveTransforms(false)

    local mhScale, mhFacing, mhX, mhY, mhZ = mhT.scale, mhT.facing, mhT.posX, mhT.posY, mhT.posZ
    local ohScale, ohFacing, ohX, ohY, ohZ = ohT.scale, ohT.facing, ohT.posX, ohT.posY, ohT.posZ

    if GobNukedEm3DDB.enableBob and IsPlayerMoving() then
        local intensity = (GobNukedEm3DDB.bobIntensity or 1.0) * 0.03
        local bobX = math.sin(bobTimer * 8) * intensity
        local bobZ = math.abs(math.cos(bobTimer * 16)) * intensity

        mhX = mhX + bobX
        mhZ = mhZ + bobZ
        ohX = ohX - bobX
        ohZ = ohZ + bobZ
    end

    -- Mainhand Animations
    if mhAnimProgress > 0 and mhType ~= "NONE" then
        local p = mhAnimProgress
        if mhType == "GUN" then
            mhY = mhY - (p * 0.25)
            mhZ = mhZ + (p * 0.1)
        elseif mhType == "BOW" then
            mhY = mhY - (p * 0.15)
        elseif mhType == "MELEE_1H" then
            if swingPattern == 1 then
                mhX = mhX - (math.sin(p * math.pi) * 0.5)
                mhY = mhY + (math.sin(p * math.pi) * 0.2)
                mhZ = mhZ - (p * 0.25)
                mhFacing = mhFacing + (p * 0.6)
            elseif swingPattern == 2 then
                mhX = mhX + (math.sin(p * math.pi) * 0.45)
                mhY = mhY + (math.sin(p * math.pi) * 0.15)
                mhZ = mhZ + (p * 0.2)
                mhFacing = mhFacing - (p * 0.5)
            elseif swingPattern == 3 then
                mhY = mhY + (p * 0.4)
                mhZ = mhZ - (math.sin(p * math.pi) * 0.3)
                mhFacing = mhFacing + (p * 0.3)
            end
        elseif mhType == "MELEE_2H" then
            if swingPattern == 1 then
                mhX = mhX - (math.sin(p * math.pi) * 0.6)
                mhY = mhY + (math.cos(p * math.pi) * 0.2)
                mhZ = mhZ - (p * 0.1)
                mhFacing = mhFacing + (p * 0.8)
            elseif swingPattern == 2 then
                mhX = mhX + (math.sin(p * math.pi) * 0.5)
                mhY = mhY + (p * 0.15)
                mhZ = mhZ - (math.sin(p * math.pi) * 0.4)
                mhFacing = mhFacing - (p * 0.6)
            elseif swingPattern == 3 then
                mhY = mhY + (p * 0.3)
                mhZ = mhZ - (math.sin(p * math.pi) * 0.5)
                mhFacing = mhFacing + (p * 0.2)
            end
        elseif mhType == "MELEE_1H_CASTER" then
            if swingPattern == 1 then
                mhY = mhY + (p * 0.15)
                mhZ = mhZ + (p * 0.08)
            elseif swingPattern == 2 then
                mhZ = mhZ + (p * 0.2)
                mhFacing = mhFacing - (p * 0.3)
            elseif swingPattern == 3 then
                mhX = mhX - (p * 0.2)
                mhY = mhY + (p * 0.1)
            end
        elseif mhType == "STAFF" then
            if swingPattern == 1 then
                mhY = mhY + (p * 0.2)
            elseif swingPattern == 2 then
                mhY = mhY + (p * 0.15)
                mhZ = mhZ - (p * 0.25)
            elseif swingPattern == 3 then
                mhX = mhX - (p * 0.15)
                mhZ = mhZ + (p * 0.15)
                mhFacing = mhFacing + (p * 0.3)
            end
        elseif mhType == "SHIELD" then
            if swingPattern == 1 then
                mhY = mhY + (p * 0.2)
            elseif swingPattern == 2 then
                mhX = mhX - (p * 0.15)
                mhY = mhY + (p * 0.1)
            elseif swingPattern == 3 then
                mhZ = mhZ + (p * 0.18)
            end
        end
    end

    -- Offhand Animations
    if ohAnimProgress > 0 and ohType ~= "NONE" then
        local p = ohAnimProgress
        if ohType == "GUN" then
            ohY = ohY - (p * 0.25)
            ohZ = ohZ + (p * 0.1)
        elseif ohType == "MELEE_1H" then
            if swingPattern == 1 then
                ohX = ohX + (math.sin(p * math.pi) * 0.5)
                ohY = ohY + (math.sin(p * math.pi) * 0.2)
                ohZ = ohZ - (p * 0.25)
                ohFacing = ohFacing - (p * 0.6)
            elseif swingPattern == 2 then
                ohX = ohX - (math.sin(p * math.pi) * 0.45)
                ohY = ohY + (math.sin(p * math.pi) * 0.15)
                ohZ = ohZ + (p * 0.2)
                ohFacing = ohFacing + (p * 0.5)
            elseif swingPattern == 3 then
                ohY = ohY + (p * 0.4)
                ohZ = ohZ - (math.sin(p * math.pi) * 0.3)
                ohFacing = ohFacing - (p * 0.3)
            end
        elseif ohType == "MELEE_2H" then
            if swingPattern == 1 then
                ohX = ohX + (math.sin(p * math.pi) * 0.6)
                ohY = ohY + (math.cos(p * math.pi) * 0.2)
                ohZ = ohZ - (p * 0.1)
                ohFacing = ohFacing - (p * 0.8)
            elseif swingPattern == 2 then
                ohX = ohX - (math.sin(p * math.pi) * 0.5)
                ohY = ohY + (p * 0.15)
                ohZ = ohZ - (math.sin(p * math.pi) * 0.4)
                ohFacing = ohFacing + (p * 0.6)
            elseif swingPattern == 3 then
                ohY = ohY + (p * 0.3)
                ohZ = ohZ - (math.sin(p * math.pi) * 0.5)
                ohFacing = ohFacing - (p * 0.2)
            end
        elseif ohType == "MELEE_1H_CASTER" then
            if swingPattern == 1 then
                ohY = ohY + (p * 0.15)
                ohZ = ohZ + (p * 0.08)
            elseif swingPattern == 2 then
                ohZ = ohZ + (p * 0.2)
                ohFacing = ohFacing + (p * 0.3)
            elseif swingPattern == 3 then
                ohX = ohX + (p * 0.2)
                ohY = ohY + (p * 0.1)
            end
        elseif ohType == "STAFF" then
            if swingPattern == 1 then
                ohY = ohY + (p * 0.2)
            elseif swingPattern == 2 then
                ohY = ohY + (p * 0.15)
                ohZ = ohZ - (p * 0.25)
            elseif swingPattern == 3 then
                ohX = ohX + (p * 0.15)
                ohZ = ohZ + (p * 0.15)
                ohFacing = ohFacing - (p * 0.3)
            end
        elseif ohType == "SHIELD" then
            if swingPattern == 1 then
                ohY = ohY + (p * 0.2)
            elseif swingPattern == 2 then
                ohX = ohX + (p * 0.15)
                ohY = ohY + (p * 0.1)
            elseif swingPattern == 3 then
                ohZ = ohZ + (p * 0.18)
            end
        end
    end

    mhModel:SetModelScale(mhScale)
    mhModel:SetFacing(mhFacing)
    mhModel:SetPosition(mhY, mhX, mhZ)

    ohModel:SetModelScale(ohScale)
    ohModel:SetFacing(ohFacing)
    ohModel:SetPosition(ohY, ohX, ohZ)

    UpdateStealthAlpha()
end

mhModel:SetScript("OnModelLoaded", ApplyTransforms)
ohModel:SetScript("OnModelLoaded", ApplyTransforms)

fpFrame:SetScript("OnUpdate", function(self, elapsed)
    local updated = false

    if GobNukedEm3DDB.enableBob and IsPlayerMoving() then
        bobTimer = bobTimer + elapsed
        updated = true
    end

    if mhAnimProgress > 0 then
        mhAnimProgress = math.max(0, mhAnimProgress - (elapsed * 3.5))
        updated = true
    end

    if ohAnimProgress > 0 then
        ohAnimProgress = math.max(0, ohAnimProgress - (elapsed * 3.5))
        updated = true
    end

    if updated then
        ApplyTransforms()
    end
end)

local function TriggerAttackAnimation()
    local mhType = GobNukedEm3DDB.mh_type or "GUN"
    local ohType = GobNukedEm3DDB.oh_type or "MELEE_1H"

    local mhValid = (mhType ~= "NONE")
    local ohValid = (ohType ~= "NONE")

    if mhValid and ohValid then
        if activeHandToggle then
            mhAnimProgress = 1.0
        else
            ohAnimProgress = 1.0
        end
        activeHandToggle = not activeHandToggle
    elseif mhValid then
        mhAnimProgress = 1.0
    elseif ohValid then
        ohAnimProgress = 1.0
    end

    swingPattern = (swingPattern % 3) + 1
    ApplyTransforms()
end

-------------------------------------------------------------------------------
-- 5. CORE ITEM RENDERING LOGIC
-------------------------------------------------------------------------------
local function GetWeaponItemID(slotID)
    local isMH = (slotID == 16)
    local typeKey = isMH and "mh_type" or "oh_type"
    local overridesKey = isMH and "mh_overrides" or "oh_overrides"

    local currentType = GobNukedEm3DDB[typeKey] or (isMH and "GUN" or "MELEE_1H")
    
    if currentType == "NONE" then
        return nil
    end

    local overrides = GobNukedEm3DDB[overridesKey] or {}
    local overrideVal = overrides[currentType]

    if overrideVal and overrideVal ~= "" then
        local customID = tonumber(overrideVal) or GetItemInfoInstant(overrideVal)
        if customID then return customID end
    end

    if ItemSlotLocation and C_Transmog and C_Transmog.GetSlotInfo then
        local slotLoc = ItemSlotLocation:CreateFromEquipmentSlot(slotID)
        if slotLoc and slotLoc:IsValid() then
            local isTransmogrified, _, _, _, _, _, _, _, sourceID = C_Transmog.GetSlotInfo(slotLoc)
            if isTransmogrified and sourceID and sourceID > 0 then
                if C_TransmogCollection and C_TransmogCollection.GetSourceInfo then
                    local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
                    if sourceInfo and sourceInfo.itemID then
                        return sourceInfo.itemID
                    end
                end
            end
        end
    end

    return GetInventoryItemID("player", slotID)
end

local function RenderSlot(modelFrame, slotID)
    modelFrame:ClearModel()
    
    local isMH = (slotID == 16)
    local typeKey = isMH and "mh_type" or "oh_type"
    local overridesKey = isMH and "mh_overrides" or "oh_overrides"

    local currentType = GobNukedEm3DDB[typeKey] or (isMH and "GUN" or "MELEE_1H")
    if currentType == "NONE" then return end

    local overrides = GobNukedEm3DDB[overridesKey] or {}
    local overrideVal = overrides[currentType]

    if overrideVal and overrideVal ~= "" then
        local numVal = tonumber(overrideVal)
        if numVal then
            if numVal > 250000 then
                modelFrame:SetModel(numVal)
                return
            else
                modelFrame:SetItem(numVal)
                return
            end
        else
            local itemID = GetItemInfoInstant(overrideVal)
            if itemID then
                modelFrame:SetItem(itemID)
                return
            end
        end
    end

    local itemID = GetWeaponItemID(slotID)
    if itemID then
        modelFrame:SetItem(itemID)
    end
end

local function UpdateWeaponModels()
    if not fpFrame:IsShown() then return end
    RenderSlot(mhModel, 16)
    RenderSlot(ohModel, 17)
    C_Timer.After(0.05, ApplyTransforms)
end

-------------------------------------------------------------------------------
-- 6. FPS CONTROLS & CAMERA DYNAMICS
-------------------------------------------------------------------------------
local savedCVars = {}

local function EnableFPSControls()
    wasMountedState = false
    
    -- Record current 3rd-person zoom level to restore on exit
    GobNukedEm3DDB.savedZoom = GetCameraZoom()

    -- Save user's original CVar settings prior to entering FPS mode
    savedCVars.cameraSmoothStyle = GetCVar("cameraSmoothStyle")
    savedCVars.cameraTerrainTilt = GetCVar("cameraTerrainTilt")
    savedCVars.cameraMode = GetCVar("cameraMode")
    savedCVars.test_cameraDynamicPitch = GetCVar("test_cameraDynamicPitch")

    -- Enable dynamic FPS alignment CVars
    SetCVar("cameraSmoothStyle", 4)
    SetCVar("cameraTerrainTilt", 1)
    SetCVar("cameraMode", 1)
    SetCVar("test_cameraDynamicPitch", 1)

    -- Reset View 5 to default (facing directly forward behind player) and snap camera to it
    ResetView(5)
    SetView(5)

    -- Zoom directly in to 1st person perspective along character facing vector
    CameraZoomIn(50)

    fpFrame:Show()
    UpdateWeaponModels()
    UpdateStealthAlpha()
    UpdateMountVisibility()
end

local function DisableFPSControls()
    fpFrame:Hide()
    wasMountedState = false

    -- Restore original pre-FPS CVars
    if savedCVars.cameraSmoothStyle ~= nil then SetCVar("cameraSmoothStyle", savedCVars.cameraSmoothStyle) else SetCVar("cameraSmoothStyle", 1) end
    if savedCVars.cameraTerrainTilt ~= nil then SetCVar("cameraTerrainTilt", savedCVars.cameraTerrainTilt) else SetCVar("cameraTerrainTilt", 0) end
    if savedCVars.cameraMode ~= nil then SetCVar("cameraMode", savedCVars.cameraMode) else SetCVar("cameraMode", 0) end
    if savedCVars.test_cameraDynamicPitch ~= nil then SetCVar("test_cameraDynamicPitch", savedCVars.test_cameraDynamicPitch) else SetCVar("test_cameraDynamicPitch", 0) end

    -- Reset View 5 preset and zoom out to original third-person distance
    ResetView(5)
    if GobNukedEm3DDB.savedZoom and GobNukedEm3DDB.savedZoom > 0 then
        CameraZoomOut(GobNukedEm3DDB.savedZoom)
    end
end

local function ToggleFPSMode()
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[GobNukedEm3D]|r Cannot toggle FPS Mode while in combat!")
        return
    end

    if fpFrame:IsShown() then
        DisableFPSControls()
    else
        EnableFPSControls()
    end
end

-------------------------------------------------------------------------------
-- 7. TAINT-PROOF CUSTOM CONFIGURATION PANEL
-------------------------------------------------------------------------------
local configPanel = CreateFrame("Frame", "GobNukedEm3DConfig", UIParent)
configPanel:SetSize(340, 580)
configPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
configPanel:SetMovable(true)
configPanel:EnableMouse(true)
configPanel:RegisterForDrag("LeftButton")
configPanel:SetScript("OnDragStart", configPanel.StartMoving)
configPanel:SetScript("OnDragStop", configPanel.StopMovingOrSizing)
configPanel:Hide()

local bg = configPanel:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(configPanel)
bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

local border = configPanel:CreateTexture(nil, "BORDER")
border:SetPoint("TOPLEFT", configPanel, "TOPLEFT", -2, 2)
border:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", 2, -2)
border:SetColorTexture(0.3, 0.3, 0.3, 1)

local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 15, -12)
title:SetText("Gob Nuked 'Em 3D - Settings")

local closeBtn = CreateFrame("Button", nil, configPanel, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", -5, -5)

local currentTab = "MH"

local WEAPON_TYPES = {
    { text = "None / Hidden (No Animation)", value = "NONE" },
    { text = "Gun / Crossbow (Recoil)", value = "GUN" },
    { text = "Bow (Draw / Release)", value = "BOW" },
    { text = "1H Melee (Combo Swings)", value = "MELEE_1H" },
    { text = "1H Melee / Caster (Pulses)", value = "MELEE_1H_CASTER" },
    { text = "2H Melee (Combo Swings)", value = "MELEE_2H" },
    { text = "Staff / Wand (Cast Pulses)", value = "STAFF" },
    { text = "Shield / Offhand (Bashes)", value = "SHIELD" },
}

local dropdownLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
dropdownLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 30, -75)
dropdownLabel:SetText("Weapon Type (For Animations):")

local typeButton = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
typeButton:SetSize(280, 24)
typeButton:SetPoint("TOPLEFT", dropdownLabel, "BOTTOMLEFT", 0, -5)

local typeMenu = CreateFrame("Frame", nil, configPanel)
typeMenu:SetSize(280, 204)
typeMenu:SetPoint("TOPLEFT", typeButton, "BOTTOMLEFT", 0, -2)
typeMenu:SetFrameStrata("DIALOG")
typeMenu:Hide()

local menuBg = typeMenu:CreateTexture(nil, "BACKGROUND")
menuBg:SetAllPoints(typeMenu)
menuBg:SetColorTexture(0.1, 0.1, 0.1, 0.98)

local overrideLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
overrideLabel:SetPoint("TOPLEFT", typeButton, "BOTTOMLEFT", 0, -10)
overrideLabel:SetText("Custom Item ID / Link for Active Type:")

local overrideEditBox = CreateFrame("EditBox", "GN3D_OverrideInput", configPanel, "InputBoxTemplate")
overrideEditBox:SetSize(280, 22)
overrideEditBox:SetPoint("TOPLEFT", overrideLabel, "BOTTOMLEFT", 0, -5)
overrideEditBox:SetAutoFocus(false)

local RefreshUIValues -- Forward declaration

local function UpdateDropdownText()
    local typeKey = (currentTab == "MH") and "mh_type" or "oh_type"
    local currentVal = GobNukedEm3DDB[typeKey] or (currentTab == "MH" and "GUN" or "MELEE_1H")
    for _, item in ipairs(WEAPON_TYPES) do
        if item.value == currentVal then
            typeButton:SetText(item.text .. "  v")
            break
        end
    end
end

for i, item in ipairs(WEAPON_TYPES) do
    local btn = CreateFrame("Button", nil, typeMenu, "UIPanelButtonTemplate")
    btn:SetSize(260, 20)
    btn:SetPoint("TOPLEFT", typeMenu, "TOPLEFT", 10, -10 - ((i - 1) * 22))
    btn:SetText(item.text)
    btn:SetScript("OnClick", function()
        local isMH = (currentTab == "MH")
        local typeKey = isMH and "mh_type" or "oh_type"
        local overridesKey = isMH and "mh_overrides" or "oh_overrides"

        local oldType = GobNukedEm3DDB[typeKey] or (isMH and "GUN" or "MELEE_1H")
        GobNukedEm3DDB[overridesKey] = GobNukedEm3DDB[overridesKey] or {}
        GobNukedEm3DDB[overridesKey][oldType] = overrideEditBox:GetText():trim()

        GobNukedEm3DDB[typeKey] = item.value
        typeMenu:Hide()

        RefreshUIValues()
        UpdateWeaponModels()
    end)
end

typeButton:SetScript("OnClick", function()
    if typeMenu:IsShown() then typeMenu:Hide() else typeMenu:Show() end
end)

overrideEditBox:SetScript("OnEnterPressed", function(self)
    local isMH = (currentTab == "MH")
    local typeKey = isMH and "mh_type" or "oh_type"
    local overridesKey = isMH and "mh_overrides" or "oh_overrides"
    local currentType = GobNukedEm3DDB[typeKey] or (isMH and "GUN" or "MELEE_1H")

    GobNukedEm3DDB[overridesKey] = GobNukedEm3DDB[overridesKey] or {}
    GobNukedEm3DDB[overridesKey][currentType] = self:GetText():trim()

    self:ClearFocus()
    UpdateWeaponModels()
end)

local function CreateSlider(parent, name, label, minVal, maxVal, step, yOffset)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, yOffset)
    slider:SetSize(280, 20)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    _G[name .. "Low"]:SetText(tostring(minVal))
    _G[name .. "High"]:SetText(tostring(maxVal))
    return slider
end

local sScale = CreateSlider(configPanel, "GN3D_S_Scale", "Model Scale", 0.5, 6.0, 0.1, -200)
local sFacing = CreateSlider(configPanel, "GN3D_S_Facing", "Rotation / Facing", 0.0, 6.28, 0.05, -250)
local sPosX = CreateSlider(configPanel, "GN3D_S_PosX", "Position X (Left / Right)", -2.0, 2.0, 0.05, -300)
local sPosY = CreateSlider(configPanel, "GN3D_S_PosY", "Position Y (Depth)", -2.0, 2.0, 0.05, -350)
local sPosZ = CreateSlider(configPanel, "GN3D_S_PosZ", "Position Z (Up / Down)", -2.0, 2.0, 0.05, -400)

local bobCheck = CreateFrame("CheckButton", "GN3D_BobCheck", configPanel, "UICheckButtonTemplate")
bobCheck:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 30, -440)
_G[bobCheck:GetName() .. "Text"]:SetText(" Enable Walking Bobbing")

local sBobIntensity = CreateSlider(configPanel, "GN3D_S_BobIntensity", "Bob Intensity", 0.1, 3.0, 0.1, -490)

bobCheck:SetScript("OnClick", function(self)
    GobNukedEm3DDB.enableBob = self:GetChecked()
    ApplyTransforms()
end)

sBobIntensity:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value / 0.1 + 0.5) * 0.1
    GobNukedEm3DDB.bobIntensity = value
    GN3D_S_BobIntensityText:SetText("Bob Intensity: " .. string.format("%.1f", value))
    ApplyTransforms()
end)

RefreshUIValues = function()
    local isMH = (currentTab == "MH")
    local typeKey = isMH and "mh_type" or "oh_type"
    local overridesKey = isMH and "mh_overrides" or "oh_overrides"

    local currentType = GobNukedEm3DDB[typeKey] or (isMH and "GUN" or "MELEE_1H")
    GobNukedEm3DDB[overridesKey] = GobNukedEm3DDB[overridesKey] or {}

    overrideEditBox:SetText(GobNukedEm3DDB[overridesKey][currentType] or "")
    UpdateDropdownText()

    bobCheck:SetChecked(GobNukedEm3DDB.enableBob == true)

    local valBob = GobNukedEm3DDB.bobIntensity or 1.0
    sBobIntensity:SetValue(valBob)
    GN3D_S_BobIntensityText:SetText("Bob Intensity: " .. string.format("%.1f", valBob))

    local transform = GetActiveTransforms(isMH)

    sScale:SetValue(transform.scale)
    GN3D_S_ScaleText:SetText("Model Scale: " .. string.format("%.2f", transform.scale))

    sFacing:SetValue(transform.facing)
    GN3D_S_FacingText:SetText("Rotation / Facing: " .. string.format("%.2f", transform.facing))

    sPosX:SetValue(transform.posX)
    GN3D_S_PosXText:SetText("Position X (Left / Right): " .. string.format("%.2f", transform.posX))

    sPosY:SetValue(transform.posY)
    GN3D_S_PosYText:SetText("Position Y (Depth): " .. string.format("%.2f", transform.posY))

    sPosZ:SetValue(transform.posZ)
    GN3D_S_PosZText:SetText("Position Z (Up / Down): " .. string.format("%.2f", transform.posZ))
end

configPanel:SetScript("OnShow", RefreshUIValues)

local function BindSlider(slider, textGlobal, label, dbKey, step)
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        local isMH = (currentTab == "MH")
        local transform = GetActiveTransforms(isMH)
        
        transform[dbKey] = value
        _G[textGlobal]:SetText(label .. ": " .. string.format("%.2f", value))
        ApplyTransforms()
    end)
end

BindSlider(sScale, "GN3D_S_ScaleText", "Model Scale", "scale", 0.1)
BindSlider(sFacing, "GN3D_S_FacingText", "Rotation / Facing", "facing", 0.05)
BindSlider(sPosX, "GN3D_S_PosXText", "Position X (Left / Right)", "posX", 0.05)
BindSlider(sPosY, "GN3D_S_PosYText", "Position Y (Depth)", "posY", 0.05)
BindSlider(sPosZ, "GN3D_S_PosZText", "Position Z (Up / Down)", "posZ", 0.05)

-- Tab Buttons
local mhTab = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
mhTab:SetSize(130, 24)
mhTab:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 30, -38)
mhTab:SetText("Mainhand (Right)")

local ohTab = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
ohTab:SetSize(130, 24)
ohTab:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", -30, -38)
ohTab:SetText("Offhand (Left)")

local function SelectTab(tab)
    currentTab = tab
    typeMenu:Hide()

    mhTab:Enable()
    ohTab:Enable()

    if tab == "MH" then mhTab:Disable() end
    if tab == "OH" then ohTab:Disable() end

    RefreshUIValues()
end

mhTab:SetScript("OnClick", function() SelectTab("MH") end)
ohTab:SetScript("OnClick", function() SelectTab("OH") end)

SelectTab("MH")

-- Reset Buttons
local resetHandBtn = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
resetHandBtn:SetSize(135, 22)
resetHandBtn:SetPoint("BOTTOMLEFT", configPanel, "BOTTOMLEFT", 25, 15)
resetHandBtn:SetText("Reset Current Hand")

local resetAllBtn = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
resetAllBtn:SetSize(135, 22)
resetAllBtn:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -25, 15)
resetAllBtn:SetText("Reset All Defaults")

resetHandBtn:SetScript("OnClick", function()
    local isMH = (currentTab == "MH")
    local typeKey = isMH and "mh_type" or "oh_type"
    local overridesKey = isMH and "mh_overrides" or "oh_overrides"
    local transformsKey = isMH and "mh_transforms" or "oh_transforms"

    GobNukedEm3DDB[typeKey] = isMH and "GUN" or "MELEE_1H"
    GobNukedEm3DDB[overridesKey] = {}
    GobNukedEm3DDB[transformsKey] = {}

    typeMenu:Hide()
    RefreshUIValues()
    UpdateWeaponModels()
end)

resetAllBtn:SetScript("OnClick", function()
    GobNukedEm3DDB = GetDefaultDB()
    typeMenu:Hide()
    RefreshUIValues()
    UpdateWeaponModels()
end)

-------------------------------------------------------------------------------
-- 8. SLASH COMMANDS & EVENT LISTENERS
-------------------------------------------------------------------------------
toggleBtn:SetScript("OnClick", ToggleFPSMode)

configBtn:SetScript("OnClick", function()
    if configPanel:IsShown() then
        configPanel:Hide()
    else
        configPanel:Show()
    end
end)

SLASH_GOBNUKED1 = "/gn3d"
SLASH_GOBNUKED2 = "/gobnuked"
SlashCmdList["GOBNUKED"] = function(msg)
    if msg == "config" or msg == "settings" or msg == "options" then
        if configPanel:IsShown() then configPanel:Hide() else configPanel:Show() end
    else
        ToggleFPSMode()
    end
end

-- Event frame for model updates, stealth changes, mount visibility & spellcast triggers
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("TRANSMOGRIFY_UPDATE")
eventFrame:RegisterEvent("TRANSMOGRIFY_SUCCESS")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UPDATE_STEALTH")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("VEHICLE_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == "GobNukedEm3D" then
        GobNukedEm3DDB = GobNukedEm3DDB or GetDefaultDB()
        GobNukedEm3DDB.mh_overrides = GobNukedEm3DDB.mh_overrides or {}
        GobNukedEm3DDB.oh_overrides = GobNukedEm3DDB.oh_overrides or {}
        GobNukedEm3DDB.mh_transforms = GobNukedEm3DDB.mh_transforms or {}
        GobNukedEm3DDB.oh_transforms = GobNukedEm3DDB.oh_transforms or {}
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 == "player" and fpFrame:IsShown() then
            TriggerAttackAnimation()
        end
    elseif event == "UPDATE_STEALTH" or (event == "UNIT_AURA" and arg1 == "player") then
        UpdateStealthAlpha()
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "VEHICLE_UPDATE" then
        UpdateMountVisibility()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" and arg1 ~= 16 and arg1 ~= 17 then
        return
    else
        if fpFrame:IsShown() then
            if event == "PLAYER_EQUIPMENT_CHANGED" or event == "TRANSMOGRIFY_SUCCESS" or event == "UNIT_INVENTORY_CHANGED" then
                C_Timer.After(0.25, UpdateWeaponModels)
            end
        end
    end
end)
