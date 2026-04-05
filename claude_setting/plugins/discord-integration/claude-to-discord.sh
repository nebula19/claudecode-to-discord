#!/bin/bash

# Hook 데이터를 먼저 읽기 (UserPromptSubmit은 설정 로딩 없이 바로 처리)
input=$(cat)
hook_event_name=$(echo "$input" | jq -r '.hook_event_name')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# UserPromptSubmit: 사용자 입력을 임시 파일에 저장 후 종료
if [ "$hook_event_name" = "UserPromptSubmit" ]; then
    prompt=$(echo "$input" | jq -r '.prompt // empty')
    if [ -n "$prompt" ] && [ "$prompt" != "null" ]; then
        echo "$prompt" > "/tmp/claude-discord-prompt-${session_id}.tmp"
    fi
    exit 0
fi

# Discord 설정 파일 경로 (프로젝트별 > 전역)
PROJECT_DISCORD_CONFIG="$(pwd)/.claude/plugins/discord-integration/discord-config.json"
GLOBAL_DISCORD_CONFIG="$HOME/.claude/plugins/discord-integration/discord-config.json"

# 기본값 설정
DISCORD_BOT_TOKEN=""
DISCORD_CHANNEL_ID=""
DISCORD_GUILD_ID=""
DISCORD_WEBHOOK_URL=""
DISPLAY_NAME=""
USED_CONFIG_FILE=""

# 설정 파일 우선순위: 프로젝트별 > 전역
if [ -f "$PROJECT_DISCORD_CONFIG" ]; then
    DISCORD_BOT_TOKEN=$(jq -r '.bot_token // empty' "$PROJECT_DISCORD_CONFIG")
    DISCORD_CHANNEL_ID=$(jq -r '.channel_id // empty' "$PROJECT_DISCORD_CONFIG")
    DISCORD_GUILD_ID=$(jq -r '.guild_id // empty' "$PROJECT_DISCORD_CONFIG")
    DISCORD_WEBHOOK_URL=$(jq -r '.webhook_url // empty' "$PROJECT_DISCORD_CONFIG")
    DISPLAY_NAME=$(jq -r '.display_name // empty' "$PROJECT_DISCORD_CONFIG")
    USED_CONFIG_FILE="$PROJECT_DISCORD_CONFIG"
elif [ -f "$GLOBAL_DISCORD_CONFIG" ]; then
    DISCORD_BOT_TOKEN=$(jq -r '.bot_token // empty' "$GLOBAL_DISCORD_CONFIG")
    DISCORD_CHANNEL_ID=$(jq -r '.channel_id // empty' "$GLOBAL_DISCORD_CONFIG")
    DISCORD_GUILD_ID=$(jq -r '.guild_id // empty' "$GLOBAL_DISCORD_CONFIG")
    DISCORD_WEBHOOK_URL=$(jq -r '.webhook_url // empty' "$GLOBAL_DISCORD_CONFIG")
    DISPLAY_NAME=$(jq -r '.display_name // empty' "$GLOBAL_DISCORD_CONFIG")
    USED_CONFIG_FILE="$GLOBAL_DISCORD_CONFIG"
else
    echo "오류: Discord 설정 파일이 없습니다." >&2
    echo "" >&2
    echo "다음 중 하나의 설정 파일을 생성해주세요:" >&2
    echo "" >&2
    echo "1. 프로젝트별 설정 (이 프로젝트에서만 사용):" >&2
    echo "   mkdir -p .claude/plugins/discord-integration" >&2
    echo "   cat > .claude/plugins/discord-integration/discord-config.json << EOF" >&2
    echo '   {' >&2
    echo '     "bot_token": "your-discord-bot-token-here",' >&2
    echo '     "channel_id": "your-discord-channel-id-here",' >&2
    echo '     "guild_id": "your-discord-server-id-here"' >&2
    echo '   }' >&2
    echo '   EOF' >&2
    echo "" >&2
    echo "2. 전역 설정 (모든 프로젝트에서 사용):" >&2
    echo "   mkdir -p ~/.claude/plugins/discord-integration" >&2
    echo "   cat > ~/.claude/plugins/discord-integration/discord-config.json << EOF" >&2
    echo '   {' >&2
    echo '     "bot_token": "your-discord-bot-token-here",' >&2
    echo '     "channel_id": "your-discord-channel-id-here",' >&2
    echo '     "guild_id": "your-discord-server-id-here"' >&2
    echo '   }' >&2
    echo '   EOF' >&2
    exit 1
fi

