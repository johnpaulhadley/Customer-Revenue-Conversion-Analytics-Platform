"""Measure what the dbt model design saves in BigQuery bytes scanned.

Two measurements, both written to data/processed/cost/:

1. query_comparison.csv: the same business questions asked four ways, from the
   raw events with no pruning, from the raw events with daily-table pruning,
   from the partitioned staging table, and from the marts. Each is a dry run,
   so this part costs nothing.
2. dbt_runs.csv: bytes billed by every model and test in recent dbt runs,
   read from the project's BigQuery job history. It shows a full build next to
   an incremental run that reprocesses only the last few days.

Run it after `dbt build` and one incremental `dbt run`:
    python analysis/measure_cost.py
"""
import json
import os
import re
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from google.cloud import bigquery

load_dotenv()
PROJECT = os.environ["GCP_PROJECT"]
RAW = "`bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`"
STG = f"`{PROJECT}.staging.stg_events`"
SESSIONS_MART = f"`{PROJECT}.marts.fct_daily_sessions`"
PRODUCT_MART = f"`{PROJECT}.marts.fct_product_daily`"
OUT = Path("data/processed/cost")

SESSION_ID = "(select value.int_value from unnest(event_params) where key = 'ga_session_id')"

QUESTIONS = {
    "December conversion by device": {
        "1. Raw events, no pruning": f"""
            select device.category,
                   count(distinct concat(user_pseudo_id, cast({SESSION_ID} as string))) as sessions,
                   count(distinct if(event_name = 'purchase', ecommerce.transaction_id, null)) as orders
            from {RAW}
            where event_date between '20201201' and '20201231'
            group by 1""",
        "2. Raw events, daily tables pruned": f"""
            select device.category,
                   count(distinct concat(user_pseudo_id, cast({SESSION_ID} as string))) as sessions,
                   count(distinct if(event_name = 'purchase', ecommerce.transaction_id, null)) as orders
            from {RAW}
            where _table_suffix between '20201201' and '20201231'
            group by 1""",
        "3. Staging table, partition pruned": f"""
            select device_category, count(distinct session_key) as sessions,
                   count(distinct if(event_name = 'purchase', transaction_id, null)) as orders
            from {STG}
            where event_date between '2020-12-01' and '2020-12-31'
            group by 1""",
        "4. Mart": f"""
            select device_category, sum(sessions) as sessions, sum(orders) as orders
            from {SESSIONS_MART}
            where session_date between '2020-12-01' and '2020-12-31'
            group by 1""",
    },
    "Revenue by product category, all months": {
        "1. Raw events, no pruning": f"""
            select it.item_category, sum(it.item_revenue_in_usd) as revenue
            from {RAW}, unnest(items) as it
            where event_name = 'purchase'
            group by 1""",
        "3. Staging table": f"""
            select it.item_category, sum(it.item_revenue_in_usd) as revenue
            from {STG}, unnest(items) as it
            where event_name = 'purchase'
            group by 1""",
        "4. Mart": f"""
            select item_category, sum(item_revenue_usd) as revenue
            from {PRODUCT_MART}
            group by 1""",
    },
}

JOB_HISTORY = """
    select creation_time, total_bytes_processed, total_bytes_billed,
           total_slot_ms, cache_hit, statement_type, query
    from `region-us`.INFORMATION_SCHEMA.JOBS_BY_USER
    where creation_time > timestamp_sub(current_timestamp(), interval 7 day)
      and job_type = 'QUERY'
      and parent_job_id is null
      and state = 'DONE'
      and query like '%"app": "dbt"%'
"""

COMMENT = re.compile(r"/\*\s*(\{.*?\})\s*\*/", re.S)


def dry_run_bytes(client, sql):
    job = client.query(sql, job_config=bigquery.QueryJobConfig(dry_run=True, use_query_cache=False))
    return job.total_bytes_processed


def compare_queries(client):
    rows = []
    for question, versions in QUESTIONS.items():
        for version, sql in versions.items():
            rows.append({"question": question, "version": version, "bytes_scanned": dry_run_bytes(client, sql)})
    df = pd.DataFrame(rows)
    df["mb_scanned"] = (df["bytes_scanned"] / 1e6).round(2)
    first = df.groupby("question")["bytes_scanned"].transform("first")
    df["times_less_than_raw"] = (first / df["bytes_scanned"]).round(1)
    return df


def dbt_runs(client):
    jobs = client.query(JOB_HISTORY).to_dataframe()
    if jobs.empty:
        return jobs
    meta = jobs["query"].str.extract(COMMENT)[0].map(lambda s: json.loads(s) if isinstance(s, str) else {})
    jobs["invocation_id"] = meta.map(lambda m: m.get("invocation_id"))
    jobs["node_id"] = meta.map(lambda m: m.get("node_id"))
    jobs = jobs.dropna(subset=["invocation_id"])
    jobs["resource"] = jobs["node_id"].str.split(".").str[0]
    jobs["name"] = jobs["node_id"].str.split(".").str[-1]
    per_node = (jobs.groupby(["invocation_id", "resource", "name"], as_index=False)
                .agg(started=("creation_time", "min"), queries=("query", "size"),
                     bytes_billed=("total_bytes_billed", "sum")))
    run_start = per_node.groupby("invocation_id")["started"].transform("min")
    per_node["run_started"] = run_start
    per_node["mb_billed"] = (per_node["bytes_billed"] / 1e6).round(1)
    return per_node.sort_values(["run_started", "started"]).drop(columns="started")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    client = bigquery.Client(project=PROJECT)

    comparison = compare_queries(client)
    comparison.to_csv(OUT / "query_comparison.csv", index=False)
    print("\nSame question, different source (dry runs):")
    print(comparison[["question", "version", "mb_scanned", "times_less_than_raw"]].to_string(index=False))

    runs = dbt_runs(client)
    runs.to_csv(OUT / "dbt_runs.csv", index=False)
    if runs.empty:
        print("\nNo dbt jobs found in the last 7 days. Run dbt build first.")
        return
    summary = (runs.groupby(["run_started", "invocation_id"], as_index=False)
               .agg(nodes=("name", "nunique"), mb_billed=("mb_billed", "sum"))
               .sort_values("run_started"))
    print("\nBytes billed per dbt run:")
    print(summary.to_string(index=False))
    latest = runs[runs["invocation_id"] == summary["invocation_id"].iloc[-1]]
    print("\nLatest run by model and test:")
    print(latest[["resource", "name", "queries", "mb_billed"]].to_string(index=False))


if __name__ == "__main__":
    main()
