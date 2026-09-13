---
adr: 0002
titulo: Identidade de rastreamento do trabalho
data: 2026-09-13
status: aceito
lentes:
  primaria: operations
  revisado_contra: [architecture]
---

## Contexto

O identificador de trabalho aparece em commits, branches, PRs e ADRs.
Trocá-lo depois quebra retroativamente todos os links já escritos.

## Decisão

Prefixo HML para o laboratório, separado do HUB usado no restante do
ecossistema. Gestão no GitHub Projects; Confluence entra só quando
houver material de publicação.

## Consequências

- Decisão barata agora, cara de reverter depois.
- Fronteira clara entre laboratório e ecossistema no board.
