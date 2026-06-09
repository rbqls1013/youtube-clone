# YouTube Clone (상용 VOD 연동 PoC)

AI 코딩 에이전트와 **Kollus VOD Platform**, **Claude AI SDK**, **MCP(Model Context Protocol)** 를 활용하여
기획부터 iOS 프론트엔드, Cloudflare 백엔드, 상용 영상 플랫폼 연동까지 전체 사이클을 구현한 교육용/PoC(Proof of Concept) 프로젝트입니다.

---

## 프로젝트 목적

- AI 보조 도구를 활용한 풀스택 애플리케이션 개발 워크플로우 검증
- **Kollus VOD** 의 업로드/재생 파이프라인 및 콜백 웹훅 연동 실증
- **Claude AI(Haiku)** 를 Cloudflare Workers에서 직접 호출하여 영상 자동 분석 및 추천 구현
- SwiftUI를 활용한 네이티브 비디오 플레이어 및 Shorts UI/UX 구현

---

## 핵심 기능 (Key Features)

| 기능 | 설명 |
|---|---|
| **비디오 스트리밍** | Kollus VOD Player SDK + HLS 기반 안정적인 영상 재생 |
| **Shorts UI** | 스크롤 시 자동 재생 · 무한 루프가 적용된 틱톡/쇼츠 스타일 페이징 뷰 |
| **AI 영상 분석** | Claude Haiku로 썸네일·제목·태그를 분석해 카테고리·키워드·무드를 자동 추출 |
| **AI 추천 알고리즘** | Jaccard 유사도(키워드) + 카테고리 일치 + 채널 + 로그 기반 인기도를 합산한 추천 점수 |
| **인터랙션** | 영상/댓글 좋아요, 댓글·대댓글(Nested Comments), 채널 구독 |
| **사용자 프로필** | 닉네임 + Base64 아바타 저장, DiceBear fallback |
| **Serverless 아키텍처** | Cloudflare Workers + D1 엣지 기반 초고속 API 및 DB |

---

## 아키텍처 (Architecture)

```text
[ iOS App (SwiftUI) ]
       │  ▲
(API)  │  │ (JSON / JWT Token)
       ▼  │
[ Cloudflare Workers ]──(SQL)──▶[ Cloudflare D1 (SQLite) ]
       │  ▲                              │
(API)  │  │ (Upload URL / mckey)         │ (ai_category, ai_keywords)
       ▼  │                              ▲
[ Kollus VOD Platform ]        [ Anthropic Claude API ]
       │                         (claude-haiku-4-5-20251001)
       └──▶ POST /webhooks/kollus (인코딩 완료 비동기 콜백)
```

---

## 기술 스택

| 영역 | 기술 | 비고 |
|---|---|---|
| 모바일 앱 | iOS 17+, SwiftUI | Combine, PhotosUI, KollusPlayer SDK |
| 백엔드 | Cloudflare Workers (TypeScript) | Serverless Edge Computing |
| DB | Cloudflare D1 | SQLite 기반, 엣지 분산 DB |
| 영상 플랫폼 | Kollus VOD (Catenoid) | 업로드·트랜스코딩·HLS 스트리밍 |
| AI 분석 | Anthropic Claude Haiku | 영상 카테고리/키워드/무드 자동 추출 |
| AI Tools | Claude Code, Kollus MCP | 개발 생산성 극대화 및 API 규격 자동 해석 |
| 런타임 환경 | Node.js compat (Cloudflare) | `nodejs_compat` flag 활성화 |

---

## API 목록

### 기본

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/health` | 서버 상태 확인 |
| GET | `/me` | 클라이언트 IP 해시 기반 userId 반환 |

### 영상

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/videos?limit=10&offset=0` | 일반 영상 목록 (페이지네이션) |
| GET | `/shorts` | Shorts 영상 목록 (최신 50개) |
| PUT | `/videos/:id` | 영상 정보 수정 (본인만, `X-Uploader-Id` 헤더 필요) |
| DELETE | `/videos/:id` | 영상 삭제 (본인만, 좋아요·댓글 연쇄 삭제) |
| POST | `/views` | 조회수 1 증가 `{ videoId }` |

