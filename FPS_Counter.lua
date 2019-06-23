local addonName, _ = ...
local DEBUG = true
local Main = CreateFrame('FRAME')
local OptionsPanel = {}
local Utils = {}

-------------------------
--      Constants
-------------------------

local ADDON_DISPLAY_NAME = "FPS Counter"
local COLOR_YELLOW_RGB = { 1, 0.85, 0.02 }
local CUSTOM_STRING_FPS_PATTERN = "$fps"

-------------------------
--       Strings
-------------------------

local Strings = {}
Strings.welcomeMessage = [[FPS Counter: |cffffff00Welcome to FPS Counter!
The addon settings can be found in the interface options. Alternatively they can be opened directly with a right click on the FPS counter while holding the "Alt" key.|r]]
Strings.FPS_COUNTER_TOOLTIP_LINE_1 = "[Hold Alt + Left Mouse Button] drag frame"
Strings.FPS_COUNTER_TOOLTIP_LINE_2 = "[Alt + Right Mouse Button] open settings"
Strings.TOOLTIP_ANCHOR = "Sets the anchor point relative to the screen."
Strings.TOOLTIP_PIVOT = [[Sets the zero point of the frame.
If for example the value is set to "Top Left", the frame will grow to the right and bottom.]]

-------------------------
--      Settings
-------------------------

local DEFAULT_ACCOUNT_SETTINGS = {
  welcomeMessageShown = false
}

local DEFAULT_CHARACTER_SETTINGS = {
  useCharacterSettings = false
}

local DEFAULT_GENERAL_SETTINGS = {
  showTooltip = true, -- TODO: disable mouse input on no tooltip and no modifier key pressed
  refreshInterval = 0.5,
  useTextFormat = false,
  textFormat = "FPS: "..CUSTOM_STRING_FPS_PATTERN,
  strata = 'TOOLTIP',
  anchor = 'TOPLEFT',
  pivot = 'TOPLEFT',
  offsetX = 2,
  offsetY = -2,
  decimals = 0,
  textAlignment = 'LEFT',
  font = 'Fonts\\FRIZQT__.TTF',
  fontSize = 10,
  fontColor = { r = COLOR_YELLOW_RGB[1], g = COLOR_YELLOW_RGB[2], b = COLOR_YELLOW_RGB[3], a = 1 },
  fontFlagOutline = false,
  fontFlagThickOutline = false,
  fontFlagMonochrome = false,
}

local TEXT_CALC_RELATED_SETTINGS = {
  'useTextFormat',
  'textFormat',
  'decimals',
  'fontSize',
  'fontFlagOutline',
  'fontFlagThickOutline',
  'fontFlagMonochrome'
}

local Settings = {}
Settings.account = nil
Settings.character = nil
Settings.general = nil
Settings.broadcastChanges = true
Settings.notBroadcastedSettings = {}

function Settings:Init()
  FPSCOUNTER_ACCOUNT_SETTINGS = FPSCOUNTER_ACCOUNT_SETTINGS or {}
  FPSCOUNTER_CHARACTER_SETTINGS = FPSCOUNTER_CHARACTER_SETTINGS or {}
  FPSCOUNTER_GENERAL_SETTINGS_ACCOUNT = FPSCOUNTER_GENERAL_SETTINGS_ACCOUNT or {}
  FPSCOUNTER_GENERAL_SETTINGS_CHARACTER = FPSCOUNTER_GENERAL_SETTINGS_CHARACTER or {}
  
  setmetatable(FPSCOUNTER_ACCOUNT_SETTINGS, { __index = DEFAULT_ACCOUNT_SETTINGS })
  self.account = FPSCOUNTER_ACCOUNT_SETTINGS
  
  setmetatable(FPSCOUNTER_CHARACTER_SETTINGS, { __index = DEFAULT_CHARACTER_SETTINGS })
  self.character = FPSCOUNTER_CHARACTER_SETTINGS
  
  if FPSCOUNTER_CHARACTER_SETTINGS.useCharacterSettings then
    setmetatable(FPSCOUNTER_GENERAL_SETTINGS_CHARACTER, { __index = DEFAULT_GENERAL_SETTINGS })
    self.general = FPSCOUNTER_GENERAL_SETTINGS_CHARACTER
  else
    setmetatable(FPSCOUNTER_GENERAL_SETTINGS_ACCOUNT, { __index = DEFAULT_GENERAL_SETTINGS })
    self.general = FPSCOUNTER_GENERAL_SETTINGS_ACCOUNT
  end
  
  setmetatable(Settings, { __index = Settings.Get, __newindex = Settings.Set })
