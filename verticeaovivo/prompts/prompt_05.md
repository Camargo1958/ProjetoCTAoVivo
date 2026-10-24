Leia o CLAUDE.md da raiz.
Use as skills databricks-apps e databricks-app-design. A gold, o score
(gold.score_estouro_30d) e o Genie "Farol · Diretoria" já existem.

1. Confira `databricks apps list --profile <perfil>` (limite de 3 apps no
   Free Edition). Descubra o id do Genie "Farol · Diretoria" e crie o app
   numa pasta minha-torre/ na raiz deste repositório:
   databricks apps init --name minha-torre \
     --features analytics,genie \
     --set analytics.sql-warehouse.id=<warehouse> \
     --set genie.genie-space.id=<id do Genie "Farol · Diretoria"> \
     --set "genie.genie-space.name=Farol · Diretoria" \
     --run none --profile <perfil>
   O app é um bundle próprio, dentro da pasta do bundle vertice. Acrescente
   ao databricks.yml da RAIZ (o do vertice) sync: { exclude: ["minha-torre/**"] },
   senão o deploy do vertice sobe o node_modules do app inteiro.

2. config/queries (apague os exemplos do template):
   - kpis.sql: projetos em andamento, em risco (atenção + crítico),
     críticos, melancias, estouro previsto e carteira
     (projeto_situacao_atual), e alto risco em 30 dias (faixa_risco = 'alto'
     na data_referencia mais recente de score_estouro_30d).
   - projetos_risco.sql: projetos em andamento do pior para o melhor, com
     SPI, CPI, estouro, atraso projetado, farol do gerente × calculado,
     melancia, a causa mais frequente no status_estruturado dos últimos 90
     dias e os dias de impacto por falta_sre e por rotatividade.
   - pessoas_ociosas.sql: pessoas com utilização < 20% nas últimas 12
     semanas (utilizacao_pessoa_semana), com horas paradas e custo ocioso
     MÉDIOS por semana e custo_hora.
   A probabilidade por projeto (gold.score_estouro_30d) vem de uma rota
   GET /api/score-estouro no servidor que responde {disponivel, linhas}:
   se a tabela não existir, a tela mostra "—" em vez de quebrar o build.

3. Telas (português, R$, índices com 2 casas, Number() em tudo que vem do
   warehouse):
   - Projetos em risco: 4 KPIs (em risco, estouro previsto, carteira, alto
     risco em 30 dias) + tabela (situação com cor: crítico vermelho, atenção
     âmbar; farol do gerente com 🍉 quando é melancia; coluna P(estouro)).
   - Simulador: escolher uma pessoa ociosa e um projeto destino (só atenção
     ou crítico; para SRE, ordene pelos dias de falta_sre); mostrar horas no
     mês (× 4 semanas), ociosidade que deixa de ser paga, dias de cronograma
     recuperados (dias de impacto da causa nos últimos 90 dias ÷ 90 × 30),
     mobilização = horas de onboarding (editável, 40) × custo_hora, e saldo.
     Explique a conta num <details>.
   - Perguntar: <GenieChat alias="default" />.
   Sem cache no createApp. Título "Projeto Farol".

4. npm run typecheck, npm run lint, databricks apps validate.
   Depois: databricks bundle deploy --profile <perfil> (cria o app e o
   service principal). Crie scripts/conceder-acesso.sh (lê o
   service_principal_client_id com apps get e dá USE CATALOG em
   lakehouse_vertice e USE SCHEMA + SELECT na gold e na silver), rode e
   faça databricks apps deploy --profile <perfil>. Me mostre a URL.