### 업로드 / 재생 (Kollus 연동)

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/upload-url` | Kollus 업로드 URL 발급 + DB 레코드 생성 |
| POST | `/webhooks/kollus` | Kollus 인코딩 완료 콜백 수신, `status=ready` 저장 |
| POST | `/playback-token` | Kollus 재생용 JWT 생성 및 `playbackUrl` 반환 |

### 썸네일

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/thumbnail/:uploadFileKey` | Kollus 원본 포스터 이미지 프록시 |
| POST | `/thumbnail-upload` | iOS에서 추출한 고해상도 썸네일(Base64) 저장 |
| GET | `/thumbnail-image/:videoId` | 저장된 썸네일 바이너리 서빙 |

### 사용자

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/users/:id` | 프로필 조회 (nickname) |
| PUT | `/users/:id` | 프로필 저장 (nickname, avatarData) |
| GET | `/user-avatar/:id` | 아바타 이미지 서빙 (없으면 DiceBear redirect) |

### 인터랙션

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/likes?videoId=&userId=` | 영상 좋아요 수 + 본인 여부 조회 |
| POST | `/likes` | 영상 좋아요 토글 `{ videoId, userId }` |
| GET | `/comments?videoId=` | 댓글 목록 (최신순) |
| POST | `/comments` | 댓글/대댓글 작성 `{ videoId, content, userId, parentId? }` |
| POST | `/comment-likes` | 댓글 좋아요 토글 `{ commentId, userId }` |
| GET | `/comment-likes?videoId=&userId=` | 내가 좋아요한 댓글 ID 목록 |

### 구독

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/subscriptions?subscriberId=&channelId=` | 구독 여부 + 구독자 수 |
| POST | `/subscriptions` | 구독 토글 `{ subscriberId, channelId }` |
| GET | `/subscriptions/channels?subscriberId=` | 구독 중인 채널 목록 |
| GET | `/subscriptions/videos?subscriberId=` | 구독 채널의 최신 영상 목록 |

### AI 분석 / 추천 (Claude 연동)

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/analyze-video` | Claude Haiku로 영상 분석, `ai_category·ai_keywords` 저장 |
| GET | `/recommendations?videoId=&limit=10` | AI 기반 유사 영상 추천 |

### 관리자 (Admin)

| 메서드 | 경로 | 설명 |
|---|---|---|
| POST | `/admin/backfill-mckey` | mckey 누락 영상에 Kollus API로 일괄 보정 |
| POST | `/admin/backfill-uploader` | uploader_id 누락 영상에 IP 해시 일괄 채움 |
| POST | `/admin/migrate-uploader` | IP 해시 → 기기 ID로 uploader_id 일괄 교체 |
| GET | `/debug/mckey?key=` | Kollus media-contents API 응답 직접 확인 |

---

## DB Schema

```sql
CREATE TABLE users (
  id         TEXT PRIMARY KEY,
  nickname   TEXT,
  avatar_data TEXT,            -- Base64 인코딩 이미지
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE videos (
  id                      TEXT PRIMARY KEY,
  title                   TEXT NOT NULL,
  description             TEXT,
  tags                    TEXT,
  thumbnail_url           TEXT,
  thumbnail_data          TEXT,                -- Base64 고해상도 썸네일
  kollus_upload_file_key  TEXT,
  kollus_media_content_key TEXT,
  uploader_id             TEXT,
  is_short                INTEGER DEFAULT 0,  -- 1 = Shorts
  view_count              INTEGER DEFAULT 0,
  like_count              INTEGER DEFAULT 0,
  ai_category             TEXT,               -- Claude 분석 결과
  ai_keywords             TEXT,               -- 콤마 구분 키워드
  ai_analyzed             INTEGER DEFAULT 0,
  status                  TEXT NOT NULL,      -- uploading / processing / ready / failed
  created_at              TEXT NOT NULL,
  updated_at              TEXT NOT NULL
);

CREATE TABLE likes (
  user_id    TEXT NOT NULL,
  video_id   TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, video_id)
);

CREATE TABLE comments (
  id         TEXT PRIMARY KEY,
  video_id   TEXT NOT NULL,
  user_id    TEXT NOT NULL,
  content    TEXT NOT NULL,
  parent_id  TEXT,             -- NULL이면 최상위 댓글
  like_count INTEGER DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE comment_likes (
  id         TEXT PRIMARY KEY,
  comment_id TEXT NOT NULL,
  user_id    TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE subscriptions (
  id            TEXT PRIMARY KEY,
  subscriber_id TEXT NOT NULL,
  channel_id    TEXT NOT NULL,
  created_at    TEXT NOT NULL
);
```

