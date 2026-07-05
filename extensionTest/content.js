const CLOUD_IMAGE_URL =
  "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSg1EFT4QCkl8fmstgM7mA2wbOGgpZOUIG3CgEjbw_9hNzNpXTjCMHilLI&s=10";

// Listen for trigger from background
chrome.runtime.onMessage.addListener((message) => {
  if (message.action !== "showOverlay") return;

  // prevent duplicates
  if (document.getElementById("wiki-overlay")) return;

  const overlay = document.createElement("div");
  overlay.id = "wiki-overlay";

  Object.assign(overlay.style, {
    position: "fixed",
    top: 0,
    left: 0,
    width: "100vw",
    height: "100vh",
    backgroundColor: "rgba(0,0,0,0.9)",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    zIndex: 999999
  });

  const img = document.createElement("img");
  img.src = CLOUD_IMAGE_URL;
  img.style.maxWidth = "70%";
  img.style.maxHeight = "70%";
  img.style.borderRadius = "12px";

  overlay.appendChild(img);
  document.body.appendChild(overlay);

  // auto-remove after 3 seconds
  setTimeout(() => overlay.remove(), 3000);
});