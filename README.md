# Claude Code to Discord Integration

Claude Code CLI의 프롬프트와 AI 응답을 실시간으로 Discord 채널에 전송하는 플러그인입니다.

## ✨ 주요 기능

- 🤖 Claude Code 대화 내용을 Discord로 자동 전송
- 🧵 날짜별 쓰레드 시스템으로 대화 구조화
- 🏗️ 프로젝트별 독립 설정
- 🔧 간편한 원라인 설치

## 🚀 빠른 시작

### 1단계: 원라인 설치
```bash
curl -fsSL https://raw.githubusercontent.com/nebula19/claudecode-to-discord/main/install.sh | bash
```

### 2단계: Discord Bot 설정
1. [Discord Developer Portal](https://discord.com/developers/applications)에서 새 애플리케이션 생성
2. Bot 섹션에서 Bot 생성 및 Token 복사
3. Bot Permissions: `Send Messages`, `Create Public Threads`, `Send Messages in Threads`
4. 서버에 Bot 초대 (OAuth2 URL Generator 사용)

### 3단계: 채널 설정
1. Discord에서 원하는 채널의 ID 복사 (개발자 모드 활성화 필요)
2. 설정 파일에 Channel ID와 Server ID 입력

## 📁 프로젝트 구조

```
.claude/
├── settings.local.json         # Claude Code Hook 설정
└── plugins/
    └── discord-integration/
        ├── claude-to-discord.sh  # 메인 스크립트
        ├── discord-config.json   # Discord 설정
        └── discord-threads.json  # 스레드 캐시 (자동 생성)
```

## 📱 동작 방식

### 쓰레드 시스템
- **쓰레드 키**: `{사용자}_{날짜}` (예: `john_2025-08-21`)
- **첫 메시지**: 새로운 쓰레드 생성
- **후속 메시지**: 같은 쓰레드에 추가
- **새로운 날**: 새로운 쓰레드 자동 생성

### 스레드 제목 포맷
```
👤 사용자명 | 📅 월-일 | 🚀 프로젝트명
```

### 메시지 포맷
```
# 💬 사용자 질문
```
사용자 질문 내용
```

# 🤖 Claude 답변
AI 응답 내용
```

## 🔧 고급 설정

### 프로젝트별 설정
각 프로젝트마다 다른 채널 사용:
```bash
# 프로젝트 루트에서
mkdir -p .claude/plugins/discord-integration
cat > .claude/plugins/discord-integration/discord-config.json << 'EOF'
{
  "bot_token": "your-discord-bot-token",
  "channel_id": "your-discord-channel-id",
  "guild_id": "your-discord-server-id",
  "display_name": "John"
}
EOF
```

### 설정 파일 우선순위
1. **프로젝트별**: `./.claude/plugins/discord-integration/discord-config.json`
2. **전역**: `~/.claude/plugins/discord-integration/discord-config.json`

## 🔍 문제 해결

### 메시지가 전송되지 않는 경우
1. **Bot Token 확인**:
   ```bash
   curl -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
        "https://discord.com/api/v10/users/@me"
   ```

2. **채널 접근 권한 확인**:
   - Bot이 서버에 초대되었는지 확인
   - 채널에 메시지 전송 및 스레드 생성 권한 필요

3. **Hook 실행 확인**:
   ```bash
   echo '{"hook_event_name":"Stop","transcript_path":"test"}' | \
   ./.claude/plugins/discord-integration/claude-to-discord.sh
   ```

### 디버그 모드
스크립트 상단에 추가:
```bash
set -x  # 디버그 모드 활성화
```

## 🔒 보안 주의사항

- ❌ Bot Token을 코드에 하드코딩하지 마세요
- ✅ 설정 파일 권한 제한 (`chmod 600`)
- ✅ Git에 토큰 커밋 금지 (`.gitignore` 추가)

```bash
# .gitignore에 추가
echo ".claude/plugins/discord-integration/discord-config.json" >> .gitignore
```

## 📦 수동 설치

자세한 수동 설치 방법은 [SETUP.md](SETUP.md)를 참조하세요.

## 🤝 기여하기

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 🆘 지원

문제가 발생하면 [Issues](https://github.com/your-repo/cclogmon/issues)에 보고해주세요.

---

**Made with ❤️ for better Claude Code experience**
