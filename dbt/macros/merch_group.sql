{#
  Map the store's category labels to merchandise groups. View events carry page
  paths ("Home/Apparel/Men's / Unisex/") and purchases carry short names
  ("Apparel"), so both are matched by keyword. Product types are listed first;
  collections (Sale, New, brand and campus shops) only apply when no product
  type matches.
#}
{% macro merch_group(col) -%}
    case
        when {{ col }} is null then 'Unknown'
        when regexp_contains({{ col }}, r"(?i)apparel|men's|women's|kids|hats|socks|t-shirts|unisex") then 'Apparel'
        when regexp_contains({{ col }}, r'(?i)bags|backpacks') then 'Bags'
        when regexp_contains({{ col }}, r'(?i)drinkware|water bottles|mugs') then 'Drinkware'
        when regexp_contains({{ col }}, r'(?i)stationery|notebooks|writing|stickers') then 'Stationery'
        when regexp_contains({{ col }}, r'(?i)small goods|accessories') then 'Small goods'
        when regexp_contains({{ col }}, r'(?i)gift card') then 'Gift cards'
        when regexp_contains({{ col }}, r'(?i)lifestyle') then 'Lifestyle'
        when regexp_contains({{ col }}, r'(?i)sale|clearance') then 'Collection: Sale'
        when regexp_contains({{ col }}, r'(?i)campus') then 'Collection: Campus'
        when regexp_contains({{ col }}, r'(?i)shop by brand') then 'Collection: Brand shops'
        when regexp_contains({{ col }}, r'(?i)eco-friendly') then 'Collection: Eco-friendly'
        when regexp_contains({{ col }}, r'(?i)/new/|^new$') then 'Collection: New'
        when regexp_contains({{ col }}, r'(?i)^\s*$|\(not set\)|uncategorized|^home/?$') then 'Unknown'
        else 'Other'
    end
{%- endmacro %}
