local addon, Addon = ...

local function RemoveRuneRefund(spellId, all)
    Addon.FindAndRemoveRune(spellId, all);
    Addon.InitializePagination(nil, Addon.UIRune.CurrentPage);
    Addon.UIRune.InitFrameRunes();
end

Addon.Popup = {};





StaticPopupDialogs["DIALOG_CONFIRM_RESET_ALL_TALENT"] = {
    text = "Are your sure you want to reset your talents?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        AIO.Handle("RunesAIO", "ResetTalents");
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["DIALOG_CONFIRM_RESET_ALL_RUNE"] = {
    text = "Are you sure you want to reset all Rune slots? This action is irreversible.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        RunesAIO.ResetAllSlots()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

Addon.Popup.RerollSelection = function(uuid)
    StaticPopupDialogs["DIALOG_CONFIRM_REROLL"] = {
        text = "Are you sure you want to reroll your current selection?",
        button1 = "Accept",
        button2 = "Cancel",
        OnAccept = function(self)
            AIO.Handle("RunesAIO", "Reroll", uuid);
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show("DIALOG_CONFIRM_REROLL")
end


StaticPopupDialogs["DIALOG_HOW_TO_UPGRADE_RUNE"] = {
    text =
        "To upgrade your runes, you'll need three runes of the same quality. Depending on their rank, you'll also need a specific amount of Cosmic Essence: " ..
        " \n" ..
        " \n" ..
        "Uncommon Quality: 45 Cosmic Essence \n" ..
        "Rare Quality: 450 Cosmic Essence \n" ..
        "Epic Quality: 1,350 Cosmic Essence \n" ..
        "Legendary Quality: 4,500 Cosmic Essence \n" ..
        "Mythic Quality: 9,000 Cosmic Essence"
    ,
    button1 = "Ok",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

Addon.Popup.AddLoadout = function()
    StaticPopupDialogs["ADD_LOADOUT"] = {
        text = "Name:",
        button1 = "Submit",
        button2 = "Cancel",
        OnAccept = function(self)
            local input = self.editBox:GetText();
            if input then
                AIO.Handle("RunesAIO", "AddLoadout", input);
            end
        end,
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("ADD_LOADOUT")
end




Addon.Popup.ShowPopupRefundRune = function(quality, spellId, name)
    local multiplier = math.pow(3, quality - 1);
    local runicDust = (50 * multiplier);
    StaticPopupDialogs["DIALOG_CONFIRM_REFUND_RUNE"] = {
        text = "Are you sure you want to transform one stack of [" .. name .. "] into " .. runicDust .. " Runic Dust? ",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            RunesAIO.RefundRune(spellId)
            RemoveRuneRefund(spellId);
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    StaticPopup_Show("DIALOG_CONFIRM_REFUND_RUNE")
end

Addon.Popup.ShowPopupRefundAllRune = function(count, quality, spellId, name)
    local multiplier = math.pow(3, quality - 1);
    local runicDust = (50 * multiplier) * count;
    StaticPopupDialogs["DIALOG_CONFIRM_REFUND_RUNE"] = {
        text = "Are you sure you want to transform " ..
            count .. " of [" .. name .. "] into " .. runicDust .. " Runic Dust? ",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            RunesAIO.RefundAllRune(spellId)
            RemoveRuneRefund(spellId, true);
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    StaticPopup_Show("DIALOG_CONFIRM_REFUND_RUNE")
end

Addon.Popup.ShowPopupExtractRune = function(spellId, name)
    StaticPopupDialogs["DIALOG_CONFIRM_EXTRACT"] = {
        text = "Are you sure you want to extract the rune [" ..
        name ..
        "]? Extracting it will cause you to unlearn it, but in return, you'll gain the ability to learn another rune of a rank one tier lower.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            RunesAIO.ExtractRune(spellId)
            RemoveRuneRefund(spellId);
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    StaticPopup_Show("DIALOG_CONFIRM_EXTRACT")
end


Addon.Popup.ShowPopupLearnRune = function(spellId, name)
    StaticPopupDialogs["DIALOG_CONFIRM_LEARN_RUNE"] = {
        text = "Are you sure you want to learn the rune [" .. name .. "]?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            RunesAIO.LearnRune(spellId)
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    StaticPopup_Show("DIALOG_CONFIRM_LEARN_RUNE")
end


Addon.Popup.ShowPopupAutoRefund = function(rune)
    StaticPopup_Hide("DIALOG_CONFIRM_AUTO_LUCKY_RUNE");
    StaticPopupDialogs["DIALOG_CONFIRM_AUTO_REFUND_RUNE"] = {
        text =
        "When you enable Auto-Recycle, the rune will be automatically recycled upon its acquisition. \n\n Are you sure you want to enable Auto-Recycle?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            if not rune.isAutoRefund then
                rune.isAutoRefund = true;
                Addon.UIRune.AutoRecycleRunes[rune.spellId]:Show();
            else
                rune.isAutoRefund = false;
                Addon.UIRune.AutoRecycleRunes[rune.spellId]:Hide();
            end
            RunesAIO.AutoRefund(rune.spellId);
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    StaticPopup_Show("DIALOG_CONFIRM_AUTO_REFUND_RUNE")
end

Addon.Popup.ShowPopupLuckyRune = function(rune)
    StaticPopup_Hide("DIALOG_CONFIRM_AUTO_REFUND_RUNE");

    local mesg =
    "Are you sure you want to activate the Lucky Rune? When you open cards, you have an increased chance of obtaining one of your 3 Lucky Runes. \n\n |cffff0000You need 3 Lucky Runes for it to work."

    if Addon.UIRune.RuneToUpdate.isLucky then
        mesg = "Are you sure you want to deactivate this Lucky Rune? "
    end

    StaticPopupDialogs["DIALOG_CONFIRM_AUTO_LUCKY_RUNE"] = {
        text = mesg,
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            if Addon.UIRune.RuneToUpdate.isLucky then
                Addon.UIRune.LuckyCount = Addon.UIRune.LuckyCount - 1;
                Addon.UIRune.UpdateLuckyCount();
                Addon.UIRune.RuneToUpdate.isLucky = false;
                Addon.UIRune.LuckyRunes[rune.spellId]:Hide()
                RunesAIO.LuckyRune(rune.spellId, false)
            else
                RunesAIO.LuckyRune(rune.spellId, true)
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
    StaticPopup_Show("DIALOG_CONFIRM_AUTO_LUCKY_RUNE")
end
