# YouTube Clone (Commercial VOD Integration PoC)

An educational PoC (Proof of Concept) project that uses an AI coding agent together with the **Kollus VOD Platform**, the **Claude AI SDK**, and **MCP (Model Context Protocol)**
to implement the full cycle — from planning through the iOS frontend, the Cloudflare backend, and integration with a commercial video platform.

---

## Project Goals

- Validate a full-stack application development workflow using AI-assisted tools
- Demonstrate integration with the **Kollus VOD** upload/playback pipeline and callback webhooks
- Call **Claude AI (Haiku)** directly from Cloudflare Workers for automatic video analysis and recommendations
- Build a native video player and Shorts UI/UX with SwiftUI

---

## Key Features

| Feature | Description |
|---|---|
| **Video Streaming** | Reliable playback with the Kollus VOD Player SDK + HLS |
| **Shorts UI** | TikTok/Shorts-style paging view with autoplay on scroll and infinite looping |
| **AI Video Analysis** | Claude Haiku analyzes the thumbnail, title, and tags to automatically extract category, keywords, and mood |
| **AI Recommendation Algorithm** | Recommendation score combining Jaccard similarity (keywords) + category match + channel + log-scaled popularity |
| **Interactions** | Video/comment likes, comments and replies (nested comments), channel subscriptions |
| **User Profiles** | Nickname + Base64 avatar storage, DiceBear fallback |
| **Serverless Architecture** | Ultra-fast edge API and DB with Cloudflare Workers + D1 |

---

## Architecture

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
       └──▶ POST /webhooks/kollus (async callback when encoding completes)
