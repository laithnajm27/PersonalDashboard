import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const oauthCallbackPath = "/api";
const oauthScopes = [
  "instagram_business_basic",
  "instagram_business_manage_insights",
].join(",");
const encoder = new TextEncoder();
const decoder = new TextDecoder();

type AssistantMessage = { role: "user" | "assistant"; content: string };
type InstagramInsightsPayload = {
  follower_count: number;
  impressions: number;
  reach: number;
  engagement_rate: number;
  username: string;
  top_posts: Record<string, unknown>[];
  updated_at: string;
};
type StoredConnection = {
  owner_id: string;
  instagram_user_id: string;
  username: string;
  encrypted_access_token: string;
  token_iv: string;
  token_expires_at: string;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function callbackResponse(message: string, status = 200): Response {
  const escaped = message
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
  return new Response(
    `<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Instagram-Verbindung</title><body style="font:16px system-ui;max-width:36rem;margin:15vh auto;padding:1.5rem;background:#101211;color:#fff"><h1>Instagram-Verbindung</h1><p>${escaped}</p><p>Du kannst dieses Fenster schließen und zum Personal Dashboard zurückkehren.</p></body></html>`,
    {
      status,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
        "X-Content-Type-Options": "nosniff",
      },
    },
  );
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Server-Konfiguration fehlt: ${name}`);
  }
  return value;
}

function getAdminClient(): SupabaseClient {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

async function getAuthenticatedUser(request: Request) {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return null;
  }
  const supabase = createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) {
    return null;
  }
  return data.user;
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value);
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function toBase64Url(bytes: Uint8Array): string {
  return toBase64(bytes)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

async function hashState(state: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(state));
  return toBase64Url(new Uint8Array(digest));
}

async function getEncryptionKey(): Promise<CryptoKey> {
  const rawKey = fromBase64(requiredEnv("META_TOKEN_ENCRYPTION_KEY"));
  if (rawKey.length !== 32) {
    throw new Error("META_TOKEN_ENCRYPTION_KEY muss Base64-kodiert 32 Bytes enthalten.");
  }
  return await crypto.subtle.importKey(
    "raw",
    rawKey,
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
}

async function encryptToken(token: string, ownerId: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: encoder.encode(ownerId) },
    await getEncryptionKey(),
    encoder.encode(token),
  );
  return {
    encrypted_access_token: toBase64(new Uint8Array(encrypted)),
    token_iv: toBase64(iv),
  };
}

async function decryptToken(connection: StoredConnection): Promise<string> {
  const decrypted = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: fromBase64(connection.token_iv),
      additionalData: encoder.encode(connection.owner_id),
    },
    await getEncryptionKey(),
    fromBase64(connection.encrypted_access_token),
  );
  return decoder.decode(decrypted);
}

async function fetchMetaJson(url: URL, init?: RequestInit) {
  const response = await fetch(url, init);
  const body = await response.json();
  if (!response.ok) {
    throw new Error(
      typeof body?.error?.message === "string"
        ? body.error.message
        : "Instagram konnte die Anfrage nicht verarbeiten.",
    );
  }
  return body;
}

function graphUrl(path: string): URL {
  const version = Deno.env.get("META_GRAPH_VERSION") ?? "v26.0";
  return new URL(`https://graph.instagram.com/${version}/${path}`);
}

async function takeOAuthState(admin: SupabaseClient, state: string) {
  const stateHash = await hashState(state);
  const { data, error } = await admin
    .from("instagram_oauth_states")
    .delete()
    .eq("state_hash", stateHash)
    .select("owner_id,expires_at")
    .maybeSingle();
  if (error) {
    throw new Error("OAuth-Status konnte nicht geprüft werden.");
  }
  if (!data || Date.parse(data.expires_at) <= Date.now()) {
    return null;
  }
  return data as { owner_id: string; expires_at: string };
}

