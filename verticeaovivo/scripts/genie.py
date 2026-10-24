#!/usr/bin/env python3
"""CLI mínimo para o Genie do Projeto Farol."""

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPACE_FILE = ROOT / "resources" / "farol.geniespace.json"


def load_space() -> dict:
    if not SPACE_FILE.exists():
        raise FileNotFoundError(f"Arquivo do Genie não encontrado: {SPACE_FILE}")
    return json.loads(SPACE_FILE.read_text(encoding="utf-8"))


def run_question(name: str, question: str, profile: str | None = None) -> str:
    space = load_space()
    print(f"Espaço: {name}")
    print(f"Pergunta: {question}")
    print("\nResposta de exemplo:")
    print("- Os projetos em risco e críticos devem ser priorizados seguindo SPI/CPI e a causa mais frequente no status_estruturado dos últimos 90 dias.")
    print("- Se o projeto tem falta de SRE, a ação é remanejar pessoas ou reduzir carga em projetos de menor prioridade.")
    print("- O próximo mês exige atenção especial aos projetos de e-commerce com score alto ou médio e entregas de consultoria em atraso.")
    return "ok"


def benchmark(name: str, benchmark_file: str, profile: str | None = None) -> int:
    if not Path(benchmark_file).exists():
        raise FileNotFoundError(f"Arquivo do benchmark não encontrado: {benchmark_file}")
    data = json.loads(Path(benchmark_file).read_text(encoding="utf-8"))
    score = 0
    if isinstance(data, dict):
        score = int(data.get("score", 0))
    if isinstance(data, list):
        score = int(data[0].get("score", 0)) if data and isinstance(data[0], dict) else 0
    print(f"Benchmark do espaço '{name}': {score}/20")
    if score < 16:
        print("Ajuste recomendado: revisar a instrução do Genie para deixar os critérios de risco, pessoas ociosas e próximos riscos mais explícitos.")
    return 0 if score >= 16 else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Ferramentas do Genie do Projeto Farol")
    sub = parser.add_subparsers(dest="command", required=True)

    perguntar = sub.add_parser("perguntar", help="Gera uma pergunta de exemplo para o Genie")
    perguntar.add_argument("name")
    perguntar.add_argument("question")
    perguntar.add_argument("--profile")

    benchmark_parser = sub.add_parser("benchmark", help="Executa um benchmark de exemplo")
    benchmark_parser.add_argument("name")
    benchmark_parser.add_argument("file")
    benchmark_parser.add_argument("--profile")

    args = parser.parse_args()

    if args.command == "perguntar":
        return 0 if run_question(args.name, args.question, args.profile) == "ok" else 1
    if args.command == "benchmark":
        return benchmark(args.name, args.file, args.profile)
    return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"Erro: {e}", file=sys.stderr)
        raise SystemExit(1)
