require("dotenv").config();

const express = require("express");
const { handleVerify, handleWebhookPost } = require("./webhook");
const { sendTextMessage, markAsRead, getMedia, subscribeAppToWaba, listSubscribedApps } = require("./whatsapp");
const { log, warn, error } = require("./logger");

const app = express();

log("Env loaded", {
  port: process.env.PORT || 3000,
  hasVerifyToken: Boolean(process.env.VERIFY_TOKEN),
  verifyTokenLen: process.env.VERIFY_TOKEN ? String(process.env.VERIFY_TOKEN).length : 0,
  hasAppSecret: Boolean(process.env.APP_SECRET),
  graphVersion: process.env.GRAPH_VERSION || "v22.0"
});

app.use(
  express.json({
    verify: (req, _res, buf) => {
      req.rawBodyBuffer = buf;
    },
    limit: "2mb"
  })
);

app.get("/health", (_req, res) => res.status(200).json({ ok: true }));

app.get(["/webhook", "/webhook/"], handleVerify);
app.post(["/webhook", "/webhook/"], handleWebhookPost);

app.post("/send", async (req, res) => {
  try {
    const adminBearer = process.env.ADMIN_BEARER;
    if (adminBearer) {
      const auth = req.get("authorization") || "";
      if (auth !== `Bearer ${adminBearer}`) return res.sendStatus(401);
    }

    const { to, text } = req.body || {};
    if (!to || !text) return res.status(400).json({ error: "Expected body: { to, text }" });

    const result = await sendTextMessage({ toE164: to, text });
    return res.status(200).json(result);
  } catch (err) {
    error("Send failed", err?.payload || err?.message || err);
    return res.status(500).json({ error: "send_failed", details: err?.payload || err?.message || String(err) });
  }
});

app.post("/read", async (req, res) => {
  try {
    const adminBearer = process.env.ADMIN_BEARER;
    if (adminBearer) {
      const auth = req.get("authorization") || "";
      if (auth !== `Bearer ${adminBearer}`) return res.sendStatus(401);
    }

    const { message_id } = req.body || {};
    if (!message_id) return res.status(400).json({ error: "Expected body: { message_id }" });

    const result = await markAsRead(message_id);
    return res.status(200).json(result);
  } catch (e) {
    error("Mark read failed", e?.payload || e?.message || e);
    return res.status(500).json({ error: "mark_read_failed", details: e?.payload || e?.message || String(e) });
  }
});

app.get("/media/:mediaId", async (req, res) => {
  try {
    const adminBearer = process.env.ADMIN_BEARER;
    if (adminBearer) {
      const auth = req.get("authorization") || "";
      if (auth !== `Bearer ${adminBearer}`) return res.sendStatus(401);
    }

    const { mediaId } = req.params;
    if (!mediaId) return res.status(400).json({ error: "Missing media_id" });

    const { base64, mimeType } = await getMedia(mediaId);
    return res.status(200).json({ base64, mimeType });
  } catch (e) {
    error("Media fetch failed", e?.payload || e?.message || e);
    return res.status(500).json({ error: "media_failed", details: e?.payload || e?.message || String(e) });
  }
});

app.post("/waba/subscribe", async (_req, res) => {
  try {
    const result = await subscribeAppToWaba();
    res.status(200).json(result);
  } catch (e) {
    warn("Subscribe failed", e?.payload || e?.message || e);
    res.status(500).json({ error: "subscribe_failed", details: e?.payload || e?.message || String(e) });
  }
});

app.get("/waba/subscribed_apps", async (_req, res) => {
  try {
    const result = await listSubscribedApps();
    res.status(200).json(result);
  } catch (e) {
    warn("List subscribed apps failed", e?.payload || e?.message || e);
    res.status(500).json({ error: "list_failed", details: e?.payload || e?.message || String(e) });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => log(`Server listening on :${port}`));
