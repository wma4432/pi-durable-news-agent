# Local setup — Mike's fork

Operational notes for running this fork. **Not upstream.** `README.md` is kept identical
to upstream so it never conflicts on a merge.

Fuller project notes — what the thing is, the sweep pipeline, Hype/Facts/Signal, the
cost model, and the sandbox decision — live in the ideas repo at
`projects/durable-news-agent/` (`knowledge/local-setup-notes.md`).

## Remotes

| Remote | Points at |
|---|---|
| `origin` | `wma4432/pi-durable-news-agent` — this fork, where local work lands |
| `upstream` | `disler/pi-durable-news-agent` — the original |

Pull upstream changes with `git fetch upstream && git merge upstream/main`.

## Running it

Use `./run.sh`, not bare `just` — it handles two local quirks:

1. The justfile hardcodes `set shell := ["zsh", ...]`. **zsh isn't installed here** and
   installing it needs sudo. `--shell bash` overrides it; the recipes are POSIX-clean.
2. Node 24 comes from nvm, which isn't active in a non-login shell.

```bash
cp .env.example .env            # you must do this one — the repo hook blocks agent access
./run.sh api tokens             # writes the two bearer tokens (names only, never values)

./run.sh combos dev             # FREE + OFFLINE: faux model, fixture news, UI on :4851
./run.sh combos local           # real mode — needs an OpenRouter key in the env file
./run.sh net down local         # stop API, UI and tick
```

Start with `combos dev`. It needs no key and costs nothing, and it shows the real
interface — enough to decide whether an OpenRouter account is worth opening at all.

The two tokens are local passwords between the server and its own clients. Not a
third-party thing; nothing leaves the machine.

## The cron line is always every minute

`cron: "* * * * *"` in the network config is the *tick*. The **API's own schedule**
(5 min default, 1–60 or off) decides which ticks actually run a sweep. So cadence and
cost are controlled in the app — not by editing crontab.

## Two security notes from upstream, relevant if this ever leaves this box

- A device with a `ui` entry **serves its UI open to that network** — anyone on the
  same Wi-Fi can read *and steer* the agent. Drop `ui` from its entry to keep it private.
- A private VM needs `just net tunnel vm` before the CLI or TUI can reach it.

## Honest caveat

**This box is not always on.** "Proactive" assumes a machine that stays up — the author
uses an always-on Mac mini. Under WSL it only sweeps while your computer is running and
the process is up, so it's fine for evaluating and wrong for the actual promise.

The candidate always-on host is the **GEEKOM** (192.168.1.123) — Ubuntu Server, already
on the LAN, this repo's `linux` device kind. See the ideas project for why that is now a
co-tenancy decision rather than a free one.

## Install state as of 2026-11-08

- [x] Repo cloned
- [x] Node 24.22.2 (nvm; `.nvmrc` pins it)
- [x] `just` 1.59.0 in `~/.local/bin`
- [x] 261 npm packages
- [x] `run.sh` wrapper + `.nvmrc`
- [ ] Env file — **your step**
- [ ] OpenRouter key — only needed for real mode
