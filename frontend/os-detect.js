const yearSpan = document.getElementById("year");
if (yearSpan) {
  yearSpan.textContent = String(new Date().getFullYear());
}

// Placeholder download URLs – replace with real links to your builds later
const DOWNLOAD_LINKS = {
  windows: {
    label: "Windows",
    arch: "x64",
    links: [{ label: "Download .exe", href: "#" }]
  },
  macos: {
    label: "macOS",
    arch: "Intel & Apple Silicon",
    links: [{ label: "Download .dmg", href: "#" }]
  },
  linux: {
    label: "Linux",
    arch: "x64",
    links: [
      { label: "Download .AppImage", href: "#" },
      { label: "Download .deb", href: "#" }
    ]
  },
  android: {
    label: "Android",
    arch: "ARM",
    links: [{ label: "Download .apk", href: "#" }]
  },
  ios: {
    label: "iOS",
    arch: "App Store",
    links: [{ label: "Open in App Store", href: "#" }]
  }
};

function detectPlatform() {
  const ua = navigator.userAgent || navigator.vendor || window.opera || "";
  const platform = navigator.platform || "";

  if (/windows phone/i.test(ua)) return "android"; // treat as mobile
  if (/android/i.test(ua)) return "android";
  if (/iPad|iPhone|iPod/.test(ua) && !window.MSStream) return "ios";
  if (/Mac/i.test(platform)) return "macos";
  if (/Win/i.test(platform)) return "windows";
  if (/Linux/i.test(platform)) return "linux";

  // default
  return "windows";
}

function renderPrimaryDownload() {
  const primaryContainer = document.getElementById("primary-download");
  if (!primaryContainer) return;

  const detected = detectPlatform();
  const config = DOWNLOAD_LINKS[detected];

  const button = document.createElement("button");
  button.className = "download-button";

  const mainSpan = document.createElement("span");
  mainSpan.textContent = `Download for ${config.label}`;

  const subSpan = document.createElement("span");
  subSpan.textContent = `Detected: ${config.label}`;
  subSpan.className = "subtitle";

  button.appendChild(mainSpan);
  button.appendChild(subSpan);

  // Use first link as primary – you can add real href and navigation later
  button.addEventListener("click", () => {
    const firstLink = config.links[0];
    if (firstLink && firstLink.href && firstLink.href !== "#") {
      window.location.href = firstLink.href;
    } else {
      window.alert("Download link will be available soon.");
    }
  });

  primaryContainer.appendChild(button);
}

function renderAllPlatforms() {
  const container = document.getElementById("all-platforms");
  if (!container) return;

  Object.values(DOWNLOAD_LINKS).forEach((platform) => {
    const card = document.createElement("div");
    card.className = "platform-card";

    const name = document.createElement("div");
    name.className = "platform-name";
    name.textContent = platform.label;

    const arch = document.createElement("div");
    arch.className = "platform-arch";
    arch.textContent = platform.arch;

    const linksContainer = document.createElement("div");
    linksContainer.className = "platform-links";

    platform.links.forEach((linkCfg) => {
      const a = document.createElement("a");
      a.textContent = linkCfg.label;
      a.href = linkCfg.href || "#";
      a.addEventListener("click", (e) => {
        if (linkCfg.href === "#") {
          e.preventDefault();
          window.alert("Download link will be available soon.");
        }
      });
      linksContainer.appendChild(a);
    });

    card.appendChild(name);
    card.appendChild(arch);
    card.appendChild(linksContainer);

    container.appendChild(card);
  });
}

async function renderServersTable() {
  const body = document.getElementById("servers-table-body");
  if (!body) return;

  try {
    const backendBase = "http://localhost:4000";
    const res = await fetch(`${backendBase}/api/servers`);
    const data = await res.json().catch(() => ({}));
    const servers = data.servers || [];

    body.innerHTML = "";

    servers.forEach((s, idx) => {
      const tr = document.createElement("tr");

      const ping = s.pingMs ?? (25 + idx * 5);
      const load = s.loadPercent ?? Math.min(80, 20 + (s.locations || 1) * 5);
      const host = s.host || s.ip || "n/a";
      const name = s.country || s.name || "Server";

      tr.innerHTML = `
        <td>${name}</td>
        <td>${host}</td>
        <td>${ping} ms</td>
        <td>${load}%</td>
        <td>
          <span class="servers-pill ${s.isFree ? "free" : "paid"}">
            ${s.isFree ? "Free" : "Premium"}
          </span>
        </td>
      `;

      body.appendChild(tr);
    });
  } catch (e) {
    // ignore errors
  }
}

async function callAuth(endpoint, payload) {
  const backendBase = "http://localhost:4000";
  const url = `${backendBase}${endpoint}`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      platform: /Android/i.test(navigator.userAgent)
        ? "android"
        : /iPhone|iPad|iPod/i.test(navigator.userAgent)
        ? "ios"
        : "web",
      "device-type": "desktop",
      "app-version": "web-1.0.0",
    },
    body: JSON.stringify(payload),
  });

  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

