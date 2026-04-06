# Claude Code to Discord Integration Setup Guide

Claude Code CLI의 프롬프트와 AI 응답을 실시간으로 Discord 스레드에 전송하는 도구입니다.

## 🔄 업데이트 (기존 설치자)

```bash
curl -fsSL https://raw.githubusercontent.com/nebula19/claudecode-to-discord/main/update.sh | bash
```

설정 파일(`discord-config.json`)은 유지하고 스크립트와 hook 설정만 최신화합니다.

---

## 🚀 빠른 설치 (원라인 설치)

### 자동 설치 스크립트 사용
```bash
curl -fsSL https://raw.githubusercontent.com/nebula19/claudecode-to-discord/main/install.sh | bash
```

스크립트가 다음을 자동으로 수행합니다:
- Discord Bot Token 입력 받기
- Channel ID, Guild ID 입력 받기  
- 사용자 표시 이름 입력 받기 (선택사항)
- 설정 파일 자동 생성
- Claude Code Hook 자동 설정
- Bot 연결 테스트

## 📋 수동 설정 (필요시)

### 1. Discord Bot 생성
1. https://discord.com/developers/applications 에서 "New Application" 클릭
2. 애플리케이션 이름 입력 (예: "Claude Code Monitor")
3. Bot 섹션에서 "Add Bot" 클릭
4. Bot Token 복사 (`MTI...` 형태)

### 2. Bot 권한 설정
OAuth2 → URL Generator에서:
- **Scopes**: `bot`
- **Bot Permissions**: 
  - `Send Messages`
  - `Create Public Threads`
  - `Send Messages in Threads`

### 3. 채널 설정
1. Discord에서 개발자 모드 활성화
2. 원하는 채널 우클릭 → ID 복사
3. 서버 우클릭 → ID 복사

### 4. 수동 설정 파일 생성
```bash
# 프로젝트별 설정
mkdir -p .claude/plugins/discord-integration
cat > .claude/plugins/discord-integration/discord-config.json << 'EOF'
{
  "bot_token": "your-discord-bot-token-here",
  "channel_id": "your-discord-channel-id-here",
  "guild_id": "your-discord-server-id-here",
  "display_name": "John"
}
EOF

# 권한 제한
chmod 600 .claude/plugins/discord-integration/discord-config.json
```

### 5. 수동 스크립트 설치
```bash
# 1. 프로젝트 .claude 디렉토리 생성
mkdir -p .claude/plugins/discord-integration

# 2. 스크립트 다운로드
curl -o .claude/plugins/discord-integration/claude-to-discord.sh https://raw.githubusercontent.com/nebula19/claudecode-to-discord/main/claude_setting/plugins/discord-integration/claude-to-discord.sh

# 3. 실행 권한 부여
chmod +x .claude/plugins/discord-integration/claude-to-discord.sh

# 4. Claude Code Hook 설정
cat > .claude/settings.local.json << 'EOF'
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
```

## 🔧 고급 설정

### 프로젝트별 설정
```bash
# .gitignore에 추가
echo ".claude/plugins/discord-integration/discord-config.json" >> .gitignore
```

### 설정 파일 우선순위
1. **프로젝트별**: `./.claude/plugins/discord-integration/discord-config.json`
2. **전역**: `~/.claude/plugins/discord-integration/discord-config.json`

## 🔍 문제 해결

### Bot Token 확인
```bash
curl -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
     "https://discord.com/api/v10/users/@me"
```

### Hook 실행 확인
```bash
echo '{"hook_event_name":"Stop","transcript_path":"test"}' | \
./.claude/plugins/discord-integration/claude-to-discord.sh
```

## 🔒 보안 주의사항

```bash
# 설정 파일 권한 제한
chmod 600 .claude/plugins/discord-integration/discord-config.json

# .gitignore에 추가  
echo ".claude/plugins/discord-integration/discord-config.json" >> .gitignore
```