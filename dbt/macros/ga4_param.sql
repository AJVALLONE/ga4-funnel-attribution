{#-
  GA4 stores event details as a list of key/value pairs called event_params.
  This pulls one key out of that list.

  value_type is one of: string, int, float, double
  Example: {{ ga4_param('page_location', 'string') }}
-#}
{% macro ga4_param(key, value_type='string') -%}
    (select ep.value.{{ value_type }}_value from unnest(event_params) as ep where ep.key = '{{ key }}' limit 1)
{%- endmacro %}
