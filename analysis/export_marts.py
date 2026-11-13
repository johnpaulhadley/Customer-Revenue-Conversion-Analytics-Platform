"""Export the dbt marts to CSV for the analysis notebook and Tableau Public.

Tableau Public cannot connect to BigQuery, so the dashboards read these files.
They are small (a few MB in total) and are committed to the repository, so the
notebook can be re-run without a Google Cloud account.

Usage:
    python analysis/export_marts.py
"""
import os
from pathlib import Path

from dotenv import load_dotenv
from google.cloud import bigquery

load_dotenv()
PROJECT = os.environ["GCP_PROJECT"]
MAX_BYTES = int(os.environ.get("MAX_BYTES_BILLED", 5_000_000_000))
OUT = Path("data/exports")
P = PROJECT

EXPORTS = {
    # Day x channel x device x new/returning x country group. Additive counts only.
    "daily_sessions": f"""
        select * from `{P}.marts.fct_daily_sessions`
        order by session_date, channel, device_category, user_type, country_group, first_user_channel""",

    # Product x month. The daily product mart is aggregated to keep the file small.
    "product_monthly": f"""
        select date_trunc(event_date, month) as month, item_name, item_category,
               sum(item_views) as item_views, sum(add_to_carts) as add_to_carts,
               sum(orders_with_item) as orders_with_item, sum(units_sold) as units_sold,
               round(sum(item_revenue_usd), 2) as item_revenue_usd
        from `{P}.marts.fct_product_daily`
        group by 1, 2, 3
        order by 1, item_revenue_usd desc""",

    # One row per order with the attributes of the session it was placed in.
    "orders": f"""
        select o.transaction_id, o.order_date, round(o.revenue_usd, 2) as revenue_usd, o.item_quantity,
               coalesce(s.channel, 'No session') as channel,
               coalesce(s.first_user_channel, 'No session') as first_user_channel,
               coalesce(s.device_category, 'No session') as device_category,
               case when s.session_key is null then 'No session'
                    when s.is_new_user then 'New' else 'Returning' end as user_type,
               coalesce(s.country_group, 'No session') as country_group
        from `{P}.intermediate.int_orders` o
        left join `{P}.intermediate.int_sessions` s using (session_key)
        order by o.order_date, o.transaction_id""",

    # Buyers only; the 266k non-buyers are summarised in customer_segments.
    "buyers": f"""
        select user_pseudo_id, first_seen_date, first_user_channel, first_device_category, sessions,
               orders, round(revenue_usd, 2) as revenue_usd, first_order_date, last_order_date,
               days_since_last_order, is_repeat_buyer, monetary_score, customer_segment
        from `{P}.marts.dim_customers`
        where orders > 0
        order by revenue_usd desc""",

    "customer_segments": f"""
        select customer_segment, first_user_channel, first_device_category,
               count(*) as users, countif(orders > 0) as buyers, sum(orders) as orders,
               round(sum(revenue_usd), 2) as revenue_usd, sum(sessions) as sessions
        from `{P}.marts.dim_customers`
        group by 1, 2, 3
        order by 1, 2, 3""",

    # Sources behind each session channel, to check what the channels contain.
    "session_sources": f"""
        select channel, coalesce(session_source, '(none)') as session_source,
               coalesce(session_medium, '(none)') as session_medium,
               count(*) as sessions, countif(reached_purchase) as purchase_sessions,
               round(sum(revenue_usd), 2) as revenue_usd
        from `{P}.intermediate.int_sessions`
        group by 1, 2, 3
        having count(*) >= 50
        order by sessions desc""",

    "purchase_reconciliation": f"""
        select * from `{P}.marts.fct_purchase_reconciliation` order by event_date""",
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    client = bigquery.Client(project=PROJECT)
    total = 0
    for name, sql in EXPORTS.items():
        job = client.query(sql, job_config=bigquery.QueryJobConfig(maximum_bytes_billed=MAX_BYTES))
        df = job.to_dataframe()
        df.to_csv(OUT / f"{name}.csv", index=False)
        total += job.total_bytes_billed or 0
        print(f"{name}: {len(df):,} rows")
    print(f"Exported to {OUT}/, {total / 1e6:,.1f} MB billed")


if __name__ == "__main__":
    main()