# 필수 설정 체크: webhook_url 또는 bot_token+channel_id 중 하나 필요
_has_webhook=false
_has_bot=false

[ -n "$DISCORD_WEBHOOK_URL" ] && [ "$DISCORD_WEBHOOK_URL" != "null" ] && _has_webhook=true
[ -n "$DISCORD_BOT_TOKEN" ] && [ "$DISCORD_BOT_TOKEN" != "null" ] && [ "$DISCORD_BOT_TOKEN" != "your-discord-bot-token-here" ] && \
[ -n "$DISCORD_CHANNEL_ID" ] && [ "$DISCORD_CHANNEL_ID" != "null" ] && [ "$DISCORD_CHANNEL_ID" != "your-discord-channel-id-here" ] && _has_bot=true

if [ "$_has_webhook" = "false" ] && [ "$_has_bot" = "false" ]; then
    echo "오류: webhook_url 또는 bot_token+channel_id를 설정해주세요." >&2
    echo "$USED_CONFIG_FILE 파일을 확인해주세요." >&2
    exit 1
fi

# 프로젝트 이름 추출
project_name=$(basename "$(pwd)")

# 사용자 이름 및 날짜 추출
user_name=$(whoami)
current_date=$(date '+%Y-%m-%d')
current_month_day=$(date '+%m-%d')
thread_key="${user_name}_${current_date}"

# 표시 이름 설정 (display_name이 있으면 사용, 없으면 시스템 username 사용)
if [ -n "$DISPLAY_NAME" ] && [ "$DISPLAY_NAME" != "null" ] && [ "$DISPLAY_NAME" != "" ]; then
    display_user_name="$DISPLAY_NAME"
else
    display_user_name="$user_name"
fi

# 프로젝트별 스레드 캐시 파일 설정 (현재 작업 디렉토리 사용)
project_claude_dir="$(pwd)/.claude/plugins/discord-integration"
THREAD_CACHE_FILE="$project_claude_dir/discord-threads.json"

# 스레드 캐시 파일 초기화
if [ ! -f "$THREAD_CACHE_FILE" ]; then
    mkdir -p "$(dirname "$THREAD_CACHE_FILE")"
    echo '{}' > "$THREAD_CACHE_FILE"
fi

# 스레드 ID 관리 함수들
get_thread_id() {
    local key="$1"
    if [ ! -f "$THREAD_CACHE_FILE" ]; then
        mkdir -p "$(dirname "$THREAD_CACHE_FILE")"
        echo '{}' > "$THREAD_CACHE_FILE"
    fi
    jq -r ".\"$key\" // \"\"" "$THREAD_CACHE_FILE" 2>/dev/null || echo ""
}

save_thread_id() {
    local key="$1"
    local thread_id="$2"
    if [ ! -f "$THREAD_CACHE_FILE" ]; then
        mkdir -p "$(dirname "$THREAD_CACHE_FILE")"
        echo '{}' > "$THREAD_CACHE_FILE"
    fi
    local temp_file=$(mktemp)
    jq ". + {\"$key\": \"$thread_id\"}" "$THREAD_CACHE_FILE" > "$temp_file" && mv "$temp_file" "$THREAD_CACHE_FILE"
}

# Discord API 기본 URL
DISCORD_API_BASE="https://discord.com/api/v10"

