# Secret checker

A universal pre-publish scanner. Before anything goes into a public repo or out to the internet, run this and let its exit code decide whether you are allowed to publish. It does not rely on an assistant remembering to look; it is a program that either passes or fails.

Cross-platform: the same Betterleaks binary works on Windows, macOS, and Linux. You pick the wrapper that matches your shell.

## What it does

It runs [Betterleaks](https://github.com/betterleaks/betterleaks) over a target folder, scanning both the working tree and the full git history (a secret that was committed once and then deleted is still in history and will be found). Betterleaks is the drop-in successor to Gitleaks from the same author: it ships a large built-in rule set covering API keys, tokens, passwords, cloud credentials, and more, and it catches doubly and triply encoded secrets that older scanners miss. On top of those, it loads `betterleaks-extra.toml` from this folder so you can add project-specific patterns: an internal hostname, a reverse-proxy domain, a machine name, a personal identifier that must never ship.

## Installing and updating Betterleaks

Nothing to do. The wrapper scripts handle it: if `betterleaks` is not found on your PATH, the script installs the latest stable release automatically (via winget on Windows, brew on macOS where available, or by downloading the release binary directly from GitHub otherwise). Before every scan it compares the installed version against the latest stable release and updates if behind. No scanner binary is committed to this repo; the scripts fetch it on demand, which keeps the repo light and means the gate always runs current detection rules. If you prefer to manage the binary yourself, put any `betterleaks` on your PATH and the scripts will use it (they will still check whether a newer stable release exists).

## Run it

Windows (PowerShell):

```powershell
.\run-secret-check.ps1                  # scan the current folder
.\run-secret-check.ps1 -Target C:\path\to\repo
```

macOS / Linux (bash or zsh):

```sh
./run-secret-check.sh                   # scan the current folder
./run-secret-check.sh /path/to/repo
```

Exit code `0` means clean and safe to publish. Any other exit code means it found something; read the hits, confirm each one, rotate any credential that was ever exposed, and remove it from the file and from git history before publishing again.

## Adding a project-specific rule

Edit `betterleaks-extra.toml`. Each rule is a narrow regex with an id and a tag. Keep them specific so they do not flag legitimate content. The file ships with commented examples (an internal hostname or domain, a machine name, and a private IP address); uncomment and adapt them per project. Add one rule for each of your own identifiers that must never ship: machine name, domains, and any IPs you keep private.

Keep this file free of your real values, it is committed, and a rule containing your actual machine name or IP leaks exactly what it was written to catch. Put personal identifiers in a second, untracked config such as `checks/scan-private.toml` (the repo's `.gitignore` covers that filename). The wrapper scripts pick it up automatically when it exists and merge it with the tracked rules at scan time. Shareable team-wide patterns can live in the tracked file; anything that identifies you personally stays local. (The merge is deliberate: Betterleaks honours only the last `--config` flag it is given, so simply passing two flags would silently disable one file.)

Real credentials (tokens, passwords, API keys) do not belong in any config or script at all: they live in one untracked `.env` file at the project root as `NAME=value` lines (also covered by `.gitignore`). Scripts and docs refer to them by variable name only, and the user is asked to place values into `.env` rather than paste them into chat, because chat logs keep what is typed there.

## Prove your rules actually load

A rule that has never fired is an unverified claim. Betterleaks silently ignores a misnamed config table, so one typo can leave you scanning with zero custom rules while every scan still reads as clean, and a clean scan at the publish boundary then proves nothing. After writing or changing any rule, prove it works: scan a scratch file that contains one known match for the rule and require the scanner to flag that match. If it does not flag it, the rule or its config is broken; fix that before trusting any scan. Do the same after changing config structure, a new table, a renamed file, a new merge, since any of those can silently disconnect the rules.

## Keep patterns line-safe

The scanner reads whole files, so a pattern using `\s` can match across line breaks: a key at the end of one line and the next line's content fuse into one false hit. In key=value style patterns, use `[ \t]*` for optional gaps instead of `\s*`, and `[ \t]+` instead of `\s+`, so matching stays within a line.

## How it fits the playbook

Ground Rule 4 says secrets stay out of code, files, logs, repos, and chat output. This script is the mechanical enforcement of that rule at the publish boundary. In Phase 3, run it before any step that pushes to a remote or exposes a file externally. In Phase 4, run it across the whole project as part of the final regression pass. A red result blocks the publish until resolved, exactly like any other failing check.
