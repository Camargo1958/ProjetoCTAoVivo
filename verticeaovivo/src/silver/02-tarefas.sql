CREATE TEMPORARY VIEW tarefas_excel AS
SELECT
  coalesce(p.projeto_id, regexp_extract(e.arquivo, 'PRJ-[0-9]{3}', 0)) AS projeto_id,
  'excel' AS ferramenta,
  CAST(e.id AS STRING) AS id_na_ferramenta,
  e.fase,
  e.tarefa,
  e.responsavel,
  CASE
    WHEN NULLIF(trim(e.inicio_previsto), '') IS NULL THEN NULL
    WHEN instr(e.inicio_previsto, '/') > 0 THEN try_to_date(e.inicio_previsto, 'dd/MM/yyyy')
    ELSE date_add(DATE'1899-12-30', CAST(e.inicio_previsto AS INT))
  END AS inicio_baseline,
  CASE
    WHEN NULLIF(trim(e.termino_previsto), '') IS NULL THEN NULL
    WHEN instr(e.termino_previsto, '/') > 0 THEN try_to_date(e.termino_previsto, 'dd/MM/yyyy')
    ELSE date_add(DATE'1899-12-30', CAST(e.termino_previsto AS INT))
  END AS fim_baseline,
  CASE
    WHEN NULLIF(trim(e.inicio_real), '') IS NULL THEN NULL
    WHEN instr(e.inicio_real, '/') > 0 THEN try_to_date(e.inicio_real, 'dd/MM/yyyy')
    ELSE date_add(DATE'1899-12-30', CAST(e.inicio_real AS INT))
  END AS inicio_real,
  CASE
    WHEN NULLIF(trim(e.termino_real), '') IS NULL THEN NULL
    WHEN instr(e.termino_real, '/') > 0 THEN try_to_date(e.termino_real, 'dd/MM/yyyy')
    ELSE date_add(DATE'1899-12-30', CAST(e.termino_real AS INT))
  END AS fim_real,
  CAST(
    CASE
      WHEN instr(e.pct_concluido, '%') > 0
        THEN replace(regexp_replace(trim(e.pct_concluido), '%', ''), ',', '.')
      ELSE CAST(replace(trim(e.pct_concluido), ',', '.') AS DECIMAL(10, 2)) * 100
    END AS DECIMAL(10, 2)
  ) AS pct_como_veio,
  CAST(replace(trim(e.horas_previstas), 'h', '') AS DECIMAL(10, 2)) AS horas,
  CAST(NULL AS STRING) AS status_na_ferramenta
FROM lakehouse_vertice.bronze.excel_tarefas e
LEFT JOIN projetos p
  ON NULLIF(trim(p.codigo_ferramenta), '') = e.arquivo
WHERE upper(trim(e.tarefa)) <> 'TOTAL';

CREATE TEMPORARY VIEW tarefas_clickup AS
SELECT
  coalesce(p_codigo.projeto_id, p_nome.projeto_id) AS projeto_id,
  'clickup' AS ferramenta,
  c.id AS id_na_ferramenta,
  filter(c.custom_fields, f -> f.name = 'Fase')[0].value AS fase,
  c.name AS tarefa,
  transform(c.assignees, a -> a.username)[0] AS responsavel,
  to_date(timestamp_millis(CAST(NULLIF(filter(c.custom_fields, f -> f.name = 'Início baseline')[0].value, '') AS BIGINT))) AS inicio_baseline,
  to_date(timestamp_millis(CAST(NULLIF(filter(c.custom_fields, f -> f.name = 'Fim baseline')[0].value, '') AS BIGINT))) AS fim_baseline,
  to_date(timestamp_millis(CAST(NULLIF(c.start_date, '') AS BIGINT))) AS inicio_real,
  to_date(timestamp_millis(CAST(NULLIF(c.date_done, '') AS BIGINT))) AS fim_real,
  CAST(
    replace(
      regexp_replace(filter(c.custom_fields, f -> f.name = 'Progresso (%)')[0].value, '%', ''),
      ',',
      '.'
    ) AS DECIMAL(10, 2)
  ) AS pct_como_veio,
  CAST(c.time_estimate AS DECIMAL(18, 2)) / 3600000 AS horas,
  CASE
    WHEN lower(trim(c.status.status)) LIKE '%conclu%'
      OR lower(trim(c.status.status)) LIKE '%done%'
      OR lower(trim(c.status.status)) LIKE '%complete%'
      OR lower(trim(c.status.status)) LIKE '%closed%'
      OR lower(trim(c.status.status)) LIKE '%finished%'
      THEN 'concluida'
    WHEN lower(trim(c.status.status)) LIKE '%to do%'
      OR lower(trim(c.status.status)) LIKE '%todo%'
      OR lower(trim(c.status.status)) LIKE '%backlog%'
      OR lower(trim(c.status.status)) LIKE '%open%'
      OR lower(trim(c.status.status)) LIKE '%a fazer%'
      OR lower(trim(c.status.status)) LIKE '%pendente%'
      OR lower(trim(c.status.status)) LIKE '%not started%'
      THEN 'a_fazer'
    ELSE 'em_andamento'
  END AS status_na_ferramenta