end

function Settings:OnSerializationTypeChanged()
  if self.useCharacterSettings then
    FPSCOUNTER_GENERAL_SETTINGS_CHARACTER = Utils:TableDeepCopy(FPSCOUNTER_GENERAL_SETTINGS_ACCOUNT)
  end
  self:Init()
  OptionsPanel:RefreshAllValues()
  Main:UpdateSettings(true)
end

function Settings:Get(aKey)
  local val = self.general[aKey]
  if val == nil then
    val = self.account[aKey]
  end
  if val == nil then
    val = self.character[aKey]
  end
  if DEBUG and val == nil then
    error('Setting '..aKey..' does not exist')
  end
  return val
end

function Settings:Set(aKey, aValue)
  local oldVal = nil
  if self.general[aKey] ~= nil then
    oldVal = self.general[aKey]
    self.general[aKey] = aValue
  elseif self.account[aKey] ~= nil then
    oldVal = self.account[aKey]
    self.account[aKey] = aValue
  elseif self.character[aKey] ~= nil then
    oldVal = self.character[aKey]
    self.character[aKey] = aValue
  elseif DEBUG then
    error('Setting '..aKey..' does not exist')
  end
  if aValue ~= oldVal then
    if self.broadcastChanges then
      Main:UpdateSettings(tContains(TEXT_CALC_RELATED_SETTINGS, aKey))
    else
      tinsert(self.notBroadcastedSettings, aKey)
    end
  end
end

function Settings:BeginBulkEdit()
  self.broadcastChanges = false
end

function Settings:EndBulkEdit()
  self.broadcastChanges = true
  local recalc = false
  for _, v in ipairs(self.notBroadcastedSettings) do
    if tContains(TEXT_CALC_RELATED_SETTINGS, v) then
      recalc = true
      break
    end
  end
  Main:UpdateSettings(recalc)
end

-------------------------
--      Main Part
-------------------------

Main:SetScript('OnEvent', function(self, event, ...) self[event](self, ...) end)
Main:RegisterEvent('PLAYER_LOGIN')
Main.timeSinceLastUpdate = 0

local fpsCounter = CreateFrame('Frame', 'fpsCounter')
fpsCounter.text = nil
fpsCounter.textFormat = nil
fpsCounter.isMoving = false

function Main:PLAYER_LOGIN()
  self:UnregisterEvent('PLAYER_LOGIN')
  self['PLAYER_LOGIN'] = nil
  
  -- register events
  self:RegisterEvent('MODIFIER_STATE_CHANGED')
  self:SetScript('OnUpdate', self.OnUpdate)
  
  -- init settings
  Settings:Init()
  
  -- init options panel
  OptionsPanel:Init()
  
  -- setup fps frame
  self:SetupFpsCounter()
  
  -- load settings
  self:UpdateSettings(true)
  
  -- show welcome message
  if not Settings.welcomeMessageShown then
    Settings.welcomeMessageShown = true
    print(Strings.welcomeMessage)
  end
end

function Main:OnUpdate(aElapsed)
  self.timeSinceLastUpdate = self.timeSinceLastUpdate + aElapsed
  if self.timeSinceLastUpdate < Settings.refreshInterval then
    return
  end
  self.timeSinceLastUpdate = 0
  
  -- update fps counter
  self:UpdateFramerate()
end

function Main:MODIFIER_STATE_CHANGED(aKey, aNewState)
  if aKey == 'LALT' then
    Modifier_Key_Active = aNewState == 1
    fpsCounter:SetMovable(Modifier_Key_Active)
    if not state then
      fpsCounter:StopMovingOrSizing()
    end
  end
end

