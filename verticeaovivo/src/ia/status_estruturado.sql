CREATE TABLE IF NOT EXISTS lakehouse_vertice.gold.status_estruturado (
  projeto_id STRING COMMENT 'Identificador do projeto no PMO.',
  data_status DATE COMMENT 'Sexta-feira do registro de status do projeto.',
  farol STRING COMMENT 'Farol publicado pelo gerente do projeto.',
  causa_bloqueio STRING COMMENT 'Categoria normalizada da causa de bloqueio.',
  bloqueio STRING COMMENT 'Descricao curta do impedimento identificado.',
  quem_destrava STRING COMMENT 'Pessoa ou area responsavel por remover o impedimento.',
  dias_impacto DOUBLE COMMENT 'Impacto estimado do impedimento em dias.',
  metodo STRING COMMENT 'Origem da classificacao: regra, ia ou palavra_chave.',
  texto_status STRING COMMENT 'Texto original publicado pelo gerente.',
  _classificado_em TIMESTAMP COMMENT 'Instante em que este status foi classificado.'
)
COMMENT 'Classificacao incremental dos textos de status, preservando o resultado original de cada semana.';

MERGE INTO lakehouse_vertice.gold.status_estruturado AS destino
USING (
  WITH novos_status AS (
    SELECT
      s.projeto_id,
      s.data_status,
      s.farol,
      s.status_vazio,
      s.texto_status,
      lower(coalesce(s.texto_status, '')) AS texto_minusculo
    FROM lakehouse_vertice.silver.status_semanal s
    LEFT ANTI JOIN lakehouse_vertice.gold.status_estruturado existente
      ON existente.projeto_id = s.projeto_id
      AND existente.data_status = s.data_status
  ),
  metodo_definido AS (
    SELECT
      *,
      CASE
        WHEN status_vazio
          OR texto_minusculo RLIKE 'bloqueios: nenhum|sem bloqueios|nada relevante'
          THEN 'regra'
        WHEN data_status >= DATE'2026-07-18' THEN 'ia'
        ELSE 'palavra_chave'
      END AS metodo
    FROM novos_status
  ),
  respostas_ia AS (
    SELECT
      *,
      CASE
        WHEN metodo = 'ia' THEN ai_classify(
          texto_status,
          '["change_freeze","falta_sre","dependencia_fornecedor","rotatividade","mudanca_escopo","bug_retrabalho","aprovacao_cliente","sem_bloqueio"]',
          map('version', '2.0')
        ):response::STRING
      END AS causa_ia,
      CASE
        WHEN metodo = 'ia' THEN ai_extract(
          texto_status,
          '{
            "bloqueio": {"type": "string"},
            "quem_destrava": {"type": "string"},
            "dias_impacto": {"type": "number", "description": "Converta semanas em dias usando 7 dias por semana."}
          }',
          map('version', '2.0')
        ):response
      END AS extracao_ia
    FROM metodo_definido
  ),
  classificados AS (
    SELECT
      projeto_id,
      data_status,
      farol,
      CASE
        WHEN metodo = 'regra' AND (status_vazio OR texto_minusculo = '') THEN 'nao_reportado'
        WHEN metodo = 'regra' THEN 'sem_bloqueio'
        WHEN metodo = 'ia' THEN coalesce(
          get_json_object(causa_ia, '$[0]'),
          causa_ia,
          'nao_classificado'
        )
        WHEN texto_minusculo RLIKE 'freeze|congelamento|janela de deploy'
          THEN 'change_freeze'
        WHEN texto_minusculo RLIKE 'sre|infraestrutura|ambiente de homologação'
          THEN 'falta_sre'
        WHEN texto_minusculo RLIKE 'forge|consultoria|fornecedor'
          THEN 'dependencia_fornecedor'
        WHEN texto_minusculo RLIKE 'saída de|rotatividade|onboarding'
          THEN 'rotatividade'
        WHEN texto_minusculo RLIKE 'escopo|change request|regra de negócio'
          THEN 'mudanca_escopo'
        WHEN texto_minusculo RLIKE 'bugs|regressão|refazendo'
          THEN 'bug_retrabalho'
        WHEN texto_minusculo RLIKE 'aprovação do cliente|homologação do cliente'
          THEN 'aprovacao_cliente'
        ELSE 'nao_classificado'
      END AS causa_bloqueio,
      CASE
        WHEN metodo = 'ia' THEN extracao_ia:bloqueio::STRING
        WHEN metodo = 'regra' AND status_vazio THEN NULL
        WHEN metodo = 'regra' THEN 'Nenhum bloqueio reportado.'
        ELSE texto_status
      END AS bloqueio,
      CASE
        WHEN metodo = 'ia' THEN extracao_ia:quem_destrava::STRING
      END AS quem_destrava,
      CASE
        WHEN metodo = 'ia' THEN extracao_ia:dias_impacto::DOUBLE
        WHEN texto_minusculo RLIKE 'impacto estimado: *1 semana'
          THEN 7.0
        WHEN texto_minusculo RLIKE 'impacto estimado de [0-9]+ dias'
          THEN CAST(regexp_extract(texto_minusculo, 'impacto estimado de ([0-9]+) dias', 1) AS DOUBLE)
      END AS dias_impacto,
      metodo,
      texto_status,
      current_timestamp() AS _classificado_em
    FROM respostas_ia
  )
  SELECT *
  FROM classificados
) AS origem
ON destino.projeto_id = origem.projeto_id
  AND destino.data_status = origem.data_status
WHEN NOT MATCHED THEN INSERT (
  projeto_id,
  data_status,
  farol,
  causa_bloqueio,
  bloqueio,
  quem_destrava,
  dias_impacto,
  metodo,
  texto_status,
  _classificado_em
)
VALUES (
  origem.projeto_id,
  origem.data_status,
  origem.farol,
  origem.causa_bloqueio,
  origem.bloqueio,
  origem.quem_destrava,
  origem.dias_impacto,
  origem.metodo,
  origem.texto_status,
  origem._classificado_em
);

UPDATE lakehouse_vertice.gold.status_estruturado
SET causa_bloqueio = get_json_object(causa_bloqueio, '$[0]')
WHERE metodo = 'ia'
  AND get_json_object(causa_bloqueio, '$[0]') IS NOT NULL;

SELECT
  metodo,
  causa_bloqueio,
  count(*) AS quantidade
FROM lakehouse_vertice.gold.status_estruturado
GROUP BY metodo, causa_bloqueio
ORDER BY metodo, causa_bloqueio;
