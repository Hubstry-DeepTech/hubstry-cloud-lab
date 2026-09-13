# Hubstry Cloud Lab

Laboratório de competência operacional multicloud. Um mesmo workload
implementado em múltiplos provedores, com registro das diferenças de
arquitetura, identidade, rede, storage, observabilidade e custo.

## Método

Um experimento por vez. Cada experimento produz um achado em `achados/`,
verificável por terceiro, com custo e tempo medidos. Decisões estruturais
viram ADR em `docs/adr/`. Limite de trabalho em progresso: 2.

## Estado

| Nuvem | Nível | Notas |
|---|---|---|
| GCP | L1 | dev box `hubstry-vm-001`, OS Login + IAP |
| AWS | L0 | conta segura, budget, Identity Center |
| OCI | L0 | VCN criada; A1.Flex sem capacidade em São Paulo |

L0 reconhecimento · L1 compute · L2 plataforma · L3 portabilidade · L4 multicloud · L5 comercial
