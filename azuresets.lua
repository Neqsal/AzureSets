--------------------------------------------------------------------------------------------
    _addon = {name = 'AzureSets', version = '2.0', author = 'Nitrous(Shiva) and Neqsal'}
--[[----------------------------------------------------------------------------------------
          //      //   // / // /     / // /        // // //      //       //       
          // /    //   //          //      //     //            // /      //       
          //  //  //   / // //    /      /   /      // //      //  //     //       
          //    / //   //          //      //            //   // // //    //       
          //      //   // / // /     / // /   /   // // //   //      //   // / // /
--------------------------------------------------------------------------------------------
                            Copyright © 2025, https://neqsal.com
                                    All rights reserved.
--------------------------------------------------------------------------------------------
    Redistribution and use in source and binary forms, with or without modification, are
                   permitted provided that the following conditions are met:

      * Redistributions of source code must retain the above copyright notice, this
        list of conditions and the following disclaimer.

      * Redistributions in binary form must reproduce the above copyright notice,
        this list of conditions and the following disclaimer in the documentation
        and/or other materials provided with the distribution.

      * Neither the name of "AzureSets" nor the names of its contributors may be used
        to endorse or promote products derived from this software without specific
        prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
    EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
    OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
    SHALL "NEQSAL" BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
    GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
    TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------------------
Copyright (c) 2013, Ricky Gall
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of azureSets nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL The Addon's Contributors BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
------------------------------------------------------------------------------------------]]--
_addon.commands = {'azuresets', 'asets', 'aset'}

require('logger')

local config = require('config')
local resrc  = require('resources')
local chat = require('chat')

local send_command = windower.send_command
local add_to_chat  = windower.add_to_chat

local get_player = windower.ffxi.get_player
local get_info   = windower.ffxi.get_info

local remove_blue_magic_spell = windower.ffxi.remove_blue_magic_spell
local reset_blue_magic_spells = windower.ffxi.reset_blue_magic_spells
local set_blue_magic_spell    = windower.ffxi.set_blue_magic_spell

local job_data = {
    main = windower.ffxi.get_mjob_data,
    sub  = windower.ffxi.get_sjob_data,
}

local patterns = {
    slot  = 'slot%02u',
    line  = '%s = %q',
    index = '%02u',
}

local defaults = {
    spellsets = {default = T()},
    setspeed  = 0.65,
    setmode   = 'PreserveTraits',
}

defaults.spellsets.vw1 = T{
    slot01 = "Firespit",
    slot02 = "Heat Breath",
    slot03 = "Thermal Pulse",
    slot04 = "Blastbomb",
    slot05 = "Infrasonics",
    slot06 = "Frost Breath",
    slot07 = "Ice Break",
    slot08 = "Cold Wave",
    slot09 = "Sandspin",
    slot10 = "Magnetite Cloud",
    slot11 = "Cimicine Discharge",
    slot12 = "Bad Breath",
    slot13 = "Acrid Stream",
    slot14 = "Maelstrom",
    slot15 = "Corrosive Ooze",
    slot16 = "Cursed Sphere",
    slot17 = "Awful Eye",
}

defaults.spellsets.vw2 = T{
    slot01 = "Hecatomb Wave",
    slot02 = "Mysterious Light",
    slot03 = "Leafstorm",
    slot04 = "Reaving Wind",
    slot05 = "Temporal Shift",
    slot06 = "Mind Blast",
    slot07 = "Blitzstrahl",
    slot08 = "Charged Whisker",
    slot09 = "Blank Gaze",
    slot10 = "Radiant Breath",
    slot11 = "Light of Penance",
    slot12 = "Actinic Burst",
    slot13 = "Death Ray",
    slot14 = "Eyes On Me",
    slot15 = "Sandspray",
}

local settings = config.load(defaults)

local spells

function initialize()
    spells = resrc.spells:type('BlueMagic')
    get_current_spellset()
end

windower.register_event('job change', initialize:cond(function(main, _, sub)
    return (main == 16) or (sub == 16)
end))

windower.register_event('load', initialize:cond(function()
    return get_info().logged_in
end))

windower.register_event('login', initialize)

function blu_main_or_sub()
    local player = get_player()

    if (player.main_job_id == 16) then
        return 'main'
    elseif (player.sub_job_id == 16) then
        return 'sub'
    end
end

function set_spells(spellset, setmode)
    if not blu_main_or_sub() then
        error('Neither main or sub job set to Blue Mage.')
        return

    elseif not settings.spellsets[spellset] then
        error('Set not defined: '..spellset)
        return

    elseif is_spellset_equipped(settings.spellsets[spellset]) then
        log(spellset..' was already equipped.')
        return

    elseif not setmode then
        setmode = settings.setmode
    end

    log('Starting to set '..spellset..'.')

    if ('clearfirst'):match(setmode:lower()) then
        remove_all_spells()
        set_spells_from_spellset:schedule(settings.setspeed, spellset, 'add')

    elseif ('preservetraits'):match(setmode:lower()) then
        set_spells_from_spellset(spellset, 'remove')
    else
        error('Unexpected setmode: '..setmode)
    end
