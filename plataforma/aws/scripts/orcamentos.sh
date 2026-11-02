#!/usr/bin/env bash
# Guardrails de custo da conta AWS da Hubstry.
# Idempotente: cria o que falta e CONFERE o que já existe contra a configuração
# esperada. Divergência conta como falha (não é aceita em silêncio) e o script
# termina com código 1. Rodar no AWS CloudShell com: bash orcamentos.sh
# Não usar "set -e": numa sessão interativa colada, ele encerra o próprio terminal.
#
# Configuração esperada:
#   1. hubstry-mensal-total  — US$ 150/mês, custo bruto; e-mail em 50% e 100% do real e 100% da previsão
#   2. hubstry-quantico-gpu  — US$ 60/mês, Braket + EC2, custo bruto; e-mail em 80% do real
#   3. política hubstry-freio-quantico-gpu (nega Braket e instâncias de GPU) e o papel
#      hubstry-budgets-actions, que o AWS Budgets assume para aplicá-la
#   4. ação automática: em 100% do orçamento quântico/GPU, aplica o freio ao usuário $USUARIO_FREIO
#   5. alerta diário de anomalias de custo a partir de US$ 20, no monitor por serviço
#
# Observação: o freio não alcança o usuário root.

EMAIL="${EMAIL:-guilhermemachado.ceo@hubstry.dev}"
USUARIO_FREIO="${USUARIO_FREIO:-admin-solo}"
export AWS_PAGER=""
command -v jq >/dev/null || { echo "jq é necessário (já vem no CloudShell)"; exit 1; }
ACC=$(aws sts get-caller-identity --query Account --output text) || { echo "sem credenciais AWS"; exit 1; }
SUB='[{"SubscriptionType":"EMAIL","Address":"'"$EMAIL"'"}]'
CB='{"IncludeCredit":false,"IncludeRefund":false,"IncludeTax":true,"IncludeSubscription":true,"UseBlended":false,"IncludeRecurring":true,"IncludeOtherSubscription":true,"IncludeSupport":true,"IncludeDiscount":true,"UseAmortized":false,"IncludeUpfront":true}'
POLITICA='{"Version":"2012-10-17","Statement":[{"Sid":"FreioBraket","Effect":"Deny","Action":["braket:CreateQuantumTask","braket:CreateJob"],"Resource":"*"},{"Sid":"FreioGPU","Effect":"Deny","Action":"ec2:RunInstances","Resource":"arn:aws:ec2:*:*:instance/*","Condition":{"StringLike":{"ec2:InstanceType":["g*","p*","inf*","trn*","dl*"]}}}]}'
POLITICA_ARN="arn:aws:iam::$ACC:policy/hubstry-freio-quantico-gpu"
PAPEL_ARN="arn:aws:iam::$ACC:role/hubstry-budgets-actions"

passo() { echo; echo "== $1"; }
FALHAS=0
falhou() { echo "FALHOU: $1"; FALHAS=$((FALHAS+1)); }
# confere <descrição> <valor encontrado> <valor esperado>
confere() {
  if [ "$2" = "$3" ]; then echo "  ok: $1 = $3"
  else falhou "$1 divergente: encontrado '$2', esperado '$3'"; fi
}
existe_orc() { aws budgets describe-budget --account-id "$ACC" --budget-name "$1" >/dev/null 2>&1; }
# Limite, IncludeCredit e filtros de serviço de um orçamento, normalizados.
limite_orc()   { aws budgets describe-budget --account-id "$ACC" --budget-name "$1" --query 'Budget.BudgetLimit.Amount' --output text | awk '{printf "%g", $1}'; }
credito_orc()  { aws budgets describe-budget --account-id "$ACC" --budget-name "$1" --query 'Budget.CostTypes.IncludeCredit' --output text; }
servicos_orc() { aws budgets describe-budget --account-id "$ACC" --budget-name "$1" --output json | jq -r '[.Budget.CostFilters.Service // [] | .[]] | sort | join(",")'; }
# Notificações como "TIPO:limiar" ordenadas, ex.: ACTUAL:100,ACTUAL:50,FORECASTED:100
avisos_orc() {
  # Cada aviso vira "TIPO|OPERADOR|LIMIAR|TIPO_DO_LIMIAR|destinatários", em linhas ordenadas.
  # Os destinatários vêm de describe-subscribers-for-notification, um aviso por vez.
  # A API omite ThresholdType quando é o padrão (PERCENTAGE); por isso o "// PERCENTAGE".
  local notas n subs
  notas=$(aws budgets describe-notifications-for-budget --account-id "$ACC" --budget-name "$1" --output json) || { echo "ERRO"; return; }
  echo "$notas" | jq -c '.Notifications[]' | while read -r n; do
    subs=$(aws budgets describe-subscribers-for-notification --account-id "$ACC" --budget-name "$1" --notification "$n" --output json \
      | jq -r '[.Subscribers[] | "\(.SubscriptionType):\(.Address)"] | sort | join("+")') || subs="ERRO"
    echo "$n" | jq -r --arg s "$subs" '"\(.NotificationType)|\(.ComparisonOperator)|\(.Threshold|tostring|sub("\\.0$";""))|\(.ThresholdType // "PERCENTAGE")|\($s)"'
  done | sort | paste -sd ';' -
}

