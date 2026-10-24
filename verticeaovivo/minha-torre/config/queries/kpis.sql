WITH base AS (
  SELECT
    projeto,
    status,
    situacao,
    melancia,
    valor_contrato,
    estouro_previsto
  FROM lakehouse_vertice.gold.projeto_situacao_atual
),
status_30d AS (
  SELECT
    projeto_id,
    MAX(data_status) AS ultima_data_status,
    COUNT(DISTINCT projeto_id) AS projetos_ativos_30d
  FROM lakehouse_vertice.gold.status_estruturado
  WHERE data_status >= DATE_ADD(DATE'2026-10-16', -30)
    AND lower(trim(farol)) IN ('amarelo', 'vermelho')
  GROUP BY projeto_id
)
SELECT
  CAST(COUNT(*) FILTER (WHERE lower(trim(status)) = 'em_andamento') AS BIGINT) AS projetos_em_andamento,
  CAST(COUNT(*) FILTER (WHERE lower(trim(situacao)) IN ('atenção', 'crítico')) AS BIGINT) AS projetos_em_risco,
  CAST(COUNT(*) FILTER (WHERE lower(trim(situacao)) = 'crítico') AS BIGINT) AS projetos_criticos,
  CAST(COUNT(*) FILTER (WHERE melancia = true) AS BIGINT) AS melancias,
  CAST(COALESCE(SUM(CASE WHEN lower(trim(situacao)) IN ('atenção', 'crítico') THEN CAST(estouro_previsto AS DOUBLE) ELSE 0 END), 0) AS DOUBLE) AS valor_estouro_previsto,
  CAST(COALESCE(SUM(CAST(valor_contrato AS DOUBLE)), 0) AS DOUBLE) AS carteira_total,
  CAST(COALESCE((SELECT COUNT(DISTINCT projeto_id) FROM lakehouse_vertice.gold.status_estruturado WHERE data_status >= DATE_ADD(DATE'2026-10-16', -30) AND lower(trim(farol)) IN ('amarelo', 'vermelho')), 0) AS BIGINT) AS alto_risco_em_30d
FROM base;
