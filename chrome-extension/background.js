/**
 * YTMusic Widget — Background Service Worker v3
 *
 * Flujo confiable:
 *   COMANDOS : background → (pollCommands←server) → content script → YT Music
 *   ESTADO   : background → (pollState→tab) ← content script ← YT Music DOM/MediaSession
 */

const API = 'http://localhost:23567';

let lastState = null;

// ─── PULL de estado: background pregunta al content script ───────────────────
// (la misma dirección que los comandos, que sabemos que funciona)

async function pollState() {
  try {
    const tabs = await chrome.tabs.query({ url: 'https://music.youtube.com/*' });
    for (const tab of tabs) {
      chrome.tabs.sendMessage(tab.id, { type: 'get_state' }, (state) => {
        if (chrome.runtime.lastError) return;   // content script aún no listo
        if (state && state.title !== undefined) {
          lastState = state;
          postState(state);
        }
      });
    }
  } catch { /* sin pestañas */ }

  setTimeout(pollState, 500);   // 2× por segundo → barra más fluida
}

// ─── PULL de comandos: background pregunta al server Swift ───────────────────

async function pollCommands() {
  try {
    const res = await fetch(`${API}/command`, { signal: AbortSignal.timeout(2500) });
    if (res.ok) {
      const data = await res.json();
      const commands = data.commands || [];
      if (commands.length > 0) {
        const tabs = await chrome.tabs.query({ url: 'https://music.youtube.com/*' });
        for (const tab of tabs) {
          for (const cmd of commands) {
            if (cmd.startsWith('seek:')) {
              const position = parseFloat(cmd.substring(5));
              chrome.tabs.sendMessage(tab.id, { action: 'seek', position }, () => {
                if (chrome.runtime.lastError) {}
              });
            } else {
              chrome.tabs.sendMessage(tab.id, { action: cmd }, () => {
                if (chrome.runtime.lastError) {}
              });
            }
          }
        }
      }
    }
  } catch { /* server no disponible */ }

  setTimeout(pollCommands, 700);
}

// ─── Mensaje de popup (ping / get_state) ─────────────────────────────────────

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type === 'get_state') {
    sendResponse({ state: lastState });
    return false;
  }

  if (msg.type === 'ping') {
    fetch(`${API}/ping`, { signal: AbortSignal.timeout(2000) })
      .then(r => sendResponse({ ok: r.ok }))
      .catch(()  => sendResponse({ ok: false }));
    return true;
  }
});

// ─── Enviar estado al server Swift ───────────────────────────────────────────

async function postState(state) {
  try {
    await fetch(`${API}/state`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(state),
      signal:  AbortSignal.timeout(2000)
    });
  } catch { /* server no disponible */ }
}

// ─── Inyectar content script en pestañas ya abiertas ─────────────────────────

async function injectIntoOpenTabs() {
  try {
    const tabs = await chrome.tabs.query({ url: 'https://music.youtube.com/*' });
    for (const tab of tabs) {
      await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ['content.js']
      }).catch(() => {});
      console.log(`[BG] Inyectado en tab ${tab.id}`);
    }
  } catch (e) {
    console.warn('[BG] Error inyectando:', e);
  }
}

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url?.includes('music.youtube.com')) {
    chrome.scripting.executeScript({ target: { tabId }, files: ['content.js'] }).catch(() => {});
  }
});

// ─── Arranque ─────────────────────────────────────────────────────────────────

chrome.runtime.onInstalled.addListener(() => { injectIntoOpenTabs(); });

injectIntoOpenTabs();
pollState();       // ← nuevo: jala estado del content script
pollCommands();
console.log('[BG] Service worker iniciado ✓');
