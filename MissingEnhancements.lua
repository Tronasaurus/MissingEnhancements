local fontStringPool = {}

local function getFontString(slotFrame)
  if #fontStringPool > 0 then
    local fs = table.remove(fontStringPool)
    fs:SetParent(slotFrame)
    return fs
  else
    return slotFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  end
end

local function recycleFontString(fs)
  fs:ClearAllPoints()
  fs:SetText("")
  fs:Hide()
  fs:SetParent(nil)
  table.insert(fontStringPool, fs)
end


local TAILORING_CLOAK_ENCHANTS = {
  "Lightweave", "Swordguard", "Darkglow", "Embroidery",
  "Master's Inscription", "Shadowleather", "Zebraweave",
  "Glorious Stats", "Superior Intellect"
}

local SHIELD_ENHANCEMENTS = {
  "Shield Spike", "Ghost Iron Shield Spike", "Eternal Earthshield Spike",
  "Titanium Plating", "Vitality", "Block", "Spirit", "Intellect",
  "Minor Stamina", "Stamina", "Resilience", "Resistance",
  "when you block", "Deals damage"
}

local ENGINEERING_TINKER_ENCHANT_IDS = {
  ["3599"] = true, ["3601"] = true, ["3603"] = true, ["4256"] = true,
  ["5473"] = true, ["5474"] = true, ["8503"] = true, ["8220"] = true,
  ["8243"] = true, ["9273"] = true
}

local SLOT_FRAMES = {
  [1] = "CharacterHeadSlot", [3] = "CharacterShoulderSlot",
  [5] = "CharacterChestSlot", [6] = "CharacterWaistSlot",
  [7] = "CharacterLegsSlot", [8] = "CharacterFeetSlot",
  [9] = "CharacterWristSlot", [10] = "CharacterHandsSlot",
  [11] = "CharacterFinger0Slot", [12] = "CharacterFinger1Slot",
  [15] = "CharacterBackSlot", [16] = "CharacterMainHandSlot",
  [17] = "CharacterSecondaryHandSlot"
}