function Main:SetupFpsCounter()
  -- setup click
  fpsCounter:SetScript('OnMouseUp', function(self, aButton)
    -- open options panel on rightclick
    if aButton == 'RightButton' then
      if Modifier_Key_Active then
        OptionsPanel:Show()
      end
    end
  end)
  
  -- setup dragging
  fpsCounter:RegisterForDrag('LeftButton')
  fpsCounter:SetScript('OnDragStart', function()
    if fpsCounter:IsMovable() then
      fpsCounter:StartMoving()
      fpsCounter.isMoving = true
      GameTooltip:Hide()
    end
  end)
  
  fpsCounter:SetScript('OnDragStop', function()
    fpsCounter:StopMovingOrSizing()
    fpsCounter.isMoving = false
    -- save pos
    local pivot, _, anchor, offsetX, offsetY = fpsCounter:GetPoint()
    Settings:BeginBulkEdit()
    Settings.pivot = pivot
    Settings.anchor = anchor
    Settings.offsetX = Round(offsetX)
    Settings.offsetY = Round(offsetY)
    Settings:EndBulkEdit()
    -- update options panel
    OptionsPanel:RefreshAllValues()
  end)
  
  -- setup tooltip
  fpsCounter:SetScript('OnEnter', function()
    if fpsCounter.isMoving or not Settings.showTooltip then
      return
    end
    GameTooltip:SetOwner(fpsCounter, 'ANCHOR_PRESERVE')
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint('TOPLEFT', fpsCounter, 'BOTTOM')
    GameTooltip:AddLine(ADDON_DISPLAY_NAME, 1, 1, 1)
    GameTooltip:AddLine(Strings.FPS_COUNTER_TOOLTIP_LINE_1)
    GameTooltip:AddLine(Strings.FPS_COUNTER_TOOLTIP_LINE_2)
    GameTooltip:Show()
  end)
  fpsCounter:SetScript('OnLeave', function()
    GameTooltip:Hide()
  end)
  
  -- create fontstring
  fpsCounter.text = fpsCounter:CreateFontString(nil, 'OVERLAY', GameFontNormal)
  fpsCounter.text:ClearAllPoints()
  fpsCounter.text:SetPoint('TOPLEFT', fpsCounter)
  fpsCounter.text:SetPoint('BOTTOMRIGHT', fpsCounter)
  fpsCounter.text:SetJustifyV('TOP')
end

function Main:UpdateSettings(aRecalculateText)
  -- strata
  fpsCounter:SetFrameStrata(Settings.strata)
  
  -- pos
  local _, relativeTo = fpsCounter:GetPoint()
  fpsCounter:ClearAllPoints()
  fpsCounter:SetPoint(Settings.pivot, relativeTo, Settings.anchor, Settings.offsetX, Settings.offsetY)
  
  -- font
  local flags = {}
  if Settings.fontFlagOutline then tinsert(flags, 'OUTLINE') end
  if Settings.fontFlagThickOutline then tinsert(flags, 'THICKOUTLINE') end
  if Settings.fontFlagMonochrome then tinsert(flags, 'MONOCHROME') end
  fpsCounter.text:SetFont(Settings.font, Settings.fontSize, table.concat(flags, ', '))
  
  -- font color
  local c = Settings.fontColor
  fpsCounter.text:SetTextColor(c.r, c.g, c.b, c.a)
  
  -- text alignment
  fpsCounter.text:SetJustifyH(Settings.textAlignment)
  
  if aRecalculateText then
    -- text format
    local textFormat = nil
    if Settings.useTextFormat then
      -- TODO: error message when pattern not found
      fpsCounter.textFormat = Settings.textFormat
    else
      fpsCounter.textFormat = nil
    end
    
    -- adjust fontstring width
    fpsCounter:SetSize(999, 999)
    local str = "0000"
    if Settings.decimals > 0 then
      str = string.format("%s.%s", str, string.rep("0", Settings.decimals))
    end
    if fpsCounter.textFormat then
      str = fpsCounter.textFormat:gsub(CUSTOM_STRING_FPS_PATTERN, str)
    end
    fpsCounter.text:SetText(str)
    fpsCounter:SetSize(fpsCounter.text:GetStringWidth(), fpsCounter.text:GetStringHeight())
    
    -- update text
    self:UpdateFramerate()
  end
end

function Main:UpdateFramerate()
  local fps = Settings.decimals > 0
    and (("%%.%df"):format(Settings.decimals)):format(GetFramerate())
    or Round(GetFramerate())
    if fpsCounter.textFormat then
      fps = fpsCounter.textFormat:gsub(CUSTOM_STRING_FPS_PATTERN, fps)
    end
  fpsCounter.text:SetText(fps)
end

-------------------------
--    OPTIONS PANEL
-------------------------

local dropdownMenuFramePoint = {
  { text = "Center", value = 'CENTER' },
  { text = "Top Left", value = 'TOPLEFT' },
  { text = "Top", value = 'TOP' },
  { text = "Top Right", value = 'TOPRIGHT' },
  { text = "Right", value = 'RIGHT' },
  { text = "Bottom Right", value = 'BOTTOMRIGHT' },
  { text = "Bottom", value = 'BOTTOM' },
  { text = "Bottom Left", value = 'BOTTOMLEFT' },
  { text = "Left", value = 'LEFT' }
}

