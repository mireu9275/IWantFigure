# IWantFigure server

Backend for the IWantFigure crane-game (クレーンゲーム / UFOキャッチャー) "where to aim" coach app.
The mobile app posts **one photo**; this server prepares it, sends it to a multimodal LLM
together with the fixed CraneCoach system prompt and the JSON schema, normalizes the answer
and returns it. ASP.NET Core minimal API, .NET 10, C#.

```
phone ──POST /api/v1/analyze──▶ server ──▶ resize/orient ──▶ LLM (mock | Gemini | Claude)
                                    ◀── normalize (0..1 boxes, enums, schema check) ◀──┘
```

The schema (`shared/analysis.schema.json`), the prompt (`shared/prompt/system_prompt.md`)
and the mock sample (`shared/samples/bridge_parallel.json`) are **linked** into the server
as embedded resources, so there is a single copy shared with the Flutter app.

## Requirements

* .NET SDK 10.0 (`dotnet --version` → 10.0.x)
* For Docker: any recent Docker with BuildKit.

## Run

```bash
cd server
dotnet run --project IWantFigure.Server        # http://localhost:8080, provider = mock
curl -s http://localhost:8080/healthz          # {"status":"ok","provider":"mock"}
```

The default listen address (`http://localhost:8080`) is set in `Program.cs` only when nothing
else configured one, so the standard overrides work as usual:

```bash
ASPNETCORE_URLS=http://0.0.0.0:9000 dotnet run --project IWantFigure.Server
dotnet run --project IWantFigure.Server -- --urls http://0.0.0.0:9000
```

(`Properties/launchSettings.json` deliberately has no `applicationUrl`, because `dotnet run`
would let it override `ASPNETCORE_URLS`.)

## Switching providers

Every setting in `appsettings.json` can be overridden with an environment variable
(`Section__Key`, double underscore) or a command-line switch (`--Section:Key value`).

| Provider | Environment variables |
|----------|-----------------------|
| mock (default) | `Analysis__Provider=mock` `Analysis__MockDelayMs=800` |
| Gemini | `Analysis__Provider=gemini` `Gemini__ApiKey=AIza...` `Gemini__Model=gemini-2.5-flash` `Gemini__ThinkingBudget=0` (optional) |
| Claude | `Analysis__Provider=claude` `Claude__ApiKey=sk-ant-...` `Claude__Model=claude-sonnet-5` `Claude__MaxTokens=8192` `Claude__Effort=low` |

```bash
# Gemini
Analysis__Provider=gemini Gemini__ApiKey=AIza... dotnet run --project IWantFigure.Server

# Claude
Analysis__Provider=claude Claude__ApiKey=sk-ant-... dotnet run --project IWantFigure.Server

# Windows PowerShell
$env:Analysis__Provider="claude"; $env:Claude__ApiKey="sk-ant-..."; dotnet run --project IWantFigure.Server
```

For local development you can also use `dotnet user-secrets set Claude:ApiKey sk-ant-...`
inside `IWantFigure.Server/` (the project has a `UserSecretsId`), which keeps keys out of
`appsettings.json` and out of git.

### All settings

