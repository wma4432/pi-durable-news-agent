# Local setup — Mike's fork

Operational notes for running this fork. **Not upstream.** `README.md` is kept
byte-identical to upstream so it never conflicts on a merge; everything local lives here.

Fuller project notes — the pipeline, Hype/Facts/Signal, the measured cost model, the
provider seams and the sandbox decision — live in the ideas repo at
`projects/durable-news-agent/`.

## Remotes

| Remote | Points at |
|---|---|
| `origin` | `wma4432/pi-durable-news-agent` — this fork, where local work lands |
| `upstream` | `disler/pi-durable-news-agent` — the original |

Pull upstream changes with `git fetch upstream && git merge upstream/main`.

## Prerequisites on this box

- Node 24 via nvm (`.nvmrc` pins it)
- `just` in `~/.local/bin`
- **zsh** — installed 2026-11-08 with `sudo apt install zsh`. The justfiles hardcode
  `set shell := ["zsh", "-cu"]`, and `just` does **not** pass `--shell` down to nested
  `just` calls, so any recipe that calls another recipe (`combos dev` is two of them)
  fails without it. Installing zsh did **not** change the login shell — that is still
  `/bin/bash`, and `chsh` was deliberately not run.

`./run.sh` is still the entry point: it resolves Node 24 out of nvm, which is not active
in a non-login shell.

## Running it

```bash
./run.sh api tokens      # writes the two bearer tokens (prints names only, never values)

./run.sh combos dev      # faux model + fixture news, UI on :4851
./run.sh cron tick       # ONE sweep through the real cron path, without touching crontab
./run.sh api sources-check   # fetch every source once, live, keyless — a connectivity probe
./run.sh cli run doctor  # preflight
./run.sh net down local  # stop API, UI and tick
```

Copying the env template is a manual step — the ideas-repo hook blocks agent access to
those files by design. The two tokens are local passwords between the server and its own
clients; nothing leaves the machine.

### The three dials

`combos dev` is fake on all three. They are independent:

| Dial | Fake | Real | Needs a key? |
|---|---|---|---|
| `DNA_SEARCH_MODE` | `fixture` | `auto` | **no** — free web chain + RSS |
| `DNA_PROVIDER` | `faux` | `openrouter` | yes |
| `JEV_BACKEND` | `fixture` | `openrouter` | yes — *the same key* |

**Shell env overrides the dotenv values**, so dials can be flipped per run without editing
anything:

```bash
DNA_PROVIDER=faux DNA_SEARCH_MODE=auto JEV_BACKEND=mock \
  DNA_DATA_DIR=/tmp/dna-halfreal ./run.sh api run
```

⚠️ **`JEV_BACKEND=mock` is mandatory in that half-real mode.** The moment search stops
being `fixture`, `jevBackend` resolves to `auto` and `selectProvider()` throws without a
key. Omit it and the sweep dies.

### Accounts: one

OpenRouter only. It serves both the chat model and jev — OpenRouter passes TypeSafe's
System One protocol through, so **no separate TypeSafe account**. The OpenAI key (card
images) and Firecrawl key (richer search and page reads) both degrade gracefully; leave
them unset.

## Measured cost — 2026-11-08

One real sweep on a warm database: **$0.0437** — `modelUsd 0.0074` + **`jevUsd 0.0363`**,
499 gate calls for 93 gathered items.

**jev is 83% of the bill.** The cheap-per-call classifier dominates because it runs ~5.4
calls per *gathered* item while the expensive model only ever sees the ~7 that survive.

Consequences:

- **Cost scales with items gathered per day, not with sweep count.** Dropping from hourly
  to twice-daily saves only the model half. **The lever that actually cuts cost is trimming
  `config/sources.json`.**
- **Cold start is a cliff.** An empty data dir treats everything as new — 615 items and
  8,425 gate calls in one sweep. Keep the data dir warm and **off `/tmp`**, which does not
  survive a reboot.
- Rough rates at ~615 items/day: twice daily ≈ $7.65/mo, hourly ≈ $12.50/mo.

## Cadence

The crontab line is the *tick*; the API's own schedule decides which ticks sweep. The app
caps at 60 minutes (`SCHEDULE_PRESETS = [1,5,10,15,30,60]`), so anything longer must come
from the cron expression:

```
DNA_CRON_SCHEDULE="0 5,17 * * *"     # 5am and 5pm
```

`tickMinutes()` reads the minute field — `*` → 1, `*/N` → N, anything else → 60 — so a
`0` makes the tick hourly and `due()` green-lights both firings.

⚠️ **WSL does not run cron by default** (`sudo service cron start`), and only while WSL is
up. A 5am sweep needs a machine that is awake. Until that is solved, use `cron tick` by
hand.

## Gotchas found the hard way

- **`dna doctor`'s key check is wrong.** `doctor.ts:32` tests `^KEY=.+` against the env
  file, and the template's trailing inline comments satisfy `.+`. It reports every key
  "present" on a completely unconfigured install. Upstream bug.
- **`/v1/usage` day rows mix real and faux numbers.** Only a live sweep's own `cost` block
  is trustworthy; faux and mock fabricate token counts (`length / 4`) and hardcode cost 0.
- **The agent's model is stored in the database.** Switching `DNA_PROVIDER` faux→openrouter
  leaves `model: faux-haiku` set; PATCH `/v1/agent/config` or the sweep uses a dead stub.
- **`pkill -f "dna-server-api/src/main.ts"` self-matches** and kills your own shell. The
  `api run` recipe already frees the port via `free-port.sh`.
- **The browser hub holds the client token and proxies `/api`**, so the whole API is
  reachable at `http://127.0.0.1:4851/api/v1/...` without handling the token. Direct calls
  to :4850 are 401.
- `200` with `0 entries` from `sources-check` is **not** breakage — it passes a 24-hour
  `since` window, so a quiet source legitimately returns nothing.

## Retopicing it

The pipeline is topic-agnostic — **zero TypeScript changes**. The fetchers
(`rss`, `atom`, `web_page`, `github_releases`, `hn_front`, `hn_search`) cover anything with
a feed. What is AI-specific is six strings:

| File | What to change |
|---|---|
| `prompt_engineering/jev/worth-attention/command.json` | the gate — description, the `worth` question, both criteria |
| `prompt_engineering/jev/hfs/command.json` | `signal.instructions` — Signal means actionable *to you* |
| `agents/news-desk/SYSTEM_PROMPT.md` | 1 framing line |
| `agents/news-researcher/SYSTEM_PROMPT.md` | 2 mentions |
| `agents/deep-research/SYSTEM_PROMPT.md` | 1 mention |

Plus `config/sources.json` and `config/keywords.json` — but those are **seeds**, copied into
the database on first open, after which the DB wins. Prefer the `/v1/sources` and
`/v1/keywords` API so the repo stays clean of merge conflicts. The Hype/Facts/Signal
definitions and scoring policy are already domain-neutral; leave them alone.

## Security notes from upstream

- A device with a `ui` entry **serves its UI open to that network** — anyone on the same
  Wi-Fi can read *and steer* the agent. Drop `ui` from its entry to keep it private.
- A private VM needs `just net tunnel vm` before the CLI or TUI can reach it.

## Honest caveat

**This box is not always on.** "Proactive" assumes a machine that stays up — the author
uses an always-on Mac mini. Under WSL it only sweeps while the computer is running, so this
is fine for evaluating and wrong for the actual promise.

The candidate always-on host is the **GEEKOM** (Ubuntu Server, already on the LAN, this
repo's `linux` device kind) — now a co-tenancy decision with The Signal rather than a free
one. See the ideas project.
