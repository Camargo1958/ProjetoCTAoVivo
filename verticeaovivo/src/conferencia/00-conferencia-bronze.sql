WITH contagens AS (
  SELECT 'projetos' AS tabela, 60 AS esperado, COUNT(*) AS obtido
  FROM lakehouse_vertice.bronze.projetos
  UNION ALL
  SELECT 'status_semanal', 3911, COUNT(*)
  FROM lakehouse_vertice.bronze.status_semanal
  UNION ALL
  SELECT 'excel_tarefas', 1663, COUNT(*)
  FROM lakehouse_vertice.bronze.excel_tarefas
  UNION ALL
  SELECT 'clickup_tarefas', 2119, COUNT(*)
  FROM lakehouse_vertice.bronze.clickup_tarefas
  UNION ALL
  SELECT 'msproject_tarefas', 1260, COUNT(*)
  FROM lakehouse_vertice.bronze.msproject_tarefas
  UNION ALL
  SELECT 'colaboradores', 523, COUNT(*)
  FROM lakehouse_vertice.bronze.colaboradores
  UNION ALL
  SELECT 'apontamentos', 30883, COUNT(*)
  FROM lakehouse_vertice.bronze.apontamentos
  UNION ALL
  SELECT 'custos', 23640, COUNT(*)
  FROM lakehouse_vertice.bronze.custos
  UNION ALL
  SELECT 'entregas_fornecedor', 640, COUNT(*)
  FROM lakehouse_vertice.bronze.entregas_fornecedor
)
SELECT
  tabela,
  esperado,
  obtido,
  CASE
    WHEN obtido = esperado THEN 'OK'
    ELSE raise_error(
      concat(
        'Divergencia na tabela bronze.',
        tabela,
        ': esperado ',
        CAST(esperado AS STRING),
        ', obtido ',
        CAST(obtido AS STRING),
        '. Verifique a saida da tarefa ingestao_data_lake.'
      )
    )
  END AS resultado
FROM contagens
ORDER BY tabela;
