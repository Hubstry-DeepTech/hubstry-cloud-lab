---
entrega: 0001
titulo: Guardrails de custo da conta AWS
projeto: plataforma
nuvem: aws
status: entregue
inicio: 2026-11-02
prazo: 2026-11-02
hipotese_de_produto: >
  É possível operar vários produtos na mesma conta AWS com créditos sem
  risco de consumo descontrolado, sem travar o desenvolvimento e sem ajuste
  manual frequente de limites.
metrica_de_sucesso: >
  Alertas de custo bruto ativos; freio automático armado para os serviços
  de consumo rápido; nenhum alerta silenciado pelos créditos.
resultado_da_metrica: atingida
decisao: persistir
custo:
  pago_usd: 0
  tabela_usd: 0
  recorrente_mensal_usd: null
  estimativa: false
tempo:
  operador_horas: null
links:
  prs: []
  deploy: plataforma/aws/scripts/orcamentos.sh
  revisao_luna: null
---

## Hipótese

Créditos fazem o custo líquido aparecer como zero. Um orçamento que desconta
créditos nunca alerta, então a conta fica sem proteção real até os créditos
acabarem.

## Entrega

Executado no AWS CloudShell em 02/11/2026, com o script
`plataforma/aws/scripts/orcamentos.sh`:

| Item | Configuração | Estado |
|---|---|---|
| `hubstry-mensal-total` | US$ 150/mês, custo bruto; e-mail em 50% e 100% do real e em 100% da previsão | ativo |
| `hubstry-quantico-gpu` | US$ 60/mês, Braket + EC2; e-mail em 80% | ativo |
| Freio `hubstry-freio-quantico-gpu` | Nega `braket:CreateQuantumTask`, `braket:CreateJob` e instâncias EC2 `g*`, `p*`, `inf*`, `trn*`, `dl*` | aplicado automaticamente em 100% do orçamento quântico/GPU ao usuário `admin-solo`; status `STANDBY` |
| Alerta de anomalias | Diário, impacto ≥ US$ 20, no monitor por serviço existente | ativo; a primeira tentativa falhou porque a conta já tinha um monitor por serviço, e a assinatura foi ligada a ele |

## Evidência da configuração efetiva

Saída do resumo do script em 02/11/2026 (CloudShell, `sa-east-1`):

```text
|  hubstry-guarda-credito |  50.0  |  True   |
|  hubstry-mensal-total   |  150.0 |  False  |
|  hubstry-quantico-gpu   |  60.0  |  False  |
|  b24e09df-ebb6-471e-b309-0429c5098b3b |  STANDBY |  AUTOMATIC  |
```

A terceira coluna dos orçamentos é `IncludeCredit`. A última linha é a ação de freio: em espera, com aprovação automática. O alerta de anomalias foi confirmado pela mensagem "alerta de anomalias criado".

**Limite reconhecido:** orçamento e freio não são teto rígido de gasto. O Budgets atualiza o custo com atraso de horas, e o freio só bloqueia novas tarefas do Braket e novas instâncias de GPU; recursos já ligados continuam cobrando até serem desligados.

## Medição

**Fato.** O orçamento preexistente `hubstry-guarda-credito` (US$ 50) tem
`IncludeCredit = True`.

**Interpretação.** Enquanto houver crédito, o gasto líquido medido por ele
fica perto de zero, e o alerta não dispara.

**Fato.** Gasto bruto da conta entre setembro e novembro de 2026: US$ 0,36,
todo em Amazon Bedrock, em setembro.

## Decisão

Persistir. Pendências:

1. apagar o `hubstry-guarda-credito`, que é ineficaz e conta como terceiro
   orçamento (decisão do Guilherme);
2. aplicar o freio também ao papel do Identity Center quando o trabalho
   diário migrar para ele, já que o freio não alcança o root.

## Próxima entrega

Fundação compartilhada da plataforma (`plataforma/aws/README.md`, etapa 2),
com o Nautam IoT Protocol como primeiro inquilino.
