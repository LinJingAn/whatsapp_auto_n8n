const crypto = require("crypto");

function timingSafeEqual(a, b) {
  const aBuf = Buffer.from(a);
  const bBuf = Buffer.from(b);
  if (aBuf.length !== bBuf.length) return false;
  return crypto.timingSafeEqual(aBuf, bBuf);
}

function validateMetaSignature({ appSecret, signatureHeader, rawBodyBuffer }) {
  if (!appSecret) {
    return { ok: true, skipped: true, reason: "APP_SECRET not set" };
  }
  if (!signatureHeader) {
    return { ok: false, reason: "Missing x-hub-signature-256" };
  }

  const [algo, theirHash] = String(signatureHeader).split("=");
  if (algo !== "sha256" || !theirHash) {
    return { ok: false, reason: "Invalid signature format" };
  }

  const ourHash = crypto
    .createHmac("sha256", appSecret)
    .update(rawBodyBuffer)
    .digest("hex");

  return {
    ok: timingSafeEqual(ourHash, theirHash),
    skipped: false,
    reason: "Mismatch"
  };
}

module.exports = { validateMetaSignature };