local dropdownMenuFrameStrata = {
  { text = "Background", value = 'BACKGROUND' },
  { text = "Low", value = 'LOW' },
  { text = "Medium", value = 'MEDIUM' },
  { text = "High", value = 'HIGH' },
  { text = "Dialog", value = 'DIALOG' },
  { text = "Fullscreen", value = 'FULLSCREEN' },
  { text = "Fullscreen Dialog", value = 'FULLSCREEN_DIALOG' },
  { text = "Tooltip", value = 'TOOLTIP' }
}

local dropdownMenuTextAlignment = {
  { text = "Left", value = 'LEFT' },
  { text = "Center", value = 'CENTER' },
  { text = "Right", value = 'RIGHT' }
}

local dropdownMenuFont = {
  { text = "FRIZQT__.tff", value = 'Fonts\\FRIZQT__.TTF' },
  { text = "SKURRI.ttf", value = 'Fonts\\SKURRI.ttf' },
  { text = "ARIALN.TTF", value = 'Fonts\\ARIALN.TTF' },
  { text = "MORPHEUS.ttf", value = 'Fonts\\MORPHEUS.ttf' }
}

local DEFAULT_WIDGET_SETTINGS = {
  parent = nil,
  point = 'TOPLEFT',
  posX = 20,
  posY = -20,
  scale = 1
}

local function InvokeCallback(aCallback)
  if aCallback ~= nil then
    aCallback()
  end
end

OptionsPanel.createdFrames = {}

function OptionsPanel:Init()
  self.categoryName = ADDON_DISPLAY_NAME

  self.frame = CreateFrame('Frame', nil, UIParent)
  self.frame.name = self.categoryName
  
  local widgetSettings = Utils:TableShallowCopy(DEFAULT_WIDGET_SETTINGS)
  widgetSettings.parent = self.frame
  
  local resWidth, resHeight = Utils:GetResolution()
  local sliderMaxCenteredFrameX = math.ceil(resWidth / 2)
  local sliderMinCenteredFrameX = sliderMaxCenteredFrameX * -1
  local sliderMaxCenteredFrameY = math.ceil(resHeight / 2)
  local sliderMinCenteredFrameY = sliderMaxCenteredFrameY * -1
  
  self:AddHeadline("General", widgetSettings)
  self:AddCheckButton('useCharacterSettings', "Save settings only \nfor this character", nil, widgetSettings, function() Settings:OnSerializationTypeChanged() end)
  self:AddCheckButton('showTooltip', "Show tooltip on hover", nil, widgetSettings)
  self:AddSlider('refreshInterval', "Refresh Interval", nil, 0.01, 2, 2, widgetSettings)
  self:AddSlider('decimals', "Decimals", nil, 0, 4, 0, widgetSettings)
  self:AddCheckButton('useTextFormat', "Custom Text", nil, widgetSettings)
  widgetSettings.posY = widgetSettings.posY + 7
  self:AddEditBox('textFormat', nil, nil, false, 145, widgetSettings)
  
  widgetSettings.posX = widgetSettings.posX + 190
  widgetSettings.posY = DEFAULT_WIDGET_SETTINGS.posY
  self:AddHeadline("Font", widgetSettings)
  self:AddDropdown('font', "Font", nil, dropdownMenuFont, 100, false, widgetSettings)
  self:AddCheckButton('fontFlagOutline', "Outline", nil, widgetSettings)
  self:AddCheckButton('fontFlagThickOutline', "Thick Outline", nil, widgetSettings)
  self:AddCheckButton('fontFlagMonochrome', "Monochrome", nil, widgetSettings)
  self:AddSlider('fontSize', "Font Size", nil, 1, 150, 0, widgetSettings)
  self:AddColorPicker('fontColor', "Font Color", nil, true, widgetSettings)
  
  widgetSettings.posX = widgetSettings.posX + 230
  widgetSettings.posY = DEFAULT_WIDGET_SETTINGS.posY
  self:AddHeadline("Positioning", widgetSettings)
  self:AddDropdown('strata', "Layer", nil, dropdownMenuFrameStrata, 100, false, widgetSettings)
  self:AddDropdown('textAlignment', "Text Alignment", nil, dropdownMenuTextAlignment, 100, false, widgetSettings)
  self:AddDropdown('anchor', "Anchor", Strings.TOOLTIP_ANCHOR, dropdownMenuFramePoint, 100, false, widgetSettings)
  self:AddDropdown('pivot', "Zero point", Strings.TOOLTIP_PIVOT, dropdownMenuFramePoint, 100, false, widgetSettings)
  self:AddSlider('offsetX', "Offset X", nil, sliderMinCenteredFrameX, sliderMaxCenteredFrameX, 0, widgetSettings)
  self:AddSlider('offsetY', "Offset Y", nil, sliderMinCenteredFrameY, sliderMaxCenteredFrameY, 0, widgetSettings)
  
  InterfaceOptions_AddCategory(self.frame)
