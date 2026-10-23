#!/usr/bin/env python3
"""Gera o dashboard AI/BI do Projeto Farol em formato Lakeview."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "resources" / "dashboard-portfolio.lvdash.json"

DATASETS = [
    {
        "name": "portfolio_kpis",
        "displayName": "Indicadores da carteira",
        "queryLines": [
            "SELECT COUNT(*) AS projetos_em_andamento, SUM(valor_contrato) AS carteira, ",
            "TRY_DIVIDE(SUM(ev), SUM(pv)) AS spi, TRY_DIVIDE(SUM(ev), SUM(ac)) AS cpi, ",
            "SUM(estouro_previsto) AS estouro_previsto, ",
            "SUM(CASE WHEN situacao IN ('atenção', 'crítico') THEN 1 ELSE 0 END) AS projetos_em_risco, ",
            "SUM(CASE WHEN situacao = 'crítico' THEN 1 ELSE 0 END) AS criticos, ",
            "SUM(CASE WHEN melancia THEN 1 ELSE 0 END) AS melancias ",
            "FROM projeto_situacao_atual WHERE status = 'em_andamento' ",
        ],
    },
    {
        "name": "portfolio_projetos",
        "displayName": "Projetos em andamento",
        "queryLines": [
            "SELECT projeto, nome, cliente, gerente_projeto, valor_contrato, pv, ev, ac, ",
            "spi, cpi, eac, estouro_previsto, situacao, farol_do_gerente, farol_calculado, melancia ",
            "FROM projeto_situacao_atual WHERE status = 'em_andamento' ",
            "ORDER BY estouro_previsto DESC, nome ",
        ],
    },
    {
        "name": "portfolio_estouro",
        "displayName": "Maiores estouros previstos",
        "queryLines": [
            "SELECT projeto, nome, estouro_previsto, situacao ",
            "FROM projeto_situacao_atual WHERE status = 'em_andamento' ",
            "ORDER BY estouro_previsto DESC LIMIT 10 ",
        ],
    },
    {
        "name": "portfolio_semanal",
        "displayName": "Tendência semanal da carteira",
        "queryLines": [
            "SELECT semana, TRY_DIVIDE(SUM(ev), SUM(pv)) AS spi, ",
            "TRY_DIVIDE(SUM(ev), SUM(ac)) AS cpi ",
            "FROM fato_projeto_semana WHERE semana >= DATE'2025-03-07' ",
            "GROUP BY semana ORDER BY semana ",
        ],
    },
    {
        "name": "pessoas_top15",
        "displayName": "Custo de horas ociosas por pessoa",
        "queryLines": [
            "SELECT nome, SUM(custo_ocioso) AS custo_ocioso, ",
            "SUM(horas_ociosas) AS horas_ociosas ",
            "FROM utilizacao_pessoa_semana WHERE semana > DATE'2026-07-24' ",
            "GROUP BY nome ORDER BY custo_ocioso DESC LIMIT 15 ",
        ],
    },
    {
        "name": "pessoas_projeto",
        "displayName": "Utilização por pessoa e projeto",
        "queryLines": [
            "SELECT nome, projeto_id, SUM(horas_ociosas) AS horas_ociosas, ",
            "SUM(horas_disponiveis) AS horas_disponiveis, ",
            "SUM(horas_apontadas) AS horas_apontadas, ",
            "TRY_DIVIDE(SUM(horas_apontadas), SUM(horas_disponiveis)) AS utilizacao, ",
            "SUM(custo_ocioso) AS custo_ocioso ",
            "FROM utilizacao_pessoa_semana WHERE semana > DATE'2026-07-24' ",
            "GROUP BY nome, projeto_id ",
            "ORDER BY utilizacao ASC, horas_ociosas DESC, nome, projeto_id ",
        ],
    },
    {
        "name": "pessoas_bloqueios",
        "displayName": "Causas de bloqueio por projeto",
        "queryLines": [
            "WITH janela AS (",
            "  SELECT projeto_id, causa_bloqueio, COUNT(*) AS ocorrencias ",
            "  FROM status_estruturado ",
            "  WHERE data_status >= DATE_SUB((SELECT MAX(data_status) FROM status_estruturado), 89) ",
            "    AND causa_bloqueio NOT IN ('sem_bloqueio', 'nao_reportado') ",
            "  GROUP BY projeto_id, causa_bloqueio",
            "), projetos_prioritarios AS (",
            "  SELECT projeto_id, SUM(ocorrencias) AS total ",
            "  FROM janela GROUP BY projeto_id ORDER BY total DESC, projeto_id LIMIT 10",
            ") ",
            "SELECT j.projeto_id, j.causa_bloqueio, j.ocorrencias ",
            "FROM janela j INNER JOIN projetos_prioritarios p ON p.projeto_id = j.projeto_id ",
            "ORDER BY p.total DESC, j.projeto_id, j.ocorrencias DESC ",
        ],
    },
    {
        "name": "fornecedores_resumo",
        "displayName": "Desempenho por fornecedor",
        "queryLines": [
            "SELECT fornecedor, CONCAT_WS(', ', SORT_ARRAY(COLLECT_SET(fornecedor_como_veio))) AS grafias_cadastro, ",
            "COUNT(*) AS entregas, ",
            "TRY_DIVIDE(SUM(CASE WHEN data_entrega IS NOT NULL THEN prazo_real_dias END), ",
            "SUM(CASE WHEN data_entrega IS NOT NULL THEN prazo_prometido_dias END)) AS razao_prazo_real_prometido, ",
            "TRY_DIVIDE(SUM(CASE WHEN data_entrega IS NOT NULL AND data_entrega <= data_prometida THEN 1 ELSE 0 END), ",
            "SUM(CASE WHEN data_entrega IS NOT NULL THEN 1 ELSE 0 END)) AS percentual_no_prazo, ",
            "SUM(CASE WHEN em_aberto AND data_prometida < DATE'2026-10-16' THEN 1 ELSE 0 END) AS em_atraso_hoje ",
            "FROM lakehouse_vertice.silver.entregas_fornecedor ",
            "GROUP BY fornecedor ORDER BY em_atraso_hoje DESC, entregas DESC, fornecedor ",
        ],
    },
    {
        "name": "fornecedores_atrasos",
        "displayName": "Entregas em atraso no corte atual",
        "queryLines": [
            "SELECT entrega_id, fornecedor, fornecedor_como_veio, projeto_id, item, ",
            "data_prometida, dias_de_atraso_na_entrega, valor ",
            "FROM lakehouse_vertice.silver.entregas_fornecedor ",
            "WHERE em_aberto AND data_prometida < DATE'2026-10-16' ",
            "ORDER BY dias_de_atraso_na_entrega DESC, fornecedor, entrega_id ",
        ],
    },
]


def field(name: str, expression: str | None = None) -> dict:
    return {"name": name, "expression": expression or f"`{name}`"}


def query(dataset: str, fields: list[dict], disaggregated: bool = True) -> dict:
    return {
        "name": "main_query",
        "query": {
            "datasetName": dataset,
            "fields": fields,
            "disaggregated": disaggregated,
        },
    }


def frame(title: str) -> dict:
    return {"showTitle": True, "title": title}


def widget(name: str, dataset: str, fields: list[dict], spec: dict, position: dict) -> dict:
    return {
        "widget": {
            "name": name,
            "queries": [query(dataset, fields)],
            "spec": {**spec, "frame": spec.get("frame", frame(name))},
        },
        "position": position,
    }


def counter(name: str, title: str, field_name: str, display_name: str, position: dict, fmt: dict) -> dict:
    return widget(
        name,
        "portfolio_kpis",
        [field(field_name)],
        {
            "version": 2,
            "widgetType": "counter",
            "encodings": {
                "value": {
                    "fieldName": field_name,
                    "displayName": display_name,
                    "format": fmt,
                }
            },
            "frame": frame(title),
        },
        position,
    )


def table(
    name: str,
    title: str,
    dataset: str,
    columns: list[tuple[str, str]],
    position: dict,
    formats: dict[str, dict] | None = None,
) -> dict:
    fields = [field(field_name) for field_name, _ in columns]
    return widget(
        name,
        dataset,
        fields,
        {
            "version": 2,
            "widgetType": "table",
            "encodings": {
                "columns": [
                    {
                        "fieldName": field_name,
                        "displayName": label,
                        **({"format": formats[field_name]} if formats and field_name in formats else {}),
                    }
                    for field_name, label in columns
                ]
            },
            "frame": frame(title),
        },
        position,
    )


def page(name: str, title: str, question: str, layout: list[dict]) -> dict:
    return {
        "name": name,
        "displayName": title,
        "pageType": "PAGE_TYPE_CANVAS",
        "layoutVersion": "GRID_V1",
        "layout": [
            {
                "widget": {
                    "name": f"{name}-pergunta",
                    "multilineTextboxSpec": {
                        "lines": [f"# {title}\\n", "\\n", f"**{question}**"]
                    },
                },
                "position": {"x": 0, "y": 0, "width": 12, "height": 2},
            },
            *layout,
        ],
    }


def build_dashboard() -> dict:
    currency_brl = {
        "type": "number-currency",
        "currencyCode": "BRL",
        "abbreviation": "compact",
        "decimalPlaces": {"type": "max", "places": 2},
    }
    ratio_format = {
        "type": "number-plain",
        "decimalPlaces": {"type": "exact", "places": 2},
        "suffix": "x",
    }
    count_format = {"type": "number", "decimalPlaces": {"type": "exact", "places": 0}}
    portfolio_layout = [
        counter("kpi-carteira", "Carteira em andamento", "carteira", "Valor contratado", {"x": 0, "y": 2, "width": 3, "height": 3}, currency_brl),
        counter("kpi-spi", "SPI da carteira", "spi", "SPI", {"x": 3, "y": 2, "width": 3, "height": 3}, ratio_format),
        counter("kpi-cpi", "CPI da carteira", "cpi", "CPI", {"x": 6, "y": 2, "width": 3, "height": 3}, ratio_format),
        counter("kpi-estouro", "Estouro previsto", "estouro_previsto", "Estouro", {"x": 9, "y": 2, "width": 3, "height": 3}, currency_brl),
        counter("kpi-risco", "Projetos em risco", "projetos_em_risco", "Projetos", {"x": 0, "y": 5, "width": 4, "height": 3}, count_format),
        counter("kpi-criticos", "Projetos críticos", "criticos", "Projetos", {"x": 4, "y": 5, "width": 4, "height": 3}, count_format),
        counter("kpi-melancias", "Projetos melancia", "melancias", "Projetos", {"x": 8, "y": 5, "width": 4, "height": 3}, count_format),
        widget(
            "estouro-por-projeto",
            "portfolio_estouro",
            [field("estouro_previsto"), field("nome"), field("situacao")],
            {
                "version": 3,
                "widgetType": "bar",
                "mark": {"layout": "group"},
                "encodings": {
                    "x": {"fieldName": "estouro_previsto", "scale": {"type": "quantitative"}, "displayName": "Estouro previsto (R$)", "format": currency_brl},
                    "y": {"fieldName": "nome", "scale": {"type": "categorical"}},
                    "color": {
                        "fieldName": "situacao",
                        "scale": {
                            "type": "categorical",
                            "mappings": [
                                {"value": "crítico", "color": "#FF5F46"},
                                {"value": "atenção", "color": "#F6C344"},
                                {"value": "ok", "color": "#22C2F4"},
                            ],
                        },
                    },
                },
                "frame": frame("Top 10 — estouro previsto por projeto"),
            },
            {"x": 0, "y": 8, "width": 6, "height": 6},
        ),
        widget(
            "dispersao-spi-cpi",
            "portfolio_projetos",
            [field("projeto"), field("spi"), field("cpi"), field("situacao")],
            {
                "version": 3,
                "widgetType": "scatter",
                "encodings": {
                    "x": {"fieldName": "spi", "scale": {"type": "quantitative"}, "displayName": "SPI"},
                    "y": {"fieldName": "cpi", "scale": {"type": "quantitative"}, "displayName": "CPI"},
                    "color": {
                        "fieldName": "situacao",
                        "scale": {
                            "type": "categorical",
                            "mappings": [
                                {"value": "crítico", "color": "#FF5F46"},
                                {"value": "atenção", "color": "#F6C344"},
                                {"value": "ok", "color": "#22C2F4"},
                            ],
                        },
                    },
                },
                "frame": frame("SPI × CPI por projeto"),
            },
            {"x": 6, "y": 8, "width": 6, "height": 6},
        ),
        widget(
            "tendencia-spi-cpi",
            "portfolio_semanal",
            [field("semana"), field("spi"), field("cpi")],
            {
                "version": 3,
                "widgetType": "line",
                "encodings": {
                    "x": {"fieldName": "semana", "scale": {"type": "temporal"}, "displayName": "Semana"},
                    "y": {
                        "scale": {"type": "quantitative"},
                        "fields": [
                            {"fieldName": "spi", "displayName": "SPI"},
                            {"fieldName": "cpi", "displayName": "CPI"},
                        ],
                    },
                },
                "frame": frame("SPI e CPI semanais da carteira"),
            },
            {"x": 0, "y": 14, "width": 12, "height": 6},
        ),
        table(
            "projetos-em-andamento",
            "Projetos em andamento e faróis",
            "portfolio_projetos",
            [
                ("projeto", "Projeto"),
                ("nome", "Nome"),
                ("gerente_projeto", "Gerente"),
                ("situacao", "Situação"),
                ("farol_do_gerente", "Farol gerente"),
                ("farol_calculado", "Farol calculado"),
                ("melancia", "Melancia"),
                ("spi", "SPI"),
                ("cpi", "CPI"),
                ("estouro_previsto", "Estouro previsto"),
            ],
            {"x": 0, "y": 20, "width": 12, "height": 7},
            {
                "spi": {"type": "number-plain", "decimalPlaces": {"type": "exact", "places": 2}},
                "cpi": {"type": "number-plain", "decimalPlaces": {"type": "exact", "places": 2}},
                "estouro_previsto": currency_brl,
            },
        ),
    ]
    people_layout = [
        table(
            "top-pessoas-ociosas",
            "Top 15 — custo de horas ociosas",
            "pessoas_top15",
            [("nome", "Pessoa"), ("custo_ocioso", "Custo ocioso (R$)"), ("horas_ociosas", "Horas ociosas")],
            {"x": 0, "y": 2, "width": 6, "height": 7},
            {"custo_ocioso": currency_brl},
        ),
        table(
            "utilizacao-pessoa-projeto",
            "Utilização por pessoa e projeto — da mais ociosa à mais ocupada",
            "pessoas_projeto",
            [
                ("nome", "Pessoa"),
                ("projeto_id", "Projeto"),
                ("horas_ociosas", "Horas ociosas"),
                ("horas_disponiveis", "Horas disponíveis"),
                ("horas_apontadas", "Horas apontadas"),
                ("utilizacao", "Utilização"),
                ("custo_ocioso", "Custo ocioso (R$)"),
            ],
            {"x": 6, "y": 2, "width": 6, "height": 7},
            {
                "utilizacao": {"type": "number-percent", "decimalPlaces": {"type": "max", "places": 1}},
                "custo_ocioso": currency_brl,
            },
        ),
        widget(
            "causas-bloqueio-projeto",
            "pessoas_bloqueios",
            [field("projeto_id"), field("ocorrencias"), field("causa_bloqueio")],
            {
                "version": 3,
                "widgetType": "bar",
                "encodings": {
                    "x": {"fieldName": "projeto_id", "scale": {"type": "categorical"}, "displayName": "Projeto"},
                    "y": {"fieldName": "ocorrencias", "scale": {"type": "quantitative"}, "displayName": "Ocorrências"},
                    "color": {"fieldName": "causa_bloqueio", "scale": {"type": "categorical"}},
                },
                "frame": frame("Causas de bloqueio — Top 10 projetos, últimos 90 dias"),
            },
            {"x": 0, "y": 9, "width": 12, "height": 6},
        ),
    ]
    supplier_layout = [
        table(
            "desempenho-fornecedores",
            "Desempenho consolidado por fornecedor",
            "fornecedores_resumo",
            [
                ("fornecedor", "Fornecedor normalizado"),
                ("grafias_cadastro", "Grafias no cadastro"),
                ("entregas", "Entregas"),
                ("razao_prazo_real_prometido", "Prazo real ÷ prometido"),
                ("percentual_no_prazo", "% no prazo"),
                ("em_atraso_hoje", "Em atraso no corte"),
            ],
            {"x": 0, "y": 2, "width": 12, "height": 7},
            {
                "razao_prazo_real_prometido": {
                    "type": "number-plain",
                    "decimalPlaces": {"type": "exact", "places": 2},
                    "suffix": "x",
                },
                "percentual_no_prazo": {
                    "type": "number-percent",
                    "decimalPlaces": {"type": "max", "places": 1},
                },
            },
        ),
        table(
            "entregas-atrasadas",
            "Entregas em aberto atrasadas no corte de 16/10/2026",
            "fornecedores_atrasos",
            [
                ("entrega_id", "Entrega"),
                ("fornecedor", "Fornecedor"),
                ("fornecedor_como_veio", "Grafia original"),
                ("projeto_id", "Projeto"),
                ("item", "Item"),
                ("data_prometida", "Data prometida"),
                ("dias_de_atraso_na_entrega", "Dias em atraso"),
                ("valor", "Valor (R$)"),
            ],
            {"x": 0, "y": 9, "width": 12, "height": 7},
            {"valor": currency_brl},
        ),
    ]
    return {
        "datasets": [
            {
                **dataset,
                "queryLines": [
                    line if line.endswith((" ", "\n")) else f"{line}\n"
                    for line in dataset["queryLines"]
                ],
            }
            for dataset in DATASETS
        ],
        "pages": [
            page(
                "portfolio",
                "Portfólio",
                "Estamos entregando os projetos dentro do prazo e do orçamento?",
                portfolio_layout,
            ),
            page(
                "pessoas",
                "Pessoas",
                "Onde a capacidade da equipe está ociosa e quais bloqueios precisam de decisão?",
                people_layout,
            ),
            page(
                "fornecedores",
                "Fornecedores",
                "Quais fornecedores entregam no prazo e quais entregas estão atrasadas?",
                supplier_layout,
            ),
        ],
        "uiSettings": {
            "theme": {
                "canvasBackgroundColor": {"light": "#F7F9FC", "dark": "#14141A"},
                "widgetBackgroundColor": {"light": "#FFFFFF", "dark": "#1E1E27"},
                "widgetBorderColor": {"light": "#FFFFFF", "dark": "#1E1E27"},
                "fontColor": {"light": "#172033", "dark": "#F2F5FA"},
                "selectionColor": {"light": "#0059DB", "dark": "#22C2F4"},
                "visualizationColors": [
                    "#0059DB",
                    "#22C2F4",
                    "#FF5F46",
                    "#F6C344",
                    "#26A269",
                    "#8C6EE8",
                    "#62718A",
                ],
                "widgetHeaderAlignment": "LEFT",
            }
        },
    }


def main() -> None:
    OUTPUT.write_text(
        json.dumps(build_dashboard(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Dashboard gerado: {OUTPUT.relative_to(ROOT)}")
    print(f"{len(DATASETS)} datasets · 3 páginas · GRID_V1")


if __name__ == "__main__":
    main()