passo "1. hubstry-mensal-total (US\$ 150, custo bruto)"
if existe_orc hubstry-mensal-total; then echo "já existe; conferindo"; else
aws budgets create-budget --account-id "$ACC" \
 --budget '{"BudgetName":"hubstry-mensal-total","BudgetLimit":{"Amount":"150","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST","CostTypes":'"$CB"'}' \
 --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":50,"ThresholdType":"PERCENTAGE"},"Subscribers":'"$SUB"'},{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":100,"ThresholdType":"PERCENTAGE"},"Subscribers":'"$SUB"'},{"Notification":{"NotificationType":"FORECASTED","ComparisonOperator":"GREATER_THAN","Threshold":100,"ThresholdType":"PERCENTAGE"},"Subscribers":'"$SUB"'}]' \
 && echo "criado; conferindo" || falhou "criar hubstry-mensal-total"; fi
if existe_orc hubstry-mensal-total; then
  confere "mensal-total limite" "$(limite_orc hubstry-mensal-total)" "150"
  confere "mensal-total IncludeCredit" "$(credito_orc hubstry-mensal-total)" "False"
  confere "mensal-total avisos" "$(avisos_orc hubstry-mensal-total)" \
    "ACTUAL|GREATER_THAN|100|PERCENTAGE|EMAIL:$EMAIL;ACTUAL|GREATER_THAN|50|PERCENTAGE|EMAIL:$EMAIL;FORECASTED|GREATER_THAN|100|PERCENTAGE|EMAIL:$EMAIL"
fi

passo "2. hubstry-quantico-gpu (US\$ 60, Braket + EC2)"
if existe_orc hubstry-quantico-gpu; then echo "já existe; conferindo"; else
aws budgets create-budget --account-id "$ACC" \
 --budget '{"BudgetName":"hubstry-quantico-gpu","BudgetLimit":{"Amount":"60","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST","CostTypes":'"$CB"',"CostFilters":{"Service":["Amazon Braket","Amazon Elastic Compute Cloud - Compute"]}}' \
 --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80,"ThresholdType":"PERCENTAGE"},"Subscribers":'"$SUB"'}]' \
 && echo "criado; conferindo" || falhou "criar hubstry-quantico-gpu"; fi
if existe_orc hubstry-quantico-gpu; then
  confere "quantico-gpu limite" "$(limite_orc hubstry-quantico-gpu)" "60"
  confere "quantico-gpu IncludeCredit" "$(credito_orc hubstry-quantico-gpu)" "False"
  confere "quantico-gpu serviços" "$(servicos_orc hubstry-quantico-gpu)" "Amazon Braket,Amazon Elastic Compute Cloud - Compute"
  # O freio da ação (passo 4) cria um aviso ACTUAL:100 próprio; o de 80% é o de e-mail.
  # O aviso de 80% é o de e-mail; a ação de freio (passo 4) pode registrar um aviso próprio de 100%,
  # aceito só com o mesmo destinatário.
  AV=$(avisos_orc hubstry-quantico-gpu)
  A80="ACTUAL|GREATER_THAN|80|PERCENTAGE|EMAIL:$EMAIL"
  case "$AV" in
    "$A80"|"ACTUAL|GREATER_THAN|100|PERCENTAGE|EMAIL:$EMAIL;$A80") echo "  ok: quantico-gpu avisos = $AV";;
    *) falhou "quantico-gpu avisos divergentes: encontrado '$AV', esperado '$A80' (mais, no máximo, um aviso de 100% para EMAIL:$EMAIL)";;
  esac
fi

passo "3. Política de freio e papel do Budgets"
if aws iam get-policy --policy-arn "$POLITICA_ARN" >/dev/null 2>&1; then echo "política já existe; conferindo"; else
aws iam create-policy --policy-name hubstry-freio-quantico-gpu --policy-document "$POLITICA" >/dev/null && echo "política criada; conferindo" || falhou "criar política de freio"; fi
VER=$(aws iam get-policy --policy-arn "$POLITICA_ARN" --query 'Policy.DefaultVersionId' --output text 2>/dev/null)
# Falha ao ler a versão ou o documento conta como falha, e não pula a comparação.
if [ -z "$VER" ] || [ "$VER" = "None" ]; then
  falhou "não foi possível ler a versão padrão da política de freio"
