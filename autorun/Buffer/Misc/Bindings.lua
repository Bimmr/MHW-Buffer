local utils = require("Buffer.Misc.Utils")
local language

local file_path = "Buffer/Bindings.json"

local pad_manager, main_pad
local mouse_keyboard_manager, main_mouse_keyboard
local key_bindings, btn_bindings
local modules = {}

local bindings = {
    btns = {},
    keys = {}
}

local popup = {}

-- Init the bindings module
function bindings.init(module_list)
    modules = module_list

    language = require("Buffer.Misc.Language")

    bindings.load_from_file()

    key_bindings = utils.generate_enum("ace.ACE_MKB_KEY.INDEX")
    btn_bindings = utils.generate_enum("ace.ACE_PAD_KEY.BITS")

    -- Testing
    -- bindings.add(1, {8192, 1024}, "miscellaneous.data.ammo_and_coatings.unlimited_ammo", true) -- R3 + R1
    -- bindings.add(1, {4096}, "great_sword.data.charge_level", 3) -- R3

    -- bindings.add(2, {8, 80}, "miscellaneous.data.ammo_and_coatings.unlimited_ammo", true) -- BACKSPACE + P
end

-- 1 = Gamepad | 2 = Keyboard
function bindings.get_device()
   if bindings.is_controller() then return 1 end
   if bindings.id_keyboard() then return 3 end
   return 0
end

-- Add a new binding
-- If device is gamepad(1)
-- If device is mouse(2)
-- If device is a keyboard(3)
function bindings.add(device, input, path, on)
    local binding_table = nil
    if device == 1 then
        binding_table = bindings.btns
    elseif device == 2 then
        binding_table = bindings.keys
    end
    if binding_table then
        table.insert(binding_table, {
            ["input"] = bindings.get_button_code(input),
            ["data"] = {
                path = path,
                on = on
            }
        })
        bindings.save_to_file()
    end
end

-- Remove a binding from the device's table (Sometimes doesn't work... will need to debug)
function bindings.remove(device, index)
    local binding_table = nil
    if device == 1 then
        binding_table = bindings.btns
    elseif device == 3 then
        binding_table = bindings.keys
    end
    if binding_table then
        table.remove(binding_table, index)
        bindings.save_to_file()
    end
end

-- ======== File Stuff ===========
function bindings.load_from_file()
    local file = json.load_file(file_path)
    if file then
        bindings.btns = file.btns or {}
        bindings.keys = file.keys or {}
    end
end

-- Save the bindings to a file
function bindings.save_to_file()
    json.dump_file(file_path, {
        ['keys'] = bindings.keys,
        ['btns'] = bindings.btns
    })
end
-- ======= Misc ===========
function bindings.get_formatted_title(path)
    path = string.gsub(path, "data%.", "")
    path = utils.split(path, ".")
    local currentPath = path[1]
    local title = language.get(currentPath .. ".title")
    for i = 2, #path, 1 do
        currentPath = currentPath .. "." .. path[i]
        if i == #path then
            title = title .. "/" .. language.get(currentPath)
        else
            title = title .. "/" .. language.get(currentPath .. ".title")
        end
    end
    return title
end
-- ======= Gamepad ==========

-- Buttons currently being pressed
local previous_buttons = 0
local triggered_buttons = {}

-- Check if the controller is being used
function bindings.is_controller()
    return bindings.get_current_button_code() > 0
end


-- Get the previous buttons
function bindings.get_previous_button_code()
    return previous_buttons
end
-- Get current buttons pressed
function bindings.get_current_button_code()
    if pad_manager == nil then
        pad_manager = sdk.get_managed_singleton("ace.PadManager")
    end
    if main_pad == nil then
        main_pad = pad_manager:get_MainPad()
    end
    local current = main_pad:get_KeyOn()
    if current == 0 then return -1 end
    return current
end

-- Get current buttons as a list of array {name, code}
function bindings.get_current_buttons()
    return bindings.get_button_names(bindings.get_current_button_code())
