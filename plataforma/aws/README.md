# Plataforma Hubstry na AWS

Versão 3.1, de 02/11/2026. Status: direção aprovada pela Luna; ajustes da segunda auditoria incorporados. Referência: ADR-0004.

Nenhum recurso desta especificação foi criado além dos guardrails de custo da entrega 0001.

## 1. Objetivo

Oferecer uma base compartilhada para colocar em produção os produtos do portfólio da Hubstry com o menor custo fixo possível. A base cobre rede, entrada HTTP, execução, dados, identidade, segredos, observabilidade e guardrails de custo. Cada produto é um inquilino da plataforma. O repositório de cada produto guarda só o que é dele, como o Dockerfile e o workflow de deploy.

## 2. Restrições de partida

| Restrição | Valor |
|---|---|
| Conta | `000185047928` (alias `hubstry-deeptech`) |
| Créditos | US$ 999,44 até 31/08/2027 e US$ 4.000 até 30/09/2028 (AWS Activate) |
| Região principal | `sa-east-1` (São Paulo) |
| Região secundária | `us-east-1`, só para o Amazon Braket, que não existe em São Paulo |
| Operação | Fundador solo; revisão independente pela Luna; decisão do Guilherme |
| Estado atual da conta | Sem AWS Organizations nem Identity Center (verificado em todas as regiões em 02/11/2026). Usuários IAM: `admin-solo` (com `AdministratorAccess`, senha de console nova e MFA por passkey desde 02/11/2026; sem chaves de acesso; é o acesso diário) e `alexandria-deploy-user` (duas chaves de acesso **desativadas** pelo Guilherme em 02/11/2026; estavam sem uso desde agosto de 2025, e nenhum repositório da Alexandria faz deploy com elas). O root, com MFA, fica reservado para tarefas que só ele pode fazer. Sem computação ativa. Há 9 buckets S3, 4 distribuições CloudFront e 2 apps Amplify em `us-east-2`, ligados às Alexandrias e a sites |

A escolha de `sa-east-1` tem três fundamentos. A latência é menor para o público brasileiro. Os dados ficam no país. E o X-Layer lê o bucket público do ONS (Operador Nacional do Sistema Elétrico), `ons-aws-prod-opendata`, que está em `sa-east-1`, o que evita transferência entre regiões.

## 3. Inquilinos e o que cada um exige

| Produto | Repositório | Proposta de produto | Exigência de infraestrutura |
|---|---|---|---|
| Nautam IoT Protocol | `guilherme-machado-ceo/iot-protocol-hubstry` | Protocolo IoT com API, dashboard e demo; depois, dispositivos reais | API em contêiner, PostgreSQL, frontend; futuramente AWS IoT Core |
| GuruDev e Alexandria | `Hubstry-DeepTech/gurudev-core` | Runtime Cloud cobrado por uso, Studio (IDE por assinatura), Sandbox Compute por tempo, OntoAPI, marketplace e despacho quântico | Execução isolada de código de terceiros, API com medição de uso, identidade de usuários, armazenamento de pacotes, Braket |
| Hubstry Security | `guilherme-machado-ceo/hubstry-security` | Plataforma de prontidão pós-quântica: Compliance Engine, Threat Intel Dashboard, benchmarks HSL contra TLS 1.3, ML-KEM e ML-DSA, trilha quântica com CUDA-Q | SaaS com isolamento por cliente, ingestão agendada, laboratório de benchmark em EC2, KMS, CloudTrail, GPU sob demanda, Braket |
| X-Layer | `Hubstry-DeepTech/hubstry-xlayer-engine` | Inteligência decisória para excedente de geração (*curtailment*) no SIN, com decisão humana | Data lake sobre os dados do ONS, pipelines agendados, otimização (QUBO), API e painel de decisão auditável |
| HexaSign | `guilherme-machado-ceo/hubstry-hexasign-lab` | Instrumentalização de analogias (refatoração em andamento) | Definir após a refatoração |

## 4. Camadas compartilhadas

