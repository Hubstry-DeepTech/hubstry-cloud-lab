---
adr: 0001
titulo: Escopo e método do laboratório
data: 2026-09-13
status: aceito
lentes:
  primaria: architecture
  revisado_contra: [finops, security]
---

## Contexto

Competência multicloud é objetivo declarado da Hubstry, primeiro para uso
interno e depois como oferta. Operador solo, crédito com prazo, notebook
de 8 GB inviabilizando trabalho local.

## Decisão

O laboratório não começa construindo plataforma multicloud. Começa
construindo evidência: um experimento por vez, cada um produzindo um
achado verificável por terceiro.

Cinco lentes de revisão, que são funções e não cargos:
architecture, security, finops, operations, interoperability.

Limite de trabalho em progresso: 2.

## Consequências

- Nenhuma trilha nova abre antes do experimento corrente fechar.
- Achado sem custo e tempo medidos é achado incompleto.
- O laboratório é objeto de estudo de si mesmo.
