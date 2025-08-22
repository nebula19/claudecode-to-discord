#!/bin/bash

# Discord 설정 파일 경로 (프로젝트별 > 전역)
PROJECT_DISCORD_CONFIG="$(pwd)/.claude/plugins/discord-integration/discord-config.json"
GLOBAL_DISCORD_CONFIG="$HOME/.claude/plugins/discord-integration/discord-config.json"

# 기본값 설정
DISCORD_BOT_TOKEN=""
DISCORD_CHANNEL_ID=""
DISCORD_GUILD_ID=""
DISPLAY_NAME=""
USED_CONFIG_FILE=""

# 설정 파일 우선순위: 프로젝트별 > 전역
if [ -f "$PROJECT_DISCORD_CONFIG" ]; then
    DISCORD_BOT_TOKEN=$(jq -r '.bot_token // empty' "$PROJECT_DISCORD_CONFIG")
    DISCORD_CHANNEL_ID=$(jq -r '.channel_id // empty' "$PROJECT_DISCORD_CONFIG")
    DISCORD_GUILD_ID=$(jq -r '.guild_id // empty' "$PROJECT_DISCORD_CONFIG")
    DISPLAY_NAME=$(jq -r '.display_name // empty' "$PROJECT_DISCORD_CONFIG")
    USED_CONFIG_FILE="$PROJECT_DISCORD_CONFIG"
elif [ -f "$GLOBAL_DISCORD_CONFIG" ]; then
    DISCORD_BOT_TOKEN=$(jq -r '.bot_token // empty' "$GLOBAL_DISCORD_CONFIG")
    DISCORD_CHANNEL_ID=$(jq -r '.channel_id // empty' "$GLOBAL_DISCORD_CONFIG")
    DISCORD_GUILD_ID=$(jq -r '.guild_id // empty' "$GLOBAL_DISCORD_CONFIG")
    DISPLAY_NAME=$(jq -r '.display_name // empty' "$GLOBAL_DISCORD_CONFIG")
    USED_CONFIG_FILE="$GLOBAL_DISCORD_CONFIG"
else
    # 설정 파일이 없으면 생성 안내
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

# 필수 설정 체크
if [ -z "$DISCORD_BOT_TOKEN" ] || [ "$DISCORD_BOT_TOKEN" = "null" ] || [ "$DISCORD_BOT_TOKEN" = "your-discord-bot-token-here" ]; then
    echo "오류: bot_token이 설정되지 않았습니다." >&2
    echo "$USED_CONFIG_FILE 파일의 bot_token을 확인해주세요." >&2
    exit 1
fi

if [ -z "$DISCORD_CHANNEL_ID" ] || [ "$DISCORD_CHANNEL_ID" = "null" ] || [ "$DISCORD_CHANNEL_ID" = "your-discord-channel-id-here" ]; then
    echo "오류: channel_id가 설정되지 않았습니다." >&2
    echo "$USED_CONFIG_FILE 파일의 channel_id를 확인해주세요." >&2
    exit 1
fi

# Hook 데이터 읽기
input=$(cat)
hook_event_name=$(echo "$input" | jq -r '.hook_event_name')
transcript_path=$(echo "$input" | jq -r '.transcript_path')
prompt=$(echo "$input" | jq -r '.prompt // empty')

# 프로젝트 이름 추출
project_name=$(basename "$(dirname "$transcript_path")" | sed 's/^-Users-[^-]*-//' | tr '-' '/')

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
    # 캐시 파일이 없으면 생성
    if [ ! -f "$THREAD_CACHE_FILE" ]; then
        mkdir -p "$(dirname "$THREAD_CACHE_FILE")"
        echo '{}' > "$THREAD_CACHE_FILE"
    fi
    jq -r ".\"$key\" // \"\"" "$THREAD_CACHE_FILE" 2>/dev/null || echo ""
}

save_thread_id() {
    local key="$1"
    local thread_id="$2"
    # 캐시 파일이 없으면 생성
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
    
    # 스레드 생성
    local thread_response=$(curl -X POST \
        -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$(jq -n --arg name "$thread_name" --arg type "11" '{name: $name, type: ($type | tonumber)}')" \
        --max-time 10 \
        --silent \
        "$DISCORD_API_BASE/channels/$DISCORD_CHANNEL_ID/threads" 2>/dev/null)
    
    local thread_id=$(echo "$thread_response" | jq -r '.id // empty')
    
    if [ -n "$thread_id" ] && [ "$thread_id" != "null" ]; then
        # 스레드에 초기 메시지 전송
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
if [ "$hook_event_name" = "Stop" ] && [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    # 최근 assistant 메시지 찾기 (text 타입이 있는 것만)
    assistant_text=$(tail -r "$transcript_path" | while IFS= read -r line; do
        if echo "$line" | jq -e '.type == "assistant" and .message.content' > /dev/null 2>&1; then
            text_content=$(echo "$line" | jq -r '.message.content[] | select(.type == "text") | .text' 2>/dev/null)
            if [ -n "$text_content" ]; then
                echo "$text_content"
                break
            fi
        fi
    done)
    
    # 최근 user 메시지 찾기 (전체 텍스트, tool_result, hook 메시지 제외)
    user_text=$(tail -r "$transcript_path" | while IFS= read -r line; do
        if echo "$line" | jq -e '.type == "user" and .message.content' > /dev/null 2>&1; then
            content=$(echo "$line" | jq -r '.message.content')
            if [[ "$content" == *"<user-prompt-submit-hook>"* ]] || [[ "$content" == "["* ]]; then
                continue
            fi
            # 사용자가 입력한 줄바꿈 그대로 유지
            echo "$content"
            break
        fi
    done)
    
    # 기본값 설정
    user_text=${user_text:-"[질문 없음]"}
    assistant_text=${assistant_text:-"[응답 없음]"}
    
    # 결합된 메시지 생성 (Discord Markdown 문법 사용)
    combined_message="
# 💬 사용자 질문
\`\`\`
${user_text}
\`\`\`

# 🤖 Claude 답변
${assistant_text}"
    
    # 기존 스레드 ID 확인
    existing_thread_id=$(get_thread_id "$thread_key")
    
    if [ -n "$existing_thread_id" ]; then
        # 기존 스레드에 메시지 추가
        send_discord_message "$combined_message" "$existing_thread_id" &
    else
        # 새 스레드 생성
        # 스레드 제목: 👤 사용자 | 📅 월-일 | 🚀 프로젝트명
        thread_name="👤 ${display_user_name} | 📅 ${current_month_day} | 🚀 ${project_name}"
        new_thread_id=$(create_discord_thread "$thread_name" "$combined_message")
        
        if [ -n "$new_thread_id" ]; then
            save_thread_id "$thread_key" "$new_thread_id"
            echo "새 스레드 생성: $new_thread_id" >&2
        else
            echo "스레드 생성에 실패했습니다." >&2
        fi
    fi &
fi