# PR #174251 port-back plan

Status as of 2026-06-20 11:40 BNE.

Fork: https://github.com/purcell-lab/forecast_solar_custom
Upstream PR: https://github.com/home-assistant/core/pull/174251

## Commits on fork (newest last)

| SHA | Summary | Port back? |
|---|---|---|
| `e008539` | Tz fix in `_today_attributes` + ship `translations/en.json` | **YES** (tz fix only — translations not needed for core) |
| `fd7e427` | Emit ISO keys in site/API timezone (`+10:00`) in attributes & service | **PROPOSE** as separate follow-up review |
| `1276810` | `get_forecast` returns `{watts: {...}, wh_period: {...}}` instead of `{forecast: [...]}` | **NO** — fork-only; diverges from the docs PR co-shipping with #174251 |
| _next_ | Emit full forecast horizon in `watts`/`wh_period` attributes (drop the today-only filter) | **NO** — fork-only; PR #174251 deliberately caps at today to limit attribute size |

## Specific changes

### 1. Tz fix (YES — port back)

In `homeassistant/components/forecast_solar/sensor.py`:

- Add `from zoneinfo import ZoneInfo`.
- `_series_for_date(series, target_date)` → add `tz: ZoneInfo` param.
- Comparison: `ts.date() == target_date` → `ts.astimezone(tz).date() == target_date`.
- `_today_attributes`: compute `tz = ZoneInfo(estimate.api_timezone)` and pass through.

Rationale: library v4+ returns `estimate.watts`/`wh_period` keys as UTC-aware datetimes, but `estimate.now()` is site-local. Without the conversion, sites east/west of UTC leak the next/previous local day's entries into "today".

Test evidence: on a Brisbane (UTC+10) install, Saturday morning Sunday-UTC entries (e.g. `2026-06-20T20:00:00+00:00` = Sun 06:00 BNE) were being bucketed into Saturday "today". Fixed.

### 2. Local-tz ISO key emission (PROPOSE separately)

Same file, optional polish:

- In `_series_for_date`, emit `local_ts.isoformat()` (where `local_ts = ts.astimezone(tz)`) instead of `ts.isoformat()`.
- In `services.py`, convert `ts` to `tz` before `.isoformat()` for the service response.

Rationale: consumers reading attributes/service expect to see `+10:00` strings, not `+00:00`. Slightly opinionated, hence raise as a follow-up.

### 3. Service response shape (DO NOT port)

Fork-only: switch list-of-objects → two dicts. Useful here for templating, but conflicts with the docs PR. Keep on fork only.

### 4. `translations/en.json` (DO NOT port)

HA core build pipeline auto-generates this from `strings.json`. Custom components must ship it; core does not.

### 5. Full-horizon `watts`/`wh_period` (DO NOT port)

Fork-only: `_today_attributes` now emits the entire forecast window returned by the library, not just today. HAEO's Open-Meteo extractor consumes the `watts` attribute directly and needs >1 day of lookahead, otherwise it interpolates and tiles a single day across the entire optimization horizon.

Kept fork-only because PR #174251 deliberately caps the attribute series at today to keep the live state payload small. If we ever want to upstream this, it should be a separate, explicitly-discussed change.

## Workflow when porting back

1. `./scripts/port_back_to_pr.sh <local-clone-of-PR-174251>` — strips fork-only manifest customizations.
2. Cherry-pick `e008539` for sensor.py tz changes (drop the translations file from the commit).
3. Push, open inline review comment on PR #174251 proposing change #2 as a follow-up.
4. Resolve inline comments where applicable.
