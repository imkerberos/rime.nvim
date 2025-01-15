-- luacheck: ignore 112 113
---@diagnostic disable: undefined-global
local rime = require "rime"
local M = require "rime.nvim.config"
local utils = require "rime.nvim.utils"

local set_scheme = function()
    local defaults = {
        RimeCompositionBG = { bg = "#F5F5DC" },
        RimePreeditNormal = { fg = "#008000" },
        RimePreeditCursor = { fg = "#008000" },
        RimeCandidateNormal = { fg = "#000000" },
        RimeCandidateSelected = { fg = "#000000", bg = "#FF2F92" },
        RimeCandidateNumber = { fg = "#808080" },
    }

    for hl_group, hl in pairs(defaults) do
        vim.api.nvim_set_hl(0, hl_group, hl)
    end
end


---setup
---@param conf table
function M.setup(conf)
    M = vim.tbl_deep_extend("force", M, conf)
    set_scheme()
    M.ns = vim.api.nvim_create_namespace('my_highlights') -- 创建命名空间，避免冲突
end

---process key
---@param key string
---@param modifiers string[]
function M.process_key(key, modifiers)
    modifiers = modifiers or {}
    local keycode, mask = require("rime.parse_key")(key, modifiers)
    return rime.processKey(M.session_id, keycode, mask)
end

---process keys
---@param keys string
---@param modifiers string[]
function M.process_keys(keys, modifiers)
    modifiers = modifiers or {}
    for key in keys:gmatch("(.)") do
        if M.process_key(key, modifiers) == false then
            return false
        end
    end
    return true
end

---get callback for draw UI
---@param key string
function M.callback(key)
    return function()
        if vim.b.rime_is_enabled then
            return M.draw_ui(key)
        end
    end
end

---get rime commit
function M.get_commit_text()
    if rime.commitComposition(M.session_id) then
        return rime.getCommit(M.session_id).text
    end
    return ""
end

---reset keymaps
function M.reset_keymaps()
    if M.preedit ~= "" and M.has_set_keymaps == false then
        for _, lhs in ipairs(M.keys.special) do
            vim.keymap.set("i", lhs, M.callback(lhs), { buffer = 0, noremap = true, nowait = true, })
        end
        M.has_set_keymaps = true
    elseif M.preedit == "" and M.has_set_keymaps == true then
        for _, lhs in ipairs(M.keys.special) do
            vim.keymap.del("i", lhs, { buffer = 0 })
        end
        M.has_set_keymaps = false
    end
end

local function highlight_line(win_id, buf_id, line_number, hl_group)
    return vim.api.nvim_buf_set_extmark(buf_id, M.ns, line_number, 0,
        { end_line = line_number + 1, end_col = 0, hl_group = hl_group }) -- 高亮整行
    -- vim.api.nvim_buf_add_highlight(buf_id, ns, hl_group, line_number, 0, -1)                                                          -- 高亮整行
end

