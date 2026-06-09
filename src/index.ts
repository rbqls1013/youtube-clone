export default {
  async fetch(request: Request, env: any): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return Response.json({ status: 'ok', timestamp: new Date().toISOString() });
    }

    // POST /views — 조회수 1 증가
    if (url.pathname === '/views' && request.method === 'POST') {
      const { videoId } = await request.json() as any;
      if (!videoId) return Response.json({ error: 'videoId required' }, { status: 400 });
      await env.DB.prepare('UPDATE videos SET view_count = COALESCE(view_count, 0) + 1 WHERE id = ?').bind(videoId).run();
      return Response.json({ ok: true });
    }

    // GET /user-avatar/:id — 커스텀 아바타 서빙, 없으면 DiceBear redirect
    const userAvatarMatch = url.pathname.match(/^\/user-avatar\/([^/]+)$/);
    if (userAvatarMatch && request.method === 'GET') {
      const userId = userAvatarMatch[1];
      const user = await env.DB.prepare('SELECT avatar_data FROM users WHERE id = ?').bind(userId).first() as any;
      if (user?.avatar_data) {
        const imageData = Uint8Array.from(atob(user.avatar_data), c => c.charCodeAt(0));
        return new Response(imageData, { headers: { 'Content-Type': 'image/jpeg', 'Cache-Control': 'public, max-age=3600' } });
      }
      return Response.redirect(`https://api.dicebear.com/9.x/fun-emoji/png?seed=${userId}&size=128&radius=50`, 302);
    }

    // GET /users/:id — 프로필 조회
    // PUT /users/:id — 프로필 저장
    const userMatch = url.pathname.match(/^\/users\/([^/]+)$/);
    if (userMatch) {
      const userId = userMatch[1];
      if (request.method === 'GET') {
        const user = await env.DB.prepare('SELECT id, nickname FROM users WHERE id = ?').bind(userId).first();
        return Response.json({ user: user || null });
      }
      if (request.method === 'PUT') {
        const body = await request.json() as any;
        const nickname = body.nickname ?? null;
        const avatarData = body.avatarData ?? null;
        const now = new Date().toISOString();
        const existing = await env.DB.prepare('SELECT id FROM users WHERE id = ?').bind(userId).first();
        if (existing) {
          if (avatarData) {
            await env.DB.prepare('UPDATE users SET nickname = COALESCE(?, nickname), avatar_data = ?, updated_at = ? WHERE id = ?')
              .bind(nickname, avatarData, now, userId).run();
          } else {
            await env.DB.prepare('UPDATE users SET nickname = COALESCE(?, nickname), updated_at = ? WHERE id = ?')
              .bind(nickname, now, userId).run();
          }
        } else {
          await env.DB.prepare('INSERT INTO users (id, nickname, avatar_data, created_at, updated_at) VALUES (?, ?, ?, ?, ?)')
            .bind(userId, nickname, avatarData, now, now).run();
        }
        return Response.json({ ok: true, hasAvatar: !!avatarData });
      }
    }

    // GET /subscriptions/videos?subscriberId=X — 구독한 채널의 영상 목록
    if (url.pathname === '/subscriptions/videos' && request.method === 'GET') {
      const subscriberId = url.searchParams.get('subscriberId');
      if (!subscriberId) return Response.json({ error: 'subscriberId required' }, { status: 400 });
      const { results: subs } = await env.DB.prepare(
        'SELECT channel_id FROM subscriptions WHERE subscriber_id = ?'
      ).bind(subscriberId).all() as any;
      if (!subs || subs.length === 0) return Response.json({ videos: [] });
      const placeholders = subs.map(() => '?').join(',');
      const channelIds = subs.map((s: any) => s.channel_id);
      const { results: videos } = await env.DB.prepare(
        `SELECT * FROM videos WHERE uploader_id IN (${placeholders}) AND status = 'ready' ORDER BY created_at DESC`
      ).bind(...channelIds).all();
      return Response.json({ videos });
    }

    // GET /subscriptions/channels?subscriberId=X — 구독 채널 목록
    if (url.pathname === '/subscriptions/channels' && request.method === 'GET') {
      const subscriberId = url.searchParams.get('subscriberId');
      if (!subscriberId) return Response.json({ error: 'subscriberId required' }, { status: 400 });
      const { results } = await env.DB.prepare(
        'SELECT s.channel_id, u.nickname FROM subscriptions s LEFT JOIN users u ON s.channel_id = u.id WHERE s.subscriber_id = ? ORDER BY s.created_at DESC'
      ).bind(subscriberId).all() as any;
      return Response.json({ channels: results || [] });
    }

    // GET /subscriptions?subscriberId=X&channelId=Y
    if (url.pathname === '/subscriptions' && request.method === 'GET') {
      const subscriberId = url.searchParams.get('subscriberId');
      const channelId = url.searchParams.get('channelId');
      if (!subscriberId || !channelId) return Response.json({ error: 'params required' }, { status: 400 });
      const sub = await env.DB.prepare('SELECT 1 FROM subscriptions WHERE subscriber_id = ? AND channel_id = ?').bind(subscriberId, channelId).first();
      const countRow = await env.DB.prepare('SELECT COUNT(*) as count FROM subscriptions WHERE channel_id = ?').bind(channelId).first() as any;
      return Response.json({ subscribed: !!sub, count: countRow?.count ?? 0 });
    }

    // POST /subscriptions — 구독 토글
    if (url.pathname === '/subscriptions' && request.method === 'POST') {
      const { subscriberId, channelId } = await request.json() as any;
      if (!subscriberId || !channelId) return Response.json({ error: 'params required' }, { status: 400 });
      const existing = await env.DB.prepare('SELECT 1 FROM subscriptions WHERE subscriber_id = ? AND channel_id = ?').bind(subscriberId, channelId).first();
      if (existing) {
        await env.DB.prepare('DELETE FROM subscriptions WHERE subscriber_id = ? AND channel_id = ?').bind(subscriberId, channelId).run();
      } else {
        const id = crypto.randomUUID();
        await env.DB.prepare('INSERT INTO subscriptions (id, subscriber_id, channel_id, created_at) VALUES (?, ?, ?, ?)').bind(id, subscriberId, channelId, new Date().toISOString()).run();
      }
      const countRow = await env.DB.prepare('SELECT COUNT(*) as count FROM subscriptions WHERE channel_id = ?').bind(channelId).first() as any;
      return Response.json({ subscribed: !existing, count: countRow?.count ?? 0 });
    }

    // PUT /videos/:id — 영상 정보 수정 (본인만)
    // DELETE /videos/:id — 영상 삭제 (본인만)
    const deleteVideoMatch = url.pathname.match(/^\/videos\/([^/]+)$/);
    if (deleteVideoMatch && request.method === 'PUT') {
      const videoId = deleteVideoMatch[1];
      const uploaderId = request.headers.get('X-Uploader-Id') || '';
      const video = await env.DB.prepare('SELECT uploader_id FROM videos WHERE id = ?').bind(videoId).first() as any;
      if (!video) return Response.json({ error: 'not found' }, { status: 404 });
      if (video.uploader_id !== uploaderId) return Response.json({ error: 'unauthorized' }, { status: 403 });
      const { title, description, tags } = await request.json() as any;
      await env.DB.prepare(
        'UPDATE videos SET title = COALESCE(?, title), description = COALESCE(?, description), tags = COALESCE(?, tags), updated_at = ? WHERE id = ?'
      ).bind(title ?? null, description ?? null, tags ?? null, new Date().toISOString(), videoId).run();
      return Response.json({ ok: true });
    }
    if (deleteVideoMatch && request.method === 'DELETE') {
      const videoId = deleteVideoMatch[1];
      const uploaderId = request.headers.get('X-Uploader-Id') || '';
      const video = await env.DB.prepare('SELECT uploader_id FROM videos WHERE id = ?').bind(videoId).first() as any;
      if (!video) return Response.json({ error: 'not found' }, { status: 404 });
      if (video.uploader_id !== uploaderId) return Response.json({ error: 'unauthorized' }, { status: 403 });
      await env.DB.prepare('DELETE FROM videos WHERE id = ?').bind(videoId).run();
      await env.DB.prepare('DELETE FROM likes WHERE video_id = ?').bind(videoId).run();
      await env.DB.prepare('DELETE FROM comments WHERE video_id = ?').bind(videoId).run();
      return Response.json({ ok: true });
    }

    if (url.pathname === '/debug/mckey' && request.method === 'GET') {
      const key = url.searchParams.get('key') || '';
      const r = await fetch(`https://c-api-kr.kollus.com/api/media-contents/${key}?access_token=${env.KOLLUS_API_ACCESS_TOKEN}`);
      return new Response(await r.text(), { headers: { 'Content-Type': 'application/json' } });
    }

    if (url.pathname === '/admin/backfill-mckey' && request.method === 'POST') {
      const { results } = await env.DB.prepare(
        "SELECT id, kollus_upload_file_key FROM videos WHERE kollus_media_content_key IS NULL AND kollus_upload_file_key IS NOT NULL"
      ).all() as any;

      const log: any[] = [];
      for (const video of results) {
        try {
          const r = await fetch(`https://c-api-kr.kollus.com/api/media-contents/${video.kollus_upload_file_key}?access_token=${env.KOLLUS_API_ACCESS_TOKEN}`);
          const data = await r.json() as any;
          const keys = data?.data?.media_content_keys;
          const mckey = Array.isArray(keys) && keys.length > 0 ? keys[0] : null;
          const posterUrl = data?.data?.poster_url ?? null;
          if (mckey) {
            await env.DB.prepare(
              'UPDATE videos SET kollus_media_content_key = ?, thumbnail_url = COALESCE(thumbnail_url, ?), updated_at = ? WHERE id = ?'
            ).bind(mckey, posterUrl, new Date().toISOString(), video.id).run();
          }
          log.push({ id: video.id, upload_file_key: video.kollus_upload_file_key, mckey, status: r.status });
        } catch (e: any) {
          log.push({ id: video.id, error: e.message });
        }
      }
      return Response.json({ updated: log });
    }

    const thumbnailMatch = url.pathname.match(/^\/thumbnail\/(.+)$/);
    if (thumbnailMatch && request.method === 'GET') {
      const uploadFileKey = thumbnailMatch[1];
      const kollusUrl = `https://c-api-kr.kollus.com/api/media-contents/${uploadFileKey}/poster/download?access_token=${env.KOLLUS_API_ACCESS_TOKEN}`;
      const res = await fetch(kollusUrl);
      return new Response(res.body, {
        status: res.status,
        headers: {
          'Content-Type': res.headers.get('Content-Type') ?? 'image/jpeg',
          'Cache-Control': 'public, max-age=86400',
        },
      });
    }

    // POST /admin/backfill-uploader — 현재 요청자 IP를 uploader_id가 없는 모든 영상에 채움
    if (url.pathname === '/admin/backfill-uploader' && request.method === 'POST') {
      const ip = request.headers.get('CF-Connecting-IP') || '0.0.0.0';
      const data = new TextEncoder().encode(ip + (env.USER_ID_SALT || 'yt-clone-salt'));
      const hash = await crypto.subtle.digest('SHA-256', data);
      const uploaderId = Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('').slice(0, 16);
      const result = await env.DB.prepare(
        "UPDATE videos SET uploader_id = ? WHERE uploader_id IS NULL"
      ).bind(uploaderId).run();
      return Response.json({ ok: true, uploaderId, changes: result.meta.changes });
    }

    // POST /admin/migrate-uploader — IP 해시 기반 uploader_id를 기기 ID로 교체
    if (url.pathname === '/admin/migrate-uploader' && request.method === 'POST') {
      const { newUploaderId } = await request.json() as any;
      if (!newUploaderId) return Response.json({ error: 'newUploaderId required' }, { status: 400 });
      const ip = request.headers.get('CF-Connecting-IP') || '0.0.0.0';
      const data = new TextEncoder().encode(ip + (env.USER_ID_SALT || 'yt-clone-salt'));
      const hash = await crypto.subtle.digest('SHA-256', data);
      const oldUploaderId = Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('').slice(0, 16);
      const result = await env.DB.prepare(
        'UPDATE videos SET uploader_id = ? WHERE uploader_id = ?'
      ).bind(newUploaderId, oldUploaderId).run();
      return Response.json({ ok: true, changes: result.meta.changes, old: oldUploaderId, new: newUploaderId });
    }

    // POST /analyze-video — Claude로 영상 분석 (태그→제목→설명→썸네일 순)
    if (url.pathname === '/analyze-video' && request.method === 'POST') {
      const { videoId } = await request.json() as any;
      if (!videoId) return Response.json({ error: 'videoId required' }, { status: 400 });

      const video = await env.DB.prepare('SELECT * FROM videos WHERE id = ?').bind(videoId).first() as any;
      if (!video) return Response.json({ error: 'not found' }, { status: 404 });

      // 썸네일 URL 결정 (고화질 커스텀 > Kollus 원본)
      const thumbnailUrl = video.thumbnail_url
        ? (video.thumbnail_url.includes('thumbnail-image')
            ? video.thumbnail_url
            : video.thumbnail_url)
        : null;

      // 메시지 구성: 태그 → 제목 → 설명 → 썸네일 → 채널
      const textContent = `다음 영상을 분석하고 JSON으로만 응답하세요. 다른 설명 없이 JSON만 출력하세요.

분석 우선순위: 태그 > 제목 > 설명 > 썸네일 > 채널

제목: ${video.title || '없음'}
태그: ${video.tags || '없음'}
설명: ${video.description || '없음'}
채널ID: ${video.uploader_id || '없음'}

JSON 형식:
{
  "category": "단일 카테고리 (게임/음악/교육/요리/여행/스포츠/뉴스/엔터테인먼트/기술/생활/기타 중 하나)",
  "keywords": ["핵심키워드1", "키워드2", "키워드3", "키워드4", "키워드5"],
  "mood": "분위기 (유머/정보/감동/긴장/일상/리뷰 중 하나)"
}`;

      const messages: any[] = [{
        role: 'user',
        content: thumbnailUrl
          ? [
              { type: 'image', source: { type: 'url', url: thumbnailUrl } },
              { type: 'text', text: textContent }
            ]
          : textContent
      }];

      const claudeRes = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'x-api-key': env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 300,
          messages,
        }),
      });

      if (!claudeRes.ok) {
        const err = await claudeRes.text();
        return Response.json({ error: 'Claude API 오류', detail: err }, { status: 500 });
      }

      const claudeData = await claudeRes.json() as any;
      const rawText = claudeData.content?.[0]?.text || '{}';

      let analysis: any = {};
      try {
        const jsonMatch = rawText.match(/\{[\s\S]*\}/);
        analysis = jsonMatch ? JSON.parse(jsonMatch[0]) : {};
      } catch { analysis = {}; }

      const category = analysis.category || null;
      const keywords = Array.isArray(analysis.keywords)
        ? analysis.keywords.slice(0, 10).join(',')
        : null;

      await env.DB.prepare(
        'UPDATE videos SET ai_category = ?, ai_keywords = ?, ai_analyzed = 1, updated_at = ? WHERE id = ?'
      ).bind(category, keywords, new Date().toISOString(), videoId).run();

      return Response.json({ ok: true, category, keywords, mood: analysis.mood });
    }

    // GET /recommendations?videoId=X&limit=10 — AI 기반 유사 영상 추천
    if (url.pathname === '/recommendations' && request.method === 'GET') {
      const videoId = url.searchParams.get('videoId');
      const limit = parseInt(url.searchParams.get('limit') || '10');
      if (!videoId) return Response.json({ videos: [] });

      const target = await env.DB.prepare('SELECT * FROM videos WHERE id = ?').bind(videoId).first() as any;
      if (!target) return Response.json({ videos: [] });

      const { results: allVideos } = await env.DB.prepare(
        "SELECT * FROM videos WHERE id != ? AND status = 'ready' ORDER BY created_at DESC LIMIT 100"
      ).bind(videoId).all() as any;

      const targetKeywords = new Set<string>(
        [
          ...(target.ai_keywords || '').split(','),
          ...(target.tags || '').split(','),
          ...(target.title || '').split(/\s+/),
        ].map((k: string) => k.trim().toLowerCase()).filter(Boolean)
      );

      const scored = (allVideos || []).map((v: any) => {
        const vKeywords = new Set<string>(
          [
            ...(v.ai_keywords || '').split(','),
            ...(v.tags || '').split(','),
            ...(v.title || '').split(/\s+/),
          ].map((k: string) => k.trim().toLowerCase()).filter(Boolean)
        );

        // 키워드 유사도 (Jaccard)
        let shared = 0;
        targetKeywords.forEach(k => { if (vKeywords.has(k)) shared++; });
        const union = new Set([...targetKeywords, ...vKeywords]).size;
        const keywordScore = union > 0 ? (shared / union) * 50 : 0;

        // 카테고리 일치
        const categoryScore = (target.ai_category && v.ai_category === target.ai_category) ? 25 : 0;

        // 같은 채널
        const channelScore = (target.uploader_id && v.uploader_id === target.uploader_id) ? 10 : 0;

        // 인기도 (로그 스케일)
        const viewScore = Math.min(Math.log((v.view_count || 0) + 1) / Math.log(1000) * 10, 10);
        const likeScore = Math.min(Math.log((v.like_count || 0) + 1) / Math.log(100) * 5, 5);

        return { ...v, _score: keywordScore + categoryScore + channelScore + viewScore + likeScore };
      });

      scored.sort((a: any, b: any) => b._score - a._score);
      const top = scored.slice(0, limit).map(({ _score, ...v }: any) => v);

      return Response.json({ videos: top });
    }

    // GET /me — IP 해시 기반 userId 반환
    if (url.pathname === '/me' && request.method === 'GET') {
      const ip = request.headers.get('CF-Connecting-IP') || '0.0.0.0';
      const data = new TextEncoder().encode(ip + (env.USER_ID_SALT || 'yt-clone-salt'));
      const hash = await crypto.subtle.digest('SHA-256', data);
      const userId = Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('').slice(0, 16);
      return Response.json({ userId });
    }

    // POST /thumbnail-upload — iOS에서 추출한 고해상도 썸네일 저장
    if (url.pathname === '/thumbnail-upload' && request.method === 'POST') {
      const body = await request.json() as any;
      const { videoId, imageBase64 } = body;
      if (!videoId || !imageBase64) {
        return Response.json({ error: 'videoId and imageBase64 required' }, { status: 400 });
      }
      const thumbnailUrl = `${url.origin}/thumbnail-image/${videoId}`;
      await env.DB.prepare(
        'UPDATE videos SET thumbnail_data = ?, thumbnail_url = ?, updated_at = ? WHERE id = ?'
      ).bind(imageBase64, thumbnailUrl, new Date().toISOString(), videoId).run();
      return Response.json({ ok: true, thumbnailUrl });
    }

    // GET /thumbnail-image/:videoId — 저장된 썸네일 바이너리 서빙
    const thumbnailImageMatch = url.pathname.match(/^\/thumbnail-image\/(.+)$/);
    if (thumbnailImageMatch && request.method === 'GET') {
      const videoId = thumbnailImageMatch[1];
      const row = await env.DB.prepare(
        'SELECT thumbnail_data FROM videos WHERE id = ?'
      ).bind(videoId).first() as any;
      if (!row?.thumbnail_data) {
        return new Response('Not found', { status: 404 });
      }
      const imageData = Uint8Array.from(atob(row.thumbnail_data), c => c.charCodeAt(0));
      return new Response(imageData, {
        headers: {
          'Content-Type': 'image/jpeg',
          'Cache-Control': 'public, max-age=86400',
        },
      });
    }

    if (url.pathname === '/shorts' && request.method === 'GET') {
      try {
        const { results } = await env.DB.prepare(
          "SELECT * FROM videos WHERE is_short = 1 AND status = 'ready' ORDER BY created_at DESC LIMIT 50"
        ).all();
        return Response.json({ videos: results || [] });
      } catch {
        return Response.json({ videos: [] });
      }
    }

    if (url.pathname === '/videos' && request.method === 'GET') {
      const limit = Math.min(parseInt(url.searchParams.get('limit') || '10'), 50);
      const offset = parseInt(url.searchParams.get('offset') || '0');
      try {
        const { results } = await env.DB.prepare(
          'SELECT * FROM videos WHERE (is_short IS NULL OR is_short = 0) ORDER BY created_at DESC LIMIT ? OFFSET ?'
        ).bind(limit, offset).all();
        const countRow = await env.DB.prepare(
          'SELECT COUNT(*) as total FROM videos WHERE (is_short IS NULL OR is_short = 0)'
        ).first() as any;
        return Response.json({ videos: results, total: countRow?.total ?? 0 });
      } catch {
        const { results } = await env.DB.prepare(
          'SELECT * FROM videos ORDER BY created_at DESC LIMIT ? OFFSET ?'
        ).bind(limit, offset).all();
        const countRow = await env.DB.prepare('SELECT COUNT(*) as total FROM videos').first() as any;
        return Response.json({ videos: results, total: (countRow as any)?.total ?? 0 });
      }
    }

    if (url.pathname === '/upload-url' && request.method === 'POST') {
      const body = await request.json() as any;
      const title = body.title || '제목 없음';
      const videoId = crypto.randomUUID();
      // 클라이언트가 보낸 기기 ID 우선, 없으면 IP 해시 fallback
      let uploaderId: string = body.uploaderId || '';
      if (!uploaderId) {
        const ip = request.headers.get('CF-Connecting-IP') || '0.0.0.0';
        const ipData = new TextEncoder().encode(ip + (env.USER_ID_SALT || 'yt-clone-salt'));
        const ipHash = await crypto.subtle.digest('SHA-256', ipData);
        uploaderId = Array.from(new Uint8Array(ipHash)).map(b => b.toString(16).padStart(2, '0')).join('').slice(0, 16);
      }

      const kollusRes = await fetch('https://c-api-kr.kollus.com/api/upload/create-url', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          access_token: env.KOLLUS_API_ACCESS_TOKEN,
          title,
          category_key: env.KOLLUS_CATEGORY_KEY,
        }).toString(),
      });

      const kollusData = await kollusRes.json() as any;

      if (kollusData.status !== 'ok') {
        return Response.json({ error: 'Kollus 업로드 URL 발급 실패', detail: kollusData }, { status: 500 });
      }

      const uploadUrl = kollusData.data?.upload_url;
      const uploadFileKey = kollusData.data?.upload_file_key;
      const now = new Date().toISOString();

      const description = body.description || null;
      const tags = body.tags || null;
      const isShort = body.isShort ? 1 : 0;
      try {
        await env.DB.prepare(
          'INSERT INTO videos (id, title, description, tags, kollus_upload_file_key, status, uploader_id, is_short, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        ).bind(videoId, title, description, tags, uploadFileKey, 'uploading', uploaderId, isShort, now, now).run();
      } catch {
        await env.DB.prepare(
          'INSERT INTO videos (id, title, description, tags, kollus_upload_file_key, status, uploader_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
        ).bind(videoId, title, description, tags, uploadFileKey, 'uploading', uploaderId, now, now).run();
      }

      return Response.json({ videoId, uploadUrl, uploadFileKey });
    }

    if (url.pathname === '/webhooks/kollus' && request.method === 'POST') {
      const rawText = await request.text();
      const params = new URLSearchParams(rawText);

      const allFields: Record<string, string> = {};
      params.forEach((value, key) => { allFields[key] = value; });
      console.log('[Webhook] 모든 필드:', JSON.stringify(allFields));

      const updateType = params.get('update_type');
      if (updateType) {
        return Response.json({ ok: true, skipped: true });
      }

      const uploadFileKey = params.get('upload_file_key');
      const mediaContentKey =
        params.get('media_content_key') ??
        params.get('content_key') ??
        params.get('mckey') ??
        null;
      const transcodingResult = params.get('transcoding_result');
      const title = params.get('title');

      let status = 'processing';
      if (transcodingResult === '1' || transcodingResult === 'success') {
        status = 'ready';
      } else if (transcodingResult === '0' || transcodingResult === 'fail') {
        status = 'failed';
      }

      const now = new Date().toISOString();

      if (!uploadFileKey) {
        if (!mediaContentKey) {
          return Response.json({ ok: true, skipped: true });
        }
        const videoId = crypto.randomUUID();
        await env.DB.prepare(
          'INSERT INTO videos (id, title, kollus_media_content_key, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)'
        ).bind(videoId, title ?? mediaContentKey, mediaContentKey, status, now, now).run();
        return Response.json({ ok: true, created: true, videoId });
      }

      let resolvedThumbnailUrl: string | null = null;

      // Kollus API로 썸네일 조회
      try {
        const apiUrl = `https://c-api-kr.kollus.com/api/media-contents/${uploadFileKey}?access_token=${env.KOLLUS_API_ACCESS_TOKEN}`;
        const r = await fetch(apiUrl);
        const data = await r.json() as any;
        resolvedThumbnailUrl = data?.data?.poster_url ?? null;
      } catch (e) {
        console.log('[Webhook] API 조회 실패:', e);
      }

      // 채널에 자동 추가
      try {
        await fetch(`https://c-api-kr.kollus.com/api/channels/${env.KOLLUS_CHANNEL_ID}/media-contents/${uploadFileKey}/attach`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ access_token: env.KOLLUS_API_ACCESS_TOKEN }).toString(),
        });
        console.log('[Webhook] 채널 추가 완료:', uploadFileKey);
      } catch (e) {
        console.log('[Webhook] 채널 추가 실패:', e);
      }

      const existing = await env.DB.prepare(
        'SELECT id FROM videos WHERE kollus_upload_file_key = ?'
      ).bind(uploadFileKey).first();

      if (existing) {
        await env.DB.prepare(
          'UPDATE videos SET status = ?, title = COALESCE(?, title), thumbnail_url = COALESCE(thumbnail_url, ?), updated_at = ? WHERE kollus_upload_file_key = ?'
        ).bind(status, title, resolvedThumbnailUrl, now, uploadFileKey).run();
      } else {
        const videoId = crypto.randomUUID();
        await env.DB.prepare(
          'INSERT INTO videos (id, title, kollus_upload_file_key, thumbnail_url, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
        ).bind(videoId, title ?? uploadFileKey, uploadFileKey, resolvedThumbnailUrl, status, now, now).run();
      }

      return Response.json({ ok: true });
    }

    if (url.pathname === '/playback-token' && request.method === 'POST') {
      const body = await request.json() as any;
      const videoId = body.videoId;

      if (!videoId) {
        return Response.json({ error: 'videoId missing' }, { status: 400 });
      }

      const video = await env.DB.prepare(
        'SELECT * FROM videos WHERE id = ?'
      ).bind(videoId).first() as any;

      if (!video) {
        return Response.json({ error: '영상을 찾을 수 없습니다' }, { status: 404 });
      }

      if (video.status !== 'ready') {
        return Response.json({ error: '아직 재생 준비가 안 된 영상입니다', status: video.status }, { status: 400 });
      }

      let mediaContentKey = video.kollus_media_content_key;

      // mckey 없으면 Kollus API로 실시간 조회
      if (!mediaContentKey && video.kollus_upload_file_key) {
        try {
          const r = await fetch(`https://c-api-kr.kollus.com/api/media-contents/${video.kollus_upload_file_key}?access_token=${env.KOLLUS_API_ACCESS_TOKEN}`);
          const data = await r.json() as any;
          const keys = data?.data?.media_content_keys;
          mediaContentKey = Array.isArray(keys) && keys.length > 0 ? keys[0] : null;
          if (mediaContentKey) {
            const posterUrl = data?.data?.poster_url ?? null;
            await env.DB.prepare(
              'UPDATE videos SET kollus_media_content_key = ?, thumbnail_url = COALESCE(thumbnail_url, ?), updated_at = ? WHERE id = ?'
            ).bind(mediaContentKey, posterUrl, new Date().toISOString(), videoId).run();
            console.log('[Playback] mckey 실시간 조회 성공:', mediaContentKey);
          }
        } catch (e) {
          console.log('[Playback] mckey 조회 실패:', e);
        }
      }

      if (!mediaContentKey) {
        return Response.json({ error: 'media_content_key가 없습니다. 잠시 후 다시 시도해주세요.' }, { status: 400 });
      }

      const customKey = env.KOLLUS_USER_KEY;
      const securityKey = env.KOLLUS_SECURITY_KEY;
      const expt = Math.floor(Date.now() / 1000) + 3600;
      const payload = {
        cuid: 'anonymous',
        expt,
        mc: [{ mckey: mediaContentKey }],
      };

      const header = { alg: 'HS256', typ: 'JWT' };
      const encode = (obj: any) => btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
      const headerB64 = encode(header);
      const payloadB64 = encode(payload);
      const signingInput = `${headerB64}.${payloadB64}`;

      const key = await crypto.subtle.importKey(
        'raw',
        new TextEncoder().encode(securityKey),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign']
      );

      const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signingInput));
      const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
        .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

      const jwt = `${signingInput}.${signatureB64}`;
      const playbackUrl = `https://v.kr.kollus.com/si?jwt=${jwt}&custom_key=${customKey}`;

      return Response.json({ playbackUrl });
    }

    if (url.pathname === '/likes' && request.method === 'GET') {
      const videoId = url.searchParams.get('videoId');
      const userId = url.searchParams.get('userId') || 'anonymous';

      if (!videoId) {
        return Response.json({ error: 'videoId missing' }, { status: 400 });
      }

      const countRow = await env.DB.prepare(
        'SELECT COUNT(*) as count FROM likes WHERE video_id = ?'
      ).bind(videoId).first() as any;

      const likedRow = await env.DB.prepare(
        'SELECT 1 FROM likes WHERE user_id = ? AND video_id = ?'
      ).bind(userId, videoId).first();

      return Response.json({ count: countRow?.count ?? 0, liked: !!likedRow });
    }

    if (url.pathname === '/likes' && request.method === 'POST') {
      const body = await request.json() as any;
      const videoId = body.videoId;
      const userId = body.userId || 'anonymous';

      if (!videoId) {
        return Response.json({ error: 'videoId missing' }, { status: 400 });
      }

      const existing = await env.DB.prepare(
        'SELECT * FROM likes WHERE user_id = ? AND video_id = ?'
      ).bind(userId, videoId).first();

      if (existing) {
        await env.DB.prepare(
          'DELETE FROM likes WHERE user_id = ? AND video_id = ?'
        ).bind(userId, videoId).run();
      } else {
        const now = new Date().toISOString();
        await env.DB.prepare(
          'INSERT INTO likes (user_id, video_id, created_at) VALUES (?, ?, ?)'
        ).bind(userId, videoId, now).run();
      }

      const countRow = await env.DB.prepare(
        'SELECT COUNT(*) as count FROM likes WHERE video_id = ?'
      ).bind(videoId).first() as any;

      return Response.json({ liked: !existing, count: countRow?.count ?? 0 });
    }

    // POST /comment-likes — 댓글 좋아요 토글
    if (url.pathname === '/comment-likes' && request.method === 'POST') {
      const { commentId, userId } = await request.json() as any;
      if (!commentId || !userId) return Response.json({ error: 'params required' }, { status: 400 });
      const existing = await env.DB.prepare('SELECT 1 FROM comment_likes WHERE comment_id = ? AND user_id = ?').bind(commentId, userId).first();
      if (existing) {
        await env.DB.prepare('DELETE FROM comment_likes WHERE comment_id = ? AND user_id = ?').bind(commentId, userId).run();
        await env.DB.prepare('UPDATE comments SET like_count = MAX(0, COALESCE(like_count,0) - 1) WHERE id = ?').bind(commentId).run();
        return Response.json({ liked: false });
      } else {
        await env.DB.prepare('INSERT INTO comment_likes (id, comment_id, user_id, created_at) VALUES (?,?,?,?)').bind(crypto.randomUUID(), commentId, userId, new Date().toISOString()).run();
        await env.DB.prepare('UPDATE comments SET like_count = COALESCE(like_count,0) + 1 WHERE id = ?').bind(commentId).run();
        return Response.json({ liked: true });
      }
    }

    // GET /comment-likes?videoId=X&userId=Y — 내가 좋아요한 댓글 ID 목록
    if (url.pathname === '/comment-likes' && request.method === 'GET') {
      const videoId = url.searchParams.get('videoId');
      const userId = url.searchParams.get('userId');
      if (!videoId || !userId) return Response.json({ likedIds: [] });
      const { results } = await env.DB.prepare(
        'SELECT cl.comment_id FROM comment_likes cl JOIN comments c ON cl.comment_id = c.id WHERE c.video_id = ? AND cl.user_id = ?'
      ).bind(videoId, userId).all() as any;
      return Response.json({ likedIds: (results || []).map((r: any) => r.comment_id) });
    }

    if (url.pathname === '/comments' && request.method === 'GET') {
      const videoId = url.searchParams.get('videoId');
      if (!videoId) return Response.json({ error: 'videoId missing' }, { status: 400 });
      const { results } = await env.DB.prepare(
        'SELECT * FROM comments WHERE video_id = ? ORDER BY created_at DESC'
      ).bind(videoId).all();
      return Response.json({ comments: results });
    }

    if (url.pathname === '/comments' && request.method === 'POST') {
      const body = await request.json() as any;
      const { videoId, content, userId = 'anonymous', parentId = null } = body;
      if (!videoId || !content) return Response.json({ error: 'videoId, content 필요' }, { status: 400 });
      const id = crypto.randomUUID();
      const now = new Date().toISOString();
      await env.DB.prepare(
        'INSERT INTO comments (id, video_id, user_id, content, parent_id, created_at) VALUES (?, ?, ?, ?, ?, ?)'
      ).bind(id, videoId, userId, content, parentId, now).run();
      return Response.json({ id, videoId, userId, content, parentId, createdAt: now });
    }

    return Response.json({ error: 'Not found' }, { status: 404 });
  }
}