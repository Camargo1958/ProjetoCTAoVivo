SELECT
  c.colaborador_id AS pessoa_id,
  c.nome,
  c.papel,
  c.senioridade,
  CAST(COALESCE(c.custo_hora, 0) AS DOUBLE) AS custo_hora,
  CAST(AVG(CASE WHEN a.horas_disponiveis > 0 THEN a.horas_disponiveis ELSE 0 END) AS DOUBLE) AS horas_disponiveis_media_semana,
  CAST(AVG(CASE WHEN a.horas_apontadas > 0 THEN a.horas_apontadas ELSE 0 END) AS DOUBLE) AS horas_apontadas_media_semana,
  CAST(AVG(GREATEST(COALESCE(a.horas_disponiveis, 0) - COALESCE(a.horas_apontadas, 0), 0)) AS DOUBLE) AS horas_ociosas_media_semana,
  CAST(AVG(CASE WHEN COALESCE(a.horas_disponiveis, 0) > 0 THEN (COALESCE(a.horas_disponiveis, 0) - COALESCE(a.horas_apontadas, 0)) / a.horas_disponiveis ELSE 0 END) AS DOUBLE) AS utilizacao_media,
  CAST(AVG(GREATEST(COALESCE(a.horas_disponiveis, 0) - COALESCE(a.horas_apontadas, 0), 0) * COALESCE(c.custo_hora, 0)) AS DOUBLE) AS custo_ocioso_medio_semana
FROM lakehouse_vertice.gold.utilizacao_pessoa_semana a
JOIN lakehouse_vertice.silver.colaboradores c
  ON c.colaborador_id = a.colaborador_id
WHERE a.semana >= DATE_ADD(DATE'2026-10-16', -84)
GROUP BY c.colaborador_id, c.nome, c.papel, c.senioridade, c.custo_hora
HAVING AVG(CASE WHEN COALESCE(a.horas_disponiveis, 0) > 0 THEN (COALESCE(a.horas_disponiveis, 0) - COALESCE(a.horas_apontadas, 0)) / a.horas_disponiveis ELSE 0 END) < 0.2
ORDER BY custo_ocioso_medio_semana DESC, horas_ociosas_media_semana DESC;
