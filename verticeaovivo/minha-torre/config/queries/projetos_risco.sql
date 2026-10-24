WITH projetos AS (
  SELECT
    projeto,
    nome,
    cliente,
    situacao,
    spi,
    cpi,
    estouro_previsto,
    atraso_projetado_dias,
    farol_do_gerente,
    farol_calculado,
    melancia,
    CASE
      WHEN lower(trim(situacao)) = 'crítico' THEN 1
      WHEN lower(trim(situacao)) = 'atenção' THEN 2
      ELSE 3
    END AS ordem_situacao
  FROM lakehouse_vertice.gold.projeto_situacao_atual
  WHERE lower(trim(status)) = 'em_andamento'
    AND lower(trim(situacao)) IN ('atenção', 'crítico')
),
causa_mais_frequente AS (
  SELECT
    projeto_id,
    causa_bloqueio AS causa_mais_frequente
  FROM (
    SELECT
      projeto_id,
      causa_bloqueio,
      COUNT(*) AS qtd,
      ROW_NUMBER() OVER (
        PARTITION BY projeto_id
        ORDER BY COUNT(*) DESC, causa_bloqueio ASC
      ) AS rn
    FROM lakehouse_vertice.gold.status_estruturado
    WHERE data_status >= DATE_ADD(DATE'2026-10-16', -90)
      AND causa_bloqueio IS NOT NULL
    GROUP BY projeto_id, causa_bloqueio
  )
  WHERE rn = 1
),
impacto_por_causa AS (
  SELECT
    projeto_id,
    SUM(CASE WHEN lower(trim(causa_bloqueio)) = 'falta_sre' THEN COALESCE(dias_impacto, 0) ELSE 0 END) AS dias_impacto_falta_sre,
    SUM(CASE WHEN lower(trim(causa_bloqueio)) = 'rotatividade' THEN COALESCE(dias_impacto, 0) ELSE 0 END) AS dias_impacto_rotatividade
  FROM lakehouse_vertice.gold.status_estruturado
  WHERE data_status >= DATE_ADD(DATE'2026-10-16', -90)
    AND causa_bloqueio IS NOT NULL
  GROUP BY projeto_id
)
SELECT
  p.projeto AS projeto,
  p.nome,
  p.cliente,
  p.situacao,
  p.spi,
  p.cpi,
  p.estouro_previsto,
  p.atraso_projetado_dias,
  p.farol_do_gerente,
  p.farol_calculado,
  p.melancia,
  COALESCE(c.causa_mais_frequente, '—') AS causa_mais_frequente,
  COALESCE(i.dias_impacto_falta_sre, 0) AS dias_impacto_falta_sre,
  COALESCE(i.dias_impacto_rotatividade, 0) AS dias_impacto_rotatividade
FROM projetos p
LEFT JOIN causa_mais_frequente c
  ON c.projeto_id = p.projeto
LEFT JOIN impacto_por_causa i
  ON i.projeto_id = p.projeto
ORDER BY p.ordem_situacao ASC, p.spi ASC, p.cpi ASC;