end

function OptionsPanel:RefreshAllValues()
  for _, v in ipairs(self.createdFrames) do
    if v.RefreshValue ~= nil then
      v:RefreshValue()
    end
  end
end

function OptionsPanel:Show()
  -- called twice because when interface settings where not opened before the category gets not selected
  InterfaceOptionsFrame_OpenToCategory(self.categoryName)
  InterfaceOptionsFrame_OpenToCategory(self.categoryName)
end

function OptionsPanel:AddHeadline(aText, aWidgetSettings)
  local fs = aWidgetSettings.parent:CreateFontString(nil, 'OVERLAY', GameFontNormal)
  fs:SetPoint(aWidgetSettings.point, aWidgetSettings.posX, aWidgetSettings.posY)
  fs:SetScale(aWidgetSettings.scale)
  fs:SetFont('Fonts\\FRIZQT__.TTF', 18, 'OUTLINE')
  fs:SetTextColor(unpack(COLOR_YELLOW_RGB))
  fs:SetText(aText)
  
  self:IncreasePosY(aWidgetSettings, fs, 10)
  return fs
end

function OptionsPanel:AddCheckButton(aSetting, aText, aTooltip, aWidgetSettings, aCallback)
  local id = self:MakeFrameId(aSetting)
  
  -- create frame
  local frame = CreateFrame('CheckButton', id, aWidgetSettings.parent, 'ChatConfigCheckButtonTemplate')
  frame:SetPoint(aWidgetSettings.point, aWidgetSettings.posX, aWidgetSettings.posY)
  frame:SetScale(aWidgetSettings.scale)
  frame:SetScript('OnClick', 
    function()
      Settings[aSetting] = frame:GetChecked()
      InvokeCallback(aCallback)
    end
  )
  
  -- setup refresh function
  frame.RefreshValue = function(self)
    self:SetChecked(Settings[aSetting])
  end
  frame:RefreshValue()
  
  -- set text
  if not Utils:StrIsNilOrEmpty(aText) then
    getglobal(frame:GetName().. 'Text'):SetText(aText)
  end
  
  -- set tooltip
  if not Utils:StrIsNilOrEmpty(aTooltip) then
    frame.tooltip = aTooltip
  end
  
  -- increase pos for next frame
  self:IncreasePosY(aWidgetSettings, frame)
  
  self:OnFrameCreated(frame)
  return frame
end

function OptionsPanel:AddEditBox(aSetting, aText, aTooltip, aIsNumeric, aWidth, aWidgetSettings, aCallback)
  local id = self:MakeFrameId(aSetting)
  
  -- add extra space
  if aText then
    aWidgetSettings.posY = aWidgetSettings.posY - 15
  end
  
  -- create frame
  local editBox = CreateFrame('EditBox', id, aWidgetSettings.parent, 'InputBoxTemplate')
  editBox:ClearAllPoints()
  editBox:SetPoint(aWidgetSettings.point, aWidgetSettings.posX + 7, aWidgetSettings.posY)
  editBox:SetSize(aWidth, 30)
  editBox:SetScale(aWidgetSettings.scale)
  editBox:SetAutoFocus(false)
  if aIsNumeric then
    editBox:SetNumeric()
  end
  
  -- setup scripts
  local function SaveValue(self)
    Settings[aSetting] = aIsNumeric and Utils:Round(self:GetNumber()) or self:GetText()
    self:ClearFocus()
    InvokeCallback(aCallback)
  end
  editBox:SetScript('OnEnterPressed', SaveValue)
  editBox:SetScript('OnEditFocusLost', SaveValue)
  
  -- setup refresh function
  editBox.RefreshValue = function(self)
    if aIsNumeric then
      self:SetNumber(Utils:Round(Settings[aSetting]))
    else
      self:SetText(Settings[aSetting])
    end
    self:SetCursorPosition(0)
  end
  editBox:RefreshValue()
  
  -- add fontstring
  if not Utils:StrIsNilOrEmpty(aText) then
    editBox.fontString = editBox:CreateFontString(id..'fs', 'OVERLAY', GameFontNormal)
    editBox.fontString:SetPoint('TOPLEFT', editBox, -3, 10)
    editBox.fontString:SetFont('Fonts\\FRIZQT__.TTF', 12)
    editBox.fontString:SetText(aText)
  end
  
  -- increase pos for next frame
  self:IncreasePosY(aWidgetSettings, editBox)
  
  self:OnFrameCreated(editBox)
  return editBox
