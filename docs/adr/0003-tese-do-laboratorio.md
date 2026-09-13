---
adr: 0003
titulo: Tese do laboratório — arquitetura multicloud sobre oferta abundante
data: 2026-09-13
status: proposta
lentes:
  primaria: architecture
  revisado_contra: [security, finops, interoperability]
---

## Contexto

A oferta global de nuvem — norte-americana, chinesa, brasileira, europeia —
opera em forte competição, com programas de crédito, trials e tiers
gratuitos disputando adoção. A prática dominante de arquitetura ainda assume
um provedor por vez.

Três sinais tornam a questão relevante agora:

1. Os próprios provedores constroem integrações explícitas entre si,
   reduzindo a validade de uma separação rígida entre ecossistemas.
2. Organizações públicas brasileiras tratam soberania digital como controle
   sobre dados, operação, tecnologia e jurisdição — não como localização
   física dos dados.
3. A iniciativa Nuvem Brasileira, conduzida por MGI, ABDI, Serpro e BNDES,
   explicita a busca por maior soberania sobre computação em nuvem.

## Decisão

O laboratório existe para construir e validar uma prática profissional de
arquitetura e engenharia multicloud operando deliberadamente sobre oferta
abundante.

Não parte da premissa de que multicloud seja superior. Seu objetivo é
produzir evidência experimental sobre os trade-offs entre portabilidade,
soberania, segurança, custo e complexidade operacional.

O produto é uma metodologia verificável de avaliação arquitetural, destinada
a sustentar oferta B2B e B2G de arquitetura, engenharia, DevOps, governança,
segurança, FinOps e avaliação de portabilidade e soberania.

Os cinco eixos de avaliação e o contrato de registro estão em `docs/metodo.md`.

## Hipótese principal

A possibilidade de escolha entre provedores constitui capacidade
arquitetural mensurável, desde que o custo de coordenação, portabilidade e
governança não supere o valor obtido.

## Critério de falsificação

A tese é enfraquecida ou refutada se experimentos repetidos demonstrarem que:

1. a portabilidade medida exige esforço desproporcional;
2. os custos de coordenação superam os benefícios obtidos;
3. as integrações necessárias introduzem dependências proprietárias maiores
   que as eliminadas;
4. os ganhos de soberania não compensam a complexidade adicional;
5. a arquitetura resultante é mais difícil de operar, proteger ou recuperar;
6. single-cloud com plano de saída documentado produz resultado
   consistentemente superior para o workload analisado.

Qualquer desses resultados é achado válido do laboratório.

## Consequências

**Crédito não é custo zero.** Todo experimento registra custo pago, custo a
preço de tabela, e custo recorrente após o fim de créditos. Sem isso o
laboratório produz arquitetura que o cliente não sustenta.

**Hora de operador é hipótese, não métrica primária.** Registrada desde o
início; sua centralidade só se declara quando houver evidência.

**Nenhum score antes de método de pontuação.** Campos de score existem
vazios (`null`) até que critérios, pesos e método estejam definidos.

**Integrações nativas entre provedores** (Interconnect, Database@) são
objeto de estudo e evidência de tendência, não componente do pipeline. A
integração praticável ocorre nas camadas de API e identidade.

**Referência externa a interrogar.** O Serpro publica metodologia de
avaliação de soberania em gradiente, com três dimensões, 15 critérios,
ponderação de 30% dados / 40% operação / 30% tecnologia, e um Teste de
Desconexão. O laboratório trata essa ponderação como hipótese metodológica
externa, não como peso adotado. O Teste de Desconexão é candidato a
experimento executável.

**Referência conceitual.** O modelo de soberania digital da Gartner
distingue soberania de dados, operacional e tecnológica. Usado como
referencial de análise, não como certificação.

**B2G.** A hipótese comercial é atuar nas camadas de avaliação, arquitetura,
interoperabilidade e governança — não como provedor de infraestrutura
soberana. Forma jurídica de participação em iniciativa governamental será
analisada quando houver oportunidade concreta.

**Pluralidade de créditos não prova independência.** Independência se avalia
pela capacidade efetiva de reconstruir, substituir, migrar, operar, auditar
e interromper sem dependência desproporcional de um fornecedor.

**multicloud-native** não é tratado aqui como termo definido. Produzir
definição operacional baseada em propriedades verificáveis é artefato
pendente do laboratório.

## Alternativas consideradas

**Single-cloud** não é descartada. Pode ser a decisão correta quando o custo
de coordenação é elevado, as dependências proprietárias são aceitáveis, os
requisitos de soberania são atendidos e existe estratégia documentada de
saída.

**Multicloud para redundância** não é justificativa primária. Redundância
entre provedores exige replicação, consistência, health check, roteamento,
failover e teste de recuperação — cada um um projeto. Resiliência multicloud
é resultado possível de maturidade, não premissa de desenho.

## Status

Proposta. A aceitação significará apenas que a tese está suficientemente
definida para ser testada — não que esteja comprovada.
