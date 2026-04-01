local Addon = select(2, ...)
local ScrapButton = CreateFrame("Button", "ProjectEbonholdScrapButton", MerchantFrame)
local function GetJunkValue()
  local total = 0
  
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local quality = select(3, GetItemInfo(link))
        local itemID = tonumber(link:match("item:(%d+)"))
        
        
        if quality == 0 then
          local _, count = GetContainerItemInfo(bag, slot)
          local vendorPrice = select(11, GetItemInfo(link))
          if vendorPrice and vendorPrice > 0 then
            total = total + (vendorPrice * (count or 1))
          end
        end
      end
    end
  end
  
  return total
end

local function SellJunk()
  
  if ScrapService and ScrapService.SellJunk then
    ScrapService.SellJunk()
  end
end





function ScrapButton:CreateButton()
  self:SetSize(37, 37)
  self:SetFrameStrata("HIGH")
  
  
  local bg = self:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(27, 27)
  bg:SetPoint("CENTER", -0.5, -1.2)
  bg:SetTexture(0, 0, 0, 0.5)
  
  
  local icon = self:CreateTexture(nil, "ARTWORK")
  icon:SetSize(33, 33)
  icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Green")
  self.icon = icon
  
  
  
  self:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  self:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  
  
  self:RegisterForClicks("LeftButtonUp")
  self:SetScript("OnClick", self.OnClick)
  self:SetScript("OnEnter", self.OnEnter)
  self:SetScript("OnLeave", self.OnLeave)
  
  
  self:UpdatePosition()
  
  
  hooksecurefunc("MerchantFrame_UpdateRepairButtons", function()
    self:UpdatePosition()
  end)
  
  
  hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
    self:UpdateState()
  end)
  
  hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
    self:UpdateState()
  end)
end

function ScrapButton:UpdatePosition()
  if CanMerchantRepair() then
    
    local offset = -3.5
    local scale = 0.9
    
    if CanGuildBankRepair() then
      
      self:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", offset, 0)
    else
      
      offset = -1.5
      scale = 1
      self:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", offset, 0)
    end
    
    self:SetScale(scale)
  else
    
    self:SetPoint("RIGHT", MerchantBuyBackItemItemButton, "LEFT", -17, 0.5)
    self:SetScale(1.1)
  end
end

function ScrapButton:UpdateState()
  
  if MerchantFrame.selectedTab == 2 then
    self:Hide()
    return
  else
    self:Show()
  end
  
  local value = GetJunkValue()
  local hasJunk = value > 0
  
  
  self.icon:SetDesaturated(not hasJunk)
  
  if hasJunk then
    self.icon:SetAlpha(1)
    self:Enable()
  else
    self.icon:SetAlpha(0.5)
    self:Disable()
  end
end

function ScrapButton:OnClick(button)
  if button == "LeftButton" then
    SellJunk()
    self:UpdateState()
  end
end

function ScrapButton:OnEnter()
  local value = GetJunkValue()
  
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  
  if value > 0 then
    GameTooltip:SetText("|cFFFFD700Sell Junk|r", 1, 1, 1)
    
    
    local gold = floor(value / 10000)
    local silver = floor((value % 10000) / 100)
    local copper = value % 100
    
    local moneyString = ""
    if gold > 0 then
      moneyString = format("%d|cFFFFD700g|r ", gold)
    end
    if silver > 0 or gold > 0 then
      moneyString = moneyString .. format("%d|cFFC7C7CFs|r ", silver)
    end
    moneyString = moneyString .. format("%d|cFFEDA55Fc|r", copper)
    
    GameTooltip:AddLine("Value: " .. moneyString, 1, 1, 1)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("|cFF888888Left-click:|r Sell all junk", 0.8, 0.8, 0.8)
  else
    GameTooltip:SetText("|cFF888888No junk to sell|r", 1, 1, 1)
  end
  
  GameTooltip:Show()
end

function ScrapButton:OnLeave()
  GameTooltip:Hide()
end





ScrapButton:RegisterEvent("MERCHANT_SHOW")
ScrapButton:RegisterEvent("MERCHANT_CLOSED")
ScrapButton:RegisterEvent("BAG_UPDATE")

ScrapButton:SetScript("OnEvent", function(self, event, ...)
  if event == "MERCHANT_SHOW" then
    self:Show()
    self:UpdateState()
    
    
    if AUTO_SELL then
      
      C_Timer.After(0.2, function()
        if MerchantFrame:IsShown() then
          SellJunk()
          self:UpdateState()
        end
      end)
    end
    
  elseif event == "MERCHANT_CLOSED" then
    self:Hide()
    
  elseif event == "BAG_UPDATE" then
    if MerchantFrame:IsShown() then
      self:UpdateState()
    end
  end
end)





ScrapButton:CreateButton()
ScrapButton:Hide() 


if MerchantRepairText then
  MerchantRepairText:SetAlpha(0)
end