end

function OptionsPanel:AddSlider(aSetting, aText, aTooltip, aMinVal, aMaxVal, aDecimals, aWidgetSettings, aCallback)
  local id = self:MakeFrameId(aSetting)
  
  -- add extra space
  aWidgetSettings.posY = aWidgetSettings.posY - 15
  
  -- create frame for slider
  local slider = CreateFrame('Slider', id..'sl', aWidgetSettings.parent, 'OptionsSliderTemplate')
  slider:SetPoint(aWidgetSettings.point, aWidgetSettings.posX + 5, aWidgetSettings.posY)
  slider:SetScale(aWidgetSettings.scale)
  slider:SetMinMaxValues(aMinVal, aMaxVal)
  
  -- create frame for edit box
  slider.editBox = CreateFrame('EditBox', id..'eb', slider, 'InputBoxTemplate')
  slider.editBox:SetSize(50, 30)
  slider.editBox:ClearAllPoints()
  slider.editBox:SetPoint('TOP', slider, 'BOTTOM', 0, 5)
  slider.editBox:SetAutoFocus(false)
  slider.editBox:SetNumeric()
  
  -- setup refresh function
  slider.RefreshValue = function(self)
    local val = Settings[aSetting]
    self:SetValue(val)
    self.editBox:SetNumber(val)
    self.editBox:SetCursorPosition(0)
  end
  slider:RefreshValue()
  
  -- setup scripts
  slider:SetScript('OnValueChanged', function(self, aValue)
    local val = Utils:Round(aValue, aDecimals)
    self.editBox:SetNumber(val)
    Settings[aSetting] = val
    InvokeCallback(aCallback)
  end)
  slider.editBox:SetScript('OnEnterPressed', function(self)
    local val = Utils:Round(self:GetNumber(), aDecimals)
    self:GetParent():SetValue(val)
    self:ClearFocus()
    self:SetNumber(val)
  end)
  
  -- override slider texts
  getglobal(slider:GetName()..'Low'):SetText(aMinVal)
  getglobal(slider:GetName()..'High'):SetText(aMaxVal)
  getglobal(slider:GetName()..'Text'):SetText(aText)
  
  -- set tooltip
  if not Utils:StrIsNilOrEmpty(aTooltip) then
    slider.tooltipText = aTooltip
  end
  
  -- increase pos for next frame
  self:IncreasePosY(aWidgetSettings, slider)
  self:IncreasePosY(aWidgetSettings, slider.editBox)
  
  self:OnFrameCreated(slider)
  return slider
end

