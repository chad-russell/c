return {
    -- NvimTree
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        config = function()
            require("nvim-tree").setup({
                on_attach = function(bufnr)
                    local api = require("nvim-tree.api")

                    local function opts(desc)
                        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
                    end

                    -- Start with default mapings
                    api.config.mappings.default_on_attach(bufnr)

                    -- remove defaults - open-in-place is never useful to me
                    vim.keymap.del("n", "<C-e>", { buffer = bufnr })

                    -- override defaults
                    vim.keymap.set("n", ".", api.tree.change_root_to_node, opts("CD"))
                    vim.keymap.set("n", "?", api.tree.toggle_help, opts("Help"))
                    vim.keymap.set("n", "y", api.fs.copy.node, opts("Copy"))
                end,
                disable_netrw = false,
                hijack_netrw = true,
                sync_root_with_cwd = true,
                view = {
                    width = 50,
                },
            })
        end,
    },
}

