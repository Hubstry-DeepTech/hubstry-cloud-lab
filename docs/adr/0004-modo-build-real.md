---
adr: 0004
titulo: Modo build real — o laboratório opera o portfólio em produção
data: 2026-11-02
status: proposto
substitui: [0001]
mantem: [0002, 0003]
lentes:
  primaria: operations
  revisado_contra: [architecture, finops, security]
---

## Contexto

O ADR-0001 definiu o laboratório como produção de evidência, um experimento
por vez, com limite global de dois trabalhos em progresso, e decidiu não
começar construindo plataforma.

Essa premissa não corresponde à operação da Hubstry. O portfólio tem vários
produtos de base tecnológica que precisam de infraestrutura real ao mesmo
tempo: Nautam IoT Protocol, GuruDev e Alexandria, Hubstry Security, X-Layer
e HexaSign. O operador é solo, e o tempo disponível não comporta experimentos
que não resultem em entrega utilizável.

Há também uma janela concreta de recursos. A conta AWS tem cerca de
US$ 5.000 em créditos AWS Activate, com vencimentos em agosto de 2027 e
setembro de 2028.

## Decisão

O laboratório passa a operar em modo de construção real, no padrão de
startup enxuta. Cada ciclo testa uma hipótese de produto por meio de uma
entrega em produção, e não por meio de um experimento isolado.

1. **A unidade de trabalho é a entrega.** Cada entrega tem hipótese de
   produto, métrica de sucesso, prazo curto, deploy real e decisão final:
   persistir, pivotar ou cortar.
2. **O limite de trabalho em progresso passa a ser por projeto.** Cada
   projeto mantém no máximo uma entrega ativa. O limite global de dois deixa
   de valer.
3. **A plataforma é construída e compartilhada.** Rede, balanceador, banco,
   identidade, segredos, observabilidade e guardrails de custo são comuns aos
   projetos. A especificação fica em `plataforma/aws/`.
4. **A AWS é a nuvem de produção do portfólio** enquanto houver crédito. A GCP
   permanece para pesquisa e produtos que já operam nela. Nenhum produto roda
   em duplicidade de produção em dois provedores.
5. **A governança de revisão continua.** O Claude planeja e implementa, a Luna
   audita de forma independente, e o Guilherme decide merges e criação de
   infraestrutura.

## O que se mantém do método

As regras de evidência de custo baixo continuam valendo, porque protegem o
caixa sem atrasar a entrega:

- os três custos separados: pago, tabela e recorrente;
- ausência de medição registrada como `null`, nunca como zero;
- fato, evidência e interpretação separados no registro;
- documentação de fornecedor tratada como afirmação a verificar.

A tese multicloud do ADR-0003 continua como horizonte de longo prazo. Ela
deixa de bloquear entregas: portabilidade e soberania passam a ser
registradas quando uma entrega as afetar, e não como pré-condição.

## Consequências

- O registro de entrega substitui o achado como documento principal
  (`entregas/`). Os achados existentes permanecem como histórico.
- Toda entrega nasce com orçamento de custo e alarme. Recursos caros
  (GPU, hardware quântico) só são ligados por decisão explícita e ficam sob
  freio automático de orçamento.
- Cortar uma entrega é resultado legítimo e deve ser registrado com o motivo.
- A velocidade aumenta, e com ela o risco de dívida técnica. O risco é
  mitigado pela revisão independente em cada PR e pela regra de que nada vai
  para produção sem CI verde.

## Alternativas descartadas

**Manter o ADR-0001.** Produziria evidência metodológica, mas sem os
produtos de que a empresa precisa no prazo dos créditos.

**Repositório separado para a plataforma.** Foi considerado. Descartado
porque o laboratório e a plataforma passam a ser a mesma operação; separar
criaria dois lugares para a mesma decisão.
