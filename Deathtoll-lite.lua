--[[
 *  The MIT License (MIT)
 *
 *  Copyright (c) 2016 Sjshovan (Apogee)
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to
 *  deal in the Software without restriction, including without limitation the
 *  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 *  sell copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
]]--

_addon.author   = 'Sjshovan (Apogee)';
_addon.name     = 'Deathtoll-Lite';
_addon.version  = '1.1.3';

require 'common'

---------------------------------------------------------------------------------------------------
-- desc: Default Deathtoll configuration table.
---------------------------------------------------------------------------------------------------
local default_config =
{
    deathtoll = 0;
    last_killed = "";
    solo = false;
};

---------------------------------------------------------------------------------------------------
-- desc: Deathtoll variables.
---------------------------------------------------------------------------------------------------
local deathtoll_config = default_config;

local _core =  AshitaCore;

local _resource = _core:GetResourceManager();
local _chat =  _core:GetChatManager();
local _data =  _core:GetDataManager();
local _party = _data:GetParty();
local _player = _data:GetPlayer();

local chatModes = {
    say         = 1,
    shout       = 3,
    tell        = 4,
    party       = 5,
    linkshell   = 6,
    echo        = 206,
    unity       = 211,
    combatInfo  = 36,
    combatInfo2 = 37
}

local helpCmds = {
    "======================",
    "Deathtoll-Lite Commands",
    "======================",
    "/dtl get => Display the current death toll.",
    "/dtl set x => Set the current death toll to x.",
    "/dtl add x => Add x to the current death toll.",
    "/dtl sub x => Subtract x from the current death toll.",
    "/dtl last => Display the last enemy killed.",
    "/dtl solo (on/off) => Switch counting kills made by party members.",
    "/dtl reload => Reload the Deathtoll-Lite addon.",
    "/dtl unload => Unload the Deathtoll-Lite addon.",
    "/dtl (help/?) => Display this list of commands.",
    "======================",
}

---------------------------------------------------------------------------------------------------
-- desc: Deathtoll functions.
---------------------------------------------------------------------------------------------------

-----------------------------------------------------
-- desc: helper.
-----------------------------------------------------
local function isInt(n)
    n = tonumber(n);
    return (type(n) == "number" and (math.floor(n) == n));
end

local function isSwitch(n)
    return n == "on" or n == "off";
end

local function getMax(...)
    local args = {...}
    local max = 0;
    for k, num in pairs(args) do
        if num > max then
            max = num;
        end
    end
    return max;
end

local function getWords(message)
    local words = {};
    for word in message:gmatch("%S+") do
        table.insert(words, word);
    end
    return words;
end

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

