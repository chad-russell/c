-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Set leader keys first
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load core config
require("core.options")
require("core.keymaps")
require("core.autocmds")

-- Load plugins
require("lazy").setup("plugins")
