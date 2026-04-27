/**
 * YTMusic Widget — Content Script v2
 * Selectores robustizados, sin fetch directo a localhost.
 */

// Guardia: evitar doble ejecución si el script se inyecta más de una vez
if (window.__ytWidgetActive) {
  console.log('[YTWidget] Ya activo en esta pestaña, omitiendo re-inyección.');
} else {
window.__ytWidgetActive = true;

let lastTrackId = '';

// ─── Selectores robustos para YouTube Music ──────────────────────────────────

const SEL = {
  title:    'yt-formatted-string.title.ytmusic-player-bar',
  artist:   '.subtitle.ytmusic-player-bar a, .subtitle.ytmusic-player-bar yt-formatted-string',
  albumArt: 'img.ytmusic-player-bar',
  playBtn:  '#play-pause-button, .play-pause-button',
  prevBtn:  '.previous-button, tp-yt-paper-icon-button[aria-label*="Previous"]',
  nextBtn:  '.next-button, tp-yt-paper-icon-button[aria-label*="Next"]',
  likeBtn:  'ytmusic-like-button-renderer tp-yt-paper-icon-button[aria-label*="Like"], ytmusic-like-button-renderer #button-shape-like button',
  repeat:   '.repeat.ytmusic-player-bar, tp-yt-paper-icon-button.repeat',
  shuffle:  '.shuffle.ytmusic-player-bar, tp-yt-paper-icon-button.shuffle',
  slider:   'tp-yt-paper-slider#progress-bar, #progress-bar',
  timeInfo: '.time-info'
};

function q(selector) {
  for (const s of selector.split(',')) {
    const el = document.querySelector(s.trim());
    if (el) return el;
  }
  return null;
}

// ─── Leer estado ──────────────────────────────────────────────────────────────

function getPlayerState() {
  try {
    // ── Fuente primaria: Media Session API (la misma que usa macOS) ───────────
    const ms   = navigator.mediaSession;
    const meta = ms?.metadata;

    const title    = meta?.title  || q(SEL.title)?.textContent?.trim()  || '';
    const artist   = meta?.artist || q(SEL.artist)?.textContent?.trim() || '';
    const albumArt = (meta?.artwork?.length > 0
                       ? meta.artwork[meta.artwork.length - 1].src
                       : null)
                     || q(SEL.albumArt)?.src || '';

    // playbackState: 'playing' | 'paused' | 'none'
    const isPlaying = ms?.playbackState === 'playing';

    // ── Botones (solo disponibles en DOM) ─────────────────────────────────────
    const likeBtn = q(SEL.likeBtn);
    const isLiked = likeBtn?.getAttribute('aria-pressed') === 'true'
                 || likeBtn?.getAttribute('aria-label')?.toLowerCase().includes('unlike') || false;

    const repeatBtn  = q(SEL.repeat);
    const repeatMode = repeatBtn?.getAttribute('aria-label') || 'NONE';

    const shuffleBtn = q(SEL.shuffle);
    const isShuffled = shuffleBtn?.getAttribute('aria-pressed') === 'true';

    // ── Progreso — leer del elemento <video> (actualiza en tiempo real) ──────
    const video       = document.querySelector('video');
    const currentTime = (video && !isNaN(video.currentTime)) ? video.currentTime
                        : parseFloat(q(SEL.slider)?.value || 0);
    const duration    = (video && video.duration > 0 && !isNaN(video.duration)) ? video.duration
                        : parseFloat(q(SEL.slider)?.max || 0);

    // Tiempos formateados desde el DOM (fallback al cálculo)
    const timeRaw   = q(SEL.timeInfo)?.textContent?.trim() || '';
    const timeParts = timeRaw.split('/').map(s => s.trim());
    const timeText  = timeParts.length === 2 ? timeParts[0] : '';
    const totalText = timeParts.length === 2 ? timeParts[1] : '';

    const trackId = `${title}::${artist}`;
    return { title, artist, albumArt, isPlaying, isLiked, repeatMode, isShuffled,
             currentTime, duration, timeText, totalText, trackId };
  } catch (e) {
    console.warn('[YTWidget] getPlayerState error:', e);
    return null;
  }
}

// ─── Enviar estado al background ──────────────────────────────────────────────

function sendState() {
  const state = getPlayerState();
  if (!state) return;

  try {
    chrome.runtime.sendMessage({ type: 'state_update', state }, () => {
      if (chrome.runtime.lastError) { /* background no disponible, ignorar */ }
    });
  } catch { /* extension context invalidated */ }

  if (state.trackId !== lastTrackId && state.title) {
    lastTrackId = state.trackId;
    console.log('[YTWidget] ▶', state.title, '—', state.artist);
  }
}

// ─── Ejecutar acciones ────────────────────────────────────────────────────────

function safeClick(selector) {
  const el = q(selector);
  if (el) {
    el.click();
    setTimeout(sendState, 400);
    return true;
  }
  console.warn('[YTWidget] No se encontró el elemento:', selector);
  return false;
}

// ─── Seek via simulación de click en el slider ────────────────────────────────

function seekTo(position) {
  const pos = Math.max(0, Math.min(1, position));

  // 1. Intentar con el slider de YouTube Music (tp-yt-paper-slider)
  const slider = q(SEL.slider);
  if (slider) {
    const rect = slider.getBoundingClientRect();
    if (rect.width > 0) {
      const x = rect.left + rect.width * pos;
      const y = rect.top + rect.height / 2;

      // Simular interacción completa de mouse (igual que el usuario)
      const opts = (type) => new MouseEvent(type, {
        bubbles: true, cancelable: true, view: window,
        clientX: x, clientY: y, buttons: type === 'mousedown' ? 1 : 0
      });

      slider.dispatchEvent(opts('mousedown'));
      slider.dispatchEvent(opts('mouseup'));
      slider.dispatchEvent(opts('click'));

      // También probar con PointerEvents (más moderno)
      slider.dispatchEvent(new PointerEvent('pointerdown', {
        bubbles: true, cancelable: true, view: window,
        clientX: x, clientY: y, pointerId: 1, pointerType: 'mouse', buttons: 1
      }));
      slider.dispatchEvent(new PointerEvent('pointerup', {
        bubbles: true, cancelable: true, view: window,
        clientX: x, clientY: y, pointerId: 1, pointerType: 'mouse'
      }));
    }
  }

  // 2. Fallback: elemento <video> directo
  const video = document.querySelector('video');
  if (video && video.duration > 0) {
    video.currentTime = pos * video.duration;
  }

  setTimeout(sendState, 500);
}

function handleAction(action) {
  console.log('[YTWidget] Acción recibida:', action);
  switch (action) {
    case 'play_pause': safeClick(SEL.playBtn);  break;
    case 'prev':       safeClick(SEL.prevBtn);  break;
    case 'next':       safeClick(SEL.nextBtn);  break;
    case 'like':       safeClick(SEL.likeBtn);  break;
    case 'repeat':     safeClick(SEL.repeat);   break;
    case 'shuffle':    safeClick(SEL.shuffle);  break;
  }
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  // Background jala el estado
  if (msg.type === 'get_state') {
    sendResponse(getPlayerState());
    return false;
  }
  // Seek: simular click en el slider en la posición exacta
  if (msg.action === 'seek' && msg.position !== undefined) {
    seekTo(msg.position);
    return;
  }
  // Comandos de reproducción
  if (msg.action) {
    handleAction(msg.action);
  }
});

// ─── Arranque: esperar al reproductor ────────────────────────────────────────

function init() {
  const check = setInterval(() => {
    if (document.querySelector('ytmusic-player-bar')) {
      clearInterval(check);
      console.log('[YTWidget] ✓ Reproductor detectado');
      sendState();
      setInterval(sendState, 1200);

      // Observer para cambios inmediatos
      const bar = document.querySelector('ytmusic-player-bar');
      if (bar) {
        new MutationObserver(sendState).observe(bar, {
          subtree: true, childList: true, characterData: true
        });
      }
    }
  }, 600);
}

init();

} // fin del bloque else (guardia de doble inyección)