end

-- Convert the list of buttons back to a code
function bindings.get_button_code(arr_btns)
    local code = 0
    for _, btn in pairs(arr_btns) do code = code + btn.code end
    return code
end

-- Is the code being triggered
function bindings.is_button_code_triggered(code)
    local current = bindings.get_current_button_code()
    local previous = bindings.get_previous_button_code()
    return current ~= previous and current == code
end

-- Is the buttons being triggered
function bindings.is_buttons_triggered(arr_btns)
    local current = bindings.get_current_button_code()
    local previous = bindings.get_previous_button_code()

    -- if current has all buttons needed, and old has all but one, then return true
    local matches = 0
    for _, required_code in pairs(arr_btns) do
        local found = false
        for _, current_code in pairs(current) do if current_code == required_code then found = true end end
        for _, previous_code in pairs(previous) do
            if previous_code == required_code then
                found = true
                matches = matches + 1
            end
        end
        if not found then return false end
    end

    return matches + 1 == #arr_btns
end

-- Is the button being pressed
function bindings.is_button_down(code)
    local current = bindings.get_current_buttons()
    for _, btn in pairs(current) do if btn.code == code then return true end end
    return false
end

-- This function will return an array of {name, code} for each button
function bindings.get_button_names(code)
    local init_code = code

    -- If the code is a single btn
    local btns = {}
    while code > 0 do
        local largest = {
            code = 0
        }

        for btn_name, btn_code in pairs(btn_bindings) do
            if btn_code <= code and btn_code > largest.code then
                largest = {
                    name = btn_name,
                    code = btn_code
                }
            end
        end

        -- If we couldn't find a bigger code, then we must have all the possible ones
        if largest.code == 0 then break end

        -- Remove the largest and add it to the list of btns
        code = code - largest.code
        table.insert(btns, {name=largest.name, code=largest.code})
    end
    if #btns > 0 then return btns 
    elseif code ~= 0 and code ~= -1 then table.insert(btns, {name="Unknown", code=init_code}) return btns
    else return btns end
end

-- ======= Keyboard ==========


-- Keys currently being pressed
local previous_keys = {}
local triggered_keys = {}

-- Check if the keyboard is being used
function bindings.is_keyboard()
    return false
end

-- Get the previous keys
function bindings.get_previous_keys()
    return previous_keys
end

-- Get current keys pressed
function bindings.get_current_key_code()
    if mouse_keyboard_manager == nil then
        mouse_keyboard_manager = sdk.get_managed_singleton("ace.MouseKeyboardManager")
    end
    if main_mouse_keyboard == nil then
        main_mouse_keyboard = mouse_keyboard_manager:get_MainMouseKeyboard()
    end
    local keys_field = main_mouse_keyboard:get_field("_Keys")
    
end

-- Get current keys as a list of array {name, code}
function bindings.get_current_keys()
    return bindings.get_key_names(bindings.get_current_keys())
end

-- Convert the list of keys back to a code
function bindings.get_key_code(arr_keys)
   
end

-- Is the code being triggered
function bindings.is_key_code_triggered(code)
   
end

-- Is the keys being triggered
function bindings.is_keys_triggered(arr_keys)
    
end

-- Is the key being pressed
function bindings.is_key_down(code)
  
end

-- This function will return an array of {name, code} for each key
function bindings.get_key_names(code)
    
end

-- =========================================

