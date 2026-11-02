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
  # Custo desta entrega, não da conta. No AWS Budgets, monitorar e notificar
  # é gratuito, e os dois primeiros orçamentos com ação também (aqui há um);
  # Cost Anomaly Detection e IAM não cobram.
  pago_usd: 0
  tabela_usd: 0
  recorrente_mensal_usd: null
  estimativa: false
tempo:
  operador_horas: null
links:
  prs: []
  deploy: plataforma/aws/scripts/orcamentos.sh
  revisao_luna: "PR #1, três rodadas"
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

Depois da segunda auditoria da Luna, o script passou a conferir cada recurso
existente contra a configuração esperada (limite, `IncludeCredit`, avisos,
serviços filtrados, documento da política, confiança do papel, definição da
ação, usuário-alvo e limiar das anomalias). Na terceira auditoria, a
conferência passou a cobrir também destinatários, operador e tipo de
limiar de cada aviso, destinatários da ação de freio, a política de
confiança completa do papel e permissões além da esperada (políticas
anexadas, inline e limite de permissões). Divergência e falha nos comandos
de conferência do resumo contam como erro, e o script sai com código 1. A
verificação foi testada com um `aws` simulado nos cenários correto e
divergente, e também com destinatário trocado, política inline extra e
confiança ampliada.

**Execução real da versão conferente** (CloudShell, usuário `admin-solo`,
02/11/2026, commit `dc5ad45`). A primeira execução, no commit `e651289`,
acusou duas divergências nos avisos: a API omite `ThresholdType` quando é
o padrão (`PERCENTAGE`), e o `aws` simulado incluía o campo. Era defeito do
script, não da conta; corrigido, a segunda execução passou inteira:

```text
ok: mensal-total limite = 150 | IncludeCredit = False
ok: mensal-total avisos = ACTUAL>100%, ACTUAL>50%, FORECASTED>100%, todos EMAIL:guilhermemachado.ceo@hubstry.dev
ok: quantico-gpu limite = 60 | IncludeCredit = False | serviços = Amazon Braket, Amazon Elastic Compute Cloud - Compute
ok: quantico-gpu avisos = ACTUAL>80%, EMAIL:guilhermemachado.ceo@hubstry.dev
ok: documento da política de freio (v1) idêntico ao esperado
ok: papel: confiança completa só budgets.amazonaws.com; só a política gerenciada do Budgets; sem inline; sem limite de permissões
ok: ação = APPLY_IAM_POLICY | AUTOMATIC | 100 | PERCENTAGE | hubstry-freio-quantico-gpu | admin-solo | hubstry-budgets-actions; destinatário EMAIL:guilhermemachado.ceo@hubstry.dev; status STANDBY
ok: usuário admin-solo existe
ok: anomalias = DAILY | monitor 44333b9b | EMAIL:guilhermemachado.ceo@hubstry.dev | ANOMALY_TOTAL_IMPACT_ABSOLUTE >= 20
AVISO: orçamento que desconta créditos e por isso não alerta: hubstry-guarda-credito
== Todos os guardrails existem e conferem com a configuração esperada.
```

Na mesma sessão, `get-account-summary` devolveu `AccountMFAEnabled = 1` e
`AccountAccessKeysPresent = 0`: root com MFA e sem chaves de acesso.

**Limite reconhecido:** orçamento e freio não são teto rígido de gasto. O Budgets atualiza o custo com atraso de horas, e o freio só bloqueia novas tarefas do Braket e novas instâncias de GPU; recursos já ligados continuam cobrando até serem desligados.

## Medição

**Fato.** O orçamento preexistente `hubstry-guarda-credito` (US$ 50) tem
`IncludeCredit = True`.

**Interpretação.** Enquanto houver crédito, o gasto líquido medido por ele
fica perto de zero, e o alerta não dispara.

**Fato.** Gasto bruto da conta entre setembro e novembro de 2026: US$ 0,36,
todo em Amazon Bedrock, em setembro.

**Relação entre os dois números.** O custo zero do cabeçalho é o desta
entrega: no AWS Budgets, monitorar e notificar é gratuito, e os dois
primeiros orçamentos com ação também (só o `hubstry-quantico-gpu` tem
ação); Cost Anomaly Detection e IAM não cobram. Os US$ 0,36 são gasto anterior da conta, sem relação com os
guardrails, e servem como linha de base. As revisões via Bedrock feitas em
02/11/2026 (Llama 4 Maverick e DeepSeek R1) entram no custo do Nautam, não
desta entrega.

## Decisão

Persistir. Pendências:

1. `hubstry-guarda-credito` apagado pelo Guilherme em 02/11/2026
   (`aws budgets delete-budget`, executado como `admin-solo`), por ser
   ineficaz: descontava créditos e nunca alertaria;
2. acesso diário: resolvido pela entrega 0002 em 02/11/2026. O trabalho
   diário passa ao `admin-solo`, com MFA, e o freio apontado a ele fica
   efetivo. O root, que o freio não alcança, fica reservado.

## Próxima entrega

Fundação compartilhada da plataforma (`plataforma/aws/README.md`, etapa 2),
com o Nautam IoT Protocol como primeiro inquilino.
