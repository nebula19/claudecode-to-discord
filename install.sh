#!/bin/bash

set -e  # 에러 시 스크립트 종료

echo "🚀 Claude Code to Discord Integration 설치를 시작합니다..."
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 필수 도구 확인
echo "📋 필수 도구 확인 중..."
for cmd in curl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}오류: $cmd가 설치되어 있지 않습니다.${NC}"
        if [[ "$cmd" == "jq" ]]; then
            echo "jq 설치: brew install jq (macOS) 또는 apt-get install jq (Ubuntu)"
        fi
        exit 1
    fi
done
echo -e "${GREEN}✅ 필수 도구 확인 완료${NC}"
echo ""

# Claude Code 설치 확인
if ! command -v claude &> /dev/null; then
    echo -e "${RED}오류: Claude Code CLI가 설치되어 있지 않습니다.${NC}"
    echo "Claude Code 설치: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi
echo -e "${GREEN}✅ Claude Code CLI 확인 완료${NC}"
echo ""

# Discord Bot Token 입력 받기
echo -e "${BLUE}🔑 Discord Bot Token을 입력해주세요${NC}"
echo "형식: MTI... 또는 MTQ..."
echo "(Discord Developer Portal > Bot > Token)"
echo ""
read -p "Bot Token: " DISCORD_BOT_TOKEN < /dev/tty

if [[ ! "$DISCORD_BOT_TOKEN" =~ ^MT[IQ] ]]; then
    echo -e "${RED}오류: 올바른 Discord Bot Token 형식이 아닙니다. (MTI 또는 MTQ로 시작해야 함)${NC}"
    exit 1
fi

# Discord Channel ID 입력 받기
echo ""
echo -e "${BLUE}📢 메시지를 보낼 Discord Channel ID를 입력해주세요${NC}"
echo "(개발자 모드 활성화 후 채널 우클릭 > ID 복사)"
read -p "Channel ID: " DISCORD_CHANNEL_ID < /dev/tty

if [[ -z "$DISCORD_CHANNEL_ID" ]] || [[ ! "$DISCORD_CHANNEL_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}오류: 올바른 Discord Channel ID를 입력해주세요. (숫자만)${NC}"
    exit 1
fi

# Discord Guild ID 입력 받기
echo ""
echo -e "${BLUE}🏠 Discord Server(Guild) ID를 입력해주세요${NC}"
echo "(개발자 모드 활성화 후 서버 우클릭 > ID 복사)"
read -p "Guild ID: " DISCORD_GUILD_ID < /dev/tty

if [[ -z "$DISCORD_GUILD_ID" ]] || [[ ! "$DISCORD_GUILD_ID" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}오류: 올바른 Discord Guild ID를 입력해주세요. (숫자만)${NC}"
    exit 1
fi

# 사용자 표시 이름 입력 받기 (선택사항)
echo ""
echo -e "${BLUE}👤 Discord에서 표시될 사용자 이름을 입력해주세요 (선택사항)${NC}"
echo "비우면 시스템 username을 사용합니다: $(whoami)"
read -p "표시 이름 (비워두면 $(whoami) 사용): " DISPLAY_NAME < /dev/tty

# 비어있으면 기본값 사용
if [[ -z "$DISPLAY_NAME" ]]; then
    DISPLAY_NAME="$(whoami)"
fi

echo ""
echo -e "${YELLOW}📝 설정 확인:${NC}"
echo "Bot Token: ${DISCORD_BOT_TOKEN:0:12}..."
echo "Channel ID: $DISCORD_CHANNEL_ID"
echo "Guild ID: $DISCORD_GUILD_ID"
echo "표시 이름: $DISPLAY_NAME"
echo ""
read -p "계속하시겠습니까? (y/N): " confirm < /dev/tty
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "설치를 취소했습니다."
    exit 0
fi

# 프로젝트 Claude 설정 디렉토리 생성
CLAUDE_DIR="$(pwd)/.claude"
DISCORD_PLUGIN_DIR="$CLAUDE_DIR/plugins/discord-integration"
echo ""
echo "📁 프로젝트 Claude 설정 디렉토리 생성 중..."
mkdir -p "$DISCORD_PLUGIN_DIR"

# 스크립트 다운로드
echo "📥 스크립트 다운로드 중..."
SCRIPT_URL="https://raw.githubusercontent.com/nebula19/claudecode-to-discord/main/claude_setting/plugins/discord-integration/claude-to-discord.sh"
SCRIPT_PATH="$DISCORD_PLUGIN_DIR/claude-to-discord.sh"

# 기존 스크립트가 있으면 백업
if [ -f "$SCRIPT_PATH" ]; then
    echo "기존 스크립트를 백업합니다..."
    cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# 현재 디렉토리에서 스크립트 복사 (개발용)
if [ -f "$(pwd)/claude_setting/plugins/discord-integration/claude-to-discord.sh" ]; then
    echo "로컬 스크립트를 사용합니다..."
    cp "$(pwd)/claude_setting/plugins/discord-integration/claude-to-discord.sh" "$SCRIPT_PATH"
elif [ -f "$(pwd)/.claude/plugins/discord-integration/claude-to-discord.sh" ]; then
    echo "로컬 스크립트를 사용합니다..."
    cp "$(pwd)/.claude/plugins/discord-integration/claude-to-discord.sh" "$SCRIPT_PATH"
elif [ -f "$(pwd)/claude-to-discord.sh" ]; then
    echo "로컬 스크립트를 사용합니다..."
    cp "$(pwd)/claude-to-discord.sh" "$SCRIPT_PATH"
else
    # GitHub에서 다운로드 (배포용)
    if ! curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"; then
        echo -e "${RED}오류: 스크립트 다운로드에 실패했습니다.${NC}"
        echo "수동으로 claude-to-discord.sh를 $SCRIPT_PATH에 복사해주세요."
        exit 1
    fi
fi

# 실행 권한 부여
chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}✅ 스크립트 설치 완료${NC}"

# 설정 파일 생성
echo "⚙️  설정 파일 생성 중..."
CONFIG_PATH="$DISCORD_PLUGIN_DIR/discord-config.json"
cat > "$CONFIG_PATH" << EOF
{
  "bot_token": "$DISCORD_BOT_TOKEN",
  "channel_id": "$DISCORD_CHANNEL_ID",
  "guild_id": "$DISCORD_GUILD_ID",
  "display_name": "$DISPLAY_NAME"
}
EOF

# 설정 파일 권한 제한
chmod 600 "$CONFIG_PATH"
echo -e "${GREEN}✅ 설정 파일 생성 완료${NC}"

# Claude Code Hook 설정
echo "🔗 Claude Code Hook 설정 중..."
SETTINGS_PATH="$CLAUDE_DIR/settings.local.json"

# 기존 settings.local.json 백업
if [ -f "$SETTINGS_PATH" ]; then
    cp "$SETTINGS_PATH" "${SETTINGS_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "기존 설정 파일을 백업했습니다."
fi

# Hook 설정 생성/업데이트
if [ -f "$SETTINGS_PATH" ]; then
    # 기존 파일이 있는 경우 hooks 섹션 업데이트
    temp_file=$(mktemp)
    jq '. + {
        "hooks": {
            "Stop": [
                {
                    "matcher": "*",
                    "hooks": [
                        {
                            "type": "command",
                            "command": "./.claude/plugins/discord-integration/claude-to-discord.sh"
                        }
                    ]
                }
            ]
        }
    }' "$SETTINGS_PATH" > "$temp_file" && mv "$temp_file" "$SETTINGS_PATH"
else
    # 새 파일 생성
    cat > "$SETTINGS_PATH" << EOF
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "./.claude/plugins/discord-integration/claude-to-discord.sh"
          }
        ]
      }
    ]
  }
}
EOF
fi

