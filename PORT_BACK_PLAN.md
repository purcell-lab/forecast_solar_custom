# PR #174251 port-back plan

Status as of 2026-06-20 12:45 BNE.

Fork: https://github.com/purcell-lab/forecast_solar_custom
Upstream PR: https://github.com/home-assistant/core/pull/174251

## Commits on fork (newest last)

| SHA | Summary | Port back? |
|---|---|---|
| `e008539` | Tz fix in `_today_attributes` + ship `translations/en.json` | **YES** (tz fix only — translations not needed for core) |
| `fd7e427` | Emit ISO keys in site/API timezone (`+10:00`) in attributes & service | **YES** |
| `1276810` | `get_forecast` returns `{watts: {...}, wh_period: {...}}` instead of `{forecast: [...]}` | **YES** — docs PR will be updated as a follow-up |
| `a069856` | Emit full forecast horizon in `watts`/`wh_period` attributes (drop today-only filter) | **YES** — recorder cost mitigated by `_unrecorded_attributes` |

All four code changes go upstream as **four separate commits** on `purcell-lab/core:add-forecast-solar-service`, in the order above, so reviewers can evaluate each piece independently.

## Specific changes

### 1. Tz fix (port back)

In `homeassistant/components/forecast_solar/sensor.py`:

- Add `from zoneinfo import ZoneInfo`.
- `_series_for_date(series, target_date)` → add `tz: ZoneInfo` param.
- Comparison: `ts.date() == target_date` → `ts.astimezone(tz).date() == target_date`.
- `_today_attributes`: compute `tz = ZoneInfo(estimate.api_timezone)` and pass through.

Rationale: library v4+ returns `estimate.watts`/`wh_period` keys as UTC-aware datetimes, but `estimate.now()` is site-local. Without the conversion, sites east/west of UTC leak the next/previous local day's entries into "today".

Test evidence: on a Brisbane (UTC+10) install, Saturday morning Sunday-UTC entries (e.g. `2026-06-20T20:00:00+00:00` = Sun 06:00 BNE) were being bucketed into Saturday "today". Fixed.

### 2. Local-tz ISO key emission (port back)

Same file, plus `services.py`:

- In `_series_for_date`, emit `local_ts.isoformat()` (where `local_ts = ts.astimezone(tz)`) instead of `ts.isoformat()`.
- In `services.py`, convert `ts` to `tz` before `.isoformat()` for the service response.

Rationale: consumers reading attributes/service expect to see `+10:00` strings, not `+00:00`. Aligns the wire format with the timezone interpretation already used for the date filter.

### 3. Service response shape (port back)

In `services.py`: return `{watts: {ts: W}, wh_period: {ts: Wh}}` instead of `[{time, value, energy_wh}, ...]`.

Rationale: matches the attribute shape exactly, so templates can use the same parsing logic for the live attribute and the service response. The docs PR co-shipping with #174251 will be updated separately to match.

### 4. Full forecast horizon (port back)

In `sensor.py`: `_today_attributes` emits the entire forecast window returned by the library, not just today's entries.

Rationale: HAEO and other downstream optimizers need >1 day of lookahead. The recorder cost concern that motivated the today-only cap is already mitigated by `_unrecorded_attributes` on the entity class, so the live state payload size is the only remaining consideration. The library returns at most ~32 hours on the free tier and 3-6 days on paid tiers; even the paid-tier payload at 15-minute resolution stays well under the recorder's 16 KiB warning when no longer being recorded.

The helper `_series_for_date` is retained (no current callers in core), and a new helper `_series_in_tz` (no date filter) is what `_today_attributes` actually calls.

### 5. `translations/en.json` (DO NOT port)

HA core build pipeline auto-generates this from `strings.json`. Custom components must ship it; core does not.

## Workflow when porting back

1. `./scripts/port_back_to_pr.sh <local-clone-of-PR-174251>` — strips fork-only manifest customizations.
2. Cherry-pick / re-stage as four separate commits on `purcell-lab/core:add-forecast-solar-service`:
   - tz fix
   - local-tz ISO keys
   - dict service shape
   - full horizon
3. Push to `purcell-lab/core:add-forecast-solar-service` → PR #174251 updates automatically.
4. Open a follow-up against the home-assistant.io docs PR to update the documented `get_forecast` response shape.
