# Hubstry Cloud Lab

Operação de nuvem da Hubstry em modo de construção real. O laboratório coloca os produtos do portfólio em produção, mede custo e resultado de cada entrega e decide o que persiste, pivota ou é cortado.

## Método

Cada ciclo é uma entrega real, com hipótese de produto, métrica de sucesso, prazo curto, deploy e decisão. O registro fica em `entregas/`. Decisões estruturais viram ADR em `docs/adr/`. Cada projeto mantém no máximo uma entrega ativa. O método completo está no ADR-0004 e em `docs/metodo.md`.

Regras que continuam valendo:

- custo registrado em três formas: pago, tabela e recorrente;
- valor não medido é `null`, nunca zero;
- fato, evidência e interpretação ficam separados.

## Plataforma AWS

A AWS é a nuvem de produção do portfólio enquanto houver crédito. A especificação da plataforma compartilhada está em `plataforma/aws/`, e os scripts operacionais em `plataforma/aws/scripts/`.

## Estado

| Nuvem | Nível | Notas |
|---|---|---|
| AWS | L1 → L2 | guardrails de custo entregues (entrega 0001); plataforma compartilhada em especificação |
| GCP | L1 | dev box `hubstry-vm-001`, OS Login + IAP; pesquisa e produtos já operando nela |
| OCI | L0 | VCN criada; A1.Flex sem capacidade em São Paulo |

L0 reconhecimento · L1 compute · L2 plataforma · L3 portabilidade · L4 multicloud · L5 comercial

## Entregas

| # | Entrega | Projeto | Status |
|---|---|---|---|
| 0001 | Guardrails de custo da conta AWS | plataforma | entregue |

## Histórico

Até novembro de 2026, o laboratório operava como produção de evidência, com um experimento por vez (ADR-0001, agora substituído). Os achados desse período continuam em `achados/`.
