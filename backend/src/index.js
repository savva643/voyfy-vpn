const express = require("express");
const cors = require("cors");
const fetch = require("node-fetch");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 4000;

// Base URL of auth-service (production: https://auth.keep-pixel.ru)
const AUTH_SERVICE_URL =
  process.env.AUTH_SERVICE_URL || "https://auth.keep-pixel.ru";

app.use(
  cors({
    origin: true,
    credentials: true
  })
);
app.use(express.json());

// Simple health check
app.get("/api/health", (req, res) => {
  res.json({ status: "ok", service: "voyfy-backend" });
});

// Proxy auth routes to auth-service, so clients always talk to our backend
app.post("/api/auth/login", async (req, res) => {
  try {
    const response = await fetch(`${AUTH_SERVICE_URL}/api/auth/login`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        // Pass through device-related headers if present
        "device-fingerprint": req.headers["device-fingerprint"] || "",
        platform: req.headers["platform"] || "",
        "device-type": req.headers["device-type"] || "",
        "app-version": req.headers["app-version"] || "",
        authorization: req.headers.authorization || ""
      },
      body: JSON.stringify(req.body || {})
    });

    const data = await response.json().catch(() => ({}));
    res.status(response.status).json(data);
  } catch (err) {
    console.error("Auth proxy /login error:", err);
    res.status(500).json({ message: "Auth service unavailable" });
  }
});

app.post("/api/auth/register", async (req, res) => {
  try {
    const response = await fetch(`${AUTH_SERVICE_URL}/api/auth/register`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "device-fingerprint": req.headers["device-fingerprint"] || "",
        platform: req.headers["platform"] || "",
        "device-type": req.headers["device-type"] || "",
        "app-version": req.headers["app-version"] || ""
      },
      body: JSON.stringify(req.body || {})
    });

    const data = await response.json().catch(() => ({}));
    res.status(response.status).json(data);
  } catch (err) {
    console.error("Auth proxy /register error:", err);
    res.status(500).json({ message: "Auth service unavailable" });
  }
});

app.post("/api/auth/login/2fa", async (req, res) => {
  try {
    const response = await fetch(`${AUTH_SERVICE_URL}/api/auth/login/2fa`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "device-fingerprint": req.headers["device-fingerprint"] || "",
        platform: req.headers["platform"] || "",
        "device-type": req.headers["device-type"] || "",
        "app-version": req.headers["app-version"] || ""
      },
      body: JSON.stringify(req.body || {})
    });

    const data = await response.json().catch(() => ({}));
    res.status(response.status).json(data);
  } catch (err) {
    console.error("Auth proxy /login/2fa error:", err);
    res.status(500).json({ message: "Auth service unavailable" });
  }
});

app.post("/api/auth/login/backup-code", async (req, res) => {
  try {
    const response = await fetch(
      `${AUTH_SERVICE_URL}/api/auth/login/backup-code`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "device-fingerprint": req.headers["device-fingerprint"] || "",
          platform: req.headers["platform"] || "",
          "device-type": req.headers["device-type"] || "",
          "app-version": req.headers["app-version"] || ""
        },
        body: JSON.stringify(req.body || {})
      }
    );

    const data = await response.json().catch(() => ({}));
    res.status(response.status).json(data);
  } catch (err) {
    console.error("Auth proxy /login/backup-code error:", err);
    res.status(500).json({ message: "Auth service unavailable" });
  }
});

app.post("/api/auth/validate-session", async (req, res) => {
  try {
    const response = await fetch(
      `${AUTH_SERVICE_URL}/api/auth/validate-session`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "device-fingerprint": req.headers["device-fingerprint"] || "",
          platform: req.headers["platform"] || "",
          "device-type": req.headers["device-type"] || "",
          "app-version": req.headers["app-version"] || "",
          authorization: req.headers.authorization || ""
        },
        body: JSON.stringify({})
      }
    );

    const data = await response.json().catch(() => ({}));
    res.status(response.status).json(data);
  } catch (err) {
    console.error("Auth proxy /validate-session error:", err);
    res.status(500).json({ message: "Auth service unavailable" });
  }
});

app.post("/api/auth/refresh", async (req, res) => {
  try {
    const response = await fetch(`${AUTH_SERVICE_URL}/api/auth/refresh`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(req.body || {})
    });

    const data = await response.json().catch(() => ({}));
    res.status(response.status).json(data);
  } catch (err) {
    console.error("Auth proxy /refresh error:", err);
    res.status(500).json({ message: "Auth service unavailable" });
  }
});

// Static list of VPN servers (for now) – loaded from Flutter JSON for consistency
app.get("/api/servers", (req, res) => {
  try {
    const jsonPath = path.join(
      __dirname,
      "..",
      "..",
      "voyfy-flutter",
      "server",
      "server.json"
    );
    const raw = fs.readFileSync(jsonPath, "utf8");
    const servers = JSON.parse(raw);
    res.json({ servers });
  } catch (err) {
    console.error("Error reading servers:", err);
    res.json({ servers: [] });
  }
});

app.listen(PORT, () => {
  console.log(`Voyfy backend is running on http://localhost:${PORT}`);
});


