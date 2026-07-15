local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repository = "https://github.com/folke/lazy.nvim.git"
  local commit = "85c7ff3711b730b4030d03144f6db6375044ae82"
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--no-checkout",
    repository,
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    vim.fn.delete(lazypath, "rf")
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { output, "WarningMsg" },
    }, true, {})
    os.exit(1)
  end

  output = vim.fn.system({ "git", "-C", lazypath, "checkout", "--detach", commit })
  if vim.v.shell_error ~= 0 then
    vim.fn.delete(lazypath, "rf")
    vim.api.nvim_echo({
      { "Failed to check out pinned lazy.nvim commit:\n", "ErrorMsg" },
      { output, "WarningMsg" },
    }, true, {})
    os.exit(1)
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  },
  defaults = {
    lazy = false,
    version = false,
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = { enabled = true, notify = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
