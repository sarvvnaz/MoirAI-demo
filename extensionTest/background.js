const FALLBACK_IMAGE_URL =
  "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSg1EFT4QCkl8fmstgM7mA2wbOGgpZOUIG3CgEjbw_9hNzNpXTjCMHilLI&s=10";

function isAllowedMoirAI(url = "") {
  try {
    const host = new URL(url).hostname;

    return (
      host === "wikipedia.org" ||
      host.endsWith(".wikipedia.org") ||

      // local Flutter frontend/backend
      host === "localhost" ||
      host === "127.0.0.1"
    );
  } catch {
    return false;
  }
}

function canInject(url = "") {
  return url.startsWith("http://") || url.startsWith("https://");
}

async function getReminderFromBackend() {
  const { eftAccessToken } = await chrome.storage.local.get("eftAccessToken");

  if (!eftAccessToken) {
    throw new Error("Extension is not connected to EFT website yet.");
  }

  const response = await fetch(
    "http://127.0.0.1:8000/api/extension/active-reminder",
    {
      headers: {
        Authorization: `Bearer ${eftAccessToken}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Backend reminder failed: ${response.status}`);
  }

  return await response.json();
}

async function fetchImageAsDataUrl() {
  let imageUrl = FALLBACK_IMAGE_URL;

  try {
    const reminder = await getReminderFromBackend();

    if (reminder && reminder.image_url) {
      imageUrl = reminder.image_url;
    }
  } catch (error) {
    console.warn("[overlay] Using fallback image:", error.message);
  }

  const response = await fetch(imageUrl);

  if (!response.ok) {
    throw new Error(`Image fetch failed: ${response.status}`);
  }

  const blob = await response.blob();
  const buffer = await blob.arrayBuffer();
  const bytes = new Uint8Array(buffer);

  let binary = "";
  const chunkSize = 0x8000;

  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }

  return `data:${blob.type || "image/png"};base64,${btoa(binary)}`;
}

function renderOverlay(dataUrl) {
  const oldOverlay = document.getElementById("__wiki_only_overlay");
  if (oldOverlay) oldOverlay.remove();

  const host = document.createElement("div");
  host.id = "__wiki_only_overlay";

  Object.assign(host.style, {
    position: "fixed",
    inset: "0",
    zIndex: "2147483647",
    background: "rgba(0,0,0,0.88)",
    display: "flex",
    alignItems: "center",
    justifyContent: "center"
  });

  const img = document.createElement("img");
  img.src = dataUrl;
  img.alt = "Reminder";

  Object.assign(img.style, {
    maxWidth: "70vw",
    maxHeight: "70vh",
    borderRadius: "16px",
    boxShadow: "0 20px 80px rgba(0,0,0,0.45)"
  });

  host.appendChild(img);

  const parent = document.body || document.documentElement;
  parent.appendChild(host);

  setTimeout(() => {
    host.remove();
  }, 3000);
}

async function showOverlayIfNotAllowed(tab) {
  if (!tab || !tab.id) return;

  const url = tab.url || "";

  if (isAllowedMoirAI(url)) {
    return;
  }

  if (!canInject(url)) {
    console.log("[overlay] Cannot inject into:", url);
    return;
  }

  try {
    const dataUrl = await fetchImageAsDataUrl();

    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: renderOverlay,
      args: [dataUrl]
    });

    console.log("[overlay] shown on:", url);
  } catch (error) {
    console.error("[overlay] failed:", error);
  }
}

async function checkActiveTab() {
  const tabs = await chrome.tabs.query({
    active: true,
    currentWindow: true
  });

  await showOverlayIfNotAllowed(tabs[0]);
}

// Case 1: switching to any old or new tab
chrome.tabs.onActivated.addListener(async () => {
  await checkActiveTab();
});

// Case 2: opening/loading a website in a new tab
chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (changeInfo.status !== "complete") return;

  const activeTabs = await chrome.tabs.query({
    active: true,
    currentWindow: true
  });

  if (!activeTabs[0] || activeTabs[0].id !== tabId) return;

  await showOverlayIfNotAllowed(tab);
});

// Case 3: clicking/focusing another Chrome window
chrome.windows.onFocusChanged.addListener(async (windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) return;

  await checkActiveTab();
});

// Case 4: extension reload / first install while already on a non-allowed tab
chrome.runtime.onInstalled.addListener(async () => {
  await checkActiveTab();
});

chrome.runtime.onStartup.addListener(async () => {
  await checkActiveTab();
});

// Website → extension connection
chrome.runtime.onMessageExternal.addListener((message, sender, sendResponse) => {
  if (message.action !== "CONNECT_EFT_USER") {
    sendResponse({ success: false, error: "Unknown action" });
    return;
  }

  const token = message.accessToken;

  if (!token || typeof token !== "string") {
    sendResponse({ success: false, error: "Missing access token" });
    return;
  }

  chrome.storage.local.set(
    {
      eftAccessToken: token,
      eftConnectedAt: Date.now()
    },
    () => {
      console.log("[EFT Extension] Connected to website session");
      sendResponse({ success: true });
    }
  );

  return true;
});

// Also run once when the service worker wakes up
checkActiveTab();