---feed keys
---@param text string
function M.feed_keys(text)
    if vim.v.char ~= "" then
        vim.v.char = text
    else
        -- cannot work
        -- vim.api.nvim_feedkeys(text, 't', true)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = cursor[1]
        local col = cursor[2]
        vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { text })
        vim.api.nvim_win_set_cursor(0, { row, col + #text })
    end
    M.win_close()
    M.preedit = ""
    M.reset_keymaps()
end

---draw UI
---@param key string
function M.draw_ui(key)
    if key == "" then
        key = vim.v.char
    end
    if M.preedit == "" then
        for _, disable_key in ipairs(M.keys.disable) do
            if key == vim.keycode(disable_key) then
                M.disable()
            end
        end
    end
    if M.process_key(key, {}) == false then
        if #key == 1 then
            M.feed_keys(key)
        end
        return
    end
    local context = rime.getContext(M.session_id)
    if context.menu.num_candidates == 0 then
        M.feed_keys(M.get_commit_text())
        return
    end
    vim.v.char = ""

    local lines, row, col = require("rime.draw_ui")(context, M.ui, vim.api.nvim_strwidth(M.ui.left))
    M.preedit = lines[1]
        :gsub(M.ui.cursor, "")
        :gsub(" ", "")

    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(vim.api.nvim_strwidth(line), width)
    end
    local config = {
        relative = "cursor",
        height = #lines,
        style = "minimal",
        width = width,
        border = "none",
        row = 1,
        col = col,
    }
    if M.buf_id == 0 or not vim.api.nvim_buf_is_valid(M.buf_id) then
        M.buf_id = vim.api.nvim_create_buf(false, true)
    end
    vim.schedule(
        function()
            vim.api.nvim_buf_set_lines(M.buf_id, 0, #lines, false, lines)
            if (M.win_id == 0 or not vim.api.nvim_win_is_valid(M.win_id)) then
                M.win_id = vim.api.nvim_open_win(M.buf_id, false, config)
                M.selected_extmark_id = highlight_line(M.win_id, M.buf_id, row, "RimeCandidateSelected")
                vim.api.nvim_win_set_option(M.win_id, 'winhighlight', "Normal:RimeCompositionBG")
            else
                vim.api.nvim_win_set_config(M.win_id, config)
                if M.selected_extmark_id then
                    vim.api.nvim_buf_del_extmark(M.buf_id, M.ns, M.selected_extmark_id)
                    M.selected_extmark_id = highlight_line(M.win_id, M.buf_id, row, "RimeCandidateSelected")
                end
            end
            --[[
            RimeCompositionBG
            RimePreeditNormal, RimePreeditCursor
            RimeCandidateNormal
            RimeCandidateSelected
            RimeCandidateNumber
            --]]
        end
    )
    M.reset_keymaps()
end

---close IME window
function M.win_close()
    vim.schedule(
        function()
            if M.win_id ~= 0 and vim.api.nvim_win_is_valid(M.win_id) then
                vim.api.nvim_win_close(M.win_id, false)
            end
            M.win_id = 0
        end
    )
end

---clear composition
function M.clearComposition()
    rime.clearComposition(M.session_id)
end

---initial
function M.init()
    if M.session_id == 0 then
        vim.fn.mkdir(M.rime.log_dir, "p")
        rime.init(M.rime)
        M.session_id = rime.createSession()
    end
    if M.augroup_id == 0 then
        M.augroup_id = vim.api.nvim_create_augroup("rime", { clear = false })
    end
end

function M.my_callback(key)
    return function()
        local key = vim.v.char
        M.callback(key)()
    end
end

---enable IME
function M.enable()
    vim.print("enable rime")
    M.init()
    local keymap_options = { buffer = 0, noremap = true, nowait = true }
    for _, nowait_key in ipairs(M.keys.nowait) do
        vim.keymap.set("i", nowait_key, nowait_key, keymap_options)
    end

    vim.api.nvim_create_autocmd("InsertCharPre", {
        group = M.augroup_id,
        buffer = 0,
        callback = M.my_callback(""),
        -- callback = M.callback(""),
    })
    vim.api.nvim_create_autocmd({ "InsertLeave", "WinLeave" }, {
        group = M.augroup_id,
        buffer = 0,
        callback = function()
            M.clearComposition()
            M.win_close()
        end
    })
    vim.b.rime_is_enabled = true
end

---disable IME
function M.disable()
    vim.print("disable rime")
    for _, nowait_key in ipairs(M.keys.nowait) do
        vim.keymap.del("i", nowait_key, { buffer = 0 })
    end

    vim.api.nvim_create_augroup("rime", {})
    vim.b.rime_is_enabled = false
end

---get context with all candidates
---@param keys string
---@return table
function M.get_context_with_all_candidates(keys)
    M.init()
    M.process_keys(keys, {})
    local context = rime.getContext(M.sessionId)
    if (keys ~= '') then
        local result = context
        while (not context.menu.is_last_page) do
            M.process_key('=', {})
            context = rime.getContext(M.sessionId)
            result.menu.num_candidates = result.menu.num_candidates + context.menu.num_candidates
            if (result.menu.select_keys and context.menu.select_keys) then
                table.insert(result.menu.select_keys, context.menu.select_keys)
            end
            if (result.menu.candidates and context.menu.candidates) then
                table.insert(result.menu.candidates, context.menu.candidates)
            end
        end
    end
    M.clearComposition()
    return context
end

---toggle IME
function M.toggle()
    if vim.b.rime_is_enabled then
        M.disable()
    else
        M.enable()
    end
end

function M.inlineAscii()
    if vim.b.rime_is_enabled then
        rime.inlineAscii()
        vim.notify("inline ascii")
    end
end

function M.icon()
    if vim.b.rime_is_enabled then
        return "🌐", { fg = "green" }
    else
        return "🌐", { fg = "grey" }
    end
end

M.rime_enabled = false

function M.enable_rime()
    vim.print("install event filter")
    if M.rime_enabled then
        return
    end
    M.rime_enabled = true

    local rime_group = vim.api.nvim_create_augroup("RimeTriggerGroup", { clear = true })

    vim.api.nvim_create_autocmd("TextChangedI", {
        group = rime_group,
        pattern = "*",
        callback = function()
            local word_before = utils.get_chars_before_cursor(2, 2) or ""
            vim.print("word_before: \"" .. word_before .. "\"")
            -- 行首不变
            if word_before == "" then return end
            -- 英文+标点 + 空格 -> 英文
            -- 中文+标点 + 空格 -> 中文
            --      英文 + 空格 -> 中文
            --      中文 + 空格 -> 英文
            --  大写字母 + 空格 -> 中文
            if word_before:match("[%w%p]%s") then
                vim.print("1")
                if not vim.b.rime_is_enabled then
                    M.enable()
                end
            elseif word_before:match("[^%w%p]%s") then
                vim.print("2")
                if vim.b.rime_is_enabled then
                    M.disable()
                end
            elseif word_before:match("[%w%p]$") then
                vim.print("3")
                if vim.b.rime_is_enabled then
                    M.disable()
                end
            elseif word_before:match("[^%w%p]$") then
                vim.print("4")
                if not vim.b.rime_is_enabled then
                    M.enable()
                end
            else
                vim.print("5")
            end
        end
    })

    if not vim.b.rime_is_enabled then
        M.enable()
    end
end

function M.disable_rime()
    if not M.rime_enabled then
        return
    end
    M.rime_enabled = false
    vim.api.nvim_del_augroup_by_name("RimeTriggerGroup")
    if vim.b.rime_is_enabled then
        M.disable()
    end
end

function M.toggle_rime()
    if M.rime_enabled then
        M.disable_rime()
    else
        M.enable_rime()
    end
end

return M