async function exchangeAuthorizationCode(code: string) {
  const redirectUri = requiredEnv("META_OAUTH_REDIRECT_URI");
  const appId = requiredEnv("META_INSTAGRAM_APP_ID");
  const appSecret = requiredEnv("META_APP_SECRET");

  const shortLivedForm = new URLSearchParams({
    client_id: appId,
    client_secret: appSecret,
    grant_type: "authorization_code",
    redirect_uri: redirectUri,
    code,
  });
  const shortLivedResponse = await fetch(
    "https://api.instagram.com/oauth/access_token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: shortLivedForm,
    },
  );
  const shortLived = await shortLivedResponse.json();
  if (!shortLivedResponse.ok || typeof shortLived.access_token !== "string") {
    throw new Error("Meta konnte den Login-Code nicht einlösen.");
  }

  const longLivedUrl = graphUrl("access_token");
  longLivedUrl.searchParams.set("grant_type", "ig_exchange");
  longLivedUrl.searchParams.set("client_secret", appSecret);
  longLivedUrl.searchParams.set("access_token", shortLived.access_token);
  const longLived = await fetchMetaJson(longLivedUrl);
  if (
    typeof longLived.access_token !== "string" ||
    typeof longLived.expires_in !== "number"
  ) {
    throw new Error("Meta hat keinen gültigen Langzeit-Token zurückgegeben.");
  }

  const profileUrl = graphUrl("me");
  profileUrl.searchParams.set("fields", "user_id,username");
  profileUrl.searchParams.set("access_token", longLived.access_token);
  const profile = await fetchMetaJson(profileUrl);
  const instagramUserId = profile.user_id?.toString() ?? profile.id?.toString();
  if (!instagramUserId || typeof profile.username !== "string") {
    throw new Error("Meta hat kein gültiges Instagram-Profil zurückgegeben.");
  }

  return {
    accessToken: longLived.access_token as string,
    expiresAt: new Date(Date.now() + longLived.expires_in * 1000).toISOString(),
    instagramUserId,
    username: profile.username as string,
  };
}