```

---

## Tech Stack

| Area | Technology | Notes |
|---|---|---|
| Mobile App | iOS 17+, SwiftUI | Combine, PhotosUI, KollusPlayer SDK |
| Backend | Cloudflare Workers (TypeScript) | Serverless edge computing |
| DB | Cloudflare D1 | SQLite-based, edge-distributed DB |
| Video Platform | Kollus VOD (Catenoid) | Upload, transcoding, HLS streaming |
| AI Analysis | Anthropic Claude Haiku | Automatic extraction of video category/keywords/mood |
| AI Tools | Claude Code, Kollus MCP | Maximizing development productivity and automatically interpreting API specs |
| Runtime | Node.js compat (Cloudflare) | `nodejs_compat` flag enabled |

---

## API Reference

### Basics

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Server health check |
| GET | `/me` | Returns a userId based on a hash of the client IP |

### Videos

| Method | Path | Description |
|---|---|---|
| GET | `/videos?limit=10&offset=0` | Regular video list (paginated) |
| GET | `/shorts` | Shorts video list (latest 50) |
| PUT | `/videos/:id` | Update video info (owner only, requires `X-Uploader-Id` header) |
| DELETE | `/videos/:id` | Delete video (owner only, cascades to likes and comments) |
| POST | `/views` | Increment view count by 1 `{ videoId }` |

### Upload / Playback (Kollus Integration)

| Method | Path | Description |
|---|---|---|
| POST | `/upload-url` | Issue a Kollus upload URL + create a DB record |
| POST | `/webhooks/kollus` | Receive the Kollus encoding-complete callback, save `status=ready` |
| POST | `/playback-token` | Generate a Kollus playback JWT and return `playbackUrl` |

### Thumbnails

| Method | Path | Description |
|---|---|---|
| GET | `/thumbnail/:uploadFileKey` | Proxy for the original Kollus poster image |
| POST | `/thumbnail-upload` | Save a high-resolution thumbnail (Base64) extracted on iOS |
| GET | `/thumbnail-image/:videoId` | Serve the stored thumbnail binary |

### Users

| Method | Path | Description |
|---|---|---|
| GET | `/users/:id` | Get profile (nickname) |
| PUT | `/users/:id` | Save profile (nickname, avatarData) |
| GET | `/user-avatar/:id` | Serve avatar image (redirects to DiceBear if none) |

### Interactions

| Method | Path | Description |
|---|---|---|
| GET | `/likes?videoId=&userId=` | Get video like count + whether the user liked it |
| POST | `/likes` | Toggle video like `{ videoId, userId }` |
| GET | `/comments?videoId=` | Comment list (newest first) |
| POST | `/comments` | Post a comment/reply `{ videoId, content, userId, parentId? }` |
| POST | `/comment-likes` | Toggle comment like `{ commentId, userId }` |
| GET | `/comment-likes?videoId=&userId=` | List of comment IDs the user has liked |

### Subscriptions

| Method | Path | Description |
|---|---|---|
| GET | `/subscriptions?subscriberId=&channelId=` | Subscription status + subscriber count |
| POST | `/subscriptions` | Toggle subscription `{ subscriberId, channelId }` |
| GET | `/subscriptions/channels?subscriberId=` | List of subscribed channels |
| GET | `/subscriptions/videos?subscriberId=` | Latest videos from subscribed channels |

### AI Analysis / Recommendations (Claude Integration)

| Method | Path | Description |
|---|---|---|
| POST | `/analyze-video` | Analyze a video with Claude Haiku, save `ai_category`/`ai_keywords` |
| GET | `/recommendations?videoId=&limit=10` | AI-based similar video recommendations |

### Admin

| Method | Path | Description |
|---|---|---|
| POST | `/admin/backfill-mckey` | Bulk-fill missing mckeys via the Kollus API |
| POST | `/admin/backfill-uploader` | Bulk-fill missing uploader_id values with IP hashes |
| POST | `/admin/migrate-uploader` | Bulk-replace uploader_id from IP hash → device ID |
| GET | `/debug/mckey?key=` | Inspect the raw Kollus media-contents API response |

---

## DB Schema

```sql
CREATE TABLE users (
  id         TEXT PRIMARY KEY,
  nickname   TEXT,
  avatar_data TEXT,            -- Base64-encoded image
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE videos (
  id                      TEXT PRIMARY KEY,
  title                   TEXT NOT NULL,
  description             TEXT,
  tags                    TEXT,
  thumbnail_url           TEXT,
  thumbnail_data          TEXT,                -- Base64 high-resolution thumbnail
  kollus_upload_file_key  TEXT,
  kollus_media_content_key TEXT,
  uploader_id             TEXT,
  is_short                INTEGER DEFAULT 0,  -- 1 = Shorts
  view_count              INTEGER DEFAULT 0,
  like_count              INTEGER DEFAULT 0,
  ai_category             TEXT,               -- Claude analysis result
  ai_keywords             TEXT,               -- Comma-separated keywords
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
  parent_id  TEXT,             -- NULL means a top-level comment
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

## Kollus VOD Integration Flow

### 1. Upload

```
App → POST /upload-url { title, uploaderId, isShort }
       └→ Worker → Kollus API (create-url) → returns upload_url, upload_file_key
App → uploads the video file directly to upload_url (multipart)
Kollus → POST /webhooks/kollus (when encoding completes)
              └→ Worker: saves status=ready, mckey, thumbnail_url to DB
                         + automatically adds it to the Kollus channel
```

### 2. Playback

```
App → POST /playback-token { videoId }
       └→ Worker → looks up kollus_media_content_key in D1
                  (if missing, queries the Kollus API in real time and caches it)
                  → generates an HS256 JWT (expt: 1 hour)
                  → returns playbackUrl (https://v.kr.kollus.com/si?jwt=...)
App → passes playbackUrl to the KollusPlayer SDK for playback
```

### JWT Payload Structure

```json
{
  "cuid": "anonymous",
  "expt": 1234567890,
  "mc": [{ "mckey": "<media_content_key>" }]
}
```

---

## Claude AI SDK Integration

The Anthropic REST API is called directly from Cloudflare Workers. (Using `fetch` instead of the official SDK — for edge runtime compatibility)

### Video Analysis (`POST /analyze-video`)

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
        // If a thumbnail exists, send the image as well (multimodal)
        { type: 'image', source: { type: 'url', url: thumbnailUrl } },
        { type: 'text', text: '...analysis prompt...' },
      ],
    }],
  }),
});
```

**Analysis input:** title, tags, description, channel ID, thumbnail image (optional)  
**Analysis output:** `category` (11 types such as gaming/music/education), `keywords` (up to 5), `mood` (humor/informative/touching, etc.)  
**Storage:** saved to the `ai_category` and `ai_keywords` columns and used by the recommendation algorithm

### Recommendation Algorithm (`GET /recommendations`)

| Score Component | Max Points | Calculation |
|---|---|---|
| Keyword similarity | 50 | Jaccard similarity × 50 |
| Category match | 25 | +25 for the same category |
| Channel match | 10 | +10 for the same uploader_id |
| View popularity | 10 | log₁₀₀₀(view_count+1) × 10 |
| Like popularity | 5 | log₁₀₀(like_count+1) × 5 |

---

## Required Environment Variables (Secrets)

| Name | Description |
|---|---|
| `KOLLUS_API_ACCESS_TOKEN` | Access token for Kollus API calls |
| `KOLLUS_SECURITY_KEY` | HS256 signing key for playback JWTs |
| `KOLLUS_USER_KEY` | custom_key for playback URLs (channel identifier) |
| `KOLLUS_CATEGORY_KEY` | Kollus category key used for uploads |
| `KOLLUS_CHANNEL_ID` | Kollus channel ID to automatically add videos to after encoding |
| `USER_ID_SALT` | Salt used when generating IP-hash-based userIds |
| `ANTHROPIC_API_KEY` | Claude AI API key |

---

## Getting Started

### Backend

```bash
# 1. Install dependencies
npm install

