const { validateMetaSignature } = require("./security");
const { log, warn } = require("./logger");

function handleVerify(req, res) {
  const mode = req.query["hub.mode"];
  const token = req.query["hub.verify_token"];
  const challenge = req.query["hub.challenge"];

  if (mode === "subscribe" && token === process.env.VERIFY_TOKEN) {
    log("Webhook verified successfully");
    return res.status(200).send(String(challenge));
  }

  warn("Webhook verification failed", {
    mode,
    tokenProvided: Boolean(token),
    providedLen: token ? String(token).length : 0,
    expectedLen: process.env.VERIFY_TOKEN ? String(process.env.VERIFY_TOKEN).length : 0
  });
  return res.sendStatus(403);
}

async function forwardToN8n(payload) {
  const url = process.env.N8N_WEBHOOK_URL;
  if (!url) return;

  try {
    await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
  } catch (e) {
    warn("Failed forwarding to N8N", e?.message || e);
  }
}

function extractUsefulEvents(body) {
  const out = { messages: [], statuses: [] };
  const entries = body?.entry || [];
  for (const entry of entries) {
    const changes = entry?.changes || [];
    for (const change of changes) {
      const value = change?.value || {};
      if (Array.isArray(value.messages)) out.messages.push(...value.messages);
      if (Array.isArray(value.statuses)) out.statuses.push(...value.statuses);
    }
  }
  return out;
}

function handleWebhookPost(req, res) {
  const signature = req.get("x-hub-signature-256");
  const rawBody = req.rawBodyBuffer;
  const { ok, skipped, reason } = validateMetaSignature({
    appSecret: process.env.APP_SECRET,
    signatureHeader: signature,
    rawBodyBuffer: rawBody
  });

  if (!ok) {
    warn("Webhook signature invalid", { reason });
    return res.sendStatus(403);
  }
  if (skipped) warn("APP_SECRET not set: signature validation skipped");

  res.status(200).json({ status: "ok" });

  const body = req.body;
  const { messages, statuses } = extractUsefulEvents(body);

  if (messages.length) {
    log("Incoming messages", messages.map((m) => ({ from: m.from, id: m.id, type: m.type })));
  }
  if (statuses.length) {
    log("Message statuses", statuses.map((s) => ({ id: s.id, status: s.status, recipient_id: s.recipient_id })));
  }

  forwardToN8n(body);
}

module.exports = { handleVerify, handleWebhookPost };