-- Checks the bindings
function bindings.update()
    if bindings.is_controller() then
        for btn, input_data in pairs(bindings.btns) do 
            if bindings.is_button_code_triggered(input_data.input) and not triggered_buttons[btn] then 
                bindings.perform(input_data.data)
                triggered_buttons[btn] = true
            end 
        end
    end
    
    if bindings.is_keyboard() then
        for key, input_data in pairs(bindings.keys) do 
            if bindings.is_key_code_triggered(input_data.input) and not triggered_keys[key] then 
                bindings.perform(input_data.data)
                triggered_keys[key] = true
            end 
        end
    end

    bindings.popup_update()

    if not bindings.is_controller() then triggered_buttons = {} end
    if bindings.is_controller() then
        local current_buttons = bindings.get_current_button_code()
        for i, triggered_buttons in pairs(triggered_buttons) do
            if not bindings.is_button_down(triggered_buttons) then triggered_buttons[i] = nil end
        end
    end
    if not bindings.is_keyboard() then triggered_keys = {} end
    if bindings.is_keyboard() then
        local current_keys = bindings.get_current_key_code()
        for i, triggered_keys in pairs(triggered_keys) do
            if not bindings.is_key_down(triggered_keys) then triggered_keys[i] = nil end
        end
    end
    previous_buttons = bindings.get_current_button_code()
    previous_keys = bindings.get_current_key_code()
end

-- Draw anything the bindings need
function bindings.draw()
    bindings.popup_draw()
end

