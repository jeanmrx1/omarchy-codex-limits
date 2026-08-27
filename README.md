# Codex Limits for Omarchy

A compact Omarchy bar widget for Codex subscription limits. It shows only the
remaining allowance for the short session window and the weekly window, plus a
thin time-to-reset meter below each value. No token counts are displayed.

## Features

- Remaining percentages for the Codex session and weekly limits
- A minimal progress line representing time left until each reset
- Exact reset countdowns in a hover tooltip
- Theme-aware colors and a configurable low-allowance warning
- Automatic refresh through Omarchy's authenticated Codex usage collector
- Click-to-refresh and an IPC refresh command

## Requirements

- Omarchy with the Agents usage collector available
- A Codex account authenticated with `codex login`

## Install

```bash
omarchy plugin add https://github.com/jeanmrx1/omarchy-codex-limits.git --enable
omarchy bar move jcsmrx.codex-limits --after omarchy.clock
```

## Configure

```bash
omarchy bar set jcsmrx.codex-limits refreshIntervalSec 300
omarchy bar set jcsmrx.codex-limits warningThreshold 20
```

The refresh interval accepts 60–3600 seconds. The warning threshold accepts
0–50 percent.

Refresh from the command line:

```bash
omarchy-shell jcsmrx.codex-limits refresh
```

## Data source

The widget reads the Codex limit record maintained under Omarchy's user state
directory and refreshes it with `omarchy-agent-usage-update --limits-only
codex`. It keeps the last valid snapshot visible if a refresh fails
temporarily.

## License

MIT
