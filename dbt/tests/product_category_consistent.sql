-- Fails if any product appears under more than one category in the product mart.
select item_name, count(distinct item_category) as categories
from {{ ref('fct_product_daily') }}
group by 1
having count(distinct item_category) > 1