# 2. Register secrets (first time only)
wrangler secret put KOLLUS_API_ACCESS_TOKEN
wrangler secret put KOLLUS_SECURITY_KEY
wrangler secret put KOLLUS_USER_KEY
wrangler secret put KOLLUS_CATEGORY_KEY
wrangler secret put KOLLUS_CHANNEL_ID
wrangler secret put USER_ID_SALT
wrangler secret put ANTHROPIC_API_KEY

# 3. Run D1 database migrations
wrangler d1 execute youtube-clone-db --remote --file=migrations/0001_init.sql

# 4. Local development server
npm run dev

# 5. Production deployment
npm run deploy
```

### iOS App

1. Open the `YoutubeClone/` project in Xcode
2. **Signing & Capabilities** → change the Bundle Identifier to `com.[your_account].YoutubeClone`
3. Verify that the KollusPlayer SDK is linked correctly
4. **Build & Run** (`⌘R`) on a simulator or a physical device

---

## Working Features Checklist

**Backend**
- ✅ Kollus upload URL issuance + automatic DB record creation
- ✅ Kollus callback handling, saving `status=ready`, and automatic channel assignment
- ✅ Kollus JWT playback URL issuance (including real-time mckey fallback)
- ✅ Video list retrieval (regular / Shorts separated, paginated)
- ✅ Video editing and deletion (with permission checks)
- ✅ View count increment
- ✅ Like toggle (videos / comments)
- ✅ Posting and retrieving comments and replies
- ✅ Channel subscribe/unsubscribe and subscription feed
- ✅ User profile storage (nickname + avatar)
- ✅ Thumbnail storage and serving (Kollus proxy / iOS high-resolution)
- ✅ Claude Haiku multimodal video analysis (category, keywords, mood)
- ✅ AI-based similar video recommendations

**iOS App**
- ✅ Video list screen (feed)
- ✅ Vertical Shorts playback screen
- ✅ KollusPlayer SDK playback URL integration
- ✅ Upload (PhotosUI → Kollus → wait for callback)

---

## MCP Usage Log

During development, the **Kollus MCP** server was connected to Claude Code to automate the following tasks:

- Checking Kollus upload API endpoints and parameter specs
- Understanding the webhook callback payload field structure (`upload_file_key`, `media_content_key`, `transcoding_result`)
- Checking the JWT playback URL generation spec (payload structure, HS256 signing method)
- Looking up how to use the channel attach API

---

## Lessons Learned

- With Cloudflare Workers + D1, you can quickly build a production-grade backend without a separate server
- Converting a Kollus `upload_file_key` → `media_content_key` must be handled via the webhook or an API lookup
- JWTs must always be generated on the backend, with the app receiving only the URL, to avoid exposing keys
- Claude Haiku enables multimodal analysis at low cost and can be called directly from Workers via `fetch`
- With an AI coding agent (Claude Code), even non-CS majors can quickly implement complex full-stack features
