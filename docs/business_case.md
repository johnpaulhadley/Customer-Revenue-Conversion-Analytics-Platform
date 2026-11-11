# Business case, scope and KPI definitions

## Decision supported
An e-commerce leadership team wants to know **where the online store is losing revenue** across traffic sources, the purchase funnel, products and customers, and **what a realistic improvement is worth in dollars**, so it can prioritise fixes.

## Data
Google Merchandise Store GA4 export, the public obfuscated sample in BigQuery: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, one table per day, November 2020 to January 2021.

## Known limits of the source
- Three months only. Repeat purchasing and long-run retention are thin, so cohort and RFM analysis is secondary.
- Traffic source is the user's first touch, not session-level. Channel analysis is first-touch attribution only.
- Google states that some fields hold placeholder values and internal consistency is limited. Every placeholder is counted and reported in the data profile, not silently dropped.

## Grain and definitions
- **Session:** `user_pseudo_id` plus the `ga_session_id` event parameter.
- **Order:** a distinct `transaction_id` on a `purchase` event. Duplicate purchase events for one transaction are counted once.
- **Revenue:** `purchase_revenue_in_usd` on the order. Item revenue is used only for product mix.
- **New versus returning:** whether the session is the user's first (`ga_session_number = 1`).

## KPIs
| # | KPI | Definition |
|---|---|---|
| 1 | Sessions, users, orders, revenue | Daily, by channel, device and country |
| 2 | Session conversion rate | Sessions with a purchase / sessions |
| 3 | Average order value | Revenue / orders |
| 4 | Revenue per session | Revenue / sessions; conversion rate x average order value |
| 5 | Funnel step rates | Share of sessions reaching each step: view item, add to cart, begin checkout, add shipping, add payment, purchase. Step-to-step drop-off |
| 6 | Cart abandonment | Sessions with add to cart but no purchase / sessions with add to cart |
| 7 | Product performance | Views, add-to-cart rate, purchase rate and revenue per item and category |
| 8 | Customer value (secondary) | Purchases and revenue per customer; repeat rate within the window |

## Statistical approach
Differences in conversion between segments (device, channel, new versus returning) are reported with 95% confidence intervals and a two-proportion test. A gap is called meaningful only when the interval excludes zero, and practical size is shown alongside significance.

## Opportunity sizing
Each recommendation is sized as: segment sessions x a stated, achievable improvement in a funnel rate x the segment's average order value. The improvement assumed is shown next to every dollar figure, along with the range under smaller and larger assumptions.

## Success criteria
1. Three to five recommendations, each with a dollar estimate and its assumption.
2. Every dashboard number traceable to a dbt model.
3. Measured BigQuery cost savings from partitioning and aggregation.
4. Limitations stated beside the findings.
