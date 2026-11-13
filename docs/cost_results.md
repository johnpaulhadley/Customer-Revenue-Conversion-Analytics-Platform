# BigQuery cost results

Measured on 13 November 2026 with `analysis/measure_cost.py`. Query comparisons are dry runs; dbt figures are bytes billed from the project's job history. On-demand pricing bills at least 10 MB for each table a query reads, which is applied below.

## Same question, different source

| Question | Source | MB scanned | MB billed | Cheaper than raw |
|---|---|---:|---:|---:|
| December conversion by device | Raw events, filtered on the date column | 1,083 | 1,083 | 1x |
| | Raw events, daily tables pruned | 398 | 398 | 2.7x |
| | Staging table, partition pruned | 102 | 102 | 10.6x |
| | Mart (`fct_daily_sessions`) | 0.8 | 10 | 108x |
| Revenue by product category, all months | Raw events | 136 | 136 | 1x |
| | Staging table | 127 | 127 | 1.1x |
| | Mart (`fct_product_daily`) | 2.6 | 10 | 14x |

The first raw query filters on the `event_date` column, which looks reasonable but makes BigQuery open all 92 daily tables. Filtering on the table suffix opens only December's. The staging table also stores a session key and drops the nested parameter array, so it reads less per row. Product revenue gains little from staging because the item array is most of the data either way; the mart is where the saving comes from.

## Full build versus incremental run

| | Full build | Incremental run |
|---|---:|---:|
| `stg_events` | 2,146 MB | 112 MB (19x less) |
| Whole pipeline, models and tests | 3,837 MB | 2,010 MB |

The incremental run reloads only the last three days of events and replaces those partitions with free copy jobs. The tables downstream of staging are rebuilt in full each time, which is now most of the cost: `int_sessions` (663 MB), `int_orders` (469 MB), `fct_product_daily` (264 MB) and `int_purchase_reconciliation` (253 MB).

## What did not help
Clustering `stg_events` by event name barely reduced the bytes read by models that filter to purchase events. Each daily partition holds about 14 MB, which BigQuery stores as one block, so there is nothing for clustering to skip. Clustering pays off on partitions far larger than these.

## Totals
Every query in the project, including the failed sandbox runs during setup and later rebuilds, used less than 30 GB of the free 1 TB monthly allowance.
