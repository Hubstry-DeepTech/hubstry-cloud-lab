#!/usr/bin/env python3
"""Estimativa mensal na AWS (cenário Nautam; extensão multiprojeto pendente), com preços oficiais da AWS Price List API.

Compara sa-east-1 (São Paulo) e us-east-1 (Virgínia), 730 h/mês, preços sob demanda.
Rodar no AWS CloudShell (já tem AWS CLI e Python):

    python3 plataforma/aws/scripts/estimar_custos.py
    python3 plataforma/aws/scripts/estimar_custos.py --com-dashboard --detalhes

O script falha, em vez de chutar, se um item tiver mais de um preço possível
ou uma unidade inesperada. A saída de --detalhes serve de evidência para a revisão.

Só faz chamadas de leitura à Price List API (gratuita). Não cria recursos.
Itens de uso variável (Amplify, transferência de dados) ficam fora do total
e são listados como observação.
"""
import argparse
import json
import re
import subprocess
import sys

HORAS_MES = 730
REGIOES = ["sa-east-1", "us-east-1"]

# Premissas de dimensionamento (ajuste aqui e rode de novo)
API_VCPU, API_GB = 0.25, 0.5          # tarefa Fargate da API
DASH_VCPU, DASH_GB = 0.5, 1.0         # tarefa Fargate do dashboard (opcional)
ALB_LCU_MEDIO = 0.5                   # tráfego baixo de POC
RDS_STORAGE_GB = 20                   # gp3, mínimo prático
SECRETS = 2                           # DATABASE_URL + reserva
LOGS_GB_MES = 1.0                     # ingestão CloudWatch Logs (retenção curta)
ECR_GB = 2.0                          # imagens versionadas (com política de limpeza)


def get_products(service, filtros):
    args = ["aws", "pricing", "get-products", "--region", "us-east-1",
            "--service-code", service, "--output", "json", "--filters"]
    args += [f"Type=TERM_MATCH,Field={k},Value={v}" for k, v in filtros.items()]
    itens, token = [], None
    while True:
        cmd = args + (["--next-token", token] if token else [])
        out = json.loads(subprocess.check_output(cmd))
        itens += [json.loads(p) for p in out.get("PriceList", [])]
        token = out.get("NextToken")
        if not token:
            return itens


def dimensoes_usd(produto):
    """Todas as dimensões de preço sob demanda > 0: (preço, unidade, descrição, beginRange)."""
    out = []
    for termo in produto["terms"].get("OnDemand", {}).values():
        for d in termo["priceDimensions"].values():
            v = float(d["pricePerUnit"].get("USD", "0"))
            if v > 0:
                out.append((v, d.get("unit", ""), d.get("description", ""),
                            float(d.get("beginRange", "0") or 0)))
    return out


EVIDENCIAS = []


def achar(service, filtros, cond, unidades, nome, regiao):
    """Exige exatamente um preço distinto, com unidade esperada; senão, falha.

    Para preços em faixas (ex.: CloudWatch), usa a primeira faixa (beginRange 0),
    que é a relevante para o volume baixo da POC.
    """
    candidatos = []
    for p in get_products(service, filtros):
        attrs = p["product"].get("attributes", {})
        if not cond(attrs):
            continue
        dims = dimensoes_usd(p)
        if not dims:
            continue
        primeira = min(dims, key=lambda d: d[3])
        candidatos.append((primeira, attrs.get("usagetype", "?")))
    if not candidatos:
        raise SystemExit(f"[{regiao}] Preço não encontrado: {nome} {filtros}")
    unidades_ok = {u.lower() for u in unidades}
    ruins = [c for c in candidatos if c[0][1].lower() not in unidades_ok]
    if ruins:
        det = "; ".join(f"{ut}: unidade={d[1]!r}" for d, ut in ruins)
        raise SystemExit(f"[{regiao}] Unidade inesperada para {nome} (esperado {unidades}): {det}")
    precos_distintos = {round(d[0], 10) for d, _ in candidatos}
    if len(precos_distintos) != 1:
        det = "; ".join(f"{ut}: {d[0]} USD/{d[1]} ({d[2]})" for d, ut in candidatos)
        raise SystemExit(f"[{regiao}] Ambíguo: {len(precos_distintos)} preços para {nome}. "
                         f"Refine o filtro. Candidatos: {det}")
    (preco, unidade, descricao, _), usagetype = candidatos[0]
    EVIDENCIAS.append((regiao, nome, usagetype, unidade, preco, descricao))
    return preco


