CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.projeto_situacao_atual
COMMENT 'Fotografia dos 60 projetos e indicadores de prazo e custo no corte de 16/10/2026.'
AS
WITH cadastro AS (
  SELECT
    projeto_id AS projeto,
    nome_projeto AS nome,
    cliente,
    segmento,
    tipo_projeto,
    ferramenta,
    gerente_projeto,
    valor_contrato,
    orcamento_custo AS orcamento,
    data_inicio,
    data_fim_baseline,
    datediff(data_fim_baseline, data_inicio) AS duracao_baseline_dias,
    status
  FROM projetos
),
tarefas_agregadas AS (
  SELECT
    p.projeto AS projeto_id,
    p.orcamento,
    coalesce(
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
                  datediff(DATE'2026-10-16', t.inicio_baseline),
                  datediff(t.fim_baseline, t.inicio_baseline)
                )
              )
            )
          END
        ),
        sum(t.horas)
      ),
      0
    ) * p.orcamento AS pv,
    coalesce(try_divide(sum(t.horas * t.pct_concluido), sum(t.horas)), 0)
      * p.orcamento / 100 AS ev
  FROM cadastro p
  LEFT JOIN tarefas t
    ON t.projeto_id = p.projeto
  GROUP BY p.projeto, p.orcamento
),
custos_ate_hoje AS (
  SELECT
    projeto_id,
    sum(valor) AS ac
  FROM custos
  WHERE data <= DATE'2026-10-16'
  GROUP BY projeto_id
),
farol_mais_recente AS (
  SELECT projeto_id, farol
  FROM (
    SELECT
      projeto_id,
      farol,
      row_number() OVER (
        PARTITION BY projeto_id
        ORDER BY data_status DESC
      ) AS posicao
    FROM status_semanal
    WHERE data_status <= DATE'2026-10-16'
  )
  WHERE posicao = 1
),
indicadores AS (
  SELECT
    p.*,
    t.pv,
    t.ev,
    coalesce(c.ac, 0) AS ac,
    try_divide(t.ev, t.pv) AS spi_bruto,
    try_divide(t.ev, c.ac) AS cpi_bruto,
    f.farol AS farol_do_gerente
  FROM cadastro p
  LEFT JOIN tarefas_agregadas t
    ON t.projeto_id = p.projeto
  LEFT JOIN custos_ate_hoje c
    ON c.projeto_id = p.projeto
  LEFT JOIN farol_mais_recente f
    ON f.projeto_id = p.projeto
),
com_eac AS (
  SELECT
    *,
    CAST(round(spi_bruto, 4) AS DECIMAL(18, 4)) AS spi,
    CAST(round(cpi_bruto, 4) AS DECIMAL(18, 4)) AS cpi,
    try_divide(orcamento, cpi_bruto) AS eac_bruto
  FROM indicadores
),
com_projecao AS (
  SELECT
    *,
    CAST(round(eac_bruto, 2) AS DECIMAL(18, 2)) AS eac,
    greatest(eac_bruto - orcamento, 0) AS estouro_previsto,
    try_divide(valor_contrato - eac_bruto, valor_contrato) AS margem_projetada,
    CASE
      WHEN spi_bruto > 0 AND duracao_baseline_dias IS NOT NULL
        THEN greatest(CAST(round(try_divide(duracao_baseline_dias, spi_bruto) - duracao_baseline_dias) AS INT), 0)
      ELSE NULL
    END AS atraso_projetado_dias
  FROM com_eac
)
SELECT
  projeto,
  nome,
  cliente,
  segmento,
  tipo_projeto,
  ferramenta,
  gerente_projeto,
  valor_contrato,
  orcamento,
  data_inicio,
  data_fim_baseline,
  duracao_baseline_dias,
  status,
  pv,
  ev,
  ac,
  spi,
  cpi,
  eac,
  CAST(estouro_previsto AS DECIMAL(18, 2)) AS estouro_previsto,
  margem_projetada,
  atraso_projetado_dias,
  date_add(data_fim_baseline, atraso_projetado_dias) AS termino_projetado,
  CASE
    WHEN lower(trim(status)) <> 'em_andamento' THEN 'concluído'
    WHEN spi_bruto < 0.8 OR cpi_bruto < 0.8 THEN 'crítico'
    WHEN spi_bruto < 0.9 OR cpi_bruto < 0.9 THEN 'atenção'
    ELSE 'ok'
  END AS situacao,
  farol_do_gerente,
  CASE
    WHEN spi_bruto >= 0.95 THEN 'verde'
    WHEN spi_bruto >= 0.90 THEN 'amarelo'
    WHEN spi_bruto < 0.90 THEN 'vermelho'
  END AS farol_calculado,
  lower(trim(status)) = 'em_andamento'
    AND farol_do_gerente = 'verde'
    AND spi_bruto < 0.9 AS melancia
FROM com_projecao;

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.utilizacao_pessoa_semana
COMMENT 'Utilizacao semanal por pessoa e projeto, incluindo horas ociosas, custo e SPI.'
AS
SELECT
  a.colaborador_id,
  c.nome,
  c.papel,
  c.senioridade,
  a.projeto_id,
  a.semana,
  a.horas_disponiveis,
  a.horas_apontadas,
  greatest(a.horas_disponiveis - a.horas_apontadas, 0) AS horas_ociosas,
  try_divide(a.horas_apontadas, a.horas_disponiveis) AS utilizacao,
  greatest(a.horas_disponiveis - a.horas_apontadas, 0) * c.custo_hora AS custo_ocioso,
  f.spi AS spi_do_projeto
FROM apontamentos a
JOIN colaboradores c
  ON c.colaborador_id = a.colaborador_id
LEFT JOIN lakehouse_vertice.gold.fato_projeto_semana f
  ON f.projeto_id = a.projeto_id
  AND f.semana = a.semana
WHERE a.semana <= DATE'2026-10-16';