end

function is_spellset_equipped(spellset)
    return S(spellset):map(string.lower) == S(get_current_spellset())
end

function set_spells_from_spellset(spellset, setPhase)
    local setToSet = settings.spellsets[spellset]
    local currentSet = get_current_spellset()

    if setPhase == 'remove' then
        -- Remove Phase
        for k, v in pairs(currentSet) do
            if not setToSet:contains(v:lower()) then
                local slotToRemove = tonumber(k:sub(5, k:len()))
                --setSlot = k

                remove_blue_magic_spell(slotToRemove)
                --log('Removed spell: '..v..' at #'..slotToRemove)
                set_spells_from_spellset:schedule(settings.setspeed, spellset, 'remove')
                return
            end
        end
    end

    -- Did not find spell to remove. Start set phase
    -- Find empty slot:
    local slotToSetTo

    for i = 1, 20 do
        local slotName = patterns.slot:format(i)

        if not currentSet[slotName] then
            slotToSetTo = i
            break
        end
    end

    if slotToSetTo then
        -- We found an empty slot. Find a spell to set.
        for _, v in pairs(setToSet) do
            if not currentSet:contains(v:lower()) then

                if v then
                    local spellID = find_spell_id_by_name(v)

                    if spellID then
                        set_blue_magic_spell(spellID, tonumber(slotToSetTo))
                        --log('Set spell: '..v..' ('..spellID..') at: '..slotToSetTo)
                        set_spells_from_spellset:schedule(settings.setspeed, spellset, 'add')
                        return
                    end
                end
            end
        end
    end

    -- Unable to find any spells to set. Must be complete.
    log(spellset..' has been equipped.')
    send_command('@timers c "Blue Magic Cooldown" 60 up')
end

function find_spell_id_by_name(spellname)
    for spell in spells:it() do
        if spell.english:lower() == spellname:lower() then
            return spell.id
        end
    end

    return nil
end

function set_single_spell(setspell,slot)
    if not blu_main_or_sub() then
        return
    end

    local tmpTable = T(get_current_spellset())

    for key in pairs(tmpTable) do
        if tmpTable[key]:lower() == setspell then
            error('That spell is already set.')
            return
        end
    end

    if tonumber(slot) < 10 then
        slot = '0'..slot
    end

    --insert spell add code here
    for spell in spells:it() do
        if spell.english:lower() == setspell then
            --This is where single spell setting code goes.
            --Need to set by spell id rather than name.
            set_blue_magic_spell(spell.id, tonumber(slot))
            send_command('@timers c "Blue Magic Cooldown" 60 up')
            tmpTable['slot'.. slot] = setspell
        end
    end

    --tmpTable = nil
end

function get_current_spellset()
    local role = blu_main_or_sub()

    if job_data[role] then
        local blu_spells = T(job_data[role]().spells)

        -- Returns all values but 512
        blu_spells = blu_spells:filter(function(id) return id ~= 512 end)
        -- Transforms them from IDs to lowercase English names
        blu_spells = blu_spells:map(function(id) return spells[id].english:lower() end)
        -- Transform the keys from numeric x or xx to string 'slot0x' or 'slotxx'
        blu_spells = blu_spells:key_map(function(slot) return patterns.slot:format(slot) end)

        return blu_spells
    end
end

function remove_all_spells()
    reset_blue_magic_spells()
    notice('All spells removed.')
end

function save_set(setname)
    if setname == 'default' then
        error('Please choose a name other than default.')
        return
    end

    local curSpells = T(get_current_spellset())

    settings.spellsets[setname] = curSpells
    settings:save('all')

    notice('Set '.. setname ..' saved.')
end

function delete_set(setname)
    if settings.spellsets[setname] == nil then
        error('Please choose an existing spellset.')
        return
    end

    settings.spellsets[setname] = nil
    settings:save('all')

    notice('Deleted '.. setname ..'.')
end

function get_spellset_list()
    log("Listing sets:")

    for key,_ in pairs(settings.spellsets) do
        if key ~= 'default' then
            local it = 0

            for i = 1, #settings.spellsets[key] do
                it = it + 1
            end

            log("\t".. key ..' '.. settings.spellsets[key]:length() ..' spells.')
        end
    end
end

function get_spellset_content(spellset)
    log('Getting '.. spellset ..'\'s spell list:')
    settings.spellsets[spellset]:print()
