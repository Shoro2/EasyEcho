local addonName, addon = ...






local function SendSellJunkRequest()
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_SELL_JUNK_ITEMS, "")
end


SLASH_sellJunk1 = "/sell_junk"
SlashCmdList["sellJunk"] = function(msg)
    SendSellJunkRequest()
end


ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_JUNK_SOLD, function(body)
    if not body or body == "" then
        if ProjectEbonholdScrapButton then
            ProjectEbonholdScrapButton:UpdateState()
        end
        return
    end


    local itemsSold, copperEarned = body:match("^(%d+)|(%d+)$")

    if itemsSold and copperEarned then
        itemsSold = tonumber(itemsSold)
        copperEarned = tonumber(copperEarned)


        local gold = math.floor(copperEarned / 10000)
        local silver = math.floor((copperEarned % 10000) / 100)
        local copper = copperEarned % 100

        local moneyString = ""
        if gold > 0 then
            moneyString = gold .. "|cffffd700g|r "
        end
        if silver > 0 or gold > 0 then
            moneyString = moneyString .. silver .. "|cffc7c7c7s|r "
        end
        moneyString = moneyString .. copper .. "|cffeda55fc|r"
        if ProjectEbonholdScrapButton then
            ProjectEbonholdScrapButton:UpdateState()
        end
    end
end)


_G.ScrapService = {
    SellJunk = SendSellJunkRequest
}
