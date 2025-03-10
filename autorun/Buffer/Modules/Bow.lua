local utils, config, language
local Module = {
    title = "bow",
    data = {
        charge_level = -1,
        all_arrow_types = false,
        unlimited_bottles = false,
        max_trick_arrow_gauge = false
    },
    old = {},
    hidden = {}
}

function Module.init()
    utils = require("Buffer.Misc.Utils")
    config = require("Buffer.Misc.Config")
    language = require("Buffer.Misc.Language")

    Module.init_hooks()
end

function Module.init_hooks()

    -- Watch for weapon changes, need to re-apply the default arrow types 
    sdk.hook(sdk.find_type_definition("app.HunterCharacter"):get_method("changeWeapon"), function(args) 
        
        -- local new_weapon_id = sdk.to_int64(args[3])
        local managed = sdk.to_managed_object(args[2])
        if not managed:get_type_definition():is_a("app.HunterCharacter") then return end
        if not managed:get_IsMaster() then return end
        if not managed:get_WeaponHandling() then return end
        if not managed:get_WeaponHandling():get_type_definition() then return end

        -- Get weapons
        local is_main_bow = managed:get_WeaponHandling():get_type_definition():is_a("app.cHunterWp11Handling")
        local is_reserve_bow = managed:get_ReserveWeaponHandling():get_type_definition():is_a("app.cHunterWp11Handling")
        
        -- If bot weapon are not a bow
        if not is_main_bow and not is_reserve_bow then return end

        -- Check if all_arrow_types is enabled and we have the old arrow types
        if Module.data.all_arrow_types and Module.old.arrow_types then

            -- Get the weapon that is being changed out
            local weapon = managed:get_WeaponHandling()
            if not is_main_bow then weapon = managed:get_ReserveWeaponHandling() end

            -- Reset arrow types to the old arrow types
            for i = 1, #weapon:get_field("<BottleInfos>k__BackingField") do
                local bottle_info = weapon:get_field("<BottleInfos>k__BackingField")[i]
                if bottle_info then
                    bottle_info:set_field("<CanLoading>k__BackingField", Module.old.arrow_types[i])
                end
            end

            -- Reset old arrow types
            Module.old.arrow_types = nil
            
        end
    end, function(retval) end)
    
    -- Weapon changes
    sdk.hook(sdk.find_type_definition("app.cHunterWp11Handling"):get_method("update"), function(args) 
        local managed = sdk.to_managed_object(args[2])
        if not managed:get_type_definition():is_a("app.cHunterWp11Handling") then return end
        if not managed:get_Hunter() then return end
        if not managed:get_Hunter():get_IsMaster() then return end

        -- Charge Level
        if Module.data.charge_level ~= -1 then
            managed:set_field("<ChargeLv>k__BackingField", Module.data.charge_level)
        end


        -- All arrow types
        if Module.data.all_arrow_types and Module.old.arrow_types == nil then
            Module.old.arrow_types = {}
            local bottle_infos = managed:get_field("<BottleInfos>k__BackingField")
            for i, bottle_info in ipairs(bottle_infos) do
                Module.old.arrow_types[i] = bottle_info:get_field("<CanLoading>k__BackingField")
                bottle_info:set_field("<CanLoading>k__BackingField", true)
            end
        elseif Module.data.all_arrow_types and Module.old.arrow_types then
            -- check if any canloading is false, if so then it didn't set and we need to re-apply and re-save (The weapon change applies twice when changing weapons)
            local bottle_infos = managed:get_field("<BottleInfos>k__BackingField")
            local needs_reapply = false
            for i, bottle_info in ipairs(bottle_infos) do
                if not bottle_info:get_field("<CanLoading>k__BackingField") then
                    needs_reapply = true
                    break
                end
            end
            if needs_reapply then
                Module.old.arrow_types = nil
            end
        end 
        if not Module.data.all_arrow_types and Module.old.arrow_types then
            local bottle_infos = managed:get_field("<BottleInfos>k__BackingField")
            for i, bottle_info in ipairs(bottle_infos) do
                bottle_info:set_field("<CanLoading>k__BackingField", Module.old.arrow_types[i])
            end
            Module.old.arrow_types = nil
        end

        -- Manually set type of arrow
        -- <BottleType>k__BackingField
            -- 1 = Close Range
            -- 2 = Power
            -- 3 = Pierce
            -- 4 = Paralysis
            -- 5 = Poison
            -- 6 = Sleep
            -- 7 = Blast
            -- 8 = Exhaust

        -- Unlimited bottles
        if Module.data.unlimited_bottles then

            local tetrad_shot_active = false

            local skills = managed:get_Hunter():get_HunterSkill():get_field("_NextSkillInfo"):get_field("_items")
            
            for i = 0, skills:get_Length()-1 do
                local skill = skills:get_Item(i)
                if skill then
                    local skill_data = skill:get_SkillData()
                    if skill_data:get_Index() == 38 then -- Tetrad Shot
                        tetrad_shot_active = true
                        break
                    end
                end
            end
            local max_bottle_num = tetrad_shot_active and 4 or 10

            if tetrad_shot_active then Module.hidden.tetrad_shot_active = true
            elseif Module.hidden.tetrad_shot_active then Module.hidden.tetrad_shot_active = false end

            managed:set_field("<BottleNum>k__BackingField", max_bottle_num)
            managed:set_field("<BottleShotCount>k__BackingField", 10-max_bottle_num)
        end

        -- Trick Arrow Gauge 
        if Module.data.max_trick_arrow_gauge then
            managed:get_field("<ArrowGauge>k__BackingField"):set_field("_Value", 100)
        end

    end, function(retval) end)
end

function Module.draw()
    imgui.push_id(Module.title)
    local changed, any_changed = false, false
    local languagePrefix = Module.title .. "."

    if imgui.collapsing_header(language.get(languagePrefix .. "title")) then
        imgui.indent(10)
       
        changed, Module.data.charge_level = imgui.slider_int(language.get(languagePrefix .. "charge_level"), Module.data.charge_level, -1, 3, Module.data.charge_level == -1 and language.get("base.disabled") or "%d")
        any_changed = any_changed or changed

        changed, Module.data.all_arrow_types = imgui.checkbox(language.get(languagePrefix .. "all_arrow_types"), Module.data.all_arrow_types)
        any_changed = any_changed or changed

        changed, Module.data.unlimited_bottles = imgui.checkbox(language.get(languagePrefix .. "unlimited_bottles"), Module.data.unlimited_bottles)
        if Module.hidden.tetrad_shot_active then
            imgui.same_line()
            utils.tooltip(language.get(languagePrefix .. "tetrad_shot_active"))
        end
        any_changed = any_changed or changed

        changed, Module.data.max_trick_arrow_gauge = imgui.checkbox(language.get(languagePrefix .. "max_trick_arrow_gauge"), Module.data.max_trick_arrow_gauge)
        any_changed = any_changed or changed

        if any_changed then config.save_section(Module.create_config_section()) end
        imgui.unindent(10)
        imgui.separator()
        imgui.spacing()
    end
    imgui.pop_id()
end

function Module.reset()
    -- Implement reset functionality if needed
end

function Module.create_config_section()
    return {
        [Module.title] = Module.data
    }
end

function Module.load_from_config(config_section)
    if not config_section then return end
    utils.mergeTables(Module.data, config_section)
end

return Module
