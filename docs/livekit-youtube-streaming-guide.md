# LiveKit → YouTube Live Streaming Guide

How to live-stream an ALIVE Meet room (a LiveKit session) to **YouTube Live** using
LiveKit **Egress** over RTMP. This streams the same room your app already joins via
`wss://livekit.alivenigeria.org`.

---

## 1. How it works (architecture)

```
                LiveKit Room (alive-meet-*)
      participants  ▲            ▲ participants join
                    │            │
            ┌───────┴────────────┴────────┐
            │      livekit-server         │  <-- already deployed
            └─────────────┬──────────────┘
                          │ Redis (shared)
            ┌─────────────┴──────────────┐
            │     livekit-egress (NEW)   │  <-- must deploy, see §3
            │  joins room, composes,     │
            │  re-encodes to RTMP        │
            └─────────────┬──────────────┘
                          │ rtmp://a.rtmp.youtube.com/live2  (+ stream key)
                     ┌────▼────┐
                     │ YouTube │
                     │  Live   │
                     └─────────┘
```

**Key fact (from the official Egress service docs):** for **self-hosted** LiveKit,
*egress is a separate service* deployed alongside the main `livekit-server` process.
It is **not** built into the single server binary. It uses Redis to talk to your
server and load-balance. (Cloud customers get it for free; you're self-hosted, so
you run the `livekit/egress` container.)

> The `livekit_client` (Dart) package in your app is a *client* SDK — it cannot
> push an RTMP stream to YouTube. All RTMP broadcasting happens **server-side** via
> Egress. Your Flutter app only tells the backend "go live" / "stop live".

---

## 2. Prerequisites

1. **LiveKit server** reachable at `wss://livekit.alivenigeria.org` (already deployed).
2. **LiveKit API key + secret** — the same `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET`
   already used by your `createLiveKitToken` Appwrite function.
3. **Redis** reachable by both `livekit-server` and `livekit-egress` (shared connection).
4. **YouTube stream key** — see §4.
5. Enough CPU/RAM on the server. **RoomComposite Egress** (compositing video) wants
   **at least 4 vCPU and 4 GB RAM** per active egress. A small Oracle AArch64 free
   instance will be tight; plan to size up or use a single Track-composite egress if
   you only need one presenter's video.
6. `livekit-server-sdk` — already in `appwrite_functions/createLiveKitToken/package.json`
   (`^2.13.1`), so the broadcast function can reuse it.

---

## 3. Deploy the Egress service (self-hosted)

### 3.1 Add Redis (if not present)
LiveKit server + egress both need a shared Redis. Add a Redis container to your
Compose stack (or reuse an existing one).

### 3.2 Egress configuration file (`egress-config.yaml`)
```yaml
# egress-config.yaml
api_key: YOUR_LIVEKIT_API_KEY
api_secret: YOUR_LIVEKIT_API_SECRET
ws_url: wss://livekit.alivenigeria.org

redis:
  address: redis:6379

prometheus_port: 9094

# Renderer used by Room/Track-composite. For headless servers this is fine.
# If you need specific chrome flags, add them here.
logging:
  level: info
```

### 3.3 Docker Compose service
```yaml
  livekit-egress:
    image: livekit/egress:latest
    restart: unless-stopped
    depends_on: [redis, livekit-server]
    environment:
      EGRESS_CONFIG_FILE: /out/config.yaml
      # Optional overrides if not in the file:
      LIVEKIT_URL: wss://livekit.alivenigeria.org
      REDIS: redis://redis:6379
    volumes:
      - ./egress-config.yaml:/out/config.yaml
    # IMPORTANT (as of v1.7.6): Chrome sandboxing requires this flag
    cap_add:
      - SYS_ADMIN
    ports:
      - "9094:9094"   # prometheus (optional)
```

