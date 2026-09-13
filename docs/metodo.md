---
titulo: Método do laboratório
versao: 0.1
status: proposta
referencia: ADR-0003
data: 2026-09-13
---

# Método

Documento operacional referenciado pelo ADR-0003. Define o que cada
experimento registra e sob quais critérios. Muda com mais frequência que o
ADR: a tese é estável, o método evolui a cada experimento.

## Regras de evidência

**Nenhum score antes de método de pontuação.** Campos de score existem
vazios (`null`) até que critérios, pesos e procedimento de medição estejam
definidos e testados.

**Ausência de medição não é zero.** Valores desconhecidos permanecem `null`.
Zero só se registra quando zero foi efetivamente medido ou demonstrado.

**Fato, evidência e interpretação ficam separados.** Todo registro distingue
o que foi observado, qual evidência sustenta a observação e qual conclusão
é derivada dela.

**Evidência de fornecedor não é evidência experimental.** Documentação de
provedor registra-se como afirmação externa a verificar, nunca como
resultado produzido pelo laboratório.

## Contrato do achado

```yaml
experimento: 000
titulo:
data:
nuvens: []
lentes: []
hipotese_anterior_ao_fato: nao      # sim | parcial | nao
verificavel_por_terceiro: nao
custo:
  pago_usd: null
  tabela_usd: null
  recorrente_mensal_usd: null
  estimativa: false
tempo:
  operador_horas: null
  execucao_horas: null
portabilidade:
  observacoes:
  score: null
soberania:
  dados:
  operacao:
  tecnologia:
  score: null
status: rascunho
```

Seções obrigatórias: Hipótese, Método, Resultado, Evidência, Interpretação,
Limitações, Próxima ação.

**`hipotese_anterior_ao_fato`** classifica a natureza do registro:

- `sim` — hipótese operacional formulada antes da execução
- `parcial` — havia pergunta ou expectativa anterior, sem hipótese completa
- `nao` — observação surgida retrospectivamente

`nao` não desqualifica o registro: classifica-o como observação exploratória,
não como teste confirmatório. Descoberta inesperada é resultado legítimo.

**`verificavel_por_terceiro`** só pode ser `sim` quando o Método contiver
comandos, versões, parâmetros, pré-condições e evidências suficientes para
que outra pessoa reproduza o procedimento e compare o resultado. Sem isso é
`nao`, e o campo não é carimbo.

## Eixo 1 — Portabilidade

Custo real de saída, medido:

- linhas de configuração ou código alteradas, separando as de autenticação
- componentes substituídos
- segredos e credenciais recriados
- dados movimentados: volume, tempo, custo de egress
- APIs proprietárias utilizadas
- tempo de reconstrução do zero
- dependências que impedem a saída

## Eixo 2 — Soberania

Três dimensões, conforme o modelo da Gartner, tratado como referencial de
análise e não como certificação:

- **Dados** — localização, processamento, jurisdição aplicável, controle de
  chaves criptográficas
- **Operação** — quem opera, acesso privilegiado, suporte, capacidade de
  operar sem o fornecedor
- **Tecnologia** — dependência de componentes proprietários, padrões
  abertos, substituibilidade

**Referências externas a interrogar, não adotadas.** O Serpro publica
metodologia de avaliação em gradiente, com 15 critérios e ponderação de 30%
dados, 40% operação e 30% tecnologia, além de um Teste de Desconexão. A
ponderação é hipótese metodológica externa. O Teste de Desconexão é
candidato a experimento executável — verificar a formulação original antes
de aplicar.

## Eixo 3 — Segurança

- identidade e controle de acesso
- gestão e tempo de vida de credenciais
- superfície de exposição
- criptografia em trânsito e em repouso
- logs e trilha de auditoria
- segregação de ambientes
- recuperação testada
- configuração insegura introduzida pela portabilidade

O último item é o mais fácil de esquecer e o mais relevante: tornar algo
portátil frequentemente significa afrouxar um controle.

## Eixo 4 — FinOps

Três custos, sempre separados:

1. **Pago** — o que saiu do bolso, incluindo crédito consumido
2. **Tabela** — o mesmo consumo a preço público, sem desconto nem crédito
3. **Recorrente** — o que o cliente pagaria por mês após o fim de créditos

Registrar também recursos provisionados, tempo de execução e custo de saída
ou migração. Marcar `estimativa: true` quando o valor for derivado de tabela
de preços em vez de fatura.

Crédito de provedor não é custo zero. Arquitetura avaliada só pelo custo
pago é arquitetura de vitrine.

## Eixo 5 — Interoperabilidade

Camadas avaliadas separadamente. Compatibilidade numa não implica
portabilidade nas outras:

- **Protocolo** — o padrão de comunicação é comum?
- **API** — a interface é compatível, e onde a compatibilidade quebra?
- **Identidade** — autenticação e autorização são portáveis?
- **Dados** — formato, esquema e volume permitem movimentação?
- **Operação** — runtime, orquestração e deploy são substituíveis?
- **Observabilidade** — métricas e logs são exportáveis?
- **Infraestrutura** — o provisionamento é reproduzível fora do provedor?

A existência de um protocolo comum não é prova de portabilidade. É o eixo
mais sujeito a conclusão apressada.

## Hora de operador

Registrada em todo experimento, separando trabalho não recorrente
(aprendizado que não se repete) de recorrente (imposto permanente de
coordenação). A distinção só produz sentido depois de vários experimentos;
até lá, registra-se sem interpretar.

Hora de operador é hipótese de métrica central, não métrica declarada.

## Revisão de fonte

Antes de commitar qualquer artefato que afirme fato externo — dado de
mercado, característica de edital, formulação de terceiro — verificar em
fonte primária. Resumo de imprensa e comentário de terceiro registram-se
como tal, com a distinção visível no texto.

Esta regra foi introduzida após uma revisão cruzada identificar uma
afirmação factual externa sem verificação suficiente em uma versão anterior
do ADR-0003.