| Camada | Serviços | Inquilinos | Custo quando ocioso |
|---|---|---|---|
| Rede | Uma VPC (Virtual Private Cloud, rede privada virtual) com sub-redes públicas e privadas em duas zonas; sem NAT Gateway no início | Todos | Zero |
| Entrada HTTP | Um ALB (Application Load Balancer) compartilhado pelos serviços do ECS Express Mode, que admite até 25 serviços por VPC | Nautam, GuruDev, Security, X-Layer | Fixo, cerca de US$ 29/mês |
| Execução contínua | ECS Fargate, só para APIs que precisam ficar no ar | Nautam e, quando houver usuários, GuruDev e Security | Por tarefa ligada |
| Execução efêmera | Tarefas ECS avulsas, Lambda e EC2 temporária para benchmark | GuruDev (Runtime e Sandbox), Security (benchmarks), X-Layer (pipelines) | Zero |
| API pública e medição | Amazon API Gateway com planos de uso e chaves | GuruDev (OntoAPI e Runtime), Security | Zero; cobrança por chamada |
| Identidade de usuários | Amazon Cognito | GuruDev Studio, Security, X-Layer | Zero na faixa gratuita |
| Banco relacional | Um RDS PostgreSQL, com um banco e um usuário por inquilino | Nautam, Security, X-Layer | Fixo, cerca de US$ 29/mês |
| Data lake | S3 em parquet, catálogo no Glue e consulta pelo Athena | X-Layer, Security (ameaças), Alexandria | Só armazenamento |
| Gateway quântico | Amazon Braket em `us-east-1`; GPU sob demanda | GuruDev, Security, X-Layer (variantes QAOA) | Zero; freio automático de orçamento |
| Segredos e chaves | Secrets Manager e KMS (com chaves ML-DSA para o Security) | Todos | Por segredo e por chave |
| Observabilidade | CloudWatch Logs com retenção de 14 dias; CloudTrail | Todos | Baixo |
| Imagens | ECR, com política de manter as 10 imagens mais recentes | Todos | Baixo |
| Custo | Budgets com custo bruto, freio quântico/GPU, alerta de anomalias, tags `projeto` | Todos | Entregue (entrega 0001) |

Princípio de custo: tudo o que não precisa ficar ligado roda sob demanda. GPU e hardware quântico só ligam por decisão explícita e ficam sob o freio de orçamento.

## 5. Convenções

- **Tags obrigatórias** em todo recurso: `projeto` (nautam, gurudev, security, xlayer, hexasign, plataforma), `ambiente` e `responsavel`. O Cost Explorer usa a tag `projeto` para separar o custo por inquilino.
- **Nomes:** `hubstry-<camada>` para recursos compartilhados e `<projeto>-<recurso>` para recursos de inquilino.
- **Segredos:** `/<projeto>/<ambiente>/<nome>` no Secrets Manager.
- **Banco:** um banco por projeto no mesmo RDS, com usuário próprio e sem acesso aos demais.
- **Deploy:** cada repositório de produto assume, por OIDC (OpenID Connect), um papel IAM restrito ao próprio projeto, condicionado ao repositório e ao Environment `production`.

## 6. Ordem de implantação

| Etapa | Entrega | Critério de avanço |
|---|---|---|
| 0001 | Guardrails de custo | Entregue |
| 0002 | Acesso diário sem root: usuário `admin-solo` com `AdministratorAccess` e MFA | **Entregue em 02/11/2026.** Chaves da Alexandria desativadas; senha antiga e desconhecida do `admin-solo` removida e substituída por uma nova, criada pelo Guilherme; login testado em janela anônima; MFA por passkey no `admin-solo` e no root |
| 0003 | Fundação: VPC, ALB, cluster ECS, ECR, provedor OIDC, convenções de tags | Auditoria da Luna; custo fixo medido |
| 0004 | RDS compartilhado com banco do Nautam e snapshot automatizado | Banco privado, backup ativo |
| 0005 | Nautam em produção: API no ECS, frontend no Amplify | CI verde, testes de saúde e de persistência |
| 0006 | X-Layer: data lake e pipeline agendado do motor Observation | Reprocessamento de um mês do ONS com custo medido |
| 0007 | GuruDev: Runtime efêmero e isolado com API medida | Execução de script de terceiro sem acesso à rede interna |
| 0008 | Security: laboratório de benchmark HSL × TLS 1.3 em EC2 efêmera | Relatório reprodutível com custo por execução |
| 0009 | Gateway quântico: Braket com freio e simulador local como padrão | Uma tarefa real dentro do orçamento |

Cada etapa é uma entrega no sentido do ADR-0004: hipótese, métrica, deploy real e decisão de persistir, pivotar ou cortar. A ordem pode mudar conforme as decisões de produto.

