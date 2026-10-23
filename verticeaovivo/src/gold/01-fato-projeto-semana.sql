CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.fato_projeto_semana (
  CONSTRAINT pv_nao_negativo EXPECT (pv >= 0)
    ON VIOLATION FAIL UPDATE,
  CONSTRAINT ev_dentro_orcamento EXPECT (ev <= orcamento)
    ON VIOLATION FAIL UPDATE
)
COMMENT 'Historico semanal de valor planejado, agregado e realizado por projeto ate 16/10/2026.'
AS
WITH projetos_com_semanas AS (
  SELECT
    p.projeto_id,
    p.orcamento_custo AS orcamento,
    CASE
      WHEN date_add(CAST(date_trunc('WEEK', p.data_inicio) AS DATE), 4) < p.data_inicio
        THEN date_add(CAST(date_trunc('WEEK', p.data_inicio) AS DATE), 11)
      ELSE date_add(CAST(date_trunc('WEEK', p.data_inicio) AS DATE), 4)
    END AS primeira_semana
  FROM projetos p
  WHERE p.data_inicio <= DATE'2026-10-16'
),
semanas AS (
  SELECT
    p.projeto_id,
    p.orcamento,
    explode(sequence(p.primeira_semana, DATE'2026-10-16', INTERVAL 7 DAYS)) AS semana
  FROM projetos_com_semanas p
),
pv_semanal AS (
  SELECT
    s.projeto_id,
    s.semana,
    s.orcamento,
    s.orcamento * coalesce(
      try_divide(
        sum(
          t.horas * CASE
            WHEN t.inicio_baseline IS NULL OR t.fim_baseline IS NULL
              OR datediff(t.fim_baseline, t.inicio_baseline) <= 0 THEN 0
            ELSE greatest(
              0,
              least(
                1,
                try_divide(
                  datediff(s.semana, t.inicio_baseline),
                  datediff(t.fim_baseline, t.inicio_baseline)
                )
              )
            )
          END
        ),
        sum(t.horas)
      ),
      0
    ) AS pv
  FROM semanas s
  LEFT JOIN tarefas t
    ON t.projeto_id = s.projeto_id
  GROUP BY s.projeto_id, s.semana, s.orcamento
),
status_observado_por_semana AS (
  SELECT
    s.projeto_id,
    s.semana,
    max(st.pct_concluido) AS pct_publicado,
    max(st.farol) AS farol_publicado
  FROM semanas s
  LEFT JOIN status_semanal st
    ON st.projeto_id = s.projeto_id
    AND st.data_status = s.semana
  GROUP BY s.projeto_id, s.semana
),
status_com_ultimo_valor AS (
  SELECT
    projeto_id,
    semana,
    last_value(pct_publicado, true) OVER (
      PARTITION BY projeto_id
      ORDER BY semana
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS pct_concluido,
    last_value(farol_publicado, true) OVER (
      PARTITION BY projeto_id
      ORDER BY semana
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS farol_do_gerente
  FROM status_observado_por_semana
),
custos_por_semana AS (
  SELECT
    projeto_id,
    semana,
    sum(valor) AS custo_semana
  FROM custos
  WHERE semana <= DATE'2026-10-16'
  GROUP BY projeto_id, semana
),
custos_acumulados AS (
  SELECT
    s.projeto_id,
    s.semana,
    sum(coalesce(c.custo_semana, 0)) OVER (
      PARTITION BY s.projeto_id
      ORDER BY s.semana
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ac
  FROM semanas s
  LEFT JOIN custos_por_semana c
    ON c.projeto_id = s.projeto_id
    AND c.semana = s.semana
),
horas_por_semana AS (
  SELECT
    projeto_id,
    semana,
    sum(horas_disponiveis) AS horas_disponiveis,
    sum(horas_apontadas) AS horas_apontadas
  FROM apontamentos
  WHERE semana <= DATE'2026-10-16'
  GROUP BY projeto_id, semana
)
SELECT
  p.projeto_id,
  p.semana,
  p.orcamento,
  p.pv,
  p.orcamento * coalesce(s.pct_concluido, 0) / 100 AS ev,
  coalesce(c.ac, 0) AS ac,
  CAST(round(try_divide(p.orcamento * coalesce(s.pct_concluido, 0) / 100, p.pv), 4) AS DECIMAL(18, 4)) AS spi,
  CAST(round(try_divide(p.orcamento * coalesce(s.pct_concluido, 0) / 100, c.ac), 4) AS DECIMAL(18, 4)) AS cpi,
  CAST(round(try_divide(p.orcamento, try_divide(p.orcamento * coalesce(s.pct_concluido, 0) / 100, c.ac)), 2) AS DECIMAL(18, 2)) AS eac,
  s.farol_do_gerente,
  coalesce(h.horas_disponiveis, 0) AS horas_disponiveis,
  coalesce(h.horas_apontadas, 0) AS horas_apontadas,
  coalesce(h.horas_disponiveis, 0) - coalesce(h.horas_apontadas, 0) AS horas_ociosas
FROM pv_semanal p
LEFT JOIN status_com_ultimo_valor s
  ON s.projeto_id = p.projeto_id
  AND s.semana = p.semana
LEFT JOIN custos_acumulados c
  ON c.projeto_id = p.projeto_id
  AND c.semana = p.semana
LEFT JOIN horas_por_semana h
  ON h.projeto_id = p.projeto_id
  AND h.semana = p.semana;
