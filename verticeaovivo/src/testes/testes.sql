WITH
projetos_sem_tarefa AS (
  SELECT count(*) AS falhas
  FROM lakehouse_vertice.silver.projetos p
  LEFT ANTI JOIN (
    SELECT DISTINCT projeto_id FROM lakehouse_vertice.silver.tarefas
  ) t
    ON t.projeto_id = p.projeto_id
),
ferramenta_incorreta AS (
  SELECT count(*) AS falhas
  FROM lakehouse_vertice.silver.tarefas t
  JOIN lakehouse_vertice.silver.projetos p
    ON p.projeto_id = t.projeto_id
  WHERE t.ferramenta <> p.ferramenta
),
projeto_multiplas_ferramentas AS (
  SELECT count(*) AS falhas
  FROM (
    SELECT projeto_id
    FROM lakehouse_vertice.silver.tarefas
    GROUP BY projeto_id
    HAVING count(DISTINCT ferramenta) <> 1
  )
),
horas_excel AS (
  SELECT
    (
      SELECT sum(horas)
      FROM lakehouse_vertice.silver.tarefas
      WHERE ferramenta = 'excel'
    ) AS silver_horas,
    (
      SELECT sum(CAST(replace(trim(horas_previstas), 'h', '') AS DECIMAL(18, 2)))
      FROM lakehouse_vertice.bronze.excel_tarefas
      WHERE upper(trim(tarefa)) = 'TOTAL'
    ) AS total_planilhas
),
pessoas_duplicadas AS (
  SELECT count(*) AS falhas
  FROM (
    SELECT colaborador_id
    FROM lakehouse_vertice.silver.colaboradores
    GROUP BY colaborador_id
    HAVING count(*) <> 1
  )
),
codeforge_variantes AS (
  SELECT count(DISTINCT fornecedor) AS quantidade
  FROM lakehouse_vertice.silver.entregas_fornecedor
  WHERE replace(lower(fornecedor), ' ', '') LIKE '%codeforge%'
),
custos_total AS (
  SELECT
    (
      SELECT sum(CAST(replace(trim(valor), ',', '.') AS DECIMAL(18, 2)))
      FROM lakehouse_vertice.bronze.custos
    ) AS bronze_total,
    (SELECT sum(valor) FROM lakehouse_vertice.silver.custos) AS silver_total
),
fotografia AS (
  SELECT count(*) AS quantidade
  FROM lakehouse_vertice.gold.projeto_situacao_atual
),
kpis_ausentes AS (
  SELECT count(*) AS quantidade
  FROM lakehouse_vertice.gold.projeto_situacao_atual
  WHERE lower(trim(status)) = 'em_andamento'
    AND (spi IS NULL OR cpi IS NULL)
),
ev_divergente AS (
  WITH status_mais_recente AS (
    SELECT projeto_id, pct_concluido
    FROM (
      SELECT
        projeto_id,
        pct_concluido,
        row_number() OVER (
          PARTITION BY projeto_id
          ORDER BY data_status DESC
        ) AS posicao
      FROM lakehouse_vertice.silver.status_semanal
      WHERE data_status <= DATE'2026-10-16'
    )
    WHERE posicao = 1
  ),
  ev_status AS (
    SELECT sum(p.orcamento_custo * coalesce(s.pct_concluido, 0) / 100) AS ev
    FROM lakehouse_vertice.silver.projetos p
    LEFT JOIN status_mais_recente s
      ON s.projeto_id = p.projeto_id
  ),
  ev_ferramentas AS (
    SELECT sum(ev) AS ev
    FROM lakehouse_vertice.gold.projeto_situacao_atual
  )
  SELECT
    abs(coalesce(s.ev, 0) - coalesce(f.ev, 0)) AS diferenca,
    greatest(abs(coalesce(s.ev, 0)), 1) AS base
  FROM ev_status s
  CROSS JOIN ev_ferramentas f
),
ac_divergente AS (
  WITH ac_fato AS (
    SELECT sum(ac) AS ac
    FROM lakehouse_vertice.gold.fato_projeto_semana
    WHERE semana = DATE'2026-10-16'
  ),
  ac_custos AS (
    SELECT sum(valor) AS ac
    FROM lakehouse_vertice.silver.custos
    WHERE data <= DATE'2026-10-16'
  )
  SELECT abs(coalesce(f.ac, 0) - coalesce(c.ac, 0)) AS diferenca
  FROM ac_fato f
  CROSS JOIN ac_custos c
),
resultados AS (
  SELECT
    1 AS numero,
    'Os 60 projetos tem cronograma na silver.tarefas' AS teste,
    CASE WHEN falhas = 0 THEN true ELSE false END AS passou,
    concat(CAST(falhas AS STRING), ' projetos sem tarefas') AS detalhe
  FROM projetos_sem_tarefa
  UNION ALL
  SELECT
    2,
    'Cada projeto veio de uma ferramenta igual ao cadastro PMO',
    CASE WHEN i.falhas = 0 AND m.falhas = 0 THEN true ELSE false END,
    concat(CAST(i.falhas AS STRING), ' tarefas com ferramenta incorreta; ', CAST(m.falhas AS STRING), ' projetos com varias ferramentas')
  FROM ferramenta_incorreta i
  CROSS JOIN projeto_multiplas_ferramentas m
  UNION ALL
  SELECT
    3,
    'Horas Excel na silver iguais a soma das linhas TOTAL',
    CASE WHEN abs(silver_horas - total_planilhas) < 0.01 THEN true ELSE false END,
    concat('silver=', CAST(silver_horas AS STRING), '; planilhas=', CAST(total_planilhas AS STRING))
  FROM horas_excel
  UNION ALL
  SELECT
    4,
    'Uma linha por pessoa na silver.colaboradores',
    CASE WHEN falhas = 0 THEN true ELSE false END,
    concat(CAST(falhas AS STRING), ' pessoas com contagem diferente de um')
  FROM pessoas_duplicadas
  UNION ALL
  SELECT
    5,
    'CodeForge normalizada em um unico fornecedor',
    CASE WHEN quantidade = 1 THEN true ELSE false END,
    concat('fornecedores distintos=', CAST(quantidade AS STRING))
  FROM codeforge_variantes
  UNION ALL
  SELECT
    6,
    'A limpeza preservou o custo total da bronze',
    CASE WHEN abs(bronze_total - silver_total) < 0.01 THEN true ELSE false END,
    concat('bronze=', CAST(bronze_total AS STRING), '; silver=', CAST(silver_total AS STRING))
  FROM custos_total
  UNION ALL
  SELECT
    7,
    'Os 60 projetos tem fotografia de hoje',
    CASE WHEN quantidade = 60 THEN true ELSE false END,
    concat('projetos=', CAST(quantidade AS STRING))
  FROM fotografia
  UNION ALL
  SELECT
    8,
    'Todo projeto em andamento tem SPI e CPI',
    CASE WHEN quantidade = 0 THEN true ELSE false END,
    concat('projetos sem SPI/CPI=', CAST(quantidade AS STRING))
  FROM kpis_ausentes
  UNION ALL
  SELECT
    9,
    'EV de hoje do status semanal bate com ferramentas em menos de 1%',
    CASE WHEN try_divide(diferenca, base) < 0.01 THEN true ELSE false END,
    concat('diferenca=', CAST(diferenca AS STRING), '; base=', CAST(base AS STRING))
  FROM ev_divergente
  UNION ALL
  SELECT
    10,
    'AC de hoje no fato igual aos lancamentos ate hoje',
    CASE WHEN diferenca < 0.01 THEN true ELSE false END,
    concat('diferenca=', CAST(diferenca AS STRING))
  FROM ac_divergente
)
SELECT
  numero,
  teste,
  CASE
    WHEN passou THEN 'OK'
    ELSE raise_error(concat('Teste ', CAST(numero AS STRING), ' falhou: ', teste, ' (', detalhe, ')'))
  END AS resultado,
  detalhe
FROM resultados
ORDER BY numero;
