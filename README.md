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

## Choose your AI

The setup first asks which AI you work with: Claude, ChatGPT and Codex, or both. Only the apps and tools for your
choice are installed. The Crypto Gameplan plugins are for Claude Code, so they come with Claude.

## Profiles

| Tool | Starter | Builder |
|---|---|---|
| Git | yes | yes |
| Claude Desktop | yes | yes |
| ChatGPT Desktop (with Codex) | yes | yes |
| Claude Code CLI | yes | yes |
| Codex CLI | yes | yes |
| Node.js | | yes |
| uv and Python | | yes |
| Docker Desktop | | optional |
| Plugin CGP Essentials (cgp-knowledge, cgp-challenge, cgp-natural-writing, cgp-agent-docs, cgp-research, cgp-test-first, cgp-architecture, cgp-review) | yes | yes |
| Plugin CGP Effort | | yes |
| Plugin CGP Crew | | yes |
| Plugin Blast Radius | yes | yes |

Starter gives you the desktop apps and both AI command line tools, so `claude` and `codex` work in any terminal; you
never have to open one if you do not want to. Builder adds what you need to build agents, scripts and your own
projects. Docker Desktop is optional there: Builder asks whether you want it (default no), because it is large and
only needed if you run containers; `--with docker-desktop` takes it without asking. Custom asks about each item. The Claude Code CLI is always installed when you choose plugins, because Claude
Code installs plugins through it. Homebrew is installed first if it is missing.

## Commands

| Command | What it does |
|---|---|
| `cgp-ai setup` | Shows the plan, installs what is missing and walks you through signing in. The first run asks for your AI and profile; later runs reuse them. `--change` asks again, `--ai claude\|openai\|both` and `--profile starter\|builder\|custom` skip the questions, `--with docker-desktop` adds Docker to Builder without asking, `--dry-run` changes nothing, `--yes` skips the confirmation and the sign-ins. |
| `cgp-ai update` | Upgrades the tools that do not update themselves and the plugins. Apps and the Claude Code CLI update themselves and are left alone. |
| `cgp-ai doctor` | Checks everything without changing anything: missing tools, the same command installed twice, sign-ins, Docker not started, missing plugins. Each finding comes with a fix. |

## Signing in

After installing, the setup goes through every app and tool that needs you: it starts the sign-in of the Claude Code
and Codex command line tools, opens Claude Desktop, ChatGPT Desktop and, if you chose it, Docker Desktop, and waits until you are done.
It ends with **All set** only when everything is installed and signed in; otherwise it lists what is still open, and
running `cgp-ai setup` again continues there.

The command line tools and Docker are checked directly. The desktop apps cannot be checked from outside, so you confirm
those yourself, and `doctor` marks them as confirmed.

## What it does and does not do

- It installs only through Homebrew or the maker's own installer. Every source is listed in [manifest.json](manifest.json).
- It never touches logins, API keys or wallets. It opens the app or starts the tool's own sign-in, and you sign in
  there yourself.
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
