# PR #174251 port-back plan

Status as of 2026-06-20 12:51 BNE.

Fork: https://github.com/purcell-lab/forecast_solar_custom
Upstream PR: https://github.com/home-assistant/core/pull/174251

## Status: ported, awaiting review

All four code changes have been pushed to `purcell-lab/core:add-forecast-solar-service` as four separate commits (in the order below). The PR is now waiting on review feedback from the home-assistant/core maintainers; no further work on this branch until that lands.

A companion docs PR against `home-assistant/home-assistant.io` is **not** open yet — it will be drafted once the main PR direction is confirmed by review (in particular the dict response shape, which is the biggest behavioural change reviewers may push back on).

## Commits on fork (newest last) → ported to PR #174251

| Fork SHA | PR SHA | Summary |
|---|---|---|
| `e008539` | `09bc31a` | Fix tz mismatch in `_today_attributes` |
| `fd7e427` | `12b9ba7` | Emit ISO keys in site/API timezone (`+10:00`) in attributes & service |
| `1276810` | `a78d8ff` | `get_forecast` returns `{watts: {...}, wh_period: {...}}` instead of `{forecast: [...]}` |
| `a069856` | `144dc0d` | Emit full forecast horizon in `watts`/`wh_period` attributes (drop today-only filter) |

The four PR commits are sequenced so each reviewer-evaluable change is independent: tz correctness → wire-format clarity → response shape → horizon.

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

Rationale: matches the attribute shape exactly, so templates can use the same parsing logic for the live attribute and the service response. A docs PR will be opened separately once the main PR direction is confirmed by review (see Follow-up work below).

### 4. Full forecast horizon (port back)

In `sensor.py`: `_today_attributes` emits the entire forecast window returned by the library, not just today's entries.

Rationale: HAEO and other downstream optimizers need >1 day of lookahead. The recorder cost concern that motivated the today-only cap is already mitigated by `_unrecorded_attributes` on the entity class, so the live state payload size is the only remaining consideration. The library returns at most ~32 hours on the free tier and 3-6 days on paid tiers; even the paid-tier payload at 15-minute resolution stays well under the recorder's 16 KiB warning when no longer being recorded.

The helper `_series_for_date` is retained (no current callers in core), and a new helper `_series_in_tz` (no date filter) is what `_today_attributes` actually calls.

### 5. `translations/en.json` (DO NOT port)

HA core build pipeline auto-generates this from `strings.json`. Custom components must ship it; core does not. This is the only file that remains fork-only.

## Follow-up work (deferred until main PR review lands)

- **Docs PR** against `home-assistant/home-assistant.io` (`source/_integrations/forecast_solar.markdown`) documenting:
  - The new `forecast_solar.get_forecast` service action and its `{watts, wh_period}` response shape
  - The `watts` and `wh_period` extra state attributes on the energy production sensors
  - The local-tz ISO key format and full-horizon coverage

  Held until review confirms the final shape of the main PR; reviewers may request changes (e.g. revert to list-of-objects for the service response) that would otherwise force a docs rewrite.

## Workflow used

1. `./scripts/port_back_to_pr.sh <local-clone-of-PR-174251>` — strips fork-only manifest customizations.
2. Stage as four separate commits on `purcell-lab/core:add-forecast-solar-service`:
   - tz fix
   - local-tz ISO keys
   - dict service shape
   - full horizon
3. Push to `purcell-lab/core:add-forecast-solar-service` → PR #174251 updates automatically. Done.
