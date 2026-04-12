const yearSpan = document.getElementById("year");
if (yearSpan) {
  yearSpan.textContent = String(new Date().getFullYear());
}

// Theme Toggle
const THEME_STORAGE_KEY = 'voyfy_theme';

function initTheme() {
  const savedTheme = localStorage.getItem(THEME_STORAGE_KEY);
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

  if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
    document.documentElement.setAttribute('data-theme', 'dark');
  } else {
    document.documentElement.setAttribute('data-theme', 'light');
  }

  updateThemeIcons();
}

function toggleTheme() {
  const currentTheme = document.documentElement.getAttribute('data-theme');
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

  document.documentElement.setAttribute('data-theme', newTheme);
  localStorage.setItem(THEME_STORAGE_KEY, newTheme);
  updateThemeIcons();
}

function updateThemeIcons() {
  const currentTheme = document.documentElement.getAttribute('data-theme');
  const iconClass = currentTheme === 'dark' ? 'fa-moon' : 'fa-sun';

  document.querySelectorAll('.theme-toggle i').forEach(icon => {
    icon.className = `fas ${iconClass}`;
  });
}

// Initialize theme on load
initTheme();

// Add event listeners for theme toggle buttons
document.addEventListener('DOMContentLoaded', () => {
  const desktopThemeToggle = document.getElementById('desktop-theme-toggle');
  const mobileThemeToggle = document.getElementById('mobile-theme-toggle');

  if (desktopThemeToggle) {
    desktopThemeToggle.addEventListener('click', toggleTheme);
  }

  if (mobileThemeToggle) {
    mobileThemeToggle.addEventListener('click', toggleTheme);
  }
});