async function handleOAuthCallback(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const state = url.searchParams.get("state");
  if (!state || state.length > 200) {
    return callbackResponse("Der Login-Status ist ungültig oder abgelaufen.", 400);
  }

  try {
    const admin = getAdminClient();
    const oauthState = await takeOAuthState(admin, state);
    if (!oauthState) {
      return callbackResponse("Der Login-Status ist ungültig oder abgelaufen.", 400);
    }
    if (url.searchParams.has("error")) {
      return callbackResponse(
        "Die Instagram-Verbindung wurde abgebrochen. Du kannst es im Dashboard erneut versuchen.",
        400,
      );
    }

    const code = url.searchParams.get("code");
    if (!code || code.length > 4096) {
      return callbackResponse("Meta hat keinen gültigen Login-Code zurückgegeben.", 400);
    }

    const account = await exchangeAuthorizationCode(code.replace(/#_$/, ""));
    const encryptedToken = await encryptToken(
      account.accessToken,
      oauthState.owner_id,
    );
    const { error } = await admin.from("instagram_connections").upsert(
      {
        owner_id: oauthState.owner_id,
        instagram_user_id: account.instagramUserId,
        username: account.username,
        ...encryptedToken,
        token_expires_at: account.expiresAt,
        connected_at: new Date().toISOString(),
      },
      { onConflict: "owner_id" },
    );
    if (error) {
      throw new Error("Instagram-Verbindung konnte nicht gespeichert werden.");
    }
    return callbackResponse(
      `Instagram @${account.username} wurde verbunden. Kehre zum Dashboard zurück und lade die Insights.`,
    );
  } catch (error) {
    console.error(
      "Instagram OAuth callback failed:",
      error instanceof Error ? error.message : "unknown error",
    );
    return callbackResponse(
      "Die Instagram-Verbindung ist fehlgeschlagen. Bitte kehre zum Dashboard zurück und versuche es erneut.",
      502,
    );
  }
}

async function startInstagramOAuth(
  admin: SupabaseClient,
  ownerId: string,
) {
  const appId = requiredEnv("META_INSTAGRAM_APP_ID");
  if (!/^\d+$/.test(appId)) {
    throw new Error(
      "META_INSTAGRAM_APP_ID muss die numerische Instagram App ID aus den Business-Login-Einstellungen enthalten (nicht die Facebook App ID).",
    );
  }
  const redirectUri = requiredEnv("META_OAUTH_REDIRECT_URI");
  const supabaseUrl = new URL(requiredEnv("SUPABASE_URL"));
  const expectedRedirect = new URL("/functions/v1/api", supabaseUrl);
  const parsedRedirect = new URL(redirectUri);
  if (
    supabaseUrl.protocol !== "https:" ||
    parsedRedirect.protocol !== "https:" ||
    parsedRedirect.origin !== expectedRedirect.origin ||
    parsedRedirect.pathname !== expectedRedirect.pathname ||
    parsedRedirect.search ||
    parsedRedirect.hash
  ) {
    throw new Error(
      `META_OAUTH_REDIRECT_URI muss exakt ${expectedRedirect.toString()} entsprechen.`,
    );
  }
  const stateBytes = crypto.getRandomValues(new Uint8Array(32));
  const state = toBase64Url(stateBytes);
  const stateHash = await hashState(state);

  const { error: expiredStateError } = await admin
    .from("instagram_oauth_states")
    .delete()
    .lt("expires_at", new Date().toISOString());
  if (expiredStateError) {
    throw new Error("Abgelaufene Instagram-Anmeldungen konnten nicht bereinigt werden.");
  }
  const { error: deleteError } = await admin
    .from("instagram_oauth_states")
    .delete()
    .eq("owner_id", ownerId);
  if (deleteError) {
    throw new Error("Vorherige Instagram-Anmeldung konnte nicht beendet werden.");
  }
  const { error: insertError } = await admin
    .from("instagram_oauth_states")
    .insert({
      state_hash: stateHash,
      owner_id: ownerId,
      expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
    });
  if (insertError) {
    throw new Error("Instagram-Anmeldung konnte nicht gestartet werden.");
  }

  const configuredEmbedUrl = Deno.env.get("META_OAUTH_EMBED_URL");
  const authorizationUrl = new URL(
    configuredEmbedUrl ?? "https://www.instagram.com/oauth/authorize",
  );
  if (
    authorizationUrl.protocol !== "https:" ||
    authorizationUrl.hostname !== "www.instagram.com" ||
    authorizationUrl.pathname.replace(/\/$/, "") !== "/oauth/authorize"
  ) {
    throw new Error(
      "META_OAUTH_EMBED_URL muss die Instagram Business Login Autorisierungs-URL enthalten.",
    );
  }
  if (
    configuredEmbedUrl &&
    authorizationUrl.searchParams.get("client_id") !== appId
  ) {
    throw new Error(
      "META_OAUTH_EMBED_URL muss zur konfigurierten Instagram App ID gehören.",
    );
  }
  const embedRedirect = authorizationUrl.searchParams.get("redirect_uri");
  if (embedRedirect && embedRedirect !== redirectUri) {
    throw new Error(
      "Die Redirect URI in META_OAUTH_EMBED_URL stimmt nicht mit META_OAUTH_REDIRECT_URI überein.",
    );
  }
  authorizationUrl.searchParams.set("client_id", appId);
  authorizationUrl.searchParams.set("redirect_uri", redirectUri);
  authorizationUrl.searchParams.set("response_type", "code");
  authorizationUrl.searchParams.set("scope", oauthScopes);
  authorizationUrl.searchParams.set("state", state);
  authorizationUrl.searchParams.set("enable_fb_login", "0");
  return authorizationUrl.toString();
}

async function getConnection(
  admin: SupabaseClient,
  ownerId: string,
): Promise<StoredConnection | null> {
  const { data, error } = await admin
    .from("instagram_connections")
    .select(
      "owner_id,instagram_user_id,username,encrypted_access_token,token_iv,token_expires_at",
    )
    .eq("owner_id", ownerId)
    .maybeSingle();
  if (error) {
    throw new Error("Instagram-Verbindungsstatus konnte nicht geladen werden.");
  }
  return data as StoredConnection | null;
}

async function getUsableAccessToken(
  admin: SupabaseClient,
  connection: StoredConnection,
): Promise<string> {
  const expiresAt = Date.parse(connection.token_expires_at);
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    throw new Error("Instagram-Verbindung abgelaufen. Bitte verbinde dein Konto erneut.");
  }

  let accessToken = await decryptToken(connection);
  const refreshThreshold = 7 * 24 * 60 * 60 * 1000;
  if (expiresAt - Date.now() < refreshThreshold) {
    const refreshUrl = graphUrl("refresh_access_token");
    refreshUrl.searchParams.set("grant_type", "ig_refresh_token");
    refreshUrl.searchParams.set("access_token", accessToken);
    const refreshed = await fetchMetaJson(refreshUrl);
    if (
      typeof refreshed.access_token !== "string" ||
      typeof refreshed.expires_in !== "number"
    ) {
      throw new Error("Instagram-Token konnte nicht erneuert werden.");
    }
    accessToken = refreshed.access_token;
    const encryptedToken = await encryptToken(
      accessToken,
      connection.owner_id,
    );
    const { error } = await admin
      .from("instagram_connections")
      .update({
        ...encryptedToken,
        token_expires_at: new Date(
          Date.now() + refreshed.expires_in * 1000,
        ).toISOString(),
      })
      .eq("owner_id", connection.owner_id);
    if (error) {
      throw new Error("Erneuerter Instagram-Token konnte nicht gespeichert werden.");
    }
  }
  return accessToken;
}

function sumMetric(metrics: Record<string, unknown>[], ...names: string[]) {
  const metric = metrics.find((item) => names.includes(String(item.name)));
  const values = Array.isArray(metric?.values) ? metric.values : [];
  return values.reduce(
    (total: number, item: Record<string, unknown>) =>
      total + (typeof item.value === "number" ? item.value : 0),
    0,
  );
}

async function fetchInstagramInsights(
  admin: SupabaseClient,
  ownerId: string,
): Promise<InstagramInsightsPayload> {
  const connection = await getConnection(admin, ownerId);
  if (!connection) {
    throw new Error("Verbinde zuerst dein Instagram-Professional-Konto.");
  }
  const accessToken = await getUsableAccessToken(admin, connection);

  const profileUrl = graphUrl("me");
  profileUrl.searchParams.set("fields", "user_id,username,followers_count");
  profileUrl.searchParams.set("access_token", accessToken);
  const profile = await fetchMetaJson(profileUrl);

  const mediaUrl = graphUrl("me/media");
  mediaUrl.searchParams.set(
    "fields",
    "id,caption,media_type,permalink,timestamp,like_count,comments_count",
  );
  mediaUrl.searchParams.set("limit", "25");
  mediaUrl.searchParams.set("access_token", accessToken);
  const mediaResult = await fetchMetaJson(mediaUrl);
  const posts = (Array.isArray(mediaResult.data) ? mediaResult.data : [])
    .map((post: Record<string, unknown>) => ({
      ...post,
      reach: 0,
    }))
    .sort(
      (left: Record<string, unknown>, right: Record<string, unknown>) =>
        Number(right.like_count ?? 0) + Number(right.comments_count ?? 0) -
        Number(left.like_count ?? 0) - Number(left.comments_count ?? 0),
    )
    .slice(0, 5);

  const insightsUrl = graphUrl("me/insights");
  insightsUrl.searchParams.set("metric", "reach,views");
  insightsUrl.searchParams.set("period", "day");
  insightsUrl.searchParams.set("access_token", accessToken);
  const insightsResult = await fetchMetaJson(insightsUrl);
  const metrics: Record<string, unknown>[] = Array.isArray(insightsResult.data)
    ? insightsResult.data
    : [];
  const followerCount = Number(profile.followers_count ?? 0);
  const interactions = posts.reduce(
    (total: number, post: Record<string, unknown>) =>
      total + Number(post.like_count ?? 0) + Number(post.comments_count ?? 0),
    0,
  );

  return {
    follower_count: followerCount,
    impressions: sumMetric(metrics, "views", "impressions"),
    reach: sumMetric(metrics, "reach"),
    engagement_rate: followerCount > 0 && posts.length > 0
      ? (interactions / posts.length / followerCount) * 100
      : 0,
    username: connection.username,
    top_posts: posts,
    updated_at: new Date().toISOString(),
  };
}

async function assistantReply(
  messages: AssistantMessage[],
  insights: InstagramInsightsPayload,
) {
  const groqApiKey = requiredEnv("GROQ_API_KEY");
  const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${groqApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: Deno.env.get("GROQ_MODEL") ?? "llama-3.1-8b-instant",
      temperature: 0.4,
      max_tokens: 700,
      messages: [
        {
          role: "system",
          content:
            "Du bist der deutschsprachige Instagram-Analyseassistent eines Foto- und Videografen. Nutze nur die bereitgestellten Insights, kennzeichne Unsicherheit und erfinde keine Kennzahlen. Gib umsetzbare, knappe Empfehlungen. Shotlists werden niemals von dir generiert.",
        },
        {
          role: "system",
          content: `Aktuelle Instagram-Insights (JSON): ${JSON.stringify(insights).slice(0, 12000)}`,
        },
        ...messages,
      ],
    }),
  });
  const result = await response.json();
  if (!response.ok) {
    throw new Error(
      result?.error?.message ?? "Die Anfrage an den KI-Dienst ist fehlgeschlagen.",
    );
  }
  const reply = result?.choices?.[0]?.message?.content;
  if (typeof reply !== "string" || reply.trim().length === 0) {
    throw new Error("Der KI-Dienst hat keine Antwort geliefert.");
  }
  return reply.trim();
}