else
  ATUAL=$(aws iam get-policy-version --policy-arn "$POLITICA_ARN" --version-id "$VER" --query 'PolicyVersion.Document' --output json 2>/dev/null | jq -cS . 2>/dev/null)
  if [ -z "$ATUAL" ]; then falhou "não foi possível ler o documento da política de freio ($VER)"
  else confere "documento da política de freio ($VER)" "$ATUAL" "$(echo "$POLITICA" | jq -cS .)"; fi
fi
if aws iam get-role --role-name hubstry-budgets-actions >/dev/null 2>&1; then echo "papel já existe; conferindo"; else
aws iam create-role --role-name hubstry-budgets-actions --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"budgets.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null \
 && aws iam attach-role-policy --role-name hubstry-budgets-actions --policy-arn arn:aws:iam::aws:policy/AWSBudgetsActionsWithAWSResourceControlAccess \
 && echo "papel criado; conferindo" && sleep 15 || falhou "criar papel do Budgets"; fi
if aws iam get-role --role-name hubstry-budgets-actions >/dev/null 2>&1; then
  # Confiança completa (não só o principal) e nenhuma permissão além da política gerenciada do Budgets.
  confere "papel: política de confiança completa" \
    "$(aws iam get-role --role-name hubstry-budgets-actions --output json | jq -cS '.Role.AssumeRolePolicyDocument')" \
    "$(echo '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"budgets.amazonaws.com"},"Action":"sts:AssumeRole"}]}' | jq -cS .)"
  confere "papel: políticas anexadas" \
    "$(aws iam list-attached-role-policies --role-name hubstry-budgets-actions --output json | jq -r '[.AttachedPolicies[].PolicyArn] | sort | join(",")')" \
    "arn:aws:iam::aws:policy/AWSBudgetsActionsWithAWSResourceControlAccess"
  confere "papel: políticas inline" \
    "$(aws iam list-role-policies --role-name hubstry-budgets-actions --output json | jq -r '.PolicyNames | sort | join(",")')" ""
  confere "papel: limite de permissões" \
    "$(aws iam get-role --role-name hubstry-budgets-actions --output json | jq -r '.Role.PermissionsBoundary.PermissionsBoundaryArn // ""')" ""
fi

passo "4. Ação automática de freio em 100% do orçamento quântico/GPU"
ACOES=$(aws budgets describe-budget-actions-for-budget --account-id "$ACC" --budget-name hubstry-quantico-gpu --output json 2>/dev/null)
N=$(printf '%s' "$ACOES" | jq '.Actions // [] | length' 2>/dev/null); N=${N:-0}
if [ "$N" = "0" ]; then
aws budgets create-budget-action --account-id "$ACC" --budget-name hubstry-quantico-gpu \
 --notification-type ACTUAL --action-type APPLY_IAM_POLICY \
 --action-threshold ActionThresholdValue=100,ActionThresholdType=PERCENTAGE \
 --definition '{"IamActionDefinition":{"PolicyArn":"'"$POLITICA_ARN"'","Users":["'"$USUARIO_FREIO"'"]}}' \
 --execution-role-arn "$PAPEL_ARN" \
 --approval-model AUTOMATIC --subscribers "$SUB" >/dev/null && echo "ação criada; conferindo" || falhou "criar ação de freio"
 ACOES=$(aws budgets describe-budget-actions-for-budget --account-id "$ACC" --budget-name hubstry-quantico-gpu --output json 2>/dev/null)
else echo "ação já existe ($N); conferindo"; fi
if [ -n "$ACOES" ]; then
  confere "ações de freio" "$(echo "$ACOES" | jq '.Actions | length')" "1"
  confere "ação: definição" "$(echo "$ACOES" | jq -r '.Actions[0] | [.ActionType, .ApprovalModel, (.ActionThreshold.ActionThresholdValue|tostring|sub("\\.0$";"")), .ActionThreshold.ActionThresholdType, .Definition.IamActionDefinition.PolicyArn, (.Definition.IamActionDefinition.Users // [] | sort | join("+")), .ExecutionRoleArn] | join(" | ")')" \
    "APPLY_IAM_POLICY | AUTOMATIC | 100 | PERCENTAGE | $POLITICA_ARN | $USUARIO_FREIO | $PAPEL_ARN"
  confere "ação: destinatários" "$(echo "$ACOES" | jq -r '[.Actions[0].Subscribers[] | "\(.SubscriptionType):\(.Address)"] | sort | join("+")')" "EMAIL:$EMAIL"
  if aws iam get-user --user-name "$USUARIO_FREIO" >/dev/null 2>&1; then echo "  ok: usuário $USUARIO_FREIO existe"
  else falhou "usuário $USUARIO_FREIO, alvo do freio, não existe"; fi
