CREATE OR REFRESH MATERIALIZED VIEW status_semanal (
  CONSTRAINT farol_valido EXPECT (farol IN ('verde', 'amarelo', 'vermelho'))
    ON VIOLATION FAIL UPDATE
)
COMMENT 'Fotografias semanais do andamento e do farol informado pelos gerentes.'
AS
SELECT
  projeto_id,
  coalesce(
    try_to_date(data_status, 'yyyy-MM-dd'),
    try_to_date(data_status, 'dd/MM/yyyy')
  ) AS data_status,
  gerente,
  lower(trim(farol)) AS farol,
  CAST(round(CAST(replace(trim(pct_concluido), ',', '.') AS DECIMAL(10, 2))) AS INT) AS pct_concluido,
  texto_status,
  lower(trim(coalesce(texto_status, ''))) IN ('', 'n/a', 'ver ata da reunião') AS status_vazio
FROM lakehouse_vertice.bronze.status_semanal;

CREATE OR REFRESH MATERIALIZED VIEW custos
COMMENT 'Custos reais tipados, mantendo estornos e identificando a semana de sexta-feira.'
AS
WITH origem AS (
  SELECT
    lancamento_id,
    projeto_id,
    coalesce(
      try_to_date(data, 'yyyy-MM-dd'),
      try_to_date(data, 'dd/MM/yyyy')
    ) AS data,
    categoria,
    descricao,
    CAST(replace(trim(valor), ',', '.') AS DECIMAL(18, 2)) AS valor,
    centro_custo
  FROM lakehouse_vertice.bronze.custos
)
SELECT
  lancamento_id,
  projeto_id,
  data,
  categoria,
  descricao,
  valor,
  valor < 0 AS estorno,
  CAST(date_add(CAST(date_trunc('WEEK', data) AS DATE), 4) AS DATE) AS semana,
  centro_custo
FROM origem;
