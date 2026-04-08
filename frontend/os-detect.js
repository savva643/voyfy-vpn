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

// Country flags mapping
const COUNTRY_FLAGS = {
  "Germany": "🇩🇪",
  "Finland": "🇫🇮",
  "Turkey": "🇹🇷",
  "USA": "🇺🇸",
  "United States": "🇺🇸",
  "UK": "🇬🇧",
  "United Kingdom": "🇬🇧",
  "France": "🇫🇷",
  "Netherlands": "🇳🇱",
  "Singapore": "🇸🇬",
  "Japan": "🇯🇵",
  "South Korea": "🇰🇷",
  "Brazil": "🇧🇷",
  "Canada": "🇨🇦",
  "Australia": "🇦🇺",
  "India": "🇮🇳",
  "Russia": "🇷🇺",
  "Poland": "🇵🇱",
  "Spain": "🇪🇸",
  "Italy": "🇮🇹",
  "Sweden": "🇸🇪",
  "Switzerland": "🇨🇭",
  "Norway": "🇳🇴",
  "Denmark": "🇩🇰",
  "Austria": "🇦🇹",
  "Belgium": "🇧🇪",
  "Czech Republic": "🇨🇿",
  "Ireland": "🇮🇪",
  "Portugal": "🇵🇹",
  "Romania": "🇷🇴",
  "Ukraine": "🇺🇦",
  "Israel": "🇮🇱",
  "UAE": "🇦🇪",
  "Hong Kong": "🇭🇰",
  "Taiwan": "🇹🇼",
  "Thailand": "🇹🇭",
  "Vietnam": "🇻🇳",
  "Indonesia": "🇮🇩",
  "Malaysia": "🇲🇾",
  "Philippines": "🇵🇭",
  "Mexico": "🇲🇽",
  "Argentina": "🇦🇷",
  "Chile": "🇨🇱",
  "Colombia": "🇨🇴",
  "Peru": "🇵🇪",
  "South Africa": "🇿🇦",
  "Egypt": "🇪🇬",
  "Nigeria": "🇳🇬",
  "Kenya": "🇰🇪",
  "Morocco": "🇲🇦",
  "New Zealand": "🇳🇿"
};

function getFlag(country) {
  return COUNTRY_FLAGS[country] || "🌍";
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

    // Default servers if API returns empty
    const defaultServers = [
      { country: "Germany", host: "de1.voyfy.vpn", pingMs: 45, loadPercent: 35, isFree: false },
      { country: "Finland", host: "fi1.voyfy.vpn", pingMs: 52, loadPercent: 28, isFree: false },
      { country: "Turkey", host: "tr1.voyfy.vpn", pingMs: 68, loadPercent: 42, isFree: true },
      { country: "USA", host: "us1.voyfy.vpn", pingMs: 85, loadPercent: 55, isFree: false },
      { country: "Singapore", host: "sg1.voyfy.vpn", pingMs: 120, loadPercent: 30, isFree: true }
    ];

    const displayServers = servers.length > 0 ? servers : defaultServers;

    displayServers.forEach((s, idx) => {
      const tr = document.createElement("tr");

      const ping = s.pingMs ?? (25 + idx * 5);
      const load = s.loadPercent ?? Math.min(80, 20 + (idx || 1) * 5);
      const host = s.host || s.ip || `${s.country?.toLowerCase() || 'srv'}.voyfy.vpn`;
      const country = s.country || s.name || "Server";
      const flag = getFlag(country);

      // Determine load color
      let loadColor = "#22c55e"; // green
      if (load > 50) loadColor = "#eab308"; // yellow
      if (load > 75) loadColor = "#ef4444"; // red

      tr.innerHTML = `
        <td><span class="server-flag">${flag}</span> ${country}</td>
        <td>${host}</td>
        <td><span class="ping-badge ${ping < 60 ? 'good' : ping < 100 ? 'medium' : 'high'}">${ping} ms</span></td>
        <td>
          <div class="load-indicator">
            <div class="load-bar" style="width: ${load}%; background: ${loadColor}"></div>
            <span>${load}%</span>
          </div>
        </td>
        <td>
          <span class="servers-pill ${s.isFree ? "free" : "paid"}">
            ${s.isFree ? "Free" : "Premium"}
          </span>
        </td>
        <td>
          <button class="connect-btn" onclick="connectToServer('${host}', '${country}')">Connect</button>
        </td>
      `;

      body.appendChild(tr);
    });
  } catch (e) {
    // Render default servers on error
    renderServersTable();
  }
}

// Placeholder for connect function
function connectToServer(host, country) {
  const token = localStorage.getItem("voyfy_token");
  if (!token) {
    alert("Please log in to connect to VPN servers.");
    showSection("auth");
    return;
  }
  alert(`Connecting to ${country} (${host})...\n\nIn the full app, this would establish a VPN connection.`);
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

// Show/hide sections based on login state
function updateUIForAuthState() {
  const token = localStorage.getItem("voyfy_token");
  const dashboard = document.getElementById("dashboard");
  const auth = document.getElementById("auth");
  const loginMsg = document.getElementById("login-message");

  if (token) {
    // User is logged in - show dashboard, hide auth
    if (dashboard) dashboard.classList.remove("hidden");
    if (auth) auth.classList.add("hidden");
  } else {
    // User is not logged in - hide dashboard, show auth
    if (dashboard) dashboard.classList.add("hidden");
    if (auth) auth.classList.remove("hidden");
  }
}

// Show specific section and scroll to it
function showSection(sectionId) {
  const section = document.getElementById(sectionId);
  if (section) {
    section.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

document.addEventListener("DOMContentLoaded", () => {
  renderPrimaryDownload();
  renderAllPlatforms();
  renderServersTable();
  setupAuthForms();
  updateUIForAuthState();

  // Auto session validation
  (async () => {
    const token = localStorage.getItem("voyfy_token");
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
        updateUIForAuthState();
      } else {
        // Token invalid, clear it
        localStorage.removeItem("voyfy_token");
        localStorage.removeItem("voyfy_refresh");
        updateUIForAuthState();
      }
    } catch (e) {
      // ignore errors
    }
  })();

  const allPlatformsBtn = document.getElementById("all-platforms-btn");
  if (allPlatformsBtn) {
    allPlatformsBtn.addEventListener("click", () => {
      showSection("download");
    });
  }
});


