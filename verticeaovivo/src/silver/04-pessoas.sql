CREATE OR REFRESH MATERIALIZED VIEW colaboradores
COMMENT 'Cadastro unico de colaboradores com papel normalizado em minusculas.'
AS
WITH origem AS (
  SELECT
    colaborador_id,
    nome,
    lower(trim(papel)) AS papel,
    senioridade,
    CAST(replace(trim(custo_hora), ',', '.') AS DECIMAL(18, 2)) AS custo_hora,
    coalesce(
      try_to_date(data_admissao, 'yyyy-MM-dd'),
      try_to_date(data_admissao, 'dd/MM/yyyy')
    ) AS data_admissao,
    coalesce(
      try_to_date(data_desligamento, 'yyyy-MM-dd'),
      try_to_date(data_desligamento, 'dd/MM/yyyy')
    ) AS data_desligamento,
    row_number() OVER (
      PARTITION BY colaborador_id
      ORDER BY
        CASE WHEN papel = lower(trim(papel)) THEN 0 ELSE 1 END,
        nome
    ) AS posicao
  FROM lakehouse_vertice.bronze.colaboradores
)
SELECT
  colaborador_id,
  nome,
  papel,
  senioridade,
  custo_hora,
  data_admissao,
  data_desligamento
FROM origem
WHERE posicao = 1;

CREATE OR REFRESH MATERIALIZED VIEW apontamentos
COMMENT 'Apontamentos semanais tipados, com a semana consolidada na sexta-feira.'
AS
WITH origem AS (
  SELECT
    colaborador_id,
    projeto_id,
    coalesce(
      try_to_date(semana_inicio, 'yyyy-MM-dd'),
      try_to_date(semana_inicio, 'dd/MM/yyyy')
    ) AS semana_inicio,
    CAST(replace(trim(horas_disponiveis), ',', '.') AS DECIMAL(18, 2)) AS horas_disponiveis,
    CAST(replace(trim(horas_apontadas), ',', '.') AS DECIMAL(18, 2)) AS horas_apontadas
  FROM lakehouse_vertice.bronze.apontamentos
)
SELECT
  colaborador_id,
  projeto_id,
  semana_inicio,
  CAST(date_add(semana_inicio, 4) AS DATE) AS semana,
  horas_disponiveis,
  horas_apontadas
FROM origem;
