#!/bin/bash

set -euo pipefail

AWS_REGION="eu-central-1"
PUBLIC_SUBNET_ID="subnet-001161b56f5aaec52"
PRIVATE_ROUTE_TABLE_ID="rtb-050a519b5cc2bbffa"

STATE_FILE="$(dirname "$0")/.nat-state"

echo "==> Выделяем Elastic IP"

ALLOCATION_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --region "$AWS_REGION" \
    --tag-specifications \
    'ResourceType=elastic-ip,Tags=[{Key=Name,Value=timecapsule-dev-nat-a-eip},{Key=Project,Value=timecapsule},{Key=Environment,Value=dev},{Key=Owner,Value=Eredin1272},{Key=Lab,Value=lab3}]' \
    --query 'AllocationId' \
    --output text)

echo "Elastic IP allocation: $ALLOCATION_ID"

echo "==> Создаём NAT Gateway"

NAT_GATEWAY_ID=$(aws ec2 create-nat-gateway \
    --subnet-id "$PUBLIC_SUBNET_ID" \
    --allocation-id "$ALLOCATION_ID" \
    --connectivity-type public \
    --region "$AWS_REGION" \
    --tag-specifications \
    'ResourceType=natgateway,Tags=[{Key=Name,Value=timecapsule-dev-nat-a},{Key=Project,Value=timecapsule},{Key=Environment,Value=dev},{Key=Owner,Value=Eredin1272},{Key=Lab,Value=lab3}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "NAT Gateway: $NAT_GATEWAY_ID"

echo "==> Ждём состояние Available"

aws ec2 wait nat-gateway-available \
    --nat-gateway-ids "$NAT_GATEWAY_ID" \
    --region "$AWS_REGION"

echo "==> Добавляем маршрут в private-rt"

aws ec2 create-route \
    --route-table-id "$PRIVATE_ROUTE_TABLE_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id "$NAT_GATEWAY_ID" \
    --region "$AWS_REGION"

cat > "$STATE_FILE" <<EOF
NAT_GATEWAY_ID=$NAT_GATEWAY_ID
ALLOCATION_ID=$ALLOCATION_ID
EOF

echo "==> NAT Gateway готов"
echo "NAT Gateway ID: $NAT_GATEWAY_ID"
echo "Elastic IP Allocation ID: $ALLOCATION_ID"