local SLOT_IS_LEFT = {
  [1] = true, [3] = true, [5] = true, [6] = false, [7] = false,
  [8] = false, [9] = true, [10] = false, [11] = false, [12] = false,
  [15] = true, [16] = true, [17] = false
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
  local success = pcall(tooltip.SetInventoryItem, tooltip, "player", slot)
  if not success then return false end
  local lines = tooltip:NumLines()
  if lines == 0 then return false end
  for i = 2, math.min(lines, 30) do
    local line = _G["MissingEnhancementsScannerTooltipTextLeft" .. i]
    if line then
      local text = line:GetText()
      if text then
        text = text:lower()
        for _, phrase in ipairs(phrases) do
          if text:find(phrase:lower(), 1, true) then
            return true
          end
        end
      end
    end
  end
  return false
end

local function isBeltMissingTinker()
  local link = GetInventoryItemLink("player", 6)
  local enchantID = getEnchantIDFromLink(link)
  if ENGINEERING_TINKER_ENCHANT_IDS[enchantID] then return false end
  return not tooltipContains(6, {
    "Tinker", "Use:", "Nitro Boosts", "Synapse Springs", "Frag Belt",
    "Phase Fingers", "Flexweave", "Springy Arachnoweave", "EMP Generator",
    "Cardboard Assassin", "Spinal Healing Injector", "Goblin Glider"
  })
end


local function isCloakMissingTailoring()
  return not tooltipContains(15, TAILORING_CLOAK_ENCHANTS)
end

local function isCloakMissingTinker()
  return not tooltipContains(15, {
    "Tinker", "Use:", "Nitro Boosts", "Synapse Springs"
  })
end

local function isCloakMissingEnchant()
  local link = GetInventoryItemLink("player", 15)
  local enchant = getEnchantIDFromLink(link)
  return enchant == nil or enchant == "0" or enchant == ""
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
  for _, fontStrings in pairs(labels) do
    for _, fs in ipairs(fontStrings) do
      fs:Hide()
    end
  end
end

local function updateTextLabels()
  if not CharacterFrame:IsVisible() then return end

  clearLabels()
  labels = {}

  local level = UnitLevel("player")
  local isEngineer = hasProfession(202)
  local isEnchanter = hasProfession(333)
  local isTailor = hasProfession(197)

  for slotID, frameName in pairs(SLOT_FRAMES) do
    local slotFrame = _G[frameName]
    if slotFrame then
      local itemLink = GetInventoryItemLink("player", slotID)
      if itemLink then
        local labelList = {}

        if slotID == 6 and isEngineer and isBeltMissingTinker() then
          table.insert(labelList, "Missing Tinker")
        end

        if (slotID == 11 or slotID == 12) and isEnchanter and isSlotMissingEnchant(slotID) then
          table.insert(labelList, "Missing Enchant")
        end

        if slotID == 15 then
          if isTailor and isCloakMissingTailoring() then
            table.insert(labelList, "Missing Embroidery")
          end
          if isEngineer and isCloakMissingTinker() then
            table.insert(labelList, "Missing Tinker")
          end
          if isCloakMissingEnchant() then
            table.insert(labelList, "Missing Enchant")
          end
        end

        if slotID == 16 and isWeaponMissingEnchant(16) then
          table.insert(labelList, "Missing Weapon Enchant")
        end

        if slotID == 17 then
          if isShield() then
            if isShieldMissingEnhancement() then
              table.insert(labelList, "Missing Shield Enchant")
            end
          elseif isWeaponMissingEnchant(17) then
            table.insert(labelList, "Missing Weapon Enchant")
          end
        end

        if slotID ~= 6 and slotID ~= 11 and slotID ~= 12 and slotID ~= 15 and slotID ~= 16 and slotID ~= 17 then
          if isSlotEnchantRequired(slotID, level) and isSlotMissingEnchant(slotID) then
            table.insert(labelList, "Missing Enchant")
          end
        end

        if #labelList > 0 then
          labels[slotID] = {}

          for i, text in ipairs(labelList) do
            local label = getFontString(slotFrame)
            label:SetTextColor(1, 0.5, 0, 1)
            label:SetScale(0.9)
            label:SetShadowColor(0, 0, 0, 1)
            label:SetShadowOffset(1, -1)
            label:SetText(text)
            label:ClearAllPoints()

            local xOffset, point, relativePoint
            if slotID == 16 then
              point, relativePoint, xOffset = "RIGHT", "LEFT", 4
            elseif slotID == 17 then
              point, relativePoint, xOffset = "LEFT", "RIGHT", 4
            elseif SLOT_IS_LEFT[slotID] then
              point, relativePoint, xOffset = "LEFT", "RIGHT", 4
            else
              point, relativePoint, xOffset = "RIGHT", "LEFT", -4
            end

            local verticalOffset
            if slotID == 15 then
              local cloakOffsets = {
                ["Missing Embroidery"] = 10,
                ["Missing Tinker"]     = -2,
                ["Missing Enchant"]    = -14
              }
              verticalOffset = cloakOffsets[text] or 0
            else
              verticalOffset = (#labelList - i) * 10
            end

            if slotID == 15 then
              label:SetPoint("LEFT", slotFrame, "RIGHT", 4, verticalOffset)
            else
              label:SetPoint(point, slotFrame, relativePoint, xOffset, verticalOffset)
            end

            label:Show()
            table.insert(labels[slotID], label)
          end
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

frame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    CharacterFrame:HookScript("OnShow", updateTextLabels)
    CharacterFrame:HookScript("OnHide", clearLabels)
  elseif CharacterFrame:IsVisible() and (event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED") then
    debouncedUpdate()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if CharacterFrame:IsVisible() then
      debouncedUpdate()
    end
  end
end)
