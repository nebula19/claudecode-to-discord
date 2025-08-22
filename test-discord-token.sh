#!/bin/bash

# Slack Bot Token 테스트 스크립트

if [ -z "$1" ]; then
    echo "사용법: $0 <bot-token>"
    echo "예: $0 xoxb-1234567890-1234567890-abcdefghijklmnopqrstuvwx"
    exit 1
fi

BOT_TOKEN="$1"

echo "🧪 Slack Bot Token 테스트 중..."
echo "Token: ${BOT_TOKEN:0:12}..."

# auth.test API 호출
response=$(curl -s -H "Authorization: Bearer $BOT_TOKEN" \
    "https://slack.com/api/auth.test")

echo ""
echo "응답:"
echo "$response" | jq '.'

echo ""
if echo "$response" | jq -e '.ok' > /dev/null 2>&1; then
    bot_name=$(echo "$response" | jq -r '.user')
    team_name=$(echo "$response" | jq -r '.team')
    echo "✅ 연결 성공: $bot_name @ $team_name"
else
    echo "❌ 연결 실패"
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        error_msg=$(echo "$response" | jq -r '.error')
        echo "에러: $error_msg"
    fi
fi