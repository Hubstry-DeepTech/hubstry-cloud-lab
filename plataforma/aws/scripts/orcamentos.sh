#!/usr/bin/env bash
# Guardrails de custo da conta AWS da Hubstry.
# Idempotente: pula o que já existe. Rodar no AWS CloudShell com: bash orcamentos.sh
# Não usar "set -e": numa sessão interativa colada, ele encerra o próprio terminal.
#
# Cria:
#   1. hubstry-mensal-total  — US$ 150/mês, custo bruto (sem descontar créditos), só alerta
#   2. hubstry-quantico-gpu  — US$ 60/mês, Braket + EC2, alerta em 80%
#   3. política hubstry-freio-quantico-gpu (nega Braket e instâncias de GPU) e o papel
#      hubstry-budgets-actions, que o AWS Budgets assume para aplicá-la
#   4. ação automática: em 100% do orçamento quântico/GPU, aplica o freio ao usuário admin-solo
#   5. alerta diário de anomalias de custo acima de US$ 20, no monitor por serviço existente
#
# Observação: o freio não alcança o usuário root.

EMAIL="${EMAIL:-guilhermemachado.ceo@hubstry.dev}"
USUARIO_FREIO="${USUARIO_FREIO:-admin-solo}"
export AWS_PAGER=""
ACC=$(aws sts get-caller-identity --query Account --output text)
SUB='[{"SubscriptionType":"EMAIL","Address":"'"$EMAIL"'"}]'
CB='{"IncludeCredit":false,"IncludeRefund":false,"IncludeTax":true,"IncludeSubscription":true,"UseBlended":false,"IncludeRecurring":true,"IncludeOtherSubscription":true,"IncludeSupport":true,"IncludeDiscount":true,"UseAmortized":false,"IncludeUpfront":true}'
existe_orc() { aws budgets describe-budget --account-id "$ACC" --budget-name "$1" >/dev/null 2>&1; }
passo() { echo; echo "== $1"; }

passo "1. hubstry-mensal-total (US\$ 150, custo bruto)"
if existe_orc hubstry-mensal-total; then echo "já existe"; else
aws budgets create-budget --account-id "$ACC" \
 --budget '{"BudgetName":"hubstry-mensal-total","BudgetLimit":{"Amount":"150","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST","CostTypes":'"$CB"'}' \
 --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":50,"ThresholdType":"PERCENTAGE"},"Subscribers":'"$SUB"'},{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":100,"ThresholdType":"PERCENTAGE"},"Subscribers":'"$SUB"'},{"Notification":{"NotificationType":"FORECASTED","ComparisonOperator":"GREATER_THAN","Threshold":100,"ThresholdType":"PERCENTAGE"},"Subscribers":'"$SUB"'}]' \
 && echo "criado"; fi

passo "2. hubstry-quantico-gpu (US\$ 60, Braket + EC2)"
if existe_orc hubstry-quantico-gpu; then echo "já existe"; else
aws budgets create-budget --account-id "$ACC" \
 --budget '{"BudgetName":"hubstry-quantico-gpu","BudgetLimit":{"Amount":"60","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST","CostTypes":'"$CB"',"CostFilters":{"Service":["Amazon Braket","Amazon Elastic Compute Cloud - Compute"]}}' \
 --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80,"ThresholdType":"PERCENTAGE"},"Subscribers":'"$SUB"'}]' \
 && echo "criado"; fi

passo "3. Política de freio e papel do Budgets"
if aws iam get-policy --policy-arn "arn:aws:iam::$ACC:policy/hubstry-freio-quantico-gpu" >/dev/null 2>&1; then echo "política já existe"; else
aws iam create-policy --policy-name hubstry-freio-quantico-gpu --policy-document '{"Version":"2012-10-17","Statement":[{"Sid":"FreioBraket","Effect":"Deny","Action":["braket:CreateQuantumTask","braket:CreateJob"],"Resource":"*"},{"Sid":"FreioGPU","Effect":"Deny","Action":"ec2:RunInstances","Resource":"arn:aws:ec2:*:*:instance/*","Condition":{"StringLike":{"ec2:InstanceType":["g*","p*","inf*","trn*","dl*"]}}}]}' >/dev/null && echo "política criada"; fi
if aws iam get-role --role-name hubstry-budgets-actions >/dev/null 2>&1; then echo "papel já existe"; else
aws iam create-role --role-name hubstry-budgets-actions --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"budgets.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null \
 && aws iam attach-role-policy --role-name hubstry-budgets-actions --policy-arn arn:aws:iam::aws:policy/AWSBudgetsActionsWithAWSResourceControlAccess \
 && echo "papel criado" && sleep 15; fi

passo "4. Ação automática de freio em 100% do orçamento quântico/GPU"
N=$(aws budgets describe-budget-actions-for-budget --account-id "$ACC" --budget-name hubstry-quantico-gpu --query 'length(Actions)' --output text 2>/dev/null)
if [ "${N:-0}" != "0" ] && [ "$N" != "None" ]; then echo "ação já existe"; else
aws budgets create-budget-action --account-id "$ACC" --budget-name hubstry-quantico-gpu \
 --notification-type ACTUAL --action-type APPLY_IAM_POLICY \
 --action-threshold ActionThresholdValue=100,ActionThresholdType=PERCENTAGE \
 --definition '{"IamActionDefinition":{"PolicyArn":"arn:aws:iam::'"$ACC"':policy/hubstry-freio-quantico-gpu","Users":["'"$USUARIO_FREIO"'"]}}' \
 --execution-role-arn "arn:aws:iam::$ACC:role/hubstry-budgets-actions" \
 --approval-model AUTOMATIC --subscribers "$SUB" >/dev/null && echo "ação criada"; fi

passo "5. Alerta de anomalias (usa o monitor por serviço já existente; só um é permitido)"
MON=$(aws ce get-anomaly-monitors --query "AnomalyMonitors[?MonitorType=='DIMENSIONAL'].MonitorArn | [0]" --output text 2>/dev/null)
if [ -z "$MON" ] || [ "$MON" = "None" ]; then
 MON=$(aws ce create-anomaly-monitor --anomaly-monitor '{"MonitorName":"hubstry-servicos","MonitorType":"DIMENSIONAL","MonitorDimension":"SERVICE"}' --query MonitorArn --output text) && echo "monitor criado"
else echo "monitor existente: $MON"; fi
if [ "$(aws ce get-anomaly-subscriptions --query "length(AnomalySubscriptions[?SubscriptionName=='hubstry-anomalias'])" --output text 2>/dev/null)" = "0" ]; then
 aws ce create-anomaly-subscription --anomaly-subscription '{"SubscriptionName":"hubstry-anomalias","MonitorArnList":["'"$MON"'"],"Subscribers":[{"Type":"EMAIL","Address":"'"$EMAIL"'"}],"Frequency":"DAILY","ThresholdExpression":{"Dimensions":{"Key":"ANOMALY_TOTAL_IMPACT_ABSOLUTE","MatchOptions":["GREATER_THAN_OR_EQUAL"],"Values":["20"]}}}' >/dev/null && echo "assinatura criada"
else echo "assinatura já existe"; fi

passo "Resumo"
aws budgets describe-budgets --account-id "$ACC" --query 'Budgets[].[BudgetName,BudgetLimit.Amount,CostTypes.IncludeCredit]' --output table
aws budgets describe-budget-actions-for-budget --account-id "$ACC" --budget-name hubstry-quantico-gpu --query 'Actions[].[ActionId,Status,ApprovalModel]' --output table 2>&1