# Discord 스레드 생성 함수
create_discord_thread() {
    local thread_name="$1"
    local initial_message="$2"

    local thread_response=$(curl -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$(jq -n --arg name "$thread_name" --arg type "11" '{name: $name, type: ($type | tonumber)}')" \
        --max-time 10 \
        --silent \
        "$DISCORD_API_BASE/channels/$DISCORD_CHANNEL_ID/threads" 2>/dev/null)

    local thread_id=$(echo "$thread_response" | jq -r '.id // empty')

    if [ -n "$thread_id" ] && [ "$thread_id" != "null" ]; then
        send_discord_message "$initial_message" "$thread_id"
        echo "$thread_id"
    else
        echo "스레드 생성 실패: $thread_response" >&2
        echo ""
    fi
}

# Discord 메시지 전송 함수
send_discord_message() {
    local content="$1"
    local channel_id="$2"

    # Discord의 메시지 길이 제한 (2000자)
    if [ ${#content} -gt 2000 ]; then
        content="${content:0:1997}..."
    fi

    local payload=$(jq -n --arg content "$content" '{content: $content}')

    local response=$(curl -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$payload" \
        --max-time 10 \
        --silent \
        "$DISCORD_API_BASE/channels/$channel_id/messages" 2>/dev/null)

    local message_id=$(echo "$response" | jq -r '.id // empty')
    if [ -n "$message_id" ] && [ "$message_id" != "null" ]; then
        echo "메시지 전송 완료: $message_id" >&2
    else
        echo "메시지 전송 실패: $response" >&2
    fi
}

# Stop hook 처리
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

if [ "$hook_event_name" = "Stop" ]; then
    # 1. UserPromptSubmit이 저장한 temp 파일에서 user_text 읽기
    PROMPT_FILE="/tmp/claude-discord-prompt-${session_id}.tmp"
    if [ -f "$PROMPT_FILE" ]; then
        user_text=$(cat "$PROMPT_FILE")
        rm -f "$PROMPT_FILE"
    fi

    # 2. transcript에서 assistant 응답 추출 + user_text 폴백
    if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
        _tmp_asst=$(mktemp)
        _tmp_user_fallback=$(mktemp)
        python3 - "$transcript_path" "$_tmp_asst" "$_tmp_user_fallback" << 'PYEOF'
import json, sys

transcript_path, asst_file, user_fallback_file = sys.argv[1], sys.argv[2], sys.argv[3]

entries = []
with open(transcript_path, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except Exception:
            pass

SKIP_TAGS = ('<user-prompt-submit-hook>', '<system-reminder>')

# 마지막 user 메시지 인덱스 찾기
last_user_idx = None
last_user_text = None
for i, entry in enumerate(entries):
    if entry.get('type') == 'user':
        content = entry.get('message', {}).get('content', '')
        if isinstance(content, list):
            if any(c.get('type') == 'tool_result' for c in content):
                continue
            text = '\n'.join(c.get('text', '') for c in content if c.get('type') == 'text')
        elif isinstance(content, str):
            text = content
        else:
            continue
        if not text or any(tag in text for tag in SKIP_TAGS):
            continue
        last_user_text = text
        last_user_idx = i

# 마지막 user 메시지 이후의 assistant 응답 찾기
asst_text = None
if last_user_idx is not None:
    for entry in entries[last_user_idx + 1:]:
        if entry.get('type') == 'assistant':
            content = entry.get('message', {}).get('content', [])
            if isinstance(content, list):
                text = '\n'.join(c.get('text', '') for c in content if c.get('type') == 'text')
                if text:
                    asst_text = text
                    break

with open(asst_file, 'w', encoding='utf-8') as f:
    f.write(asst_text or '')
with open(user_fallback_file, 'w', encoding='utf-8') as f:
    f.write(last_user_text or '')
PYEOF

        assistant_text=$(cat "$_tmp_asst")
        user_text_fallback=$(cat "$_tmp_user_fallback")
        rm -f "$_tmp_asst" "$_tmp_user_fallback"

        # UserPromptSubmit temp 파일이 없었으면 transcript에서 폴백
        if [ -z "$user_text" ]; then
            user_text="$user_text_fallback"
        fi
    fi

    # 3. user_text 기본값
    user_text=${user_text:-"[질문 없음]"}

    # 4. 취소 여부에 따라 메시지 구성
    if [ -z "$assistant_text" ]; then
        combined_message="## 💬 사용자 질문
\`\`\`
${user_text}
\`\`\`

## ⚠️ 취소됨"
    else
        combined_message="## 💬 사용자 질문
\`\`\`
${user_text}
\`\`\`

## 🤖 Claude 답변
${assistant_text}"
    fi

    # 5. Discord 전송
    if [ "$_has_bot" = "true" ]; then
        # Bot API 모드: 스레드 생성/관리
        existing_thread_id=$(get_thread_id "$thread_key")

        if [ -n "$existing_thread_id" ]; then
            send_discord_message "$combined_message" "$existing_thread_id" &
        else
            thread_name="👤 ${display_user_name} | 📅 ${current_month_day} | 🚀 ${project_name}"
            new_thread_id=$(create_discord_thread "$thread_name" "$combined_message")

            if [ -n "$new_thread_id" ]; then
                save_thread_id "$thread_key" "$new_thread_id"
                echo "새 스레드 생성: $new_thread_id" >&2
            else
                echo "스레드 생성에 실패했습니다." >&2
            fi
        fi &
    else
        # Webhook 전용 모드: 채널에 직접 전송
        (curl -X POST \
            -H "Content-Type: application/json" \
            --data "$(jq -n --arg content "$combined_message" '{content: $content}')" \
            --max-time 10 \
            --silent \
            "$DISCORD_WEBHOOK_URL" > /dev/null 2>&1) &
    fi
fi