def precos(regiao):
    rc = {"regionCode": regiao}
    # Correspondência EXATA do usagetype, com prefixo de região opcional
    # (ex.: "SAE1-LoadBalancerUsage" em sa-east-1, "LoadBalancerUsage" em us-east-1).
    # Evita variantes como Outposts, Trust Store, ARM, Windows e Spot.
    def ut(sufixo):
        # Prefixos de região têm 3 letras + 1 dígito (SAE1, USE2, EUC1...).
        # "TS-" (Trust Store) e "Outposts-" não casam com esse formato.
        padrao = re.compile(r"(?:[A-Z]{3}\d-)?" + re.escape(sufixo))
        return lambda a: padrao.fullmatch(a.get("usagetype", "")) is not None
    return {
        "fargate_vcpu_h": achar("AmazonECS", rc,
                                ut("Fargate-vCPU-Hours:perCPU"),
                                ["hours", "hrs"], "Fargate vCPU-hora", regiao),
        "fargate_gb_h": achar("AmazonECS", rc,
                              ut("Fargate-GB-Hours"),
                              ["hours", "hrs"], "Fargate GB-hora", regiao),
        "alb_h": achar("AWSELB", {**rc, "productFamily": "Load Balancer-Application"},
                       ut("LoadBalancerUsage"), ["hrs", "hours"], "ALB hora", regiao),
        "alb_lcu_h": achar("AWSELB", {**rc, "productFamily": "Load Balancer-Application"},
                           ut("LCUUsage"), ["lcu-hrs"], "ALB LCU-hora", regiao),
        "rds_h": achar("AmazonRDS", {**rc, "productFamily": "Database Instance",
                                     "instanceType": "db.t4g.micro",
                                     "databaseEngine": "PostgreSQL",
                                     "deploymentOption": "Single-AZ"},
                       ut("InstanceUsage:db.t4g.micro"), ["hrs", "hours"], "RDS db.t4g.micro hora", regiao),
        "rds_gp3_gb": achar("AmazonRDS", {**rc, "productFamily": "Database Storage",
                                          "volumeType": "General Purpose-GP3",
                                          "databaseEngine": "PostgreSQL",
                                          "deploymentOption": "Single-AZ"},
                            ut("RDS:GP3-Storage"), ["gb-mo"], "RDS gp3 GB-mês", regiao),
        "ipv4_h": achar("AmazonVPC", rc, ut("PublicIPv4:InUseAddress"),
                        ["hrs", "hours"], "IPv4 público hora", regiao),
        "secret_mes": achar("AWSSecretsManager", rc, ut("AWSSecretsManager-Secrets"),
                            ["secrets", "secret-months", "month"], "Secret mês", regiao),
        "logs_gb": achar("AmazonCloudWatch", rc, ut("DataProcessing-Bytes"),
                         ["gb"], "Logs ingestão GB", regiao),
        "ecr_gb": achar("AmazonECR", rc, ut("TimedStorage-ByteHrs"),
                        ["gb-mo"], "ECR GB-mês", regiao),
    }


def custos(p, com_dashboard):
    vcpu = API_VCPU + (DASH_VCPU if com_dashboard else 0)
    gb = API_GB + (DASH_GB if com_dashboard else 0)
    tarefas = 1 + (1 if com_dashboard else 0)
    ips = tarefas + 2  # IP público por tarefa (sub-rede pública) + ALB em 2 AZs
    return {
        "Fargate (tarefas)": (vcpu * p["fargate_vcpu_h"] + gb * p["fargate_gb_h"]) * HORAS_MES,
        "Application Load Balancer": (p["alb_h"] + ALB_LCU_MEDIO * p["alb_lcu_h"]) * HORAS_MES,
        "IPv4 públicos": ips * p["ipv4_h"] * HORAS_MES,
        "RDS db.t4g.micro": p["rds_h"] * HORAS_MES,
        "RDS armazenamento gp3": RDS_STORAGE_GB * p["rds_gp3_gb"],
        "Secrets Manager": SECRETS * p["secret_mes"],
        "CloudWatch Logs": LOGS_GB_MES * p["logs_gb"],
        "ECR": ECR_GB * p["ecr_gb"],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--com-dashboard", action="store_true",
                    help="inclui a 2ª tarefa Fargate do Streamlit")
    ap.add_argument("--detalhes", action="store_true",
                    help="mostra o usagetype, a unidade e a descrição de cada preço usado")
    a = ap.parse_args()
    tabela = {r: custos(precos(r), a.com_dashboard) for r in REGIOES}
    itens = list(next(iter(tabela.values())).keys())
    print(f"\nEstimativa mensal (USD, sob demanda, {HORAS_MES} h)"
          f" — dashboard no ECS: {'sim' if a.com_dashboard else 'não'}\n")
    print(f"{'Item':<28}" + "".join(f"{r:>14}" for r in REGIOES))
    for i in itens:
        print(f"{i:<28}" + "".join(f"{tabela[r][i]:>14.2f}" for r in REGIOES))
    print(f"{'TOTAL':<28}" + "".join(f"{sum(tabela[r].values()):>14.2f}" for r in REGIOES))
    if a.detalhes:
        print("\nEvidências (preço unitário usado em cada linha):")
        for regiao, nome, usagetype, unidade, preco, desc in EVIDENCIAS:
            print(f"  [{regiao}] {nome}: {preco} USD/{unidade} — {usagetype} — {desc}")
    print("\nFora do total (uso variável): Amplify Hosting (minutos de build, GB servidos),"
          "\ntransferência de dados para a internet, snapshots além do tamanho do banco."
          "\nSem NAT Gateway: as tarefas usam sub-rede pública com IP público e entrada"
          "\nrestrita ao security group do ALB.\n")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit(f"Falha ao chamar a AWS CLI: {e}")
