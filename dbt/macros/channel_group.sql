{#
  Map source and medium to a channel.
  - The store's own domains appear as referrers when a visit restarts mid-visit
    (for example on return from checkout). These are labelled Self-referral, not
    Referral, because nobody outside the store sent the visitor.
  - Obfuscated values in the public sample ('<Other>', '(data deleted)') become
    Unknown unless the medium still identifies the channel.
#}
{% macro channel_group(source, medium) -%}
    case
        when regexp_contains(coalesce({{ source }}, ''), r'googlemerchandisestore\.com') then 'Self-referral'
        when {{ medium }} is null or {{ medium }} in ('<Other>', '(data deleted)')
             or {{ source }} in ('<Other>', '(data deleted)') and {{ medium }} not in ('organic', 'cpc', 'referral')
            then 'Unknown'
        when {{ source }} = '(direct)' and {{ medium }} in ('(none)', '(not set)') then 'Direct'
        when {{ medium }} = 'organic' then 'Organic Search'
        when {{ medium }} in ('cpc', 'ppc', 'paidsearch') then 'Paid Search'
        when {{ medium }} = 'referral' then 'Referral'
        when {{ medium }} = 'email' then 'Email'
        when {{ medium }} = 'affiliate' then 'Affiliate'
        else 'Other'
    end
{%- endmacro %}