-- Perform the changes
function bindings.perform(data)
    local path = utils.split(data.path, ".")
    local on_value = data.on

    local enabled_text, disabled_text = "<COL YEL>".. language.get("window.bindings.enabled").."</COL>", "<COL RED>"..language.get("window.bindings.disabled").."</COL>"

    -- Find module
    local module_index
    for key, value in pairs(modules) do if modules[key].title == path[1] then module_index = key end end
    table.remove(path, 1)
    table.remove(path, 1)

    -- I have to do it this way because otherwise it changes it by value and not by reference which means the module remains unchanged...
    --     unless Lua has another option I don't know about - I'm open to suggestions

    local function toggle_boolean(module_data, path, on_value)
        local target = module_data
        for i = 1, #path - 1 do
            target = target[path[i]]
        end
        target[path[#path]] = not target[path[#path]]
        utils.send_message(bindings.get_formatted_title(data.path) .. " " .. (target[path[#path]] and enabled_text or disabled_text))
    end

    local function toggle_number(module_data, path, on_value)
        local target = module_data
        for i = 1, #path - 1 do
            target = target[path[i]]
        end
        if target[path[#path]] == -1 then
            target[path[#path]] = on_value
            utils.send_message(bindings.get_formatted_title(data.path) .. " " .. enabled_text)
        else
            target[path[#path]] = -1
            utils.send_message(bindings.get_formatted_title(data.path) .. " " .. disabled_text)
        end
    end

    print(json.dump_string(path))
    if type(on_value) == "boolean" then
        toggle_boolean(modules[module_index].data, path, on_value)
    elseif type(on_value) == "number" then
        toggle_number(modules[module_index].data, path, on_value)
    end
    
end
-- ================= Popup =====================

-- Popup updating function
function bindings.popup_update()
    if popup.open then
        if popup.listening then
            local current = popup.device == 1 and bindings.get_current_buttons() or bindings.get_current_keys()
            if #current > 0 then
                if not popup.binding then popup.binding = {} end
                popup.binding = current
            elseif #current == 0 and popup.binding and #popup.binding > 0 then
                popup.listening = false
            end
        end
    end
end

-- Open the popup for the given device (1 = Gamepad, 3 = Keyboard)
function bindings.popup_open(device)
    bindings.popup_reset()
    popup.open = true
    popup.device = device
end

-- Close the popup and reset fields
function bindings.popup_close()
    imgui.close_current_popup()
    bindings.popup_reset()
end

-- Reset the popup fields
function bindings.popup_reset()
    popup = {
        open = false,
        device = 0,
        listening = false,
        path = nil,
        on = true,
        binding = {}
    }
end

-- Draw the popup
function bindings.popup_draw()
    if popup.open then
        local popup_size = Vector2f.new(350, 135)
        -- If a path has been chosen, make the window taller
        if popup.path ~= nil then popup_size.y = 175 end
        imgui.set_next_window_size(popup_size, 1 + 256)
        imgui.begin_window("buffer_bindings", nil, 1)
        imgui.indent(10)
        imgui.spacing()
        imgui.spacing()

        -- Change title depending on device
        if popup.device == 1 then
            imgui.text(language.get("window.bindings.add_gamepad"))
        else
            imgui.text(language.get("window.bindings.add_keyboard"))
        end
        imgui.separator()
        imgui.spacing()
        imgui.spacing()

        -- If no path has been chosen use the default text from the language file, otherwise display the path selected
        local bindings_text = language.get("window.bindings.choose_modification")
        if popup.path ~= nil then bindings_text = bindings.get_formatted_title(popup.path) end
        if imgui.begin_menu(bindings_text) then
            for _, module in pairs(modules) do
                if imgui.begin_menu(language.get(module.title .. ".title")) then
                    bindings.popup_draw_menu(module, module.title)
                    imgui.end_menu()
                end
            end
            imgui.end_menu()
        end
        imgui.same_line()
        imgui.text("          ")
        imgui.spacing()

        -- If a path has been chosen show the option for the on value
        if popup.path ~= nil then
            imgui.spacing()

            -- On value for numbers - only allow numbers
            if type(popup.on) == "number" then
                imgui.text(language.get("window.bindings.on_value") .. ": ")
                imgui.same_line()
                local changed, on_value = imgui.input_text("     ", popup.on)
                if changed and on_value ~= "" and tonumber(on_value) then popup.on = tonumber(on_value) end

            -- On value for booleans, read only
            elseif type(popup.on) == "boolean" then
                imgui.text(language.get("window.bindings.on_value") .. ": ")
                imgui.same_line()
                imgui.input_text("   ", "true", 16384)
            end
            imgui.spacing()
            imgui.separator()
        end
        imgui.spacing()

        -- If not listening for inputs display default to listen from language file
        local listening_button_text = language.get("window.bindings.to_listen")

        -- If some inputs have been pressed, display them in a readable format
        if popup.binding and utils.getLength(popup.binding) > 0 then
            listening_button_text = ""
            
            for i, binding in pairs(popup.binding) do
                listening_button_text = listening_button_text .. binding.name
                if i < #popup.binding then listening_button_text = listening_button_text .. " + " end
            end
           
            if popup.listening then listening_button_text = listening_button_text .. " + ..." end

            -- If no inputs pressed use default listening from language file
        elseif popup.listening then
            listening_button_text = language.get("window.bindings.listening")
        end

        if imgui.button(listening_button_text) then
            popup.listening = true
            popup.binding = nil
        end
        imgui.separator()
        imgui.spacing()
        imgui.spacing()

        if imgui.button(language.get("window.bindings.cancel")) then bindings.popup_close() end
        if popup.path and popup.binding then
            imgui.same_line()
            if imgui.button(language.get("window.bindings.save")) then
                local path = popup.path
                -- add .data after the fist . in the path
                path = string.gsub(path, "%.", ".data.", 1)
                bindings.add(popup.device, popup.binding, path, popup.on)
                bindings.popup_close()
            end
        end
        imgui.unindent(10)
        imgui.end_window()
    end
end

function bindings.popup_draw_menu(menu, language_path)
    menu = menu or modules
    language_path = string.gsub(language_path, "%.data", "") or ""

    for key, value in pairs(menu) do

        -- If value is a table, then go deeper in the menu
        if type(value) == "table" then
            if key ~= "old" and key ~= "hidden" then
                if key == "data" then
                    bindings.popup_draw_menu(value, language_path .. "." .. key)
                elseif imgui.begin_menu(language.get(language_path .. "." .. key .. ".title")) then
                    bindings.popup_draw_menu(value, language_path .. "." .. key)
                    imgui.end_menu()
                end

            end

            -- If the value is a boolean or number, display the key
        elseif type(value) == "boolean" or type(value) == "number" then
            if imgui.menu_item(language.get(language_path .. "." .. key), nil, false, true) then
                popup.path = language_path .. "." .. key
                if type(value) == "number" then popup.on = tonumber(1) end
                if type(value) == "boolean" then popup.on = true end
            end
        end
    end
end

return bindings
