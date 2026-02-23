async function graphFetch(path, { method = "GET", token, body } = {}) {
  const base = "https://graph.facebook.com";
  const version = process.env.GRAPH_VERSION || "v22.0";
  const url = `${base}/${version}${path}`;

  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: body ? JSON.stringify(body) : undefined
  });

  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }

  if (!res.ok) {
    const err = new Error(`Graph API error ${res.status}`);
    err.status = res.status;
    err.payload = json;
    throw err;
  }

  return json;
}

async function sendTextMessage({ toE164, text }) {
  const token = process.env.ACCESS_TOKEN;
  const phoneNumberId = process.env.PHONE_NUMBER_ID;
  if (!token || !phoneNumberId) throw new Error("Missing ACCESS_TOKEN or PHONE_NUMBER_ID");

  return graphFetch(`/${phoneNumberId}/messages`, {
    method: "POST",
    token,
    body: {
      messaging_product: "whatsapp",
      to: toE164,
      type: "text",
      text: { body: text }
    }
  });
}

async function markAsRead(messageId) {
  const token = process.env.ACCESS_TOKEN;
  const phoneNumberId = process.env.PHONE_NUMBER_ID;
  if (!token || !phoneNumberId) throw new Error("Missing ACCESS_TOKEN or PHONE_NUMBER_ID");
  if (!messageId) throw new Error("Missing message_id");

  return graphFetch(`/${phoneNumberId}/messages`, {
    method: "POST",
    token,
    body: {
      messaging_product: "whatsapp",
      status: "read",
      message_id: messageId
    }
  });
}

async function getMedia(mediaId) {
  const token = process.env.ACCESS_TOKEN;
  if (!token) throw new Error("Missing ACCESS_TOKEN");
  if (!mediaId) throw new Error("Missing media_id");

  const meta = await graphFetch(`/${mediaId}`, { token });
  const mediaUrl = meta?.url;
  if (!mediaUrl) throw new Error("No url in media response");

  const res = await fetch(mediaUrl, {
    headers: { Authorization: `Bearer ${token}` }
  });
  if (!res.ok) throw new Error(`Media fetch failed ${res.status}`);
  const buffer = Buffer.from(await res.arrayBuffer());
  const mimeType = res.headers.get("content-type") || "application/octet-stream";
  const base64 = buffer.toString("base64");
  return { base64, mimeType };
}

async function subscribeAppToWaba() {
  const token = process.env.ACCESS_TOKEN;
  const wabaId = process.env.WABA_ID;
  if (!token || !wabaId) throw new Error("Missing ACCESS_TOKEN or WABA_ID");

  return graphFetch(`/${wabaId}/subscribed_apps`, { method: "POST", token });
}

async function listSubscribedApps() {
  const token = process.env.ACCESS_TOKEN;
  const wabaId = process.env.WABA_ID;
  if (!token || !wabaId) throw new Error("Missing ACCESS_TOKEN or WABA_ID");

  return graphFetch(`/${wabaId}/subscribed_apps`, { method: "GET", token });
}

module.exports = { sendTextMessage, markAsRead, getMedia, subscribeAppToWaba, listSubscribedApps };