echo -e "${GREEN}✅ Hook 설정 완료${NC}"

# Bot Token 테스트
echo ""
echo "🧪 Discord Bot 연결 테스트 중..."
test_response=$(curl -s -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    "https://discord.com/api/v10/users/@me")

echo "응답: $test_response" >&2  # 디버깅용

if echo "$test_response" | jq -e '.id' > /dev/null 2>&1; then
    bot_name=$(echo "$test_response" | jq -r '.username')
    bot_id=$(echo "$test_response" | jq -r '.id')
    echo -e "${GREEN}✅ Bot 연결 성공: $bot_name (ID: $bot_id)${NC}"
else
    echo -e "${YELLOW}⚠️  Bot 연결 테스트 실패${NC}"
    
    # 에러 상세 정보 출력
    if echo "$test_response" | jq -e '.message' > /dev/null 2>&1; then
        error_msg=$(echo "$test_response" | jq -r '.message')
        echo "에러: $error_msg"
        
        case "$error_msg" in
            *"401"*|*"Unauthorized"*)
                echo "❌ Bot Token이 잘못되었습니다. MTI로 시작하는 올바른 토큰인지 확인하세요."
                ;;
            *"403"*|*"Forbidden"*)
                echo "❌ Bot이 서버에 초대되어 있지 않거나 권한이 부족합니다."
                ;;
            *)
                echo "❌ 알 수 없는 에러입니다."
                ;;
        esac
    fi
    
    echo ""
    echo "Bot Token을 확인하고 다음 권한이 있는지 확인해주세요:"
    echo "  - Send Messages"
    echo "  - Create Public Threads"
    echo "  - Send Messages in Threads"
    echo ""
    echo "🔧 해결 방법:"
    echo "1. https://discord.com/developers/applications 에서 앱 확인"
    echo "2. Bot 섹션에서 Token 재생성"
    echo "3. OAuth2 URL Generator로 서버에 다시 초대"
fi

# 설치 완료
echo ""
echo -e "${GREEN}🎉 설치가 완료되었습니다!${NC}"
echo ""
echo -e "${BLUE}📋 다음 단계:${NC}"
echo "1. Discord에서 개발자 모드를 활성화하세요"
echo "2. Bot이 서버에 올바르게 초대되어 있는지 확인하세요"
echo "3. Claude Code를 사용해보세요!"
echo ""
echo -e "${YELLOW}💡 팁:${NC}"
echo "- 설정 파일 위치: $CONFIG_PATH"
echo "- Hook 설정 파일: $SETTINGS_PATH"
echo "- 스크립트 위치: $SCRIPT_PATH"
echo "- 이 설정은 현재 프로젝트에서만 동작합니다"
echo ""
echo -e "${BLUE}🔍 문제 해결:${NC}"
echo "- 메시지가 안 보내지면: Bot이 서버에 올바른 권한으로 초대되었는지 확인"
echo "- 에러 확인: ./.claude/plugins/discord-integration/claude-to-discord.sh 실행 후 로그 확인"
echo "- 다른 프로젝트에서도 사용하려면 각 프로젝트에서 설치 스크립트 실행"
echo ""
echo "설치 스크립트가 완료되었습니다. 즐거운 코딩하세요! 🚀"
