# Discord Bot 설정 가이드

Claude Code를 Discord와 연동하기 위한 상세 설정 가이드입니다.

## 🤖 Discord Bot 생성

### 1단계: Discord Developer Portal 접속
1. [Discord Developer Portal](https://discord.com/developers/applications)에 접속
2. "New Application" 클릭
3. 애플리케이션 이름 입력 (예: "Claude Code Monitor")

### 2단계: Bot 생성
1. 좌측 메뉴에서 "Bot" 클릭
2. "Add Bot" 버튼 클릭
3. "Reset Token" 클릭하여 Bot Token 생성
4. **⚠️ Token을 안전한 곳에 복사** (다시 볼 수 없음)

### 3단계: Bot 권한 설정
필요한 권한들:
- `Send Messages` - 메시지 전송
- `Create Public Threads` - 공개 스레드 생성
- `Send Messages in Threads` - 스레드 내 메시지 전송
- `Use Slash Commands` - (선택사항)

## 🏠 Discord 서버 설정

### 1단계: 개발자 모드 활성화
1. Discord 설정 → 고급 → 개발자 모드 활성화
2. 이제 우클릭으로 ID 복사 가능

### 2단계: 서버/채널 ID 복사
1. **서버 ID**: 서버 이름 우클릭 → "ID 복사"
2. **채널 ID**: 채널 이름 우클릭 → "ID 복사"

### 3단계: Bot 초대
1. Developer Portal에서 OAuth2 → URL Generator
2. Scopes: `bot` 선택
3. Bot Permissions: 위에서 설정한 권한들 선택
4. 생성된 URL로 봇을 서버에 초대

## ⚙️ 설정 파일 작성

### discord-config.json 예시
```json
{
  "bot_token": "MTIAAAAAAAAAAAAAAAAAAAA1.BBBBBB.CCCCCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDDDDDD0",
  "channel_id": "1234567890123456789",
  "guild_id": "9876543210987654321"
}
```

### 설정값 설명
- `bot_token`: Discord Bot Token (MTI로 시작하는 긴 문자열)
- `channel_id`: 메시지를 보낼 채널의 ID (숫자로만 구성)
- `guild_id`: Discord 서버(길드)의 ID (숫자로만 구성)

## 🔧 설정 파일 위치

### 프로젝트별 설정 (권장)
```bash
mkdir -p .claude/plugins/discord-integration
cat > .claude/plugins/discord-integration/discord-config.json << 'EOF'
{
  "bot_token": "YOUR_BOT_TOKEN_HERE",
  "channel_id": "YOUR_CHANNEL_ID_HERE", 
  "guild_id": "YOUR_GUILD_ID_HERE"
}
EOF
```

### 전역 설정
```bash
mkdir -p ~/.claude/plugins/discord-integration
cat > ~/.claude/plugins/discord-integration/discord-config.json << 'EOF'
{
  "bot_token": "YOUR_BOT_TOKEN_HERE",
  "channel_id": "YOUR_CHANNEL_ID_HERE",
  "guild_id": "YOUR_GUILD_ID_HERE"
}
EOF
```

## 🧪 테스트

### Bot Token 검증
```bash
curl -H "Authorization: Bot YOUR_BOT_TOKEN" \
     "https://discord.com/api/v10/users/@me"
```

성공 시 Bot 정보가 JSON으로 반환됩니다.

### 메시지 전송 테스트
```bash
# Hook 스크립트 직접 실행
echo '{"hook_event_name":"Stop","transcript_path":"test"}' | \
./.claude/plugins/discord-integration/claude-to-discord.sh
```

## 🔒 보안 주의사항

### Bot Token 보호
- ❌ Git에 커밋하지 마세요
- ❌ 코드에 하드코딩하지 마세요  
- ✅ 환경변수나 설정 파일 사용
- ✅ 설정 파일 권한 제한

```bash
# 권한 설정
chmod 600 .claude/plugins/discord-integration/discord-config.json

# .gitignore에 추가
echo ".claude/plugins/discord-integration/discord-config.json" >> .gitignore
```

### Bot 권한 최소화
- 필요한 권한만 부여
- 관리자 권한 부여 금지
- 정기적인 토큰 로테이션

## 🆘 문제 해결

### 403 Forbidden 오류
- Bot이 서버에 초대되었는지 확인
- 채널에 메시지 전송 권한 확인
- Bot 역할이 충분한 권한을 가지는지 확인

### 404 Not Found 오류
- 채널 ID가 올바른지 확인
- Bot이 해당 채널에 접근할 수 있는지 확인

### 401 Unauthorized 오류
- Bot Token이 올바른지 확인
- Token 앞에 "Bot " 접두사 필요

## 📚 추가 리소스

- [Discord Developer Documentation](https://discord.com/developers/docs)
- [Discord API Reference](https://discord.com/developers/docs/reference)
- [Discord Bot 권한 계산기](https://discordapi.com/permissions.html)