---

## Kollus VOD 연동 흐름

### 1. 업로드

```
앱 → POST /upload-url { title, uploaderId, isShort }
       └→ Worker → Kollus API (create-url) → upload_url, upload_file_key 반환
앱 → upload_url로 영상 파일 직접 업로드 (multipart)
Kollus → POST /webhooks/kollus (인코딩 완료 시)
              └→ Worker: status=ready, mckey, thumbnail_url DB 저장
                         + Kollus 채널 자동 추가
```

### 2. 재생

```
앱 → POST /playback-token { videoId }
       └→ Worker → D1에서 kollus_media_content_key 조회
                  (없으면 Kollus API 실시간 조회 후 캐시)
                  → HS256 JWT 생성 (expt: 1시간)
                  → playbackUrl 반환 (https://v.kr.kollus.com/si?jwt=...)
앱 → KollusPlayer SDK에 playbackUrl 전달하여 재생
```

### JWT 페이로드 구조

```json
{
  "cuid": "anonymous",
  "expt": 1234567890,
  "mc": [{ "mckey": "<media_content_key>" }]
}
```

---

## Claude AI SDK 연동

Cloudflare Workers에서 Anthropic REST API를 직접 호출합니다. (공식 SDK 대신 `fetch` 사용 — edge 런타임 호환성)

### 영상 분석 (`POST /analyze-video`)

```typescript
const response = await fetch('https://api.anthropic.com/v1/messages', {
  method: 'POST',
  headers: {
    'x-api-key': env.ANTHROPIC_API_KEY,
    'anthropic-version': '2023-06-01',
    'content-type': 'application/json',
  },
  body: JSON.stringify({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 300,
    messages: [{
      role: 'user',
      content: [
        // 썸네일이 있으면 이미지도 함께 전송 (멀티모달)
        { type: 'image', source: { type: 'url', url: thumbnailUrl } },
        { type: 'text', text: '...분석 프롬프트...' },
      ],
    }],
  }),
});
```

**분석 입력:** 제목, 태그, 설명, 채널 ID, 썸네일 이미지 (선택)  
**분석 출력:** `category` (게임/음악/교육 등 11종), `keywords` (최대 5개), `mood` (유머/정보/감동 등)  
**저장:** `ai_category`, `ai_keywords` 컬럼에 저장 후 추천 알고리즘에 활용

### 추천 알고리즘 (`GET /recommendations`)

| 점수 요소 | 최대 점수 | 계산 방법 |
|---|---|---|
| 키워드 유사도 | 50점 | Jaccard 유사도 × 50 |
| 카테고리 일치 | 25점 | 동일 카테고리 +25 |
| 채널 일치 | 10점 | 동일 uploader_id +10 |
| 조회수 인기도 | 10점 | log₁₀₀₀(view_count+1) × 10 |
| 좋아요 인기도 | 5점 | log₁₀₀(like_count+1) × 5 |

---

## 필수 환경 변수 (Secrets)