else falhou "não foi possível ler as ações do orçamento quântico/GPU"; fi

passo "5. Alerta de anomalias (usa o monitor por serviço já existente; só um é permitido)"
MON=$(aws ce get-anomaly-monitors --query "AnomalyMonitors[?MonitorType=='DIMENSIONAL' && MonitorDimension=='SERVICE'].MonitorArn | [0]" --output text 2>/dev/null)
if [ -z "$MON" ] || [ "$MON" = "None" ]; then
 MON=$(aws ce create-anomaly-monitor --anomaly-monitor '{"MonitorName":"hubstry-servicos","MonitorType":"DIMENSIONAL","MonitorDimension":"SERVICE"}' --query MonitorArn --output text) && echo "monitor criado" || falhou "criar monitor de anomalias"
else echo "monitor existente: $MON"; fi
# O monitor usado precisa ser por serviço (DIMENSIONAL + SERVICE).
if [ -n "$MON" ] && [ "$MON" != "None" ]; then
  confere "anomalias: tipo do monitor" \
    "$(aws ce get-anomaly-monitors --monitor-arn-list "$MON" --output json 2>/dev/null | jq -r '.AnomalyMonitors[0] | "\(.MonitorType) \(.MonitorDimension)"')" "DIMENSIONAL SERVICE"
fi
ASS=$(aws ce get-anomaly-subscriptions --output json 2>/dev/null | jq -c '[.AnomalySubscriptions[] | select(.SubscriptionName=="hubstry-anomalias")]')
if [ "$(echo "${ASS:-[]}" | jq length)" = "0" ]; then
 aws ce create-anomaly-subscription --anomaly-subscription '{"SubscriptionName":"hubstry-anomalias","MonitorArnList":["'"$MON"'"],"Subscribers":[{"Type":"EMAIL","Address":"'"$EMAIL"'"}],"Frequency":"DAILY","ThresholdExpression":{"Dimensions":{"Key":"ANOMALY_TOTAL_IMPACT_ABSOLUTE","MatchOptions":["GREATER_THAN_OR_EQUAL"],"Values":["20"]}}}' >/dev/null && echo "assinatura criada; conferindo" || falhou "criar assinatura de anomalias"
 ASS=$(aws ce get-anomaly-subscriptions --output json 2>/dev/null | jq -c '[.AnomalySubscriptions[] | select(.SubscriptionName=="hubstry-anomalias")]')
else echo "assinatura já existe; conferindo"; fi
if [ -n "$ASS" ] && [ "$(echo "$ASS" | jq length)" = "1" ]; then
  confere "anomalias: frequência" "$(echo "$ASS" | jq -r '.[0].Frequency')" "DAILY"
  confere "anomalias: monitor" "$(echo "$ASS" | jq -r '.[0].MonitorArnList | join(",")')" "$MON"
  confere "anomalias: e-mail" "$(echo "$ASS" | jq -r '[.[0].Subscribers[] | select(.Type=="EMAIL") | .Address] | sort | join(",")')" "$EMAIL"
  confere "anomalias: limiar" "$(echo "$ASS" | jq -r '.[0].ThresholdExpression.Dimensions | "\(.Key) \(.MatchOptions|join(",")) \(.Values|join(","))"')" "ANOMALY_TOTAL_IMPACT_ABSOLUTE GREATER_THAN_OR_EQUAL 20"
else falhou "assinatura hubstry-anomalias ausente ou duplicada"; fi

passo "Resumo"
aws budgets describe-budgets --account-id "$ACC" --query 'Budgets[].[BudgetName,BudgetLimit.Amount,CostTypes.IncludeCredit]' --output table \
  || falhou "listar orçamentos no resumo"
aws budgets describe-budget-actions-for-budget --account-id "$ACC" --budget-name hubstry-quantico-gpu --query 'Actions[].[ActionId,Status,ApprovalModel]' --output table \
  || falhou "listar ações no resumo"
EXTRA=$(aws budgets describe-budgets --account-id "$ACC" --output json 2>/dev/null | jq -r '[.Budgets[] | select(.CostTypes.IncludeCredit == true) | .BudgetName] | join(", ")')
[ -n "$EXTRA" ] && echo "AVISO: orçamento(s) que descontam créditos e por isso não alertam: $EXTRA"

echo
if [ "$FALHAS" -gt 0 ]; then echo "== $FALHAS verificação(ões) falharam. Corrija e rode de novo: o script é idempotente."; exit 1; fi
echo "== Todos os guardrails existem e conferem com a configuração esperada."
