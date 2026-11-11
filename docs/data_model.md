# Data model (draft, to be confirmed by the source profile)

## Layers
1. **Source:** the public daily event tables, read in place. Nothing is copied wholesale.
2. **staging** (dbt): `stg_events`, flattened event rows with the parameters the analysis needs, partitioned by event date and loaded incrementally day by day.
3. **intermediate** (dbt): `int_sessions` (one row per session, with funnel flags, channel, device, revenue) and `int_orders` (one row per distinct transaction).
4. **marts** (dbt): `fct_daily_channel_funnel`, `fct_product_daily`, `dim_customer` and `fct_customer_cohorts`, small aggregated tables that Tableau reads.

## Partitioning and cost
- `stg_events` is partitioned by `event_date` and clustered by `event_name`. Incremental runs process only new days; a backfill reprocesses a chosen date range.
- Marts are aggregated to day level, so dashboards scan kilobytes rather than the raw events.
- `analysis/profile_source.py` logs the bytes each query scans, which is the baseline for measuring savings.