FROM lakehouse_vertice.bronze.clickup_tarefas c
LEFT JOIN projetos p_codigo
  ON NULLIF(trim(p_codigo.codigo_ferramenta), '') = c.list_id
LEFT JOIN projetos p_nome
  ON NULLIF(trim(p_codigo.codigo_ferramenta), '') IS NULL
  AND lower(trim(p_nome.nome_projeto)) = lower(trim(c.list_name));

CREATE TEMPORARY VIEW tarefas_msproject AS
WITH tarefas_com_fase AS (
  SELECT
    m.*,
    last_value(
      CASE WHEN m.OutlineLevel = 1 THEN m.Name END,
      true
    ) OVER (PARTITION BY m.arquivo ORDER BY m.UID) AS fase
  FROM lakehouse_vertice.bronze.msproject_tarefas m
)
SELECT
  p.projeto_id,
  'msproject' AS ferramenta,
  CAST(m.UID AS STRING) AS id_na_ferramenta,
  m.fase,
  m.Name AS tarefa,
  CAST(NULL AS STRING) AS responsavel,
  CAST(m.Baseline.Start AS DATE) AS inicio_baseline,
  CAST(m.Baseline.Finish AS DATE) AS fim_baseline,
  CAST(m.ActualStart AS DATE) AS inicio_real,
  CAST(m.ActualFinish AS DATE) AS fim_real,
  CAST(m.PercentComplete AS DECIMAL(10, 2)) AS pct_como_veio,
  CAST(regexp_extract(m.Work, 'PT([0-9]+)H', 1) AS DECIMAL(10, 2)) AS horas,
  CAST(NULL AS STRING) AS status_na_ferramenta
FROM tarefas_com_fase m
LEFT JOIN projetos p
  ON NULLIF(trim(p.codigo_ferramenta), '') = m.arquivo
WHERE m.Summary = 0;

CREATE OR REFRESH MATERIALIZED VIEW tarefas (
  CONSTRAINT achou_o_projeto EXPECT (projeto_id IS NOT NULL)
    ON VIOLATION FAIL UPDATE,
  CONSTRAINT percentual_valido EXPECT (pct_concluido BETWEEN 0 AND 100)
    ON VIOLATION FAIL UPDATE,
  CONSTRAINT horas_positivas EXPECT (horas > 0)
    ON VIOLATION FAIL UPDATE
)
COMMENT 'Tarefas integradas de Excel, ClickUp e Microsoft Project com contrato comum.'
AS
WITH unidas AS (
  SELECT * FROM tarefas_excel
  UNION ALL
  SELECT * FROM tarefas_clickup
  UNION ALL
  SELECT * FROM tarefas_msproject
),
tipadas AS (
  SELECT
    projeto_id,
    ferramenta,
    id_na_ferramenta,
    fase,
    tarefa,
    responsavel,
    CAST(inicio_baseline AS DATE) AS inicio_baseline,
    CAST(fim_baseline AS DATE) AS fim_baseline,
    CAST(inicio_real AS DATE) AS inicio_real,
    CAST(fim_real AS DATE) AS fim_real,
    CAST(pct_como_veio AS DECIMAL(10, 2)) AS pct_como_veio,
    CAST(horas AS DECIMAL(18, 2)) AS horas,
    status_na_ferramenta
  FROM unidas
)
SELECT
  concat(projeto_id, '-', ferramenta, '-', id_na_ferramenta) AS tarefa_id,
  projeto_id,
  ferramenta,
  id_na_ferramenta,
  fase,
  tarefa,
  responsavel,
  inicio_baseline,
  fim_baseline,
  inicio_real,
  fim_real,
  pct_como_veio,
  least(pct_como_veio, 100) AS pct_concluido,
  pct_como_veio > 100 AS pct_veio_acima_de_100,
  horas,
  status_na_ferramenta
FROM tipadas;
