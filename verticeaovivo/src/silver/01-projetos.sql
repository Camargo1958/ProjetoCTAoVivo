CREATE OR REFRESH MATERIALIZED VIEW projetos (
  CONSTRAINT data_inicio_obrigatoria EXPECT (data_inicio IS NOT NULL)
    ON VIOLATION FAIL UPDATE,
  CONSTRAINT ferramenta_valida EXPECT (ferramenta IN ('excel', 'clickup', 'msproject'))
    ON VIOLATION FAIL UPDATE
)
COMMENT 'Cadastro tipado do PMO e de-para entre projetos e ferramentas de gestao.'
AS
WITH origem AS (
  SELECT
    projeto_id,
    nome_projeto,
    cliente,
    segmento,
    tipo_projeto,
    ferramenta AS ferramenta_como_veio,
    codigo_ferramenta,
    valor_contrato,
    orcamento_custo,
    data_inicio,
    data_fim_baseline,
    status,
    gerente_projeto
  FROM lakehouse_vertice.bronze.projetos
),
normalizado AS (
  SELECT
    projeto_id,
    nome_projeto,
    cliente,
    segmento,
    tipo_projeto,
    ferramenta_como_veio,
    CASE
      WHEN lower(trim(ferramenta_como_veio)) LIKE '%excel%'
        OR lower(trim(ferramenta_como_veio)) LIKE '%planilha%'
        OR lower(trim(ferramenta_como_veio)) LIKE '%spreadsheet%'
        THEN 'excel'
      WHEN lower(trim(ferramenta_como_veio)) LIKE '%click%up%'
        THEN 'clickup'
      WHEN lower(trim(ferramenta_como_veio)) LIKE '%project%'
        THEN 'msproject'
    END AS ferramenta,
    NULLIF(trim(codigo_ferramenta), '') AS codigo_ferramenta,
    CAST(
      CASE
        WHEN instr(trim(valor_contrato), ',') > 0
          THEN replace(replace(replace(trim(valor_contrato), 'R$', ''), '.', ''), ',', '.')
        ELSE regexp_replace(replace(trim(valor_contrato), 'R$', ''), '[^0-9.-]', '')
      END AS DECIMAL(18, 2)
    ) AS valor_contrato,
    CAST(
      CASE
        WHEN instr(trim(orcamento_custo), ',') > 0
          THEN replace(replace(replace(trim(orcamento_custo), 'R$', ''), '.', ''), ',', '.')
        ELSE regexp_replace(replace(trim(orcamento_custo), 'R$', ''), '[^0-9.-]', '')
      END AS DECIMAL(18, 2)
    ) AS orcamento_custo,
    coalesce(
      try_to_date(data_inicio, 'yyyy-MM-dd'),
      try_to_date(data_inicio, 'dd/MM/yyyy')
    ) AS data_inicio,
    coalesce(
      try_to_date(data_fim_baseline, 'yyyy-MM-dd'),
      try_to_date(data_fim_baseline, 'dd/MM/yyyy')
    ) AS data_fim_baseline,
    status,
    gerente_projeto
  FROM origem
)
SELECT *
FROM normalizado;