end

function set_default_setmode(setmode)
    if #setmode > 1 then
        if ('preservetraits'):match(setmode) then
            log("SetMode configured to preserve traits.")
            settings.setmode = 'preservetraits'
            settings:save('all')

        elseif ('clearfirst'):match(setmode) then
            log("SetMode configured to clear first.")
            settings.setmode = 'clearfirst'
            settings:save('all')

        else
            error('Invalid argument to SetMode: got "'.. setmode ..'".\nArgument must match either "preservetraits" or "clearfirst".')
        end

    else
        error('Invalid argument to SetMode: Argument to short.')
    end
end

do
    local arrow = string.char(0x81,0xa8) ..' '
    local _, __, ___, n = (' '):rep(4), (' '):rep(8), ('-'):rep(80), '\n'

    local center_alignment = function(str)
        return (' '):rep((80 - #str) /2) .. str
    end

    local headers = {
        current_list = center_alignment('AzureSets - Current Spell List'),
        help = center_alignment('AzureSets - Command List'),
    }
    
    local help_message = {
        ___,
        headers.help,
        ___,
        _ ..'1. spellset <setname> [mode]',
        __ .. arrow ..'Set spells to <setname>',
        __ .. arrow ..'(mode:optional): "ClearFirst" "PreserveTraits" overrides',
        __ .. arrow ..'setting to clear spells first or remove individually,',
        __ .. arrow ..'preserving traits where possible. Default: use settings or',
        __ .. arrow ..'preservetraits if settings not configured.',
        n,
        _ ..'2. set <setname> [mode]',
        __ .. arrow ..'Same as spellset',
        n,
        _ ..'3. save <setname>',
        __ .. arrow ..'Saves current spellset as (setname).',
        n,
        _ ..'4. add <slot> <spell>',
        __ .. arrow ..'Set spell to slot (slot:number).',
        n,
        _ ..'5. delete <setname>',
        __ .. arrow ..'Delete (setname) spellset.',
        n,
        _ ..'6. removeall',
        __ .. arrow ..'Unsets all spells.',
        n,
        _ ..'7. currentlist',
        __ .. arrow ..'Lists currently set spells.',
        n,
        _ ..'8. setlist',
        __ .. arrow ..'Lists all spellsets.',
        n,
        _ ..'9. spelllist <setname>',
        __ .. arrow ..'List spells in (setname)',
        n,
        _ ..'10. setmode <mode>',
        __ .. arrow ..'Set default setmode: "ClearFirst" "PreserveTraits"',
        n,
        _ ..'11. help',
        __ .. arrow ..'Shows this menu.',
        n,
        ___,
    }

    function display_help_message()
        for _, v in ipairs(help_message) do
            add_to_chat(121, v)
        end
    end

    function list_current_set()
        local blu_spells = T(job_data[blu_main_or_sub()]().spells)

        blu_spells = blu_spells:filter(function(id) return id ~= 512 end)
        blu_spells = blu_spells:map(function(id) return spells[id].english end)

        add_to_chat(121, ___)
        add_to_chat(121, headers.current_list)
        add_to_chat(121, ___)

        for i, v in ipairs(blu_spells) do
            add_to_chat(121, patterns.line:format(patterns.index:format(i), v))
        end

        add_to_chat(121, ___)
    end
end

local current_set_text = {
    '-----------------------------------------------------------------------------',
    '                         AzureSets - Current Spell List',
    '-----------------------------------------------------------------------------',
}

windower.register_event('addon command', function(...)
    if not blu_main_or_sub() then
        error('You are not on Main or Sub Blue Mage.')
        return
    end

    local args = T{...}

    if #args == 0 or args[1]:lower() == 'help' then
        display_help_message()
    else
        local comm = args:remove(1):lower()

        if comm == 'removeall' then
            remove_all_spells()

        elseif comm == 'add' then
            if args[2] then
                local slot  = args:remove(1)
                local spell = args:sconcat():lower()

                set_single_spell(spell, slot)
            end

        elseif comm == 'save' then
            if args[1] then
                save_set(args[1])
            end

        elseif comm == 'delete' then
            if args[1] then
                delete_set(args[1])
            end

        elseif comm == 'spellset' or comm == 'set' then
            if args[1] then
                set_spells(args[1], args[2])
            end

        elseif comm == 'currentlist' then
            local role = blu_main_or_sub()

            if job_data[role] then
                list_current_set()
            end

        elseif comm == 'setlist' then
            get_spellset_list()

        elseif comm == 'spelllist' then
            if args[1] then
                get_spellset_content(args[1])
            end

        elseif comm == 'setmode' then
            if args[1] then
                set_default_setmode(args[1]:lower())
            end
        end
    end
end)
