---
entrega: 0002
titulo: Acesso diário sem root (admin-solo com MFA)
projeto: plataforma
nuvem: aws
status: entregue
inicio: 2026-11-02
prazo: 2026-11-02
hipotese_de_produto: >
  Um fundador solo consegue operar a conta AWS no dia a dia sem usar o
  root, com um único login protegido por MFA, sem atrito recorrente.
metrica_de_sucesso: >
  Login do admin-solo com senha e MFA funcionando; root com MFA e sem
  chaves de acesso; freio quântico/GPU apontado para a identidade usada
  no dia a dia.
resultado_da_metrica: atingida
decisao: persistir
custo:
  pago_usd: 0
  tabela_usd: 0
  recorrente_mensal_usd: 0
  estimativa: false
tempo:
  operador_horas: null
links:
  prs: []
  deploy: null
  revisao_luna: "PR #1, terceira rodada: entrega considerada concluída"
---

## Hipótese

O freio automático de Braket e GPU só age sobre usuários IAM; o root não
pode ser restringido por política. Enquanto o root for a identidade de
uso diário, o freio é decorativo.

## Entrega

Feito pelo Guilherme em 02/11/2026, nesta ordem:

1. Chaves de acesso do `alexandria-deploy-user` desativadas (sem uso desde
   agosto de 2025; nenhum repositório da Alexandria faz deploy com elas).
2. `AdministratorAccess` anexada ao `admin-solo`.
3. MFA ativado no root (aplicativo autenticador).
4. Primeira tentativa de login do `admin-solo` falhou: a senha de console
   existia, mas ninguém a conhecia. A senha antiga foi removida
   (`delete-login-profile`) e uma nova foi criada pelo Guilherme no
   console, sem troca obrigatória no primeiro login.
5. Conferência prévia: alias `hubstry-deeptech`, política de senha padrão
   da AWS, `AdministratorAccess` anexada, sem limite de permissões, sem
   AWS Organizations (nenhuma SCP).
6. Login testado em janela anônima pela URL
   `https://hubstry-deeptech.signin.aws.amazon.com/console`.
7. MFA do `admin-solo`: primeiro por passkey, depois trocado por
   aplicativo autenticador (TOTP), igual ao root, a pedido do Guilherme.

## Medição

Evidência a anexar (CloudShell, logado como `admin-solo`):

```text
(saída pendente)
```

**Fato já registrado** na entrega 0001: `AccountMFAEnabled = 1` e
`AccountAccessKeysPresent = 0` (root com MFA e sem chaves de acesso).

## Decisão

Persistir. O `admin-solo` é a identidade diária e o alvo do freio
quântico/GPU. O root fica reservado a faturamento, créditos e tarefas que
só ele pode fazer. Identity Center continua fora de escopo: exige AWS
Organizations e entra com a separação por contas (gatilho "primeiro
cliente em produção").

**Lição para o modo build real:** antes de orientar um login, verificar o
estado real da identidade (senha existe e é conhecida, MFA, limite de
permissões, alias). A primeira tentativa falhou por falta dessa conferência.
