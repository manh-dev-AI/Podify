/* ==========================================================================
   Podify — Shared Layout Utilities (Common JS)
   Mạnh (Content) và Quang (Ads & Analytics) có thể tái sử dụng module này.
   ========================================================================== */

const PodifyUI = (() => {
  let toastTimer = null;

  function showToast(message) {
    const toast = document.getElementById('podifyToast');
    if (!toast) return;
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 2400);
  }

  function initThemeToggle() {
    const saved = localStorage.getItem('podify_theme') || 'dark';
    document.documentElement.setAttribute('data-theme', saved);

    const btn = document.getElementById('themeSwitchBtn');
    if (!btn) return;
    btn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme');
      const next = current === 'light' ? 'dark' : 'light';
      document.documentElement.setAttribute('data-theme', next);
      localStorage.setItem('podify_theme', next);
    });
  }

  function fmtTime(sec) {
    const s = Math.max(0, Math.floor(sec));
    const m = Math.floor(s / 60);
    const r = s % 60;
    return `${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`;
  }

  function initCommon() {
    initThemeToggle();
  }

  return { showToast, fmtTime, initCommon };
})();
