"""Profile the GA4 sample e-commerce dataset before modelling it.

Every query is dry-run first to record how many bytes it would scan, then run
with a hard cap on bytes billed. Results go to data/processed/profile/ as CSV,
plus a bytes_scanned.csv log that later shows the effect of optimization.

Usage:
    python analysis/profile_source.py
"""
import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from google.cloud import bigquery

load_dotenv()
PROJECT = os.environ["GCP_PROJECT"]
MAX_BYTES = int(os.environ.get("MAX_BYTES_BILLED", 5_000_000_000))
SRC = "`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`"
OUT = Path("data/processed/profile")

QUERIES = {
    "daily_volume": f"""
        select event_date, count(*) as events, count(distinct user_pseudo_id) as users
        from {SRC} group by 1 order by 1""",
    "totals": f"""
        select count(*) as events,
               count(distinct user_pseudo_id) as users,
               count(distinct concat(user_pseudo_id, cast((select value.int_value from unnest(event_params)
                     where key = 'ga_session_id') as string))) as sessions,
               countif(event_name = 'purchase') as purchase_events,
               count(distinct ecommerce.transaction_id) as distinct_transaction_ids,
               sum(if(event_name = 'purchase', ecommerce.purchase_revenue_in_usd, 0)) as purchase_revenue_usd,
               min(event_date) as first_date, max(event_date) as last_date
        from {SRC}""",
    "event_names": f"""
        select event_name, count(*) as events, count(distinct user_pseudo_id) as users
        from {SRC} group by 1 order by 2 desc""",
    "traffic_source": f"""
        select traffic_source.medium, traffic_source.source,
               count(distinct user_pseudo_id) as users
        from {SRC} group by 1, 2 order by 3 desc limit 40""",
    "device_geo": f"""
        select device.category as device_category, geo.country,
               count(distinct user_pseudo_id) as users
        from {SRC} group by 1, 2 order by 3 desc limit 40""",
    "purchase_quality": f"""
        select ecommerce.transaction_id is null as txn_null,
               ecommerce.transaction_id = '(not set)' as txn_not_set,
               ecommerce.purchase_revenue_in_usd is null as revenue_null,
               count(*) as purchase_events,
               sum(ecommerce.purchase_revenue_in_usd) as revenue_usd
        from {SRC} where event_name = 'purchase' group by 1, 2, 3""",
    "duplicate_transactions": f"""
        select count(*) as transaction_ids, countif(n > 1) as ids_with_multiple_purchase_events,
               sum(n) as purchase_events
        from (select ecommerce.transaction_id, count(*) as n from {SRC}
              where event_name = 'purchase' and ecommerce.transaction_id not in ('(not set)')
              group by 1)""",
    "repeat_buyers": f"""
        select purchases, count(*) as users
        from (select user_pseudo_id, count(distinct ecommerce.transaction_id) as purchases
              from {SRC} where event_name = 'purchase' group by 1)
        group by 1 order by 1""",
    "item_quality": f"""
        select it.item_name = '(not set)' as name_not_set, it.item_category in ('(not set)', '') as category_missing,
               count(*) as item_rows, sum(it.item_revenue_in_usd) as item_revenue_usd
        from {SRC}, unnest(items) as it where event_name = 'purchase' group by 1, 2""",
    "param_keys": f"""
        select ep.key, count(*) as rows_with_key
        from {SRC}, unnest(event_params) as ep group by 1 order by 2 desc limit 40""",
}

# Same question asked two ways, to measure what column pruning saves.
SCAN_COMPARISON = {
    "scan_select_star": f"select * from {SRC} where event_name = 'purchase'",
    "scan_needed_columns": f"select event_date, user_pseudo_id, ecommerce.purchase_revenue_in_usd from {SRC} where event_name = 'purchase'",
    "scan_one_month_shards": "select event_date, user_pseudo_id, ecommerce.purchase_revenue_in_usd "
                             "from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_202012*` where event_name = 'purchase'",
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    client = bigquery.Client(project=PROJECT)
    log = []
    for name, sql in {**QUERIES, **SCAN_COMPARISON}.items():
        dry = client.query(sql, job_config=bigquery.QueryJobConfig(dry_run=True, use_query_cache=False))
        log.append({"query": name, "bytes_processed": dry.total_bytes_processed})
        if name in SCAN_COMPARISON:
            print(f"{name}: would scan {dry.total_bytes_processed / 1e6:,.1f} MB (dry run only)")
            continue
        job = client.query(sql, job_config=bigquery.QueryJobConfig(maximum_bytes_billed=MAX_BYTES))
        df = job.to_dataframe()
        df.to_csv(OUT / f"{name}.csv", index=False)
        print(f"{name}: {len(df):,} rows, scanned {dry.total_bytes_processed / 1e6:,.1f} MB")
    pd.DataFrame(log).to_csv(OUT / "bytes_scanned.csv", index=False)
    total = sum(r["bytes_processed"] for r in log if r["query"] in QUERIES)
    print(f"total scanned by profile queries: {total / 1e9:,.2f} GB")


if __name__ == "__main__":
    main()
