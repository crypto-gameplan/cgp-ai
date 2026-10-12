# cgp-ai

Sets up an AI work environment on a Mac with one command: the Claude and ChatGPT apps (ChatGPT includes Codex), the Claude Code and Codex command line tools,
Node.js, Python, Docker and the Crypto Gameplan plugins for Claude Code. You pick a profile, see what is already
there and what is missing, and nothing is installed until you confirm. Windows follows.

## Install

Read the script first if you like (it is short), then run it:

```bash
curl -fsSL https://raw.githubusercontent.com/crypto-gameplan/cgp-ai/main/install.sh -o install.sh
bash install.sh
```

Or in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/crypto-gameplan/cgp-ai/main/install.sh | bash
```

The installer downloads the latest release into `~/.cgp-ai/app`, adds the `cgp-ai` command to
`~/.local/bin` and starts the setup. To see the plan without installing anything, run `cgp-ai setup --dry-run`.

## Profiles

| Tool | Starter | Builder |
|---|---|---|
| Git | yes | yes |
| Claude Desktop | yes | yes |
| ChatGPT Desktop (with Codex) | yes | yes |
| Claude Code CLI | for the plugins | yes |
| Codex CLI | | yes |
| Node.js | | yes |
| uv and Python | | yes |
| Docker Desktop | | yes |
| Plugin CGP Essentials | yes | yes |
| Plugin CGP Effort | | yes |

Starter is for working with AI in the desktop apps. Builder is for agents, scripts and your own projects. Custom
asks about each item. The Claude Code CLI comes with every profile that has plugins, because Claude Code installs
plugins through it. Homebrew is installed first if it is missing.

## Commands

| Command | What it does |
|---|---|
| `cgp-ai setup` | Shows the plan and installs what is missing. The first run asks for a profile; later runs reuse it. `--change` asks again, `--profile starter\|builder\|custom` skips the question, `--dry-run` changes nothing, `--yes` skips the confirmation. |
| `cgp-ai update` | Upgrades the tools that do not update themselves and the plugins. Apps and the Claude Code CLI update themselves and are left alone. |
| `cgp-ai doctor` | Checks everything without changing anything: missing tools, the same command installed twice, Docker not running, missing plugins. Each finding comes with a fix. |

## What it does and does not do

- It installs only through Homebrew or the maker's own installer. Every source is listed in [manifest.json](manifest.json).
- It never touches logins, API keys or wallets. You sign in to each app yourself.
- It sends nothing to Crypto Gameplan.
- It asks for your Mac password only through Homebrew's own installer, and only when Homebrew is missing.
- Tools you already installed another way are recognised and left as they are.
- It adds `~/.local/bin` (and, when it installs Homebrew, Homebrew's setup line) to `~/.zprofile`, so new terminal
  windows find the new commands.

Your choice is saved in `~/.cgp-ai/selection`.

## How it is built

Everything the tool knows lives in [manifest.json](manifest.json): every tool with its install method, the plugins
and the profiles. The scripts in `lib/` read it with `plutil`, which every Mac has, and run on the bash that ships
with macOS. Adding a tool means adding an entry to the manifest.

| Field | Meaning |
|---|---|
| `mac.method` | `brew`, `brew-cask` or `vendor` (the maker's install command in `mac.install`) |
| `mac.package` | Homebrew formula or cask name |
| `mac.check` | Command that succeeds when the tool is installed by any route, and prints its version |
| `mac.app` | App bundle in /Applications that counts as installed |
| `self_updates` | `true` when the tool updates itself; `update` then leaves it alone |
| `requires` | Tools that are installed first |

## License

MIT, see [LICENSE](LICENSE).