> [!WARNING]
> **Do not omit `cap_add: [SYS_ADMIN]`.** Without it, every RoomComposite/Web egress
> fails with `chrome failed to start`. If you prefer Chrome's sandbox on, you must
> also pass the seccomp profile — simplest is to keep it off with `cap_add` as above.

### 3.4 Make sure `livekit-server` knows about egress
Both processes must talk to the **same Redis** and use the **same API key/secret**.
Add/confirm a `redis:` block in your main `livekit-server` config so it shares the
queue that egress workers listen on.

Then restart the stack:
```bash
sudo docker compose up -d
sudo docker compose logs -f livekit-egress   # confirm "ready"
```

### 3.5 Deploying egress on Coolify (Docker Compose build pack)

Coolify treats the `docker-compose.y[a]ml` **file as the single source of truth** —
you do not enter cap_add, volumes, or environment variables in the Coolify UI for a
compose-based resource; everything is defined in the compose file itself.

Add a **Coolify Application → Build Pack = `Docker Compose`** (or use **Raw Compose
Deployment** to paste the file with minimal Coolify magic). The **`configs`** top-level
element is the Coolify-native way to create a config *file* inline (the "create a file
with content" feature) instead of a relative bind mount like `./egress-config.yaml`,
which does not exist inside a Coolify build.

Minimum Coolify-ready services:
```yaml
version: "3.8"

redis:
  image: redis:7-alpine
  restart: unless-stopped
  command: redis-server
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 3s
    retries: 5
  volumes:
    - redis-data:/data

livekit-server:
  image: livekit/livekit-server:latest
  restart: unless-stopped
  depends_on:
    redis:
      condition: service_healthy
  command: --config /etc/livekit.yaml
  volumes:
    - livekit-config:/etc
  ports:
    - "7880:7880"
    - "7881:7881"
    - "50100-50200:50100-50200/udp"
  environment:
    - LIVEKIT_KEYS=devkey:devsecret   # replace with your real key:secret

livekit-egress:
  image: livekit/egress:latest
  restart: unless-stopped
  depends_on:
    livekit-server:
      condition: service_started
    redis:
      condition: service_healthy
  environment:
    EGRESS_CONFIG_FILE: /out/config.yaml
  configs:
    - source: egress_config
      target: /out/config.yaml
  # REQUIRED as of livekit/egress v1.7.6 - without this every RoomComposite
  # egress fails with "chrome failed to start"
  cap_add:
    - SYS_ADMIN
  # Keep egress private. Only publish if you need Prometheus scraping, and bind localhost.
  # ports:
  #   - "127.0.0.1:9094:9094"

configs:
  egress_config:
    content: |
      api_key: devkey
      api_secret: devsecret
      ws_url: wss://livekit.alivenigeria.org
      redis:
        address: redis:6379
      logging:
        level: info
      prometheus_port: 9094

volumes:
  redis-data:
  livekit-config:
```

Deployment quick-notes:
- No domain is needed — egress and redis stay on Coolify's internal network; services
  resolve each other by name (`redis:6379`).
- Secrets can be interpolated with `${LIVEKIT_KEY}` referencing variables you define in
  Coolify's **Environment Variables / Secrets** tab for that resource.
- If the LiveKit server is already a **separate** Coolify resource, either copy egress
  into that stack (to share its internal Redis) or, in a fresh stack, point the egress
  `configs` `ws_url` at the server's public address and set `redis.address` to the real
  Redis hostname. Both processes must share the same API key/secret and the same Redis.
- The `YOUTUBE_STREAM_KEY` does **not** belong in this compose file — it is a
  server-side variable of the `startLiveKitBroadcast` Appwrite function only.

---

## 4. Set up the YouTube end

1. Sign in to [YouTube Studio](https://studio.youtube.com/).
2. Click **Create ▸ Go live**.
3. Choose **Stream** (not "Camera").
4. In **Stream settings** ▸ **Copy stream key**.
5. The ingest URL YouTube shows is `rtmp://a.rtmp.youtube.com/live2`. YouTube appends
   your stream key: `rtmp://a.rtmp.youtube.com/live2/<STREAM_KEY>`.
6. Recommended stream encoder settings for LiveKit Egress output:
   - Resolution: **1920x1080** (or 1280x720 to save CPU)
   - Frame rate: **30 fps**
   - Video codec: **H.264** (Egress default)
   - Audio: **AAC 48 kHz** (Egress default)
   - Bitrate: >= ~4–6 Mbps for 1080p (Lower bitrate can trigger "poor connection" and
     cut the stream offline)

> YouTube Live auto-stops if it receives no data for a short window. Keep the room
> active (someone publishing video/audio) while "Go Live" is on.

---

## 5. Server-side broadcast function

Create an Appwrite function (or a small Node microservice) that starts/stops egress.
It must run **server-side** so the YouTube stream key is never in client code.

### Package dependency
Reuse `livekit-server-sdk` (`^2.13.1`) — the same dependency already declared in
`appwrite_functions/createLiveKitToken/package.json`.

### Function source (`src/main.js` sketch)
```js
import { EgressClient, RtmpOutput } from 'livekit-server-sdk';

const host = process.env.LIVEKIT_URL || 'wss://livekit.alivenigeria.org';
const egress = new EgressClient(
  host,
  process.env.LIVEKIT_API_KEY,
  process.env.LIVEKIT_API_SECRET || process.env.LIVEKIT_SECRET,
);

// Choose the room: reject requests for any room not in an allow-list.
const ALLOWED_ROOMS = new Set([
  'alive-meet-community', 'alive-meet-prayer',
  'alive-meet-leadership', 'alive-meet-board',
]);

export default async ({ req, res }) => {
  if (req.method !== 'POST') return res.json({ error: 'Use POST.' }, 405);
  const userId = req.headers['x-appwrite-user-id'];
  if (!userId) return res.json({ error: 'Authentication required.' }, 401);

  const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  const { roomName, action } = body;

  // Only allowed roles may stream to YouTube (mirror the meeting token checks).
  // ... verify the user's role against the same users table used by createLiveKitToken ...

  if (!ALLOWED_ROOMS.has(roomName)) {
    return res.json({ error: 'Room not allowed for broadcast.' }, 403);
  }

  try {
    if (action === 'start') {
      const egressId = await egress.startRoomCompositeEgress(
        roomName,
        new RtmpOutput('rtmp://a.rtmp.youtube.com/live2', process.env.YOUTUBE_STREAM_KEY),
        {
          layout: 'speaker-layout',   // or 'grid-layout'
          width: 1920, height: 1080, fps: 30,
        },
      );
      return res.json({ egressId, status: 'started' });
    }

    if (action === 'stop') {
      await egress.stopEgress(body.egressId);
      return res.json({ status: 'stopped' });
    }

    if (action === 'list') {
      return res.json({ egresses: await egress.listEgress() });
    }

    return res.json({ error: 'Unknown action.' }, 400);
  } catch (err) {
    return res.json({ error: `Broadcast failed: ${err.message}` }, 503);
  }
};
```

> [!NOTE]
> **API-version nuance:** `livekit-server-sdk` changed this surface in v1→v2.
> The classic `startRoomCompositeEgress(roomName, output, options)` shown above still
> works in v2. If your installed SDK exposes the newer builder style, use
> `RoomCompositeEgress` / `RtmpOutput.builder()` instead. Confirm against the installed
> typings (`node -e "console.log(require.resolve('livekit-server-sdk'))"` → check
> `dist/index.d.ts`) before deploying.

### Required function env vars (set in Coolify/Appwrite console & `.env`)
| Variable | Purpose |
|---|---|
| `LIVEKIT_API_KEY` | LiveKit API key |
| `LIVEKIT_API_SECRET` | LiveKit API secret |
| `LIVEKIT_URL` | `wss://livekit.alivenigeria.org` |
| `YOUTUBE_STREAM_KEY` | The key copied from YouTube Studio (§4) — **server-side only** |
| `APPWRITE_*` (auth/db keys) | For role verification, reuse the pattern from `createLiveKitToken` |

| Function | Execute | Security |
|---|---|---|
| `startYouTubeEgress` (or similar) | `users` (authenticated) | Role-check inside so only leaders/admins/board can Go Live |

Add it to `appwrite.config.json` next to `createLiveKitToken`, then deploy with
`npm run appwrite:deploy-functions` (and set vars via
`npm run appwrite:function-vars`).

---

## 6. Wire it into the Flutter app

Follow your hexagonal pattern — `livekit_client` must **only** live in the adapter.

### 6.1 Extend the port (`lib/services/ports/meeting_gateway.dart`)
```dart
/// Starts broadcasting the current room to an external platform (e.g. YouTube).
Future<String> startBroadcast({ required String meetingType });

/// Stops an active external broadcast.
Future<void> stopBroadcast(String egressId);

/// Whether a broadcast is currently in progress.
bool get isBroadcasting;
```

### 6.2 Implement in `LiveKitMeetingGateway` (adapter)
The adapter holds the room name; it calls the **Appwrite function** (not YouTube
directly). Add fields `bool _isBroadcasting` and `String? _egressId`, and implement
using the same Appwrite-function HTTP call pattern already used elsewhere in the
adapter (see its existing token/role calls).

```dart
@override
Future<String> startBroadcast({required String meetingType}) async {
  // 1. resolve room name from meetingType (general/prayer/leadership/board)
  // 2. POST to the Appwrite function with { action: 'start', roomName }
  //    include the Appwrite session (x-appwrite-user-id) for role auth
  // 3. store returned egressId, set _isBroadcasting = true, notifyListeners()
  // 4. return egressId
}

@override
Future<void> stopBroadcast(String egressId) async {
  // POST { action: 'stop', egressId }
  _isBroadcasting = false;
  notifyListeners();
}
```

### 6.3 UI — "Go Live" button
Add a small control-bar button next to the camera/mic toggles in your meeting screen:
- If `!gateway.isBroadcasting` → "Go Live" calls `startBroadcast`.
- Else → "Stop" calls `stopBroadcast`.
- Show a status chip only for users whose role passed the backend check (the backend
  enforces it; the button is just UX).

---

## 7. Operations & troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `chrome failed to start` | Missing `cap_add: [SYS_ADMIN]` in the egress container. Add it and recreate. |
| Stream never appears on YouTube | Room has no active publisher (empty room) — keep camera/mic publishing; low bitrate can also cut it. |
| Egress starts then ends immediately | Room went empty. Egress ends when there is no audio/video to compose. |
| "Not configured" (`503`) from function | `LIVEKIT_API_KEY/SECRET` or `YOUTUBE_STREAM_KEY` missing in the function's env. Run `appwrite:function-vars`. |
| Connect refused between egress & server | Both must share the same Redis and use the same LiveKit API key/secret. |
| Poor CPU on Oracle free tier | Use 720p / 24fps, or `TrackComposite`/single `TrackEgress`, or scale the instance for events that need Go Live. |

**To stop a broadcast reliably,** call `stopEgress(egressId)` from the Appwrite
function (don't rely on killing the client) — and consider auto-stopping egress in
your meeting cleanup/`leaveMeeting` path so a dropped presenter doesn't leave an
orphan RTMP session burning CPU.

---

## 8. Security notes
- **Never ship the YouTube stream key** in Flutter/HTML code — it lives only as a
  server-side env var (`YOUTUBE_STREAM_KEY`) in the Appwrite function.
- Gate "Go Live" by **role** inside the backend function, not by showing/hiding a
  button.
- Restrict egress to an allow-list of room names (see `ALLOWED_ROOMS`) to prevent an
  attacker from pointing egress at arbitrary rooms.
- Keep the same `databases.read`/role-check pattern already in `createLiveKitToken`.