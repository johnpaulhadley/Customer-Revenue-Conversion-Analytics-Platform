-- Fails if staging does not hold exactly one row per source event in the date
-- range. Catches an empty or partly loaded table, which every other test would
-- pass. Both counts come from table metadata, so this test scans nothing.
with source_events as (
    select count(*) as events
    from {{ source('ga4', 'events') }}
    where _table_suffix between '{{ var("start_date") | replace("-", "") }}'
                            and '{{ var("end_date") | replace("-", "") }}'
),
staged_events as (
    select count(*) as events from {{ ref('stg_events') }}
)
select source_events.events as source_events, staged_events.events as staged_events
from source_events, staged_events
where source_events.events != staged_events.events