Deno.serve(async (request: Request) => {
  const requestUrl = new URL(request.url);
  if (request.method === "GET" && requestUrl.pathname.endsWith(oauthCallbackPath)) {
    return await handleOAuthCallback(request);
  }
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const user = await getAuthenticatedUser(request);
  if (!user) {
    return jsonResponse({ error: "Authentifizierung erforderlich." }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Ungültiger JSON-Request." }, 400);
  }

  try {
    const admin = getAdminClient();
    if (body.action === "instagram_oauth_start") {
      const authorizationUrl = await startInstagramOAuth(admin, user.id);
      return jsonResponse({ authorization_url: authorizationUrl });
    }
    if (body.action === "instagram_connection_status") {
      const connection = await getConnection(admin, user.id);
      if (!connection) {
        return jsonResponse({ connected: false });
      }
      return jsonResponse({
        connected: true,
        username: connection.username,
        expires_at: connection.token_expires_at,
      });
    }
    if (body.action === "instagram_disconnect") {
      const { error } = await admin
        .from("instagram_connections")
        .delete()
        .eq("owner_id", user.id);
      if (error) {
        throw new Error("Instagram-Verbindung konnte nicht getrennt werden.");
      }
      return jsonResponse({ disconnected: true });
    }
    if (body.action === "instagram_insights") {
      return jsonResponse(await fetchInstagramInsights(admin, user.id));
    }
    if (body.action === "assistant") {
      const messages = body.messages;
      if (
        !Array.isArray(messages) ||
        messages.length === 0 ||
        messages.length > 20 ||
        !messages.every(
          (message) =>
            message &&
            (message.role === "user" || message.role === "assistant") &&
            typeof message.content === "string" &&
            message.content.length > 0 &&
            message.content.length <= 4000,
        )
      ) {
        return jsonResponse({ error: "Ungültige Chat-Anfrage." }, 400);
      }
      const insights = await fetchInstagramInsights(admin, user.id);
      const reply = await assistantReply(
        messages as AssistantMessage[],
        insights,
      );
      return jsonResponse({ reply });
    }
    return jsonResponse({ error: "Unbekannte Aktion." }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Interner Fehler.";
    return jsonResponse({ error: message }, 502);
  }
});
