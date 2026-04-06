#!/bin/bash

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔄 Claude Code to Discord Integration 업데이트를 시작합니다..."
echo ""

CLAUDE_DIR="$(pwd)/.claude"
DISCORD_PLUGIN_DIR="$CLAUDE_DIR/plugins/discord-integration"
SCRIPT_PATH="$DISCORD_PLUGIN_DIR/claude-to-discord.sh"
SETTINGS_PATH="$CLAUDE_DIR/settings.local.json"

SCRIPT_URL="https://raw.githubusercontent.com/nebula19/claudecode-to-discord/main/claude_setting/plugins/discord-integration/claude-to-discord.sh"

# 설치 여부 확인
if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${RED}오류: 설치된 스크립트를 찾을 수 없습니다.${NC}"
    echo "먼저 install.sh로 설치해주세요."
    exit 1
fi

# 1. 스크립트 업데이트
echo "📥 최신 스크립트 다운로드 중..."
cp "$SCRIPT_PATH" "${SCRIPT_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

if [ -f "$(pwd)/claude_setting/plugins/discord-integration/claude-to-discord.sh" ]; then
    cp "$(pwd)/claude_setting/plugins/discord-integration/claude-to-discord.sh" "$SCRIPT_PATH"
    echo "로컬 스크립트를 사용합니다."
else
    if ! curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"; then
        echo -e "${RED}오류: 스크립트 다운로드에 실패했습니다.${NC}"
        mv "${SCRIPT_PATH}.backup."* "$SCRIPT_PATH" 2>/dev/null || true
        exit 1
    fi
fi

chmod +x "$SCRIPT_PATH"
echo -e "${GREEN}✅ 스크립트 업데이트 완료${NC}"

# 2. settings.local.json에 UserPromptSubmit hook 추가 (없는 경우만)
if [ -f "$SETTINGS_PATH" ]; then
    has_prompt_hook=$(jq 'has("hooks") and (.hooks | has("UserPromptSubmit"))' "$SETTINGS_PATH" 2>/dev/null || echo "false")

    if [ "$has_prompt_hook" = "false" ]; then
        echo ""
        echo "🔗 UserPromptSubmit hook 추가 중..."
        cp "$SETTINGS_PATH" "${SETTINGS_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

        temp_file=$(mktemp)
        jq '.hooks.UserPromptSubmit = [{"matcher": "*", "hooks": [{"type": "command", "command": "./.claude/plugins/discord-integration/claude-to-discord.sh"}]}]' \
            "$SETTINGS_PATH" > "$temp_file" && mv "$temp_file" "$SETTINGS_PATH"

        echo -e "${GREEN}✅ UserPromptSubmit hook 추가 완료${NC}"
    else
        echo -e "${GREEN}✅ UserPromptSubmit hook 이미 설정됨${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  settings.local.json 없음 - hook 설정을 건너뜁니다.${NC}"
fi

echo ""
echo -e "${GREEN}🎉 업데이트 완료!${NC}"
echo ""
echo -e "${BLUE}변경 사항:${NC}"
echo "  - Python3 기반 transcript 파싱 (jq 제어문자 오류 해결)"
echo "  - UserPromptSubmit hook으로 사용자 입력 안정적 수집"
echo "  - 취소 시 ⚠️ 취소됨 메시지 전송"
echo "  - 도구 사용 중간 Stop 스킵 → 최종 응답만 전송"
echo ""
echo -e "${YELLOW}💡 백업 파일:${NC}"
ls "${SCRIPT_PATH}.backup."* 2>/dev/null | tail -1 | xargs -I{} echo "  스크립트: {}"
ls "${SETTINGS_PATH}.backup."* 2>/dev/null | tail -1 | xargs -I{} echo "  설정: {}"
