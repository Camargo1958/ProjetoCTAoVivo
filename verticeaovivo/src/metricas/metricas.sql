CREATE OR REPLACE VIEW lakehouse_vertice.gold.mv_projetos
COMMENT 'Resumo executivo da carteira em andamento com indicadores de cronograma, custo e risco para a diretoria.'
WITH METRICS
LANGUAGE YAML AS $$
version: 1.1
source: lakehouse_vertice.gold.projeto_situacao_atual
filter: "status = 'em_andamento'"
dimensions:
  - name: projeto_id
    expr: projeto
    comment: "Identificador único do projeto no PMO."
    synonyms: ["id projeto", "projeto"]
  - name: projeto
    expr: nome
    comment: "Nome do projeto para consulta e priorização."
    synonyms: ["nome do projeto"]
  - name: cliente
    expr: cliente
    comment: "Cliente do projeto."
  - name: segmento
    expr: segmento
    comment: "Segmento de atuação do cliente."
  - name: ferramenta
    expr: ferramenta
    comment: "Ferramenta de gestão do projeto."
  - name: situacao
    expr: situacao
    comment: "Situação atual do projeto: ok, atenção ou crítico."
  - name: farol_do_gerente
    expr: farol_do_gerente
    comment: "Farol informado pelo gerente do projeto."
  - name: farol_calculado
    expr: farol_calculado
    comment: "Farol de risco calculado pela regra do projeto."
  - name: gerente_projeto
    expr: gerente_projeto
    comment: "Responsável pelo projeto na carteira."
measures:
  - name: projetos
    expr: COUNT(DISTINCT projeto)
    comment: "Número de projetos em andamento na fotografia atual."
  - name: carteira
    expr: SUM(valor_contrato)
    comment: "Valor total contratado dos projetos em andamento."
  - name: spi
    expr: SUM(ev) / SUM(pv)
    comment: "Índice agregado de desempenho do cronograma."
  - name: cpi
    expr: SUM(ev) / SUM(ac)
    comment: "Índice agregado de desempenho de custos."
  - name: eac
    expr: SUM(eac)
    comment: "Estimativa atual de conclusão da carteira."
  - name: estouro_previsto
    expr: SUM(estouro_previsto)
    comment: "Total do orçamento previsto acima do valor contratado."
  - name: margem_projetada
    expr: (SUM(valor_contrato) - SUM(eac)) / SUM(valor_contrato)
    comment: "Margem líquida esperada sobre o valor do contrato."
  - name: atraso_projetado_medio_dias
    expr: AVG(atraso_projetado_dias)
    comment: "Média do atraso previsto para os projetos em andamento."
  - name: projetos_em_risco
    expr: COUNT(DISTINCT CASE WHEN situacao IN ('atenção', 'crítico') THEN projeto END)
    comment: "Projetos em atenção ou crítico na fotografia atual."
  - name: projetos_criticos
    expr: COUNT(DISTINCT CASE WHEN situacao = 'crítico' THEN projeto END)
    comment: "Projetos na situação crítica."
  - name: projetos_melancia
    expr: COUNT(DISTINCT CASE WHEN melancia THEN projeto END)
    comment: "Projetos com farol verde e SPI abaixo de 0,9."
$$
