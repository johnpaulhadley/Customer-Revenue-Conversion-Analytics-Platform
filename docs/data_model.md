# Data model

The source is read in place from the public dataset. dbt builds three layers in the project's own BigQuery datasets: `staging`, `intermediate` and `marts`.

```
bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_YYYYMMDD   (92 daily tables)
        |
staging.stg_events                 one row per event, partitioned by day, incremental
        |
intermediate.int_orders            one row per real order (duplicates and unidentified purchases removed)
intermediate.int_sessions          one row per session: funnel flags, channel, device, new vs returning, orders
intermediate.int_purchase_reconciliation   raw purchase revenue split into orders, duplicates, unidentified
        |
marts.fct_daily_sessions           day x channel x device x new/returning x country group, additive counts
marts.fct_product_daily            day x product: views, adds to cart, orders, units, revenue
marts.dim_customers                one row per user: orders, revenue, customer segment
marts.fct_purchase_reconciliation  data-quality view for the dashboard and README
```

## Grain and definitions
- **Session:** `user_pseudo_id` + `ga_session_id`. Events with no session ID are left out of session counts.
- **Order:** one distinct `transaction_id` on a purchase event. Where the same ID appears on several purchase events, the first is kept. Purchases with a missing or `(not set)` ID cannot be de-duplicated and are reported separately, not as orders.
- **Revenue:** `purchase_revenue_in_usd` of the kept purchase event.
- **New vs returning:** the session's `ga_session_number` is 1 for a user's first session.
- **Funnel steps:** view_item, add_to_cart, begin_checkout, add_shipping_info, add_payment_info, purchase. The mart keeps two counts per step. The open count (`*_sessions`) is sessions with at least one event of that type; GA4 does not force steps into order, so a later step can exceed an earlier one. The closed count (`funnel_*`) also requires every earlier step, so each step is a subset of the last; drop-off analysis uses these.
- **Cart abandonment:** sessions with an add to cart and no purchase in the same session, over sessions with an add to cart.
- **Channel:** the session's own source and medium where the event carries them, otherwise the user's first-touch source and medium. Obfuscated values (`<Other>`, `(data deleted)`) become Unknown. Both `channel` and `first_user_channel` are kept so the two can be compared.
- **Product category:** view events carry page paths ("Home/Apparel/Men's / Unisex/") and purchases carry short names ("Apparel"), so both are mapped by keyword to merchandise groups (Apparel, Bags, Drinkware, Stationery, Small goods, Gift cards, Lifestyle, plus collections such as Sale and New). Each product gets one group, taken from its purchases where it sold and preferring a product type over a collection. Items named `(not set)` are left out.
- **Product views and adds to cart:** in this sample, view_item and add_to_cart events carry long item lists (about 36 and 44 products per session that viewed or added to cart), so per-product view and add counts measure appearances in lists, not product actions. Product analysis uses purchases only.
- **Customer segment:** non-buyer; repeat or one-time buyer; recent if the last order was within 30 days of the data's end. Three months is too short for full cohort or lifetime-value analysis.

## Why the marts are additive
`fct_daily_sessions` stores counts (sessions, sessions reaching each funnel step, orders, revenue), never rates. Tableau sums the counts for whatever filters are applied and divides afterwards, so a conversion rate for "mobile, organic search, December" is always correct. Averaging stored rates would weight small segments the same as large ones.

## Cost design
- **Daily-table pruning.** The source is one table per day. `stg_events` filters on `_table_suffix` with dates fixed when the model compiles, so BigQuery opens only the days being loaded. A filter written as a subquery would make BigQuery open every day.
- **Partitioning and clustering.** `stg_events` is partitioned by `event_date`, so date-filtered queries read only the days they need. It is also clustered by `event_name` and `user_pseudo_id`, though at about 14 MB per day the partitions are too small for clustering to skip much (see [cost results](cost_results.md)).
- **Incremental loads.** After the first build, `stg_events` reprocesses only the last three days (`lookback_days`), replacing those partitions. A chosen range can be reloaded with `--vars '{backfill_start: ..., backfill_end: ...}'`.
- **Free partition replacement.** Reloaded days replace their partitions through BigQuery copy jobs rather than a MERGE statement. Copy jobs cost nothing and are not DML, so incremental runs also work in the BigQuery sandbox.
- **Narrow columns.** Staging keeps about 25 of the source's columns and only the item fields the product analysis uses.
- **Small marts.** Dashboards read day-level marts, not events.
- **Guard rail.** Every query runs with `maximum_bytes_billed`, so a mistake fails instead of scanning terabytes.

`analysis/measure_cost.py` measures the effect: the same questions asked of the raw events, the staging table and the marts, and the bytes billed by each dbt model in a full build versus an incremental run.

## Tests
Keys are unique and not null (orders, sessions, customers, reconciliation days); channel and segment values are from a fixed list; and three custom tests check that order, duplicate and unidentified revenue add up to raw purchase revenue each day, that session-level orders and revenue in the mart match `int_orders`, and that no funnel count exceeds its session count.
