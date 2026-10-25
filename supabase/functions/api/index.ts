import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AssistantMessage = { role: "user" | "assistant"; content: string };

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function fetchInstagramInsights() {
  const accessToken = Deno.env.get("META_ACCESS_TOKEN");
  const instagramUserId = Deno.env.get("META_INSTAGRAM_USER_ID");
  const graphVersion = Deno.env.get("META_GRAPH_VERSION") ?? "v21.0";
  if (!accessToken || !instagramUserId) {
    throw new Error("Instagram ist serverseitig noch nicht konfiguriert.");
  }

  const graphBase = `https://graph.facebook.com/${graphVersion}`;
  const accountUrl = new URL(`${graphBase}/${encodeURIComponent(instagramUserId)}`);
  accountUrl.searchParams.set(
    "fields",
    "username,followers_count,media.limit(25){id,caption,like_count,comments_count,media_type,permalink,timestamp}",
  );
  accountUrl.searchParams.set("access_token", accessToken);

  const accountResponse = await fetch(accountUrl);
  const account = await accountResponse.json();
  if (!accountResponse.ok) {
    throw new Error(
      account?.error?.message ?? "Instagram-Kontodaten konnten nicht geladen werden.",
    );
  }

  const insightsUrl = new URL(
    `${graphBase}/${encodeURIComponent(instagramUserId)}/insights`,
  );
  insightsUrl.searchParams.set("metric", "impressions,reach");
  insightsUrl.searchParams.set("period", "day");
  insightsUrl.searchParams.set("access_token", accessToken);
  const insightsResponse = await fetch(insightsUrl);
  const insights = await insightsResponse.json();
  if (!insightsResponse.ok) {
    throw new Error(
      insights?.error?.message ?? "Instagram-Insights konnten nicht geladen werden.",
    );
  }

  const metrics = Array.isArray(insights.data) ? insights.data : [];
  const metricTotal = (name: string) => {
    const metric = metrics.find((item) => item.name === name);
    return Array.isArray(metric?.values)
      ? metric.values.reduce(
        (total: number, item: { value?: number }) => total + (item.value ?? 0),
        0,
      )
      : 0;
  };
  const media = Array.isArray(account.media?.data) ? account.media.data : [];
  const followerCount = Number(account.followers_count ?? 0);
  const posts = media
    .map((post: Record<string, unknown>) => ({ ...post, reach: 0 }))
    .sort(
      (left: Record<string, unknown>, right: Record<string, unknown>) =>
        Number(right.like_count ?? 0) + Number(right.comments_count ?? 0) -
        Number(left.like_count ?? 0) - Number(left.comments_count ?? 0),
    )
    .slice(0, 5);
  const interactions = posts.reduce(
    (total: number, post: Record<string, unknown>) =>
      total + Number(post.like_count ?? 0) + Number(post.comments_count ?? 0),
    0,
  );

  return {
    follower_count: followerCount,
    impressions: metricTotal("impressions"),
    reach: metricTotal("reach"),
    engagement_rate: followerCount > 0 && posts.length > 0
      ? (interactions / posts.length / followerCount) * 100
      : 0,
    username: account.username ?? "",
    top_posts: posts,
    updated_at: new Date().toISOString(),
  };
}

async function assistantReply(
  messages: AssistantMessage[],
  insights: Record<string, unknown>,
) {
  const groqApiKey = Deno.env.get("GROQ_API_KEY");
  if (!groqApiKey) {
    throw new Error("Der KI-Assistent ist serverseitig noch nicht konfiguriert.");
  }

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
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!authorization || !supabaseUrl || !supabaseAnonKey) {
    return jsonResponse({ error: "Authentifizierung erforderlich." }, 401);
  }
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: authError } = await supabase.auth.getUser();
  if (authError || !userData.user) {
    return jsonResponse({ error: "Authentifizierung fehlgeschlagen." }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Ungültiger JSON-Request." }, 400);
  }

  try {
    if (body.action === "instagram_insights") {
      return jsonResponse(await fetchInstagramInsights());
    }
    if (body.action === "assistant") {
      const messages = body.messages;
      const insights = body.insights;
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
        ) ||
        !insights ||
        typeof insights !== "object"
      ) {
        return jsonResponse({ error: "Ungültige Chat-Anfrage." }, 400);
      }
      const reply = await assistantReply(
        messages as AssistantMessage[],
        insights as Record<string, unknown>,
      );
      return jsonResponse({ reply });
    }
    return jsonResponse({ error: "Unbekannte Aktion." }, 400);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Interner Fehler.";
    return jsonResponse({ error: message }, 502);
  }
});
