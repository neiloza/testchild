/* ============================================================================
 * app.js — where your app actually starts.
 *
 * The kit's job ends here. Everything above this line (shell, install, store,
 * service worker) is plumbing that is already correct; everything below is
 * yours.
 * ========================================================================= */

import { initTabs, initSheets, toast } from "./ui.js";
import { initInstall } from "./install.js";
import { loadState, saveState } from "./store.js";

const state = loadState();

function persist() {
  saveState(state);
}

function boot() {
  initTabs("home");
  initSheets();
  initInstall({
    onInstalled: () => toast(`__APP_NAME__ is on your home screen.`),
  });

  // Register the worker after `load` so it never competes with first paint.
  if ("serviceWorker" in navigator) {
    window.addEventListener("load", () => {
      navigator.serviceWorker.register("./sw.js").catch(() => {});
    });
  }

  // ---- your app starts here ----
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot);
} else {
  boot();
}

export { state, persist };
