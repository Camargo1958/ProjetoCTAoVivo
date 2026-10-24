#!/usr/bin/env python3
"""Gera o payload serializado do Genie do Projeto Farol."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "resources" / "farol.geniespace.json"

TABLES = [
    "lakehouse_vertice.gold.fato_projeto_semana",
    "lakehouse_vertice.gold.projeto_situacao_atual",
    "lakehouse_vertice.gold.status_estruturado",
    "lakehouse_vertice.gold.utilizacao_pessoa_semana",
    "lakehouse_vertice.silver.entregas_fornecedor",
    "lakehouse_vertice.gold.mv_projetos",
]

COLUMN_PROJETO_SITUACAO = [
    "projeto", "nome", "cliente", "segmento", "ferramenta", "valor_contrato",
    "status", "spi", "cpi", "eac", "estouro_previsto", "margem_projetada",
    "atraso_projetado_dias", "situacao", "farol_do_gerente", "farol_calculado",
    "melancia", "gerente_projeto"
]

COLUMN_FATO = [
    "projeto", "semana", "valor_contrato", "ev", "pv", "ac", "eac", "spi", "cpi"
]

COLUMN_STATUS = [
    "projeto", "data_status", "texto_status", "status_vazio", "farol",
    "bloqueio", "causa", "dias_impacto"
]

COLUMN_UTILIZACAO = [
    "projeto", "colaborador_id", "semana_inicio", "percentual_utilizacao",
    "horas_disponiveis", "horas_apontadas", "semanas_12"
]

COLUMN_ENTREGAS = [
    "fornecedor", "prazo_prometido", "prazo_real", "entrega_em_atraso"
]

ALL_COLUMNS = {
    "lakehouse_vertice.gold.fato_projeto_semana": COLUMN_FATO,
    "lakehouse_vertice.gold.projeto_situacao_atual": COLUMN_PROJETO_SITUACAO,
    "lakehouse_vertice.gold.status_estruturado": COLUMN_STATUS,
    "lakehouse_vertice.gold.utilizacao_pessoa_semana": COLUMN_UTILIZACAO,
    "lakehouse_vertice.silver.entregas_fornecedor": COLUMN_ENTREGAS,
    "lakehouse_vertice.gold.mv_projetos": ["projeto", "cliente", "segmento", "spi", "cpi", "eac", "estouro_previsto", "margem_projetada"],
}


def build_payload() -> dict:
    tables = []
    for table_name in sorted(TABLES):
        columns = ALL_COLUMNS.get(table_name, [])
        conf = [{"column_name": column, "enable_format_assistance": True} for column in columns]
        tables.append({"identifier": table_name, "column_configs": conf})
    return {
        "version": 2,
        "data_sources": {"tables": tables},
    }


def main() -> int:
    payload = build_payload()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Gerado {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