function table.slice(tbl, first, last, step)
    local sliced = {}

    for i = first or 1, last or #tbl, step or 1 do
        sliced[#sliced+1] = tbl[i]
    end

    return sliced
end

-----------------------------------------------------
-- desc: message.
-----------------------------------------------------
local function echo(message)
    _chat:QueueCommand("/echo "..message, 0);
end

local function message(mode, message)
	local c_msg = "";
        for i, word in ipairs(getWords(message)) do
            local c_word = string.color(word, mode)
            c_msg = c_msg..word.." ";
        end
    _chat:AddChatMessage(mode, c_msg)
end

-----------------------------------------------------
-- desc: toll.
-----------------------------------------------------
local function filterToll(int)
    if (int < 0) then
        int = 0;
    end

    if (int > 999999999999) then
        int = 999999999999;
    end

    return int
end

local function setToll(int)
    local new_deathtoll = filterToll(tonumber(int));
    deathtoll_config.deathtoll = new_deathtoll;
    message(chatModes.party, "The death toll has been set to "..new_deathtoll..".");
end

local function storeToll(silent)
    settings:save(_addon.path .. 'settings/deathtoll.json', deathtoll_config);
    if (silent) then
        return true;
    end
    message(chatModes.linkshell, "Death toll stored.");
end

local function getToll()
   return deathtoll_config.deathtoll;
end

local function adjustToll(int, direction, silent)
    if (direction ~= -1 and direction ~= 1) then
        return false
    end

    local old_deathtoll = tonumber(getToll());
    local new_deathtoll = filterToll(old_deathtoll + (int * direction));
    local adj_ammount;
    local dir_msg;

    if getMax(old_deathtoll, new_deathtoll) == old_deathtoll then
        adj_ammount = old_deathtoll - new_deathtoll;
    else
        adj_ammount = new_deathtoll - old_deathtoll;
    end

    deathtoll_config.deathtoll = new_deathtoll;

    if (silent) then
        return true;
    end

    if direction ~= -1 then
        dir_msg = "increased";
    else
        dir_msg = "decreased";
    end

    message(chatModes.party, "The death toll has been "..dir_msg.." by "..adj_ammount..".");
end

local function displayToll()
    message(chatModes.say, "The current death toll is "..getToll()..".");
end

-----------------------------------------------------
-- desc: last_killed.
-----------------------------------------------------
local function getLastKilled()
    return deathtoll_config.last_killed;
end

local function setLastKilled(enemy, time, killer)
    deathtoll_config.last_killed = enemy.." @ "..time.." by "..killer;
end

local function displayLastKilled()
    local last_killed = deathtoll_config.last_killed;
    local killed_msg = "";

    if (last_killed == "" or last_killed == nill)  then
        killed_msg = "The last enemy hasn't been registered.";
    else
        killed_msg = "The last enemy killed was a(n) "..getLastKilled()..".";
    end

    message(chatModes.shout, killed_msg);
end

-----------------------------------------------------
-- desc: solo.
-----------------------------------------------------
local function getSolo()
   return deathtoll_config.solo;
end

local function setSolo(bool)
    deathtoll_config.solo = bool;
end

local function switchSolo(switch)

    if switch == 'on' then
        setSolo(true);
    elseif switch == 'off' then
        setSolo(false);
    else
        return false;
    end
    message(chatModes.party, "Solo mode has been switched "..switch..".");
    return true;
end

local function displaySoloStatus()
    local solo_msg = "";
    if getSolo() then
        solo_msg = "".."[".."Enabled".."]: ".."Party member kills will not be added to the death toll."
    else
        solo_msg = "".."[".."Disabled".."]: ".."Party member kills will be added to the death toll."
    end

    message(chatModes.say, solo_msg);
end

-----------------------------------------------------
-- desc: utility.
-----------------------------------------------------

local function getPlayerName()
    return _party:GetPartyMemberName(0);
end

local function parseEnemyName(match)
    local pattern = "^%w+ defeats the (.+)";
    local enemy_name = string.match(match, pattern);
    return enemy_name:gsub("%.", "");
end

local function pasePartyMemberName(match)
    local pattern = "^(%w+) defeats the .+";
    local member_name = string.match(match, pattern);
    return member_name:gsub("%.", "");
end

local function displayHelp()
    local mode;
    message(chatModes.say, "")
    for k, v in pairs(helpCmds) do
        if (k==1 or k==3 or k==#helpCmds) then
            mode = chatModes.party;
        elseif (k==2) then
            mode = chatModes.unity;
        else
            mode = chatModes.tell;
        end
        message(mode, v);
    end
    message(chatModes.say, "")
end

local function getPartyMembers()
    local members = {};
    for i=0, 6, 1 do
        local member = _party:GetPartyMemberName(i);
        if member then
            member = string.gsub(member, "%s+", "")
            table.insert(members, member);
        end
    end

    return members;
end

---------------------------------------------------------------------------------------------------
-- func: load
-- desc: First called when our addon is loaded.
---------------------------------------------------------------------------------------------------
ashita.register_event('load', function()
    deathtoll_config = settings:load(_addon.path .. 'settings/deathtoll.json') or default_config;
    deathtoll_config = table.merge(default_config, deathtoll_config);
end );

---------------------------------------------------------------------------------------------------
-- func: unload
-- desc: Called when our addon is unloaded.
---------------------------------------------------------------------------------------------------
ashita.register_event('unload', function()
    storeToll(true);
    message(chatModes.unity, "Thank you for using Deathtoll-Lite.");
end );

---------------------------------------------------------------------------------------------------
-- func: command
-- desc: Called when our addon receives a command.
---------------------------------------------------------------------------------------------------
ashita.register_event('command', function(cmd, nType)
    local args = cmd:GetArgs();

    if (args[1] ~= '/dtl' and args[1] ~= '/dtlite' and args[1] ~= '/deathtolllite') then
        return false;
    end

    if (args[2] == "get") then
        displayToll();
        return true;
    end

    if (args[2] == "set") then
        if (args[3] and isInt(args[3])) then
            setToll(args[3]);
            displayToll();
            storeToll(true);
        else
            return false;
        end

        return true;

    elseif (args[2] == "add") then
        if (args[3] and isInt(args[3])) then
            adjustToll(args[3], 1, false)
            displayToll();
            storeToll(true);
        else
            return false;
        end

        return true;

    elseif (args[2] == "sub") then
        if (args[3] and isInt(args[3])) then
            adjustToll(args[3], -1, false)
            displayToll();
            storeToll(true);
        else
            return false;
        end
        return true;

    elseif (args[2] == "last") then
        displayLastKilled();
        return true;

    elseif (args[2] == "solo") then
        if (args[3] and isSwitch(args[3])) then
            switchSolo(args[3]);
            displaySoloStatus();
        else
            displaySoloStatus();
            message(chatModes.tell, "To switch solo mode use /dtl solo on and /dtl solo off.")
        end
        return true;

    elseif (args[2] == "reload") then
        _chat:QueueCommand("/addon reload Deathtoll-lite", 0);
        return true;

    elseif (args[2] == "unload") then
        _chat:QueueCommand("/addon unload Deathtoll-lite", 0);
        return true;

    elseif (args[2] == "?" or args[2] == "help") then
        displayHelp();
        return true;

    else
        if (args[2]) then
            message(chatModes.tell, "That is not a valid Deathtoll-Lite command.");
        end

        message(chatModes.tell, "To see a list of commands type: /dtl ? or /dtl help.")
        return true;
    end

    return true;

end );

---------------------------------------------------------------------------------------------------
-- func: newchat
-- desc: Called when our addon receives a chat line.
---------------------------------------------------------------------------------------------------
ashita.register_event('newchat', function(mode, chat)

    if mode == chatModes.combatInfo or mode == chatModes.combatInfo2 then

        local timestamp = os.date('%Y-%m-%d %H:%M:%S');
        local suicide = string.match(chat, "The (.+) falls to the ground.");

        if (not suicide) then

            if getSolo() then
                local pattern = "("..getPlayerName().." defeats the .+).";
                local match = string.match(chat, pattern);

                if  match then
                    local enemy = parseEnemyName(match);

                    adjustToll(1, 1, false);
                    setLastKilled(enemy, timestamp, getPlayerName());
                    storeToll(true);
                    displayToll();
                end

            else
                local pattern = "(%w+ defeats the .+).";
                local match = string.match(chat, pattern);

                if match then
                    local killer = pasePartyMemberName(match);
                    local members = getPartyMembers();

                    if has_value(members, killer) then
                        local enemy = parseEnemyName(match);

                        adjustToll(1, 1, false);
                        setLastKilled(enemy, timestamp, killer);
                        storeToll(true);
                        displayToll();
                    end
                end
            end

        else
            adjustToll(1, 1, false);
            setLastKilled(suicide, timestamp, "Suicide");
            storeToll(true);
            displayToll();
        end

    end
    return chat;
end );