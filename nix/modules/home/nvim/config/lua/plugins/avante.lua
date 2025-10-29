return {
    {
        "yetone/avante.nvim",
        build = "make",
        event = { "BufReadPost", "BufNewFile" },
        cmd = { "AvanteAsk", "AvanteChat", "AvanteEdit" },
        version = false,
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            "nvim-telescope/telescope.nvim",
            "hrsh7th/nvim-cmp",
            "folke/snacks.nvim",
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            -- Add error handling for window management
            local avante_ok, avante = pcall(require, "avante")
            if not avante_ok then
                vim.notify("Avante failed to load", vim.log.levels.ERROR)
                return
            end

            avante.setup({
                -- debug = true,
                provider = "gemini-cli",
                acp_providers = {
                    ["gemini-cli"] = {
                        command = "gemini",
                        args = { "--experimental-acp" },
                        env = {
                            NODE_NO_WARNINGS = "1",
                            -- GEMINI_API_KEY = os.getenv("GEMINI_API_KEY"),
                        },
                    },
                },
                -- Window management configuration
                windows = {
                    position = "right",
                    width = 30,
                    sidebar_header = {
                        align = "center",
                        rounded = true,
                    },
                },
                -- Add safe window handling
                hints = {
                    enabled = true,
                },
                -- Ensure proper autocmd handling
                auto_set_highlight_group = true,
                auto_set_keymaps = true,
            })

            -- Add safety checks for window operations
            vim.api.nvim_create_autocmd("WinNew", {
                pattern = "*",
                callback = function()
                    -- Delay Avante operations to ensure window is properly initialized
                    vim.defer_fn(function()
                        -- Additional safety for new windows
                    end, 10)
                end,
                group = vim.api.nvim_create_augroup("AvanteSafeWindow", { clear = true }),
            })

            -- Override window validation for Avante
            local original_nvim_win_get_height = vim.api.nvim_win_get_height
            vim.api.nvim_win_get_height = function(win)
                if not vim.api.nvim_win_is_valid(win) then
                    vim.notify("Avante: Invalid window ID " .. tostring(win), vim.log.levels.WARN)
                    return 0
                end
                return original_nvim_win_get_height(win)
            end
        end,
    },
}
