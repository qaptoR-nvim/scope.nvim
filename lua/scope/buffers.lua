local U = {}

local scope_core = require("scope.core")
local filter = vim.tbl_filter

local function apply_cwd_only_aliases(opts)
    local has_cwd_only = opts.cwd_only ~= nil
    local has_only_cwd = opts.only_cwd ~= nil

    if has_only_cwd and not has_cwd_only then
        -- Internally, use cwd_only
        opts.cwd_only = opts.only_cwd
        opts.only_cwd = nil
    end

    return opts
end

local function extend_without_duplicates(l0, l1)
    local result = {}
    for _, v in ipairs(l0) do
        table.insert(result, v)
    end
    for _, v in ipairs(l1) do
        if not vim.tbl_contains(result, v) then
            table.insert(result, v)
        end
    end
    return result
end

local function get_all_scope_buffers()
    local scope_buffs = {}
    for _, bufs in pairs(scope_core.cache) do
        for _, buf in pairs(bufs) do
            table.insert(scope_buffs, buf)
        end
    end
    return scope_buffs
end

function U.get_scoped_buffers(opts)
    opts = opts or {}
    opts = apply_cwd_only_aliases({})
    scope_core.revalidate()
    local bufnrs = filter(
        function(b)
            if opts.show_all_buffers == false and not vim.api.nvim_buf_is_loaded(b) then
                return false
            end
            if opts.ignore_current_buffer and b == vim.api.nvim_get_current_buf() then
                return false
            end
            if opts.cwd_only and not string.find(vim.api.nvim_buf_get_name(b), vim.loop.cwd(), 1, true) then
                return false
            end
            if not opts.cwd_only and opts.cwd and not string.find(vim.api.nvim_buf_get_name(b), opts.cwd, 1, true) then
                return false
            end
            return true
        end,
        extend_without_duplicates(
            vim.tbl_filter(function(b)
                return vim.fn.buflisted(b) == 1
            end, vim.api.nvim_list_bufs()),
            get_all_scope_buffers()
        )
    )
    if not next(bufnrs) then
        return
    end
    if opts.sort_mru then
        table.sort(bufnrs, function(a, b)
            return vim.fn.getbufinfo(a)[1].lastused > vim.fn.getbufinfo(b)[1].lastused
        end)
    end

    local buffers = {}
    local default_selection_idx = 1
    for _, bufnr in ipairs(bufnrs) do
        local flag = bufnr == vim.fn.bufnr("") and "%" or (bufnr == vim.fn.bufnr("#") and "#" or " ")

        if opts.sort_lastused and not opts.ignore_current_buffer and flag == "#" then
            default_selection_idx = 2
        end

        local element = {
            bufnr = bufnr,
            flag = flag,
            info = vim.fn.getbufinfo(bufnr)[1],
        }

        if opts.sort_lastused and (flag == "#" or flag == "%") then
            local idx = ((buffers[1] ~= nil and buffers[1].flag == "%") and 2 or 1)
            table.insert(buffers, idx, element)
        else
            table.insert(buffers, element)
        end
    end

    return buffers, default_selection_idx
end

return U
