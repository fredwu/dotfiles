# Fred Wu's dotfiles

![Terminal screenshot](screenshot.png)

An opinionated, idempotent development environment for macOS and Linux. The
installer configures Zsh and Prezto, Neovim with LazyVim, command-line tools,
and the dotfile links in this repository.

## Supported systems

- macOS with Apple Command Line Tools installed
- Debian or Ubuntu (`apt`)
- Fedora (`dnf`)
- Arch Linux (`pacman`)

Both x86-64 and ARM64 Linux are supported. Other Linux distributions can still
use the repository, but the installer stops with a clear error when it cannot
find a supported package manager.

## Installation

```sh
git clone https://github.com/fredwu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Run the installer as your regular user, not with `sudo`; it requests elevated
permissions only for system package and login-shell changes.

It is safe to run `./install.sh` again. Existing files at managed paths are
moved to a timestamped directory under `~/.dotfiles-backups` before links are
created. Correct links, existing package installations, fonts, and Git
checkouts are left alone.

Claude Code, Codex, and Grok keep real configuration directories at
`~/.claude`, `~/.codex`, and `~/.grok`, allowing tool-managed configuration to
remain outside this repository. Their instruction files are linked from
`ai/shared`. [Skillshare](https://skillshare.runkids.cc/) manages their skill
directories in whole-directory symlink mode, using the Git-tracked
`ai/skillshare/skills` directory as its canonical source. Shared agents live in
`ai/skillshare/agents`. Their Markdown frontmatter is provider-neutral, so
provider-specific model and effort settings are declared once in
`ai/skillshare/agent-models.json`. One `dotfiles-agents` extra reads the real
repository agents directory and uses the repo-managed
`dotfiles-claude-agents` and `dotfiles-codex-agents` extensions to generate
Claude Markdown and Codex TOML files. The custom implementation uses only
Skillshare's documented extension contract and does not import or modify a
built-in extension. Shared transformer code stays in the repository and is not
installed as a third extension. The extension names are separate from
Skillshare's built-ins, which remain entirely under Skillshare's ownership.
Skillshare's native agent source is an empty real directory. This makes native
agent status expect zero files and leaves the generated extra as the sole owner
of `~/.claude/agents` and `~/.codex/agents`. A namespaced ownership manifest
under `$XDG_STATE_HOME/dotfiles`, or `~/.local/state/dotfiles` when that variable
is unset, records generated files. Removed agents are archived under
`~/.dotfiles-backups`; unrelated target files and other Skillshare resources are
left untouched.

The installer preserves an existing Skillshare configuration. It initializes
global skill targets without creating a nested Git repository, installs the
namespaced extension files as repo-backed links in real directories under
`~/.config/skillshare/extensions`, validates that every neutral source has both
model mappings, archives any prior native agent source, and points
`sources.agents` at the empty Skillshare directory. Skills sync normally;
generated agents force-refresh so source or model-map changes update existing
files. Skillshare skill commands such as `install`, `update`, and `uninstall`
therefore modify files in this repository; commit those changes with the rest
of the dotfiles. Configuration migration accepts the block YAML emitted by
Skillshare and fails without changing the file when relevant sections use a
different YAML form. Skillshare 0.20.25 or newer is required; Linux installs are
pinned to 0.20.25 while Homebrew upgrades remain supported.

The installer changes the account's login shell to Zsh when necessary. Open a
new terminal after it completes.

### Migrating the legacy Vim setup

Run this once on a machine previously configured by the old installer:

```sh
./install.sh --cleanup
```

Cleanup recognises the old spf13-vim checkout, its Vundle plugin tree, known
Vim symlinks, the obsolete Droid Nerd Font, and `use-agent` in the GnuPG
configuration. The Vundle tree, old font, and other ambiguous or modified data
are always archived for manual review; verified generated data is removed.
Historical `*.backup.*` files and `~/.viminfo` are always preserved. Cleanup is
repeatable and then performs the normal install.

## What is installed

- [Prezto](https://github.com/sorin-ionescu/prezto) with prezto-contrib
- [Neovim](https://neovim.io/) and [LazyVim](https://www.lazyvim.org/)
- Hack Nerd Font
- Git, GnuPG, direnv, fzf, zoxide, ripgrep, fd, Node.js, mise, and related build tools
- Grok, Codex, and Claude Code CLI casks on macOS
- Skillshare, with shared skills and agents stored in this repository
- Shared instructions for Claude Code, Codex, and Grok

On Linux, official pinned Neovim, mise, Skillshare, and Tree-sitter builds are
installed under `~/.local/opt` as needed. The pinned Neovim is used when the
distribution package is older than the version required by the locked LazyVim
configuration.

## Custom configuration

- Put personal shell values in `~/.zsh_custom`; the installer creates it once
  from `zsh/custom.example` and never overwrites it.
- Use `sr` to reload `.zshrc`.
- Add LazyVim options, keymaps, autocommands, and plugin specifications under
  `config/nvim/lua`.

## Installer development

The entry point is intentionally small; implementation modules live in
`install/lib`. Run the isolated test suite with:

```sh
/bin/bash install/tests/run.sh
```

The tests replace `HOME` with a temporary directory and do not use the network,
root privileges, or the real package managers.
