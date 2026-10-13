{#- Returns null instead of erroring when the denominator is zero. -#}
{% macro safe_divide(numerator, denominator) -%}
    safe_divide({{ numerator }}, {{ denominator }})
{%- endmacro %}