## 7. Custo

O **subtotal** fixo da base fica em torno de US$ 60 por mês em `sa-east-1`, somando balanceador, RDS, armazenamento, ECR e logs. Não é o custo total de propriedade: ainda faltam backups além da cota gratuita, tráfego de saída e, quando os gatilhos da seção 9 dispararem, VPC endpoints e o isolamento do runtime. Cada serviço contínuo acrescenta cerca de US$ 19 por mês (0,25 vCPU, 0,5 GB e IP público). O restante é por uso: execuções efêmeras, chamadas de API, consultas no Athena, horas de GPU e tarefas do Braket.

Os valores vêm de `scripts/estimar_custos.py`, que consulta a AWS Price List API e falha quando um preço é ambíguo. A execução de 02/11/2026 deu US$ 86,36 por mês para o Nautam sozinho em `sa-east-1` (US$ 54,79 em `us-east-1`). O estimador ainda precisa ser estendido para o cenário multiprojeto.

## 8. Riscos

| Risco | Mitigação |
|---|---|
| Execução de código de terceiros (GuruDev Runtime) atingir recursos internos | Tarefas efêmeras sem rota para a VPC interna, sem papel IAM com acesso a dados, com limite de tempo e de memória |
| Consumo rápido de crédito em GPU ou Braket | Freio automático de orçamento; simulador local como padrão |
| Inquilino afetar outro no RDS compartilhado | Usuário por banco, limites de conexão por usuário, monitoramento de CPU e conexões |
| Root em uso diário | Resolvido pela entrega 0002: o acesso diário é o `admin-solo`, com MFA, e o freio quântico/GPU passa a agir sobre ele. O root, com MFA, fica para faturamento e tarefas exclusivas. O Identity Center exige AWS Organizations e entra junto com a separação por contas (seção 9) |
| Dependência de serviços proprietários | Registrar na entrega quando houver; a tese multicloud do ADR-0003 continua como horizonte |

## 9. Estado atual e gatilhos de evolução

**Estado em 02/11/2026:** nenhum produto do portfólio tem clientes, dados de clientes ou usuários externos executando código. A prospecção está em andamento. A plataforma é desenhada para esse estado real, e cada proteção mais cara entra quando o fato que a justifica acontecer, e não antes. As revisões cegas via Bedrock (Llama 4 Maverick e DeepSeek R1) e a auditoria da Luna levantaram os pontos abaixo.

| Tema | Decisão agora | Gatilho para evoluir | Evolução |
|---|---|---|---|
| Autenticação das APIs | **Obrigatória desde o primeiro deploy público.** Chaves de API aleatórias, guardadas como hash, com escopo, rotação e revogação | Primeiro cliente ou parceiro com acesso próprio | Identidade padronizada por inquilino (OAuth2/OIDC, Cognito) |
| Rede | Sub-redes públicas, IP público nas tarefas, entrada só pelo security group do balanceador; sem NAT Gateway | Primeiro dado de cliente ou primeira execução de código de terceiros | Sub-redes privadas com VPC endpoints para os inquilinos afetados |
| Banco | Um RDS compartilhado, com um banco e um usuário por projeto | Primeiro dado de cliente no Security, ou disputa de recursos entre inquilinos | RDS dedicado para o inquilino afetado |
| GuruDev Runtime | Execução só pelo próprio fundador, para desenvolvimento | Primeiro usuário externo executando código | Runtime isolado: tarefas efêmeras sem rota para a VPC interna, sem credenciais de outros produtos, com limite de tempo e memória |
| Contas AWS | Conta única | Primeiro cliente em produção, ou gasto recorrente relevante em GPU e Braket | Separar produção e experimentos caros via AWS Organizations; não uma conta por produto |

A autenticação é a única proteção que não espera gatilho. Mesmo sem dados de clientes, uma rota de escrita aberta na internet permite que qualquer pessoa grave no banco e gere custo.

## 10. Fora do escopo desta versão

- AWS IoT Core: terá projeto e auditoria próprios, cobrindo identidade de dispositivo, certificados X.509 e políticas por tópico MQTT.
- Ambientes de homologação separados: no início, só produção, com proteção por Environment no GitHub.
- Multicloud ativo: a GCP segue para pesquisa e produtos que já operam nela.
