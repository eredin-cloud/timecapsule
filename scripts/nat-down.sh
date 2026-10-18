#!/bin/bash

set -euo pipefail

AWS_REGION="eu-central-1"
PRIVATE_ROUTE_TABLE_ID="rtb-050a519b5cc2bbffa"

STATE_FILE="$(dirname "$0")/.nat-state"

if [[ ! -f "$STATE_FILE" ]]; then
    echo "Файл состояния $STATE_FILE не найден"
    exit 1
fi

source "$STATE_FILE"

echo "==> Удаляем маршрут"

aws ec2 delete-route \
    --route-table-id "$PRIVATE_ROUTE_TABLE_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --region "$AWS_REGION"

echo "==> Удаляем NAT Gateway"

aws ec2 delete-nat-gateway \
    --nat-gateway-id "$NAT_GATEWAY_ID" \
    --region "$AWS_REGION"

echo "==> Ждём полного удаления NAT Gateway"

aws ec2 wait nat-gateway-deleted \
    --nat-gateway-ids "$NAT_GATEWAY_ID" \
    --region "$AWS_REGION"

echo "==> Освобождаем Elastic IP"

for attempt in {1..6}; do
    if aws ec2 release-address \
        --allocation-id "$ALLOCATION_ID" \
        --region "$AWS_REGION"; then

        echo "Elastic IP освобождён"
        rm -f "$STATE_FILE"
        echo "==> NAT Gateway полностью удалён"
        exit 0
    fi

    echo "Elastic IP ещё занят. Повтор через 10 секунд..."
    sleep 10
done

echo "Не удалось освободить Elastic IP после нескольких попыток"
exit 1