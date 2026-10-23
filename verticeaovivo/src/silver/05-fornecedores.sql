CREATE OR REFRESH MATERIALIZED VIEW entregas_fornecedor
COMMENT 'Entregas de fornecedores tipadas, com atrasos medidos no corte de 16/10/2026.'
AS
WITH origem AS (
  SELECT
    entrega_id,
    projeto_id,
    fornecedor AS fornecedor_como_veio,
    item,
    CAST(replace(trim(valor), ',', '.') AS DECIMAL(18, 2)) AS valor,
    coalesce(
      try_to_date(data_pedido, 'yyyy-MM-dd'),
      try_to_date(data_pedido, 'dd/MM/yyyy')
    ) AS data_pedido,
    coalesce(
      try_to_date(data_prometida, 'yyyy-MM-dd'),
      try_to_date(data_prometida, 'dd/MM/yyyy')
    ) AS data_prometida,
    coalesce(
      try_to_date(NULLIF(trim(data_entrega), ''), 'yyyy-MM-dd'),
      try_to_date(NULLIF(trim(data_entrega), ''), 'dd/MM/yyyy')
    ) AS data_entrega,
    CAST(NULLIF(trim(prazo_contratado_dias), '') AS INT) AS prazo_contratado_dias,
    status
  FROM lakehouse_vertice.bronze.entregas_fornecedor
),
normalizado AS (
  SELECT
    entrega_id,
    projeto_id,
    fornecedor_como_veio,
    CASE
      WHEN replace(lower(fornecedor_como_veio), ' ', '') LIKE '%codeforge%'
        THEN 'CodeForge Consultoria Ltda'
      ELSE fornecedor_como_veio
    END AS fornecedor,
    item,
    valor,
    data_pedido,
    data_prometida,
    data_entrega,
    prazo_contratado_dias,
    status,
    data_entrega IS NULL AS em_aberto
  FROM origem
)
SELECT
  entrega_id,
  projeto_id,
  fornecedor,
  fornecedor_como_veio,
  item,
  valor,
  data_pedido,
  data_prometida,
  data_entrega,
  prazo_contratado_dias,
  datediff(data_prometida, data_pedido) AS prazo_prometido_dias,
  datediff(data_entrega, data_pedido) AS prazo_real_dias,
  CASE
    WHEN data_entrega IS NOT NULL THEN greatest(datediff(data_entrega, data_prometida), 0)
    WHEN data_prometida < DATE'2026-10-16' THEN datediff(DATE'2026-10-16', data_prometida)
    ELSE 0
  END AS dias_de_atraso_na_entrega,
  em_aberto,
  CASE
    WHEN em_aberto THEN data_prometida < DATE'2026-10-16'
    ELSE data_entrega > data_prometida
  END AS em_atraso,
  status
FROM normalizado;
