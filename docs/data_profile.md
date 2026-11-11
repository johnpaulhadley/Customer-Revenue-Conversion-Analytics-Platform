# Source data profile (2026-11-11)

Produced by `analysis/profile_source.py` against `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`.

## Volume
| Measure | Value |
|---|---|
| Date range | 2020-11-01 to 2021-01-31 (92 daily tables) |
| Events | 4,295,584 (21,355 to 92,199 a day) |
| Users | 270,154 |
| Sessions (user + ga_session_id) | 360,129 |
| Purchase events | 5,692 |
| Purchase revenue on those events | $362,165 |

## Funnel events (distinct users reaching each)
| Event | Users |
|---|---|
| view_item | 61,252 |
| add_to_cart | 12,545 |
| begin_checkout | 9,715 |
| add_shipping_info | 9,714 |
| add_payment_info | 5,751 |
| purchase | 4,419 |

## Data quality findings and decisions
| Issue | Size | Decision |
|---|---|---|
| Purchase events with transaction ID `(not set)` | 883 events, $30,489 | Cannot be de-duplicated or tied to an order. Excluded from order counts and AOV; reported as a separate revenue line. |
| Purchase events with a null transaction ID | 23 events, $1,328 | Same treatment. |
| Transaction IDs recorded on more than one purchase event | 326 of 4,451 IDs; 4,786 events for 4,451 orders | De-duplicated: one row per transaction ID, keeping the first event. |
| Users whose first-touch source is obfuscated (`<Other>` or `(data deleted)`) | about 69,400 users, 26% | Reported as an "Unknown" channel, never dropped. |
| Purchased items with name and category `(not set)` | 448 item rows, no revenue | Excluded from product analysis. |
| Purchased items with a missing category only | 230 item rows, $7,319 | Kept, categorised as "Unknown". |

## Attribution
The `traffic_source` columns hold each user's first touch. The event parameters `source`, `medium` and `campaign` appear on about 1.44 million events (a third), so session-level channel can be tested as a second view in modelling.

## Repeat purchasing
523 of 4,419 purchasers (11.8%) bought more than once in the three months. Enough for a simple repeat-rate view, too little for meaningful cohort retention curves.

## Query cost baseline
| Query | Data scanned |
|---|---|
| All columns, all days, purchases only (`select *`) | 3,584 MB |
| Only the three needed columns, all days | 188 MB (19x less) |
| Same three columns, December tables only | 71 MB (51x less) |
| All ten profile queries together | 2.90 GB |

Column pruning and date filtering are the main cost levers on this source. The staging model is built to keep only needed columns and to be read by date partition.