function OptionsPanel:AddDropdown(aSetting, aText, aTooltip, aMenuList, aWidth, aIsBoolean, aWidgetSettings, aCallback)
  -- search in the MenuList for the display name of a value
  local function getSettingValueDisplayName(aMenuList, aValue, aIsBoolean)
    if aIsBoolean and type(aValue) == 'boolean' then
      aValue = aValue and 1 or 0
    end
    -- "enum" value
    for _, entry in pairs(aMenuList) do
      if entry.value == aValue then
        return entry.text
      end
    end
    return ''
  end

  local id = self:MakeFrameId(aSetting)
  
  -- add extra space
  aWidgetSettings.posY = aWidgetSettings.posY - 15
  
  -- create dropdown frame
  local dropdown = CreateFrame('Frame', id, aWidgetSettings.parent, 'UIDropDownMenuTemplate')
  dropdown:SetPoint(aWidgetSettings.point, aWidgetSettings.posX - 15, aWidgetSettings.posY)
  dropdown:SetScale(aWidgetSettings.scale)
  UIDropDownMenu_SetWidth(dropdown, aWidth)
  UIDropDownMenu_SetText(dropdown, getSettingValueDisplayName(aMenuList, Settings[aSetting], aIsBoolean))
  
  -- add fontstring
  dropdown.fontString = dropdown:CreateFontString(id..'fs', 'OVERLAY', GameFontNormal)
  dropdown.fontString:SetPoint('TOPLEFT', dropdown, 20, 10)
  dropdown.fontString:SetFont('Fonts\\FRIZQT__.TTF', 12)
  dropdown.fontString:SetText(aText)
  
  -- setup refresh function
  dropdown.RefreshValue = function(self)
    UIDropDownMenu_SetText(self, getSettingValueDisplayName(aMenuList, Settings[aSetting], aIsBoolean))
  end
  
  -- initialize dropdown
  UIDropDownMenu_Initialize(dropdown, function()
    -- iterate over all entries in the menuList
    for _, entry in pairs(aMenuList) do
      -- create dropdown ready table
      local info = UIDropDownMenu_CreateInfo()
      -- and copy all infos into it
      info = Utils:TableShallowCopy(entry)
      -- setup OnClick
      info.func = function(self, aArg1, aArg2, aChecked)
        -- save setting
        Settings[aSetting] = Utils:Ternary(aIsBoolean, Utils:Ternary(self.value == 1, true, false), self.value)
        
        -- refresh text
        UIDropDownMenu_SetText(dropdown, getSettingValueDisplayName(aMenuList, self.value))
        
        -- callback
        InvokeCallback(aCallback)
      end
      
      UIDropDownMenu_AddButton(info)
    end
  end, '', 1, aWidth)
  
  -- set tooltip
  if not Utils:StrIsNilOrEmpty(aTooltip) then
    dropdown:SetScript('OnEnter', function(self)
      GameTooltip:SetOwner(self, 'ANCHOR_TOP')
      GameTooltip:SetText(aTooltip, nil, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    dropdown:SetScript('OnLeave', function(self)
      GameTooltip:Hide()
    end)
  end
  
  -- increase pos for next frame
  self:IncreasePosY(aWidgetSettings, dropdown)
  
  self:OnFrameCreated(dropdown)
  return dropdown
end

function OptionsPanel:AddColorPicker(aSetting, aText, aTooltip, aShowAlpha, aWidgetSettings, aCallback)
  local id = self:MakeFrameId()
  
  -- add extra space
  aWidgetSettings.posY = aWidgetSettings.posY - 15
  
  -- create container for editboxes and button
  local frame = CreateFrame('Frame', id, aWidgetSettings.parent)
  frame:ClearAllPoints()
  frame:SetPoint(aWidgetSettings.point, aWidgetSettings.posX, aWidgetSettings.posY)
  frame:SetScale(aWidgetSettings.scale)
  
  -- add fontstring
  frame.fontString = frame:CreateFontString(id..'fs', 'OVERLAY', GameFontNormal)
  frame.fontString:SetPoint('TOPLEFT', frame, 5, 10)
  frame.fontString:SetFont('Fonts\\FRIZQT__.TTF', 12)
  frame.fontString:SetText(aText)
  
  local x = 7
  
  -- create pick color button
  frame.btn = CreateFrame('Button', id..'btn', frame, 'UIPanelButtonTemplate')
  frame.btn:SetText("Pick")
  frame.btn:SetPoint('LEFT', x - 5, 0)
  frame.btn:SetSize(frame.btn:GetTextWidth() + 15, 22)
  -- open color picker
  frame.btn:SetScript('OnClick', function()   
    -- setup callbacks
    local function OnChanged(aRestore)
      local r, g, b, a
      if not aRestore then
        -- color has changed
        r, g, b = ColorPickerFrame:GetColorRGB()
        a = OpacitySliderFrame:GetValue()
      else
        -- user hit cancel button
        r, g, b, a = unpack(aRestore)
      end
      -- round and clamp values
      r = Utils:Clamp(0, Utils:Round(r, 2), 1)
      g = Utils:Clamp(0, Utils:Round(g, 2), 1)
      b = Utils:Clamp(0, Utils:Round(b, 2), 1)
      a = Utils:Clamp(0, Utils:Round(1 - a, 2), 1)
      -- save
      Settings[aSetting] = { r = r, g = g, b = b, a = a }
      -- callback
      InvokeCallback(aCallback)
      -- refresh editboxes
      for _, eb in pairs(frame.editBoxes) do
        eb:RefreshValue()
      end
    end
    ColorPickerFrame.func = OnChanged
    ColorPickerFrame.opacityFunc = OnChanged
    ColorPickerFrame.cancelFunc = OnChanged
    
    -- setup rest and show
    local color = Settings[aSetting]
    ColorPickerFrame.hasOpacity = aShowAlpha
    ColorPickerFrame.opacity = 1 - color.a
    ColorPickerFrame.previousValues = { color.r, color.g, color.b, color.a };
    ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
    ColorPickerFrame:Hide() -- required to run the OnShow handler.
    ColorPickerFrame:Show()
  end)
  
  x = x + frame.btn:GetWidth() + 5
  
  -- create edit boxes
  local function AddEditBox(aTargetVal)
    -- create frame
    local editBox = CreateFrame('EditBox', id..'eb'..aTargetVal, frame, 'InputBoxTemplate')
    editBox:ClearAllPoints()
    editBox:SetPoint('LEFT', x, 0)
    editBox:SetSize(30, 30)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric()
    
    -- setup scripts
    local function SaveValue(self)
      local val = Utils:Clamp(0, Utils:Round(self:GetNumber(), 2), 1)
      -- assign new table, so that the setter will be triggered
      -- workaround should be okay for such a rare usecase
      local c = Utils:TableShallowCopy(Settings[aSetting])
      c[aTargetVal] = val
      Settings[aSetting] = c
      
      self:SetNumber(val)
      self:ClearFocus()
      
      InvokeCallback(aCallback)
    end
    editBox:SetScript('OnEnterPressed', SaveValue)
    editBox:SetScript('OnEditFocusLost', SaveValue)
    
    -- setup refresh function
    editBox.RefreshValue = function(self)
      self:SetNumber(Settings[aSetting][aTargetVal])
      self:SetCursorPosition(0)
    end
    
    -- add fontstring
    editBox.fontString = frame:CreateFontString(id..'eb'..aTargetVal..'fs', 'OVERLAY', GameFontNormal)
    editBox.fontString:SetPoint('BOTTOM', editBox, 0, -3)
    editBox.fontString:SetFont('Fonts\\FRIZQT__.TTF', 10)
    editBox.fontString:SetTextColor(0.8, 0.8, 0.8, 1)
    editBox.fontString:SetText(aTargetVal)
    
    -- attach to main frame
    if not frame.editBoxes then
      frame.editBoxes = {}
    end
    tinsert(frame.editBoxes, editBox)
    
    -- increase x for next editbox
    x = x + editBox:GetWidth() + 10
  end
  AddEditBox('r')
  AddEditBox('g')
  AddEditBox('b')
  if aShowAlpha then
    AddEditBox('a')
  end
  
  -- setup refresh function
  frame.RefreshValue = function(self)
    for _, f in ipairs(frame.editBoxes) do
      f:RefreshValue()
    end
  end
  frame.RefreshValue()
  
  -- adjust size of parent frame
  frame:SetSize(x + frame.editBoxes[1]:GetWidth(), 30)
  frame:Show()
  
  -- increase pos for next frame
  self:IncreasePosY(aWidgetSettings, frame, 5)
  
  self:OnFrameCreated(frame)
  return frame
end

function OptionsPanel:IncreasePosY(aWidgetSettings, aFrame, aExtraSpace)
  aWidgetSettings.posY = aWidgetSettings.posY - aFrame:GetHeight() - (aExtraSpace or 0)
end

function OptionsPanel:MakeFrameId()
  return addonName..#self.createdFrames
end

function OptionsPanel:OnFrameCreated(aFrame)
  self.createdFrames[#self.createdFrames + 1] = aFrame
end

-------------------------
--       Utils
-------------------------

function Utils:GetResolution()
  local x, y = strsplit('x', Display_DisplayModeDropDown:windowedmode() and GetCVar('gxWindowedResolution') or GetCVar('gxFullscreenResolution'))
  return tonumber(x), tonumber(y)
end

function Utils:TableShallowCopy(aTable)
  local copy = {}
  for k, v in pairs(aTable) do
      copy[k] = v
  end
  return copy
end

function Utils:TableDeepCopy(aTable)
  local copy = {}
  for k, v in pairs(aTable) do
      if type(orig) == 'table' then
        copy[k] = self:TableDeepCopy(v)
      else
        copy[k] = v
      end
  end
  return copy
end

function Utils:Round(aNumber, aDecimals)
  local mult = 10^(aDecimals or 0)
  return math.floor(aNumber * mult + 0.5) / mult
end

function Utils:Clamp(aLow, aNumber, aHigh)
  return math.min(math.max(aNumber, aLow), aHigh)
end

function Utils:StrIsNilOrEmpty(aStr)
  return aStr == nil or aStr == ''
end

function Utils:Ternary(aCond, aTrue, aFalse)
  if aCond then
    return aTrue
  end
  return aFalse
end