Sh_Frame = nil;
Sh_Saved = {
    Sh_Print_DEBUG = true;
};

local FlashHeal = {}
FlashHeal[1] =  {1, 202, 247, 125, .6};
FlashHeal[2] =  {2, 269, 325, 155, .6};
FlashHeal[3] =  {3, 290, 347, 185, .6};
FlashHeal[4] =  {4, 354, 420, 215, .6};
FlashHeal[5] =  {5, 456, 540, 265, .8};
FlashHeal[6] =  {6, 202, 247, 315, .9};
FlashHeal[7] =  {7, 202, 247, 380, 1};

local Heal = {}
Heal[1] =  {1, 307, 353, 131, 1};
Heal[2] =  {2, 445, 507, 174, 1};
Heal[3] =  {3, 586, 662, 216, 1};
Heal[4] =  {4, 627, 706, 259, 1};

local SpellTable = {
    ['Flash Heal'] = FlashHeal,
    ['Heal'] = Heal,
}

Sh_PlayerClass = "";

local SpellCastFunctions = { }
local is_casting = false

function SpellCastFunctions.SPELLCAST_STOP()
    is_casting = false
end

function SpellCastFunctions.SPELLCAST_START()
    is_casting = true
end

function SpellCastFunctions.SPELLCAST_FAILED()
    is_casting = false
end

function SpellCastFunctions.SPELLCAST_INTERRUPTED()
    is_casting = false
end

function Sh_PrintLn(Message)
    DEFAULT_CHAT_FRAME:AddMessage(Message, 1, 1, 1);
end

function Sh_ErrLn(Message)
    DEFAULT_CHAT_FRAME:AddMessage(Message, 1, 0.1, 0.1);
end

function Sh_Debug( Message) 
    if (Sh_Saved.Sh_Print_DEBUG) then
        DEFAULT_CHAT_FRAME:AddMessage("[SH_DBG] " .. Message, .6, .6, .6);
    end
end 

function Sh_ToggleDebug(args)
    Sh_Debug("Toggling debug");
    Sh_Saved.Sh_Print_DEBUG = not Sh_Saved.Sh_Print_DEBUG;
    Sh_PrintLn("SmartHeal Debug Logging: " .. tostring(Sh_Saved.Sh_Print_DEBUG));
end

function Sh_SelectSpellRank(spellName, deficit, totalHeal)
    local spell = SpellTable[spellName];
    local mana = UnitMana("player");
    local selectedSpell = nil;

    for rank, values in ipairs(spell) do
        local coefficient = values[5];
        local minHeal = values[2] + (totalHeal * coefficient);
        local manaCost = values[4];

        local currentSpell = spellName .. "(Rank " .. rank .. ")";
        if(selectedSpell == nil) then
            selectedSpell = currentSpell;
        end

        if(deficit < minHeal) then
            Sh_Debug("Returning " .. selectedSpell);
            return selectedSpell;
        end
        if(mana < manaCost) then
            Sh_Debug("Returning " .. selectedSpell .. " mana pressure");
            return selectedSpell;
        end
        selectedSpell = spellName .. "(Rank " .. rank .. ")";
    end

    Sh_Debug("Returning " .. selectedSpell .. " default");
    return selectedSpell;
end

function Sh_Heal(args)
    if(is_casting) then
        Sh_Debug("Already casting a spell.");
        return;
    end

    local targetName = UnitName("target");
    if (targetName == nil) then
        -- TODO: Find a target with lowest health & no incoming heals
        return;
    end

    if (UnitIsDead("target") or UnitIsGhost("target")) then
        Sh_Debug(targetName .. " is dead or a ghost.");
        return;
    end

    local deficit = UnitHealthMax("target") - UnitHealth("target");
    if (deficit <= 0) then
        Sh_Debug(targetName .. " is already at full health.");
        return;
    end


    if(_G["BCS"] == nil) then
        Sh_ErrLn("BetterCharacterStats not found! Please install BetterCharacterStats.");
    end

    local power, _, _, _ = BCS:GetSpellPower();
    local heal, _ = BCS:GetHealingPower();
    local totalHeal = heal + power;

    if(args == nil or args == "") then
        Sh_ErrLn("Usage: " .. SH_MACRO_COMMAND .. " <Spell Name>");
        -- TODO: Auto select the spell based on player class, target class / health deficit
        -- For example if the target is a rogue, and player is a priest, use renew
        -- If the target is a main tank, and player is a priest, use flash heal
        return;
    end

    local spell = Sh_SelectSpellRank(args, deficit, totalHeal);
    if (spell == nil) then
        return;
    end

    Sh_PrintLn("[SH] " .. targetName .. " (-" .. deficit .. ") <= " .. spell);
    CastSpellByName(spell, "target");
end

function Sh_Init()
    Sh_PrintLn(SH_VERSION_STRING);

    Sh_Debug( "SmartHeal Initialization started!");
    SLASH_SMARTHEAL1 = SH_MACRO_COMMAND;
    SlashCmdList["SMARTHEAL"] = Sh_Heal;

    SLASH_SHDBG1 = SH_MACRO_DEBUG;
    SlashCmdList["SHDBG"] = Sh_ToggleDebug;
end

function Sh_OnLoad (Frame)
   Sh_Debug("SmartHeal OnLoad called");
   Sh_Frame = Frame;
   Sh_Frame:RegisterEvent("PLAYER_LOGIN");
   Sh_Frame:RegisterEvent("ADDON_LOADED");

   Sh_Frame:RegisterEvent("SPELLCAST_STOP")
   Sh_Frame:RegisterEvent("SPELLCAST_INTERRUPTED")
   Sh_Frame:RegisterEvent("SPELLCAST_FAILED")
   Sh_Frame:RegisterEvent("SPELLCAST_START")
end


function Sh_OnEvent(event, arg1)
    if(event ~= nil) then
        Sh_Debug("Event: " .. event);
    end

    if(SpellCastFunctions[event]) then
      SpellCastFunctions[event]()
      return;
    end

    if(event == "ADDON_LOADED") then
        Sh_Frame:UnregisterEvent("ADDON_LOADED");
        Sh_Init();
    end

    if(event == "PLAYER_LOGIN") then
        Sh_Frame:UnregisterEvent("PLAYER_LOGIN");
        Sh_PlayerClass = UnitClass("player");
        Sh_Debug("Player class: " .. Sh_PlayerClass);
    end
end