| 이름 | 설명 |
|---|---|
| `KOLLUS_API_ACCESS_TOKEN` | Kollus API 호출용 액세스 토큰 |
| `KOLLUS_SECURITY_KEY` | 재생 JWT HS256 서명 키 |
| `KOLLUS_USER_KEY` | 재생 URL용 custom_key (채널 식별) |
| `KOLLUS_CATEGORY_KEY` | 업로드 시 사용할 Kollus 카테고리 키 |
| `KOLLUS_CHANNEL_ID` | 인코딩 완료 후 자동 추가할 Kollus 채널 ID |
| `USER_ID_SALT` | IP 해시 기반 userId 생성 시 사용하는 salt |
| `ANTHROPIC_API_KEY` | Claude AI API 키 |

---

## 실행 방법

### 백엔드

```bash
# 1. 의존성 설치
npm install

# 2. Secret 등록 (최초 1회)
wrangler secret put KOLLUS_API_ACCESS_TOKEN
wrangler secret put KOLLUS_SECURITY_KEY
wrangler secret put KOLLUS_USER_KEY
wrangler secret put KOLLUS_CATEGORY_KEY
wrangler secret put KOLLUS_CHANNEL_ID
wrangler secret put USER_ID_SALT
wrangler secret put ANTHROPIC_API_KEY

# 3. D1 데이터베이스 마이그레이션
wrangler d1 execute youtube-clone-db --remote --file=migrations/0001_init.sql

# 4. 로컬 개발 서버
npm run dev

# 5. 프로덕션 배포
npm run deploy
```

### iOS 앱

1. Xcode에서 `YoutubeClone/` 프로젝트를 열기
2. **Signing & Capabilities** → Bundle Identifier를 `com.[본인_계정].YoutubeClone`으로 변경
3. KollusPlayer SDK가 정상 링크됐는지 확인
4. 시뮬레이터 또는 실기기에서 **Build & Run** (`⌘R`)

---

## 동작하는 기능 체크리스트

**백엔드**
- ✅ Kollus 업로드 URL 발급 + DB 레코드 자동 생성
- ✅ Kollus 콜백 수신 및 `status=ready` 저장, 채널 자동 추가
- ✅ Kollus JWT 재생 URL 발급 (mckey 실시간 fallback 포함)
- ✅ 영상 목록 조회 (일반 / Shorts 분리, 페이지네이션)
- ✅ 영상 수정·삭제 (권한 체크)
- ✅ 조회수 증가
- ✅ 좋아요 토글 (영상 / 댓글)
- ✅ 댓글·대댓글 작성 및 조회
- ✅ 채널 구독·해제 및 구독 피드
- ✅ 사용자 프로필 저장 (닉네임 + 아바타)
- ✅ 썸네일 저장 및 서빙 (Kollus 프록시 / iOS 고해상도)
- ✅ Claude Haiku 멀티모달 영상 분석 (카테고리·키워드·무드)
- ✅ AI 기반 유사 영상 추천

**iOS 앱**
- ✅ 영상 목록 화면 (피드)
- ✅ Shorts 세로형 재생 화면
- ✅ KollusPlayer SDK 재생 URL 연결
- ✅ 업로드 (PhotosUI → Kollus → 콜백 대기)

---

## MCP 활용 기록

프로젝트 개발 시 **Kollus MCP** 서버를 Claude Code에 연결하여 다음 작업을 자동화:

- Kollus 업로드 API 엔드포인트 및 파라미터 규격 확인
- 웹훅 콜백 payload 필드 구조 파악 (`upload_file_key`, `media_content_key`, `transcoding_result`)
- JWT 재생 URL 생성 규격 확인 (payload 구조, HS256 서명 방식)
- 채널 attach API 활용 방법 조회

---

## 배운 점

- Cloudflare Workers + D1으로 별도 서버 없이 빠르게 프로덕션 수준의 백엔드 구축 가능
- Kollus `upload_file_key` → `media_content_key` 변환은 웹훅 또는 API 조회로 처리해야 함
- JWT는 반드시 백엔드에서 생성하고 앱은 URL만 전달받아야 키 노출 방지
- Claude Haiku는 저렴한 비용으로 멀티모달 분석이 가능하며, Workers에서 `fetch`로 직접 호출 가능
- AI 코딩 에이전트(Claude Code)로 비전공자도 복잡한 풀스택 기능을 빠르게 구현 가능
