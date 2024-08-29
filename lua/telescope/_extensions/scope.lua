local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
    error("This plugin requires nvim-telescope/telescope.nvim")
end

local finders = require("telescope.finders")
local conf = require("telescope.config").values
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local transform_mod = require("telescope.actions.mt").transform_mod
local scope_core = require("scope.core")
local get_scoped_buffers = require("scope.buffers").get_scoped_buffers

local function find_buffer_tabindex(bufnr)
    for tabi, bufs in pairs(scope_core.cache) do
        for _, b in pairs(bufs) do
            if b == bufnr then
                return tabi
            end
        end
    end
    return nil
end

local scope_buffers = function(opts)
    local buffers, default_selection_idx = get_scoped_buffers(opts)

    pickers
        .new(opts, {
            prompt_title = "Scope Buffers",
            finder = finders.new_table({
                results = buffers,
                entry_maker = opts.entry_maker or make_entry.gen_from_buffer(opts),
            }),
            previewer = conf.grep_previewer(opts),
            sorter = conf.generic_sorter(opts),
            default_selection_index = default_selection_idx,
            attach_mappings = function(prompt_bufnr, map)
                local function open_buf_in_window(prompt_buf)
                    local selection = action_state.get_selected_entry()
                    if not selection then
                        print("Nothing currently selected")
                        return
                    end
                    actions.close(prompt_buf)
                    vim.cmd("buffer " .. selection.bufnr)
                end

                local actions_mod = { ["select_window"] = open_buf_in_window }
                actions_mod = transform_mod(actions_mod)

                map("i", "<C-w>", actions_mod.select_window)
                map("n", "<C-w>", actions_mod.select_window)

                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    -- print(vim.inspect(selection))
                    actions.close(prompt_bufnr)
                    local tabi = find_buffer_tabindex(selection.bufnr)
                    if tabi ~= nil then
                        vim.api.nvim_set_current_tabpage(tabi)
                    end
                    vim.cmd("buffer " .. selection.bufnr)
                end)
                return true
            end,
        })
        :find()
end

return telescope.register_extension({
    exports = { buffers = scope_buffers },
})