| Key | Default | Meaning |
|-----|---------|---------|
| `Server:AppKey` | *(empty)* | When set, `POST /api/v1/analyze` requires header `X-App-Key: <value>` (else 401). |
| `Server:RateLimitPerMinute` | 30 | Fixed-window limit per client IP on the analyze endpoint (429 `rate_limited`). |
| `Server:MaxRequestBodyBytes` | 12582912 | Kestrel body limit (12 MB). |
| `Server:UseForwardedHeaders` | false | Honour `X-Forwarded-For` / `X-Forwarded-Proto` so rate limits are per real client. Only headers sent by a proxy in `KnownProxies` / `KnownNetworks` are trusted (ASP.NET's defaults trust loopback only). |
| `Server:KnownProxies` | `[]` | IPs of your reverse proxies / load balancers, e.g. `Server__KnownProxies__0=10.0.0.5`. |
| `Server:KnownNetworks` | `[]` | CIDR ranges of your proxies, e.g. `Server__KnownNetworks__0=10.0.0.0/8`. |
| `Analysis:Provider` | mock | `mock` / `gemini` / `claude`. |
| `Analysis:MockDelayMs` | 800 | Fake latency of the mock provider. |
| `Analysis:MaxImageLongSide` | 1456 | Downscale bound in pixels (never upscales). |
| `Analysis:JpegQuality` | 85 | Re-encode quality. |
| `Analysis:MaxImagePixels` | 50000000 | Pixel budget for JPEG (can be decoded downscaled); checked from the header before decoding. |
| `Analysis:MaxImagePixelsNonJpeg` | 16000000 | Pixel budget for PNG / WebP, which are always decoded in full (4 bytes/pixel). |
| `Analysis:MaxConcurrentDecodes` | 4 | Images decoded/resized at the same time; further requests wait (bounded memory). |
| `Analysis:ProviderTimeoutSeconds` | 30 | HttpClient timeout per upstream call. |
| `Analysis:RetryDelayMs` / `Analysis:MaxRetryDelayMs` | 500 / 5000 | Pause before the single retry on 429/5xx; an upstream `Retry-After` is honoured up to the cap. |
| `Gemini:Model` | gemini-2.5-flash | Any Gemini model that supports `responseSchema`; newer Flash releases can be set here. |
| `Gemini:ThinkingBudget` | *(null)* | When set, sends `thinkingConfig.thinkingBudget` (0 disables thinking on 2.5 models). Leave unset for models that do not support it. |
| `Gemini:Temperature` / `Gemini:MaxOutputTokens` | 0.5 / 8192 | generationConfig. |
| `Claude:Model` | claude-sonnet-5 | Exact model id (no date suffix). |
| `Claude:MaxTokens` | 8192 | Output cap. On Claude 5 / 4.6+ models it covers thinking **and** the JSON answer (~1k tokens), so keep headroom; raise it if you raise `Effort`. |
| `Claude:Effort` | low | `output_config.effort`: low / medium / high / xhigh / max, empty = omit. Never sent for `claude-haiku-*`. |
| `Claude:Thinking` | adaptive | `adaptive` / `disabled` / empty (omit the parameter). Never sent for `claude-haiku-*`. |

Claude model / parameter matrix (what the server sends):

| `Claude:Model` | `thinking` | `output_config.effort` | Notes |
|---|---|---|---|
| `claude-sonnet-5` (default), `claude-opus-5`, `claude-opus-4-8/4-7/4-6`, `claude-sonnet-4-6` | `{type: Claude:Thinking}` (`adaptive` default; `disabled` allowed) | `Claude:Effort` (`low` default) | Adaptive thinking is on even when the parameter is omitted; `MaxTokens` must cover thinking + answer. `temperature` is never sent (Claude 5 rejects non-default sampling parameters). |
| `claude-haiku-4-5` (any `claude-haiku-*`) | omitted | omitted | Haiku uses the older `budget_tokens` thinking shape and rejects `effort`/adaptive thinking; it runs without thinking. |
| `claude-fable-*` / `claude-mythos-*` | `adaptive` only (set `Claude:Thinking=adaptive` or empty) | `Claude:Effort` | Thinking cannot be disabled on these models (`disabled` returns 400). |
| `Claude:AnthropicVersion` | 2023-06-01 | `anthropic-version` header. |

## API

### `GET /healthz`

```json
{"status":"ok","provider":"mock"}
```

### `POST /api/v1/analyze`

Headers: `Content-Type: application/json`, optional `X-App-Key`. Body ≤ 12 MB.

```json
{
  "image_base64": "<base64 of a JPEG/PNG/WebP file>",
  "mime": "image/jpeg",
  "locale": "ko",
  "hints": {
    "machine_family": "UFO CATCHER 9",
    "claw_count": 2,
    "prize_size_mm": [120, 90, 160],
    "notes": "box moved about 1 cm on the last play"
  }
}
```

`locale` (`ko` | `ja` | `en`) selects the language of the free-text fields; `hints` and every
field inside it are optional and are sanitized before they reach the prompt (`claw_count` clamped
to 0..5, `prize_size_mm` keeps at most three finite values in 1..2000 mm, text fields are cut at
500 characters). The mock provider returns the `layout_type: "unknown"` variant when
`hints.notes` contains the word `unknown`.

**200** – the schema object plus metadata. All bounding boxes are `[x1, y1, x2, y2]` normalized to
`0..1` of `image.width × image.height` (the image *after* orientation fix and resize):

```json
{
  "analysis_id": "3f1c1d5a-6f0b-4b7a-9d68-2f6c0f4b6e21",
  "provider": "mock",
  "model": "sample/bridge_parallel",
  "latency_ms": 812,
  "image": { "width": 1456, "height": 971 },
  "layout_type": "bridge_parallel",
  "confidence": 0.82,
  "machine": { "claw_count": 2, "arm_power_estimate": "unknown", "assist_lamp": "blue", "exit_side": "center" },
  "objects": [
    { "id": "box1", "kind": "box", "bbox": [0.36, 0.42, 0.64, 0.74], "notes": "figure box, window facing front, slightly rotated" },
    { "id": "bar_front", "kind": "bar", "bbox": [0.12, 0.70, 0.88, 0.73], "notes": "metal front bar (手前バー)" }
  ],
  "strategy": {
    "technique": "tate_hame",
    "target_object_id": "box1",
    "target_edge": "back_right",
    "arm": "right",
    "sequence": ["Right arm tip just inside the back-right corner ..."],
    "abort_if": ["No movement after 3 plays"],
    "expected_motion": "Back end rises, box rotates about the front bar ..."
  },
  "explanation": "This is a standard bridge setup (橋渡し) ...",
  "needs_more_photos": [],
  "warnings": ["Arm power is not visible in the photo; check how much the box moves on the first play."]
}
```

Errors always have the shape `{"error": "<code>", "message"?: "...", "provider_message"?: "..."}`:

| Status | `error` | When |
|--------|---------|------|
| 400 | `missing_image`, `invalid_base64`, `invalid_image`, `unsupported_mime`, `unsupported_image_format`, `image_too_large`, `invalid_json`, `missing_body` | Bad input |
| 401 | `unauthorized` | `Server:AppKey` set and `X-App-Key` missing/wrong |
| 413 | `request_too_large` | Body over 12 MB |
| 415 | `unsupported_media_type` | `Content-Type` is not `application/json` |
| 429 | `rate_limited` | More than `Server:RateLimitPerMinute` calls from one IP; the response carries `Retry-After: 60` |
| 502 | `provider_error` (+ `provider_message`) | Upstream call failed, refused, truncated, or returned unusable JSON after one retry. `provider_message` is a short generic phrase (`upstream returned HTTP 401`, `upstream output was truncated`, ...); the full upstream diagnostics are only in the server log |
| 503 | `provider_not_configured` | Selected provider has no API key |

### curl example

```bash
base64 -w0 photo.jpg > img.b64        # macOS: base64 -i photo.jpg -o img.b64
# --rawfile reads the image from a file: passing a real photo through --arg
# fails with "Argument list too long".
jq -n --rawfile img img.b64 \
  '{image_base64:($img|split("\n")|join("")), mime:"image/jpeg", locale:"ko", hints:{claw_count:2, notes:"first try"}}' \
  > request.json

curl -s http://localhost:8080/api/v1/analyze \
  -H 'Content-Type: application/json' \
  -H 'X-App-Key: change-me' \
  --data @request.json | jq .
```

## Tests

```bash
cd server
dotnet test
```

113 xUnit tests: normalizer (both coordinate conventions incl. the already-normalized fallback,
clamping, enum fallback, target-id repair, claw_count clamp, fence stripping), image pipeline
(3000×2000 → 1456×971, EXIF orientation, metadata stripping, no upscale, format rejection,
per-format pixel budgets, bounded concurrency), prompt-builder hint sanitizing, Gemini schema
conversion, endpoint tests through `WebApplicationFactory<Program>` with the mock provider
(200 shape, 400/401/415/503 paths, unknown variant, X-Forwarded-For trust, `Retry-After` on 429,
generic 502 bodies), provider HTTP tests with a fake `HttpMessageHandler` and canned Gemini /
Claude responses (request body and header assertions, parsing, trimmed keys, Haiku parameter
matrix, `Retry-After`), and the service retry/back-off policy. No network access is needed.

## Docker

The build context is the **repository root** because the server embeds files from `shared/`:

```bash
docker build -f server/Dockerfile -t iwantfigure-server .
docker run --rm -p 8080:8080 \
  -e Analysis__Provider=claude -e Claude__ApiKey=sk-ant-... -e Server__AppKey=change-me \
  iwantfigure-server
```

The runtime image listens on `:8080` as the non-root `app` user; point your orchestrator's
health probe at `GET /healthz`.

## How a request is processed

1. **Validate** mime (`image/jpeg`, `image/png`, `image/webp`), base64, and the real byte format.
2. **Prepare the image** (`Imaging/ImagePipeline.cs`): apply EXIF orientation, downscale so the
   long side ≤ 1456 px (never upscale), strip all metadata (EXIF/GPS, XMP, IPTC, ICC),
   re-encode JPEG q85. The resulting size is what the response reports in `image`.
3. **Call the provider** (`Providers/*Provider.cs`) through a typed `HttpClient` (30 s timeout).
   Transient failures (429 / 5xx / network) are retried **once** after a short pause
   (`Analysis:RetryDelayMs`, or the upstream `Retry-After` up to `MaxRetryDelayMs`); unparseable
   answers are retried once immediately; auth errors, refusals and truncation fail with 502.
   * Gemini: `systemInstruction` + `inline_data` image + `responseSchema` JSON mode. Boxes come
     back as `[ymin, xmin, ymax, xmax]` on 0–1000.
   * Claude: `system` block with `cache_control: ephemeral` (the shared prompt never changes, so
     it is served from the prompt cache), `image` block + text, structured output via
     `output_config.format = json_schema`. Boxes come back as absolute pixels `[x1, y1, x2, y2]`.
4. **Normalize** (`Analysis/AnalysisNormalizer.cs`): convert boxes to 0..1, clamp, drop empty
   boxes, replace invalid enum values (`unknown` / `other` / `center` / `both`), repair
   `strategy.target_object_id`, guarantee all arrays, and validate against the embedded schema.
5. **Attach** `analysis_id`, `provider`, `model`, `latency_ms`, `image` and return.

## Security notes

* **Never ship API keys in the app.** The Flutter app talks only to this server; the Gemini /
  Claude keys live only here (environment variables, user-secrets, or your secret store).
  `appsettings.json` ships with empty keys on purpose.
* Set `Server:AppKey` and send it as `X-App-Key` from the app so random clients cannot spend your
  LLM budget. It is a shared secret, not user authentication - pair it with TLS (terminate HTTPS
  at your proxy / load balancer) and the per-IP rate limit.
* Behind a proxy, set `Server:UseForwardedHeaders=true` **and** list the proxy in
  `Server:KnownProxies` / `Server:KnownNetworks`; otherwise `X-Forwarded-For` is ignored and every
  user shares one rate-limit bucket. Never list networks that untrusted clients can connect from -
  they could spoof the header and dodge the limit.
* Error responses never echo upstream bodies; `provider_message` is a fixed short phrase and the
  details stay in the server log.
* The server never logs the image, the base64 payload, or API keys. Provider keys are sent in
  request headers (not URLs), and the default `HttpClient` request logging is switched off.
* Uploaded photos are processed in memory and discarded; nothing is written to disk.
  EXIF (including GPS) is stripped before the image leaves the server.
* Player hints are inserted into the prompt as labelled untrusted data and truncated to
  500 characters.

## Cost notes

* **Image size is the main cost lever.** Image tokens scale with pixel count. The default
  1456 px long side (`Analysis:MaxImageLongSide`) is enough to read bars, claws and box edges;
  lowering it to ~1024 roughly halves image tokens, raising it above ~1568 buys little on most
  models (Claude Sonnet 5 accepts up to 2576 px but charges up to ~3× more image tokens).
* JPEG q85 keeps the payload small; quality does not change token cost, only bandwidth.
* Claude: the system prompt block carries `cache_control`, so its tokens are billed at the cache
  read rate from the second request on. Watch `cache_read_input_tokens` in the debug log; if it
  stays 0 the prompt is below the model's minimum cacheable size (1024 tokens on Sonnet 5).
  `Claude:Effort=low` keeps thinking short; `MaxTokens=8192` leaves room for it plus the ~1k-token
  answer. Raise both together if you want deeper strategy reasoning.
* Gemini: `Gemini:ThinkingBudget=0` disables thinking on 2.5 models (cheapest and fastest);
  leave it unset for models that do not support the field.
* The one-retry policy can double the cost of a failed request; refusals and truncation are
  not retried.
* Player hints are clamped (three prize dimensions, 500 characters of text) so a malicious or
  buggy client cannot inflate the billed prompt.

## Project layout

```
server/
├── IWantFigure.Server.sln
├── Directory.Build.props            shared build settings (net10.0, nullable, warnings as errors)
├── Dockerfile / Dockerfile.dockerignore
├── IWantFigure.Server/
│   ├── Program.cs                   host, rate limiting, DI, Kestrel limits
│   ├── appsettings*.json
│   ├── Analysis/                    AnalysisService (orchestration + retry), AnalysisNormalizer,
│   │                                AnalysisSchema (embedded schema + enum sets), SchemaValidator
│   ├── Configuration/Options.cs     ServerOptions, AnalysisOptions, GeminiOptions, ClaudeOptions
│   ├── Contracts/                   AnalyzeRequest / AnalyzeHints / ErrorResponse / HealthResponse
│   ├── Endpoints/                   /healthz, /api/v1/analyze, AppKeyFilter
│   ├── Imaging/ImagePipeline.cs     decode → AutoOrient → resize ≤ 1456 → strip metadata → JPEG 85
│   ├── Models/AnalysisDocument.cs   C# mirror of analysis.schema.json (+ AnalysisResponse)
│   ├── Providers/                   IAnalysisProvider, MockProvider, GeminiProvider, ClaudeProvider,
│   │                                schema converters, PromptBuilder, ProviderHttp
│   └── Shared/                      SharedResources (embedded /shared files), ServerJson
└── IWantFigure.Server.Tests/        xUnit tests (see above)
```
