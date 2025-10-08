{{ config(materialized='view') }}

select
  -- pakai nama kolom yang ada di tabelmu; di sini asumsi kolomnya 'size'
  cast(size as numeric) as size
from {{ source('raw','ponds') }}