function setupAuthForms() {
  const loginForm = document.getElementById("login-form");
  const registerForm = document.getElementById("register-form");
  const loginMsg = document.getElementById("login-message");
  const regMsg = document.getElementById("reg-message");
  const twofaForm = document.getElementById("twofa-form");
  const twofaMsg = document.getElementById("twofa-message");

  let pendingTwoFaGlobalId = null;
  let twofaUseBackup = false;

  if (loginForm && loginMsg) {
    loginForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      loginMsg.textContent = "Signing in...";
      loginMsg.className = "auth-message";

      const login = document.getElementById("login-login").value.trim();
      const password = document.getElementById("login-password").value;

      try {
        const { status, data } = await callAuth("/api/auth/login", {
          login,
          password,
        });

        if (status === 200 && data.token) {
          loginMsg.textContent = "Login successful.";
          loginMsg.className = "auth-message success";
          localStorage.setItem("voyfy_token", data.token);
          if (data.refreshToken) {
            localStorage.setItem("voyfy_refresh", data.refreshToken);
          }
        } else if (
          status === 202 &&
          data.requires2FA &&
          data.globalId
        ) {
          pendingTwoFaGlobalId = data.globalId;
          loginMsg.textContent =
            "2FA required. Please enter the code from your app.";
          loginMsg.className = "auth-message";

          if (twofaForm) {
            twofaForm.classList.remove("auth-card-hidden");
          }
        } else {
          loginMsg.textContent = data.message || "Login failed.";
          loginMsg.className = "auth-message error";
        }
      } catch (err) {
        loginMsg.textContent = "Auth service unavailable.";
        loginMsg.className = "auth-message error";
      }
    });
  }

  if (registerForm && regMsg) {
    registerForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      regMsg.textContent = "Creating account...";
      regMsg.className = "auth-message";

      const login = document.getElementById("reg-login").value.trim();
      const email = document.getElementById("reg-email").value.trim();
      const password = document.getElementById("reg-password").value;
      const gameNickname = document.getElementById("reg-nick").value.trim();

      try {
        const { status, data } = await callAuth("/api/auth/register", {
          login,
          email,
          password,
          gameNickname,
        });

        if ((status === 201 || status === 200) && data.token) {
          regMsg.textContent = "Account created.";
          regMsg.className = "auth-message success";
          localStorage.setItem("voyfy_token", data.token);
          if (data.refreshToken) {
            localStorage.setItem("voyfy_refresh", data.refreshToken);
          }
        } else {
          regMsg.textContent = data.message || "Registration failed.";
          regMsg.className = "auth-message error";
        }
      } catch (err) {
        regMsg.textContent = "Auth service unavailable.";
        regMsg.className = "auth-message error";
      }
    });
  }

  if (twofaForm && twofaMsg) {
    const modeTotpBtn = document.getElementById("twofa-mode-totp");
    const modeBackupBtn = document.getElementById("twofa-mode-backup");
    const labelTotp = document.getElementById("twofa-label-totp");
    const labelBackup = document.getElementById("twofa-label-backup");

    if (modeTotpBtn && modeBackupBtn && labelTotp && labelBackup) {
      modeTotpBtn.addEventListener("click", () => {
        twofaUseBackup = false;
        modeTotpBtn.classList.add("active");
        modeBackupBtn.classList.remove("active");
        labelTotp.classList.remove("hidden");
        labelBackup.classList.add("hidden");
      });
      modeBackupBtn.addEventListener("click", () => {
        twofaUseBackup = true;
        modeBackupBtn.classList.add("active");
        modeTotpBtn.classList.remove("active");
        labelBackup.classList.remove("hidden");
        labelTotp.classList.add("hidden");
      });
    }

    twofaForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      twofaMsg.textContent = "Verifying code...";
      twofaMsg.className = "auth-message";

      let payload;
      if (twofaUseBackup) {
        const backupInput = document.getElementById("twofa-backup");
        const backup = (backupInput.value || "").trim();
        if (!pendingTwoFaGlobalId || !backup) {
          twofaMsg.textContent = "Enter backup code.";
          twofaMsg.className = "auth-message error";
          return;
        }
        payload = {
          globalId: pendingTwoFaGlobalId,
          backupCode: backup,
        };
      } else {
        const codeInput = document.getElementById("twofa-code");
        const code = (codeInput.value || "").trim();
        if (!pendingTwoFaGlobalId || !code) {
          twofaMsg.textContent = "Enter the code.";
          twofaMsg.className = "auth-message error";
          return;
        }
        payload = {
          globalId: pendingTwoFaGlobalId,
          code,
        };
      }

      try {
        const endpoint = twofaUseBackup
          ? "/api/auth/login/backup-code"
          : "/api/auth/login/2fa";
        const { status, data } = await callAuth(endpoint, payload);

        if (status === 200 && data.token) {
          twofaMsg.textContent = "2FA successful. You are logged in.";
          twofaMsg.className = "auth-message success";
          localStorage.setItem("voyfy_token", data.token);
          if (data.refreshToken) {
            localStorage.setItem("voyfy_refresh", data.refreshToken);
          }
        } else {
          twofaMsg.textContent = data.message || "Invalid code.";
          twofaMsg.className = "auth-message error";
        }
      } catch (err) {
        twofaMsg.textContent = "Auth service unavailable.";
        twofaMsg.className = "auth-message error";
      }
    });
  }
}

document.addEventListener("DOMContentLoaded", () => {
  renderPrimaryDownload();
  renderAllPlatforms();
  renderServersTable();
  setupAuthForms();

  // Auto session validation
  (async () => {
    const token = localStorage.getItem("voyfy_token");
    const statusEl = document.getElementById("login-message");
    if (!token) return;

    try {
      const backendBase = "http://localhost:4000";
      const res = await fetch(`${backendBase}/api/auth/validate-session`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          platform: "web",
          "device-type": "desktop",
          "app-version": "web-1.0.0",
        },
        body: JSON.stringify({}),
      });

      const data = await res.json().catch(() => ({}));
      if (res.status === 200 && data.valid) {
        if (statusEl) {
          statusEl.textContent = "You are already logged in.";
          statusEl.className = "auth-message success";
        }
      }
    } catch (e) {
      // ignore errors
    }
  })();

  const allPlatformsBtn = document.getElementById("all-platforms-btn");
  if (allPlatformsBtn) {
    allPlatformsBtn.addEventListener("click", () => {
      const section = document.getElementById("download");
      if (section) {
        section.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
  }
});


