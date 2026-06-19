# Forecast.Solar — PR #174251 custom-component mirror

This repository is a **HACS custom-component mirror** of the Home Assistant core integration `forecast_solar` with the changes from [PR #174251](https://github.com/home-assistant/core/pull/174251) applied.

> ⚠️ **Not for production.** This exists for live testing of the PR on a real HA instance ahead of upstream merge. The upstream PR is the source of truth for code review; this repo is the test article. Once the PR is merged, install [Home Assistant 2026.x](https://www.home-assistant.io/integrations/forecast_solar) directly and remove this custom component.

## What PR #174251 adds

- A new `forecast_solar.get_forecast` service action that returns the cached forecast time-series as `[{time, value, energy_wh}, ...]`, optionally filtered by date range or aggregated to whole hours.
- `watts` and `wh_period` dicts as extra state attributes on `sensor.energy_production_today`, capped to today's entries (kept under the recorder's 16 KiB attribute size warning even at 15-minute paid-tier resolution), and marked `_unrecorded_attributes`.

See the [PR description](https://github.com/home-assistant/core/pull/174251) and [feature request #619](https://github.com/home-assistant/feature-requests/issues/619) for full context.

## Install via HACS

1. HACS → ⋮ menu → **Custom repositories**
2. Add: `https://github.com/purcell-lab/forecast_solar_custom`
3. Category: **Integration**
4. Find "Forecast.Solar (PR #174251 custom)" in HACS → Download
5. **Restart Home Assistant** (full restart, not reload — HA needs to discover the custom component over the built-in one)
6. Existing Forecast.Solar config entries will load against the custom component automatically — no reconfiguration needed
7. Confirm install by checking logs: `Setup of forecast_solar took ...` will be followed by HA's standard `You are using a custom integration forecast_solar which has not been tested by Home Assistant` warning. That is expected.

## Uninstall

1. HACS → Forecast.Solar (PR #174251 custom) → Redownload/Remove → Remove
2. Restart Home Assistant
3. The built-in `forecast_solar` integration re-engages automatically with your existing config entry

## Workflow

This repo is the **source of truth during testing**. The upstream PR branch (`purcell-lab/core:add-forecast-solar-service`) is the source of truth for code review.

```
purcell-lab/forecast_solar_custom (this repo)
        ↑↓ sync scripts
purcell-lab/core:add-forecast-solar-service ← PR #174251
        ↑↓ rebase against
home-assistant/core:dev
```

### Edit-test-port cycle

1. Edit files under `custom_components/forecast_solar/` in this repo
2. Commit, push
3. On your HA instance: HACS → "Forecast.Solar (PR #174251 custom)" → Update → Restart HA
4. Test
5. When satisfied, port changes back to the PR branch via `scripts/port_back_to_pr.sh`
6. Push to `purcell-lab/core:add-forecast-solar-service` → PR #174251 updates

### Drift detection

A GitHub Action runs daily and on every push, diffing `custom_components/forecast_solar/` here against `homeassistant/components/forecast_solar/` in the PR branch. If they have diverged (excluding `manifest.json` version/name fields), the action fails — surfacing any unported changes early.

### Resyncing from the PR branch

If you make changes directly to the PR branch and need to pull them back into this repo:

```bash
./scripts/extract_from_pr.sh
git diff custom_components/forecast_solar/
git commit -am "sync from PR branch: <commit-sha>"
```

## Manifest versioning

`manifest.json:version` follows `5.0.1+pr174251.YYYYMMDD` — the base version of the integration in core, a build-metadata tag pinning the PR, and a date for ordering. HACS uses this for update detection.

## Files

| Path | Source |
|---|---|
| `custom_components/forecast_solar/*.py` | `homeassistant/components/forecast_solar/*.py` from PR branch |
| `custom_components/forecast_solar/manifest.json` | Modified: name, version, documentation URL |
| `custom_components/forecast_solar/services.yaml`, `icons.json`, `strings.json` | Verbatim from PR branch |
| `hacs.json` | HACS custom-repo metadata |
| `scripts/extract_from_pr.sh` | Pulls integration files from PR branch into this repo |
| `scripts/port_back_to_pr.sh` | Generates patch from this repo for the PR branch |
| `.github/workflows/drift-check.yml` | CI: diff against PR branch |

## License

Apache 2.0 (matches upstream `home-assistant/core`).
