
local TAILORING_CLOAK_ENCHANTS = {
  "Lightweave", "Swordguard", "Darkglow", "Embroidery",
  "Master's Inscription", "Shadowleather", "Zebraweave",
  "Glorious Stats", "Superior Intellect"
}

local SHIELD_ENHANCEMENTS = {
  "Shield Spike",                -- generic
  "Ghost Iron Shield Spike",
  "Eternal Earthshield Spike",
  "Titanium Plating",
  "Vitality",
  "Block",
  "Spirit",
  "Intellect",
  "Minor Stamina",
  "Stamina",
  "Resilience",
  "Resistance",
  "when you block",
  "Deals damage"
}

-- Existing setup
local SLOT_FRAMES = {
  [1] = "CharacterHeadSlot",
  [3] = "CharacterShoulderSlot",
  [5] = "CharacterChestSlot",
  [6] = "CharacterWaistSlot",
  [7] = "CharacterLegsSlot",
  [8] = "CharacterFeetSlot",
  [9] = "CharacterWristSlot",
  [10] = "CharacterHandsSlot",
  [11] = "CharacterFinger0Slot",
  [12] = "CharacterFinger1Slot",
  [15] = "CharacterBackSlot",
  [16] = "CharacterMainHandSlot",
  [17] = "CharacterSecondaryHandSlot"
}

local labels = {}
local frame = CreateFrame("Frame")

local function hasProfession(id)
  local prof1, prof2 = GetProfessions()
  for _, prof in ipairs({prof1, prof2}) do
    if prof then
      local _, _, _, _, _, _, profID = GetProfessionInfo(prof)
      if profID == id then return true end
    end
  end
  return false
end

local function getEnchantIDFromLink(link)
  if not link then return nil end
  local enchantID = link:match("Hitem:%d+:(%d+):")
  return enchantID
end

local tooltip = CreateFrame("GameTooltip", "MissingEnhancementsScannerTooltip", nil, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function tooltipContains(slot, phrases)
  tooltip:ClearLines()
  tooltip:SetInventoryItem("player", slot)

  for i = 2, tooltip:NumLines() do
    local line = _G["MissingEnhancementsScannerTooltipTextLeft" .. i]
    if line then
      local text = line:GetText()
      if text then
        for _, phrase in ipairs(phrases) do
          if text:find(phrase) then
            return true
          end
        end
      end
    end
  end
  return false
end

local function isBeltMissingTinker()
  return not tooltipContains(6, { "Tinker", "Use:" })
end

local function isCloakMissingTailoring()
  return not tooltipContains(15, TAILORING_CLOAK_ENCHANTS)
end

local function isShield()
  local link = GetInventoryItemLink("player", 17)
  if not link then return false end
  local _, _, _, _, _, itemType, itemSubType = GetItemInfo(link)
  return itemType == "Armor" and itemSubType == "Shields"
end

local function isShieldMissingEnhancement()
  local link = GetInventoryItemLink("player", 17)
  local enchantID = getEnchantIDFromLink(link)
  return enchantID == nil or enchantID == "0" or enchantID == ""
end


local function isWeaponMissingEnchant(slotID)
  local link = GetInventoryItemLink("player", slotID)
  local enchant = getEnchantIDFromLink(link)
  return enchant == nil or enchant == "0" or enchant == ""
end

local function isSlotEnchantRequired(slotID, level)
  if slotID == 1 and level > 80 then
    return false
  end
  return true
end

local function isSlotMissingEnchant(slotID)
  local link = GetInventoryItemLink("player", slotID)
  local enchant = getEnchantIDFromLink(link)
  return enchant == nil or enchant == "0" or enchant == ""
end

local function clearLabels()
  for _, fontString in pairs(labels) do
    fontString:Hide()
  end
end

local function updateTextLabels()
  clearLabels()

  local level = UnitLevel("player")
  local isEngineer = hasProfession(202)
  local isEnchanter = hasProfession(333)
  local isTailor = hasProfession(197)

  for slotID, frameName in pairs(SLOT_FRAMES) do
    local slotFrame = _G[frameName]
    if slotFrame then
      local itemLink = GetInventoryItemLink("player", slotID)
      if itemLink then
        local needsLabel = false
        local labelText = ""

        if slotID == 6 and isEngineer then
          if isBeltMissingTinker() then
            needsLabel = true
            labelText = "Missing Tinker"
          end
        elseif (slotID == 11 or slotID == 12) and isEnchanter then
          if isSlotMissingEnchant(slotID) then
            needsLabel = true
            labelText = "Missing Enchant"
          end
        elseif slotID == 15 and isTailor then
          if isCloakMissingTailoring() then
            needsLabel = true
            labelText = "Missing Embroidery"
          end
        elseif slotID == 16 then
          if isWeaponMissingEnchant(16) then
            needsLabel = true
            labelText = "Missing Weapon Enchant"
          end
        elseif slotID == 17 then
          if isShield() then
            if isShieldMissingEnhancement() then
              needsLabel = true
              labelText = "Missing Shield Enchant"
            end
          else
            if isWeaponMissingEnchant(17) then
              needsLabel = true
              labelText = "Missing Weapon Enchant"
            end
          end
        elseif slotID ~= 6 and slotID ~= 11 and slotID ~= 12 and slotID ~= 15 and slotID ~= 16 and slotID ~= 17 then
          if isSlotEnchantRequired(slotID, level) and isSlotMissingEnchant(slotID) then
            needsLabel = true
            labelText = "Missing Enchant"
          end
        end

        if needsLabel then
          if not labels[slotID] then
            local text = slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetTextColor(1, 0.1, 0.1, 1)
            text:SetScale(0.9)
            text:SetShadowColor(0, 0, 0, 1)
            text:SetShadowOffset(1, -1)
            labels[slotID] = text
          end

          local label = labels[slotID]
          label:SetText(labelText)
          label:ClearAllPoints()

          if slotID == 16 then
            label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
          elseif slotID == 17 then
            label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
          else
            if slotFrame:GetLeft() < CharacterFrame:GetWidth() / 2 then
              label:SetPoint("LEFT", slotFrame, "RIGHT", 4, 0)
            else
              label:SetPoint("RIGHT", slotFrame, "LEFT", -4, 0)
            end
          end

          label:Show()
        end
      end
    end
  end
end


local debounceTimer = nil

local function debouncedUpdate()
  if debounceTimer then
    debounceTimer:Cancel()
  end
  debounceTimer = C_Timer.NewTimer(0.2, function()
    if CharacterFrame:IsVisible() then
      updateTextLabels()
    end
  end)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
  if event == "PLAYER_LOGIN" then
    CharacterFrame:HookScript("OnShow", updateTextLabels)
  elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
    debouncedUpdate()
  end
end)