// OS Icons (SVG paths)
const OS_ICONS = {
  windows: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.9-1.801"/></svg>`,
  macos: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>`,
  linux: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12.504 0c-.155 0-.315.008-.48.021-1.907.132-3.514.915-4.5 2.08-1.017 1.2-1.398 2.706-1.198 4.348.063.525.316 1.212.646 1.986l.03.076c.103.243.22.525.313.784.32.879.503 1.612.503 2.086 0 .89-.385 1.612-.673 2.13l-.063.113c-.21.373-.405.783-.568 1.186l-.014.044c-.13.366-.197.778-.197 1.218 0 .814.24 1.54.707 2.11.475.579 1.166.97 2.01 1.14.403.083.82.124 1.242.124.164 0 .332-.008.503-.021.532-.044 1.06-.13 1.578-.26.493-.125.975-.284 1.433-.472l.072-.03c.385-.166.764-.356 1.122-.563.357-.206.692-.432.996-.672l.09-.07c.256-.208.513-.42.748-.617l.166-.14c.25-.21.484-.425.698-.64.214-.216.41-.433.582-.646l.128-.16c.25-.316.453-.625.6-.917.15-.295.23-.583.23-.853 0-.31-.08-.59-.236-.83-.157-.24-.39-.434-.7-.58-.308-.146-.687-.22-1.13-.22h-.02c-.192 0-.39.018-.593.053-.202.035-.416.09-.64.163-.223.072-.455.16-.696.264-.24.103-.485.22-.735.348-.25.13-.503.267-.756.413-.254.146-.508.3-.76.46-.252.162-.5.327-.745.495-.245.168-.483.34-.714.513-.23.174-.45.346-.66.517l-.046.037c-.166.135-.32.26-.46.373-.14.113-.265.213-.375.3-.11.086-.203.157-.28.213-.075.056-.133.095-.174.117l-.006.003c-.082.046-.206.095-.372.143-.166.048-.363.09-.59.126-.228.036-.472.063-.733.08-.26.018-.528.027-.8.027-.4 0-.76-.04-1.083-.12-.32-.08-.597-.204-.825-.37-.228-.167-.407-.377-.534-.63-.128-.253-.192-.55-.192-.888 0-.38.082-.738.247-1.07.164-.33.396-.628.694-.892.298-.263.658-.48 1.08-.648.42-.168.888-.26 1.4-.272.257-.006.497-.023.72-.05.22-.028.423-.067.605-.117.182-.05.34-.113.476-.188.135-.075.24-.163.315-.263.075-.1.113-.215.113-.343 0-.163-.05-.31-.148-.44-.1-.13-.247-.237-.442-.32-.195-.083-.436-.14-.723-.17-.287-.032-.61-.03-.97.006-.453.045-.902.142-1.346.29-.444.15-.868.338-1.272.566-.405.227-.782.485-1.132.773-.35.29-.66.604-.93.943-.27.34-.494.7-.673 1.08-.18.38-.308.773-.386 1.18-.077.405-.092.81-.046 1.215.046.405.156.79.33 1.154.175.365.412.69.71.976.3.285.66.52 1.08.702.42.184.9.295 1.44.334.54.04 1.134.003 1.78-.11.646-.114 1.344-.304 2.094-.57l.008-.003c.134-.048.305-.104.51-.168.207-.065.44-.13.702-.2.26-.07.545-.133.852-.19.308-.055.628-.096.958-.122.33-.026.665-.036 1.003-.03.34.006.672.03.998.072.325.04.636.103.934.186.298.083.577.19.838.32.26.13.495.285.706.46.21.175.393.375.55.6.155.223.278.473.367.747"/></svg>`,
  android: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0225 3.503C15.5902 8.4796 13.8531 8.095 12.001 8.095c-1.8521 0-3.589.3847-5.1366 1.0548L4.842 5.6466a.416.416 0 00-.5676-.1521.416.416 0 00-.1521.5676l1.9973 3.4592C2.7879 11.4 0 14.881 0 18.865h24c0-3.984-2.7879-7.465-6.1195-9.5436"/></svg>`,
  ios: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>`
};

// Placeholder download URLs – replace with real links to your builds later
const DOWNLOAD_LINKS = {
  windows: {
    label: "Windows",
    arch: "x64",
    icon: "windows",
    links: [{ label: "Download .exe", href: "#" }]
  },
  macos: {
    label: "macOS",
    arch: "Intel & Apple Silicon",
    icon: "macos",
    links: [{ label: "Download .dmg", href: "#" }]
  },
  linux: {
    label: "Linux",
    arch: "x64",
    icon: "linux",
    links: [
      { label: "Download .AppImage", href: "#" },
      { label: "Download .deb", href: "#" }
    ]
  },
  android: {
    label: "Android",
    arch: "ARM",
    icon: "android",
    links: [{ label: "Download .apk", href: "#" }]
  },
  ios: {
    label: "iOS",
    arch: "App Store",
    icon: "ios",
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

  const iconDiv = document.createElement("div");
  iconDiv.className = "download-icon";
  iconDiv.innerHTML = OS_ICONS[config.icon] || OS_ICONS.linux;

  const textDiv = document.createElement("div");
  textDiv.className = "download-text";

  const mainSpan = document.createElement("span");
  mainSpan.className = "download-label";
  mainSpan.textContent = `Download for ${config.label}`;

  const subSpan = document.createElement("span");
  subSpan.className = "subtitle";
  subSpan.textContent = `Detected: ${config.label}`;

  textDiv.appendChild(mainSpan);
  textDiv.appendChild(subSpan);

  button.appendChild(iconDiv);
  button.appendChild(textDiv);

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

    const header = document.createElement("div");
    header.className = "platform-header";

    const iconDiv = document.createElement("div");
    iconDiv.className = "platform-icon";
    iconDiv.innerHTML = OS_ICONS[platform.icon] || OS_ICONS.linux;

    const name = document.createElement("div");
    name.className = "platform-name";
    name.textContent = platform.label;

    header.appendChild(iconDiv);
    header.appendChild(name);

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

    card.appendChild(header);
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
    showToast('Please log in to connect to VPN servers', 'error');
    window.location.href = './auth.html';
    return;
  }
  showToast(`Connecting to ${country}...`, 'info');
}

// Update UI based on authentication state
function updateAuthUI(isLoggedIn) {
  const desktopAuthLink = document.getElementById('desktop-auth-link');
  const mobileAuthLink = document.getElementById('mobile-auth-link');
  const mobileAuthText = document.getElementById('mobile-auth-text');

  if (isLoggedIn) {
    // Update desktop header - link to profile
    if (desktopAuthLink) {
      desktopAuthLink.href = './profile.html';
      desktopAuthLink.classList.add('profile-link');
      desktopAuthLink.classList.remove('auth-tab-link');
      desktopAuthLink.innerHTML = '<i class="fas fa-user"></i> Profile';
    }
    // Update mobile bottom nav - link to profile
    if (mobileAuthLink) {
      mobileAuthLink.href = './profile.html';
      mobileAuthLink.classList.add('profile-link');
    }
    if (mobileAuthText) {
      mobileAuthText.textContent = 'Profile';
    }
  } else {
    // Reset to sign in state
    if (desktopAuthLink) {
      desktopAuthLink.href = './auth.html';
      desktopAuthLink.classList.remove('profile-link');
      desktopAuthLink.classList.add('auth-tab-link');
      desktopAuthLink.textContent = 'Sign in';
    }
    if (mobileAuthLink) {
      mobileAuthLink.href = './auth.html';
      mobileAuthLink.classList.remove('profile-link');
    }
    if (mobileAuthText) {
      mobileAuthText.textContent = 'Sign in';
    }
  }
}

// Check auth state on page load and update UI
function checkAuthState() {
  const token = localStorage.getItem('voyfy_token');
  if (token) {
    updateAuthUI(true);
    return true;
  } else {
    updateAuthUI(false);
    return false;
  }
}

// Toast notification system
function showToast(message, type = 'info', duration = 5000) {
  const container = document.getElementById('toast-container');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = `toast ${type}`;

  const icon = type === 'success' ? 'fa-check-circle' :
               type === 'error' ? 'fa-exclamation-circle' :
               'fa-info-circle';

  toast.innerHTML = `
    <i class="fas ${icon}"></i>
    <span>${message}</span>
  `;

  container.appendChild(toast);

  setTimeout(() => {
    toast.remove();
  }, duration);
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

  if (loginForm) {
    loginForm.addEventListener("submit", async (e) => {
      e.preventDefault();

      const email = document.getElementById("login-email").value.trim();
      const password = document.getElementById("login-password").value;

      if (!email || !password) {
        showToast('Please enter email and password', 'error');
        return;
      }

      showToast('Signing in...', 'info', 2000);

      try {
        const { status, data } = await callAuth("/api/auth/login", {
          email,
          password,
        });

        if (status === 200 && data.data?.tokens?.accessToken) {
          showToast('Login successful!', 'success');
          localStorage.setItem("voyfy_token", data.data.tokens.accessToken);
          if (data.data.tokens.refreshToken) {
            localStorage.setItem("voyfy_refresh", data.data.tokens.refreshToken);
          }
          // Save user info
          if (email) localStorage.setItem("voyfy_email", email);
          if (data.data?.subscription) {
            localStorage.setItem("voyfy_subscription", data.data.subscription);
          }
          // Redirect to profile
          setTimeout(() => {
            window.location.href = './profile.html';
          }, 1000);
        } else if (status === 202 && data.requires2FA && data.globalId) {
          pendingTwoFaGlobalId = data.globalId;
          showToast('2FA required. Please enter the code from your app.', 'info');
          if (twofaForm) {
            twofaForm.classList.remove("auth-card-hidden");
          }
        } else {
          showToast(data.message || 'Login failed', 'error');
        }
      } catch (err) {
        showToast('Auth service unavailable', 'error');
      }
    });
  }

  if (registerForm) {
    registerForm.addEventListener("submit", async (e) => {
      e.preventDefault();

      const email = document.getElementById("reg-email").value.trim();
      const password = document.getElementById("reg-password").value;

      if (!email || !password) {
        showToast('Please enter email and password', 'error');
        return;
      }

      if (password.length < 6) {
        showToast('Password must be at least 6 characters', 'error');
        return;
      }

      showToast('Creating account...', 'info', 2000);

      try {
        const { status, data } = await callAuth("/api/auth/register", {
          email,
          password,
        });

        if (status === 201 && data.data?.tokens?.accessToken) {
          showToast('Account created successfully!', 'success');
          localStorage.setItem("voyfy_token", data.data.tokens.accessToken);
          if (data.data.tokens.refreshToken) {
            localStorage.setItem("voyfy_refresh", data.data.tokens.refreshToken);
          }
          // Save user info
          if (email) localStorage.setItem("voyfy_email", email);
          if (data.data?.subscription) {
            localStorage.setItem("voyfy_subscription", data.data.subscription);
          }
          // Redirect to profile
          setTimeout(() => {
            window.location.href = './profile.html';
          }, 1000);
        } else {
          showToast(data.message || 'Registration failed', 'error');
        }
      } catch (err) {
        showToast('Auth service unavailable', 'error');
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
  const loginMsg = document.getElementById("login-message");

  if (!loginMsg) return;

  if (token) {
    loginMsg.textContent = "You are signed in.";
    loginMsg.className = "auth-message success";
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

  const allPlatformsBtn = document.getElementById("all-platforms-btn");
  if (allPlatformsBtn) {
    allPlatformsBtn.addEventListener("click", () => {
      showSection("download");
    });
  }
});


