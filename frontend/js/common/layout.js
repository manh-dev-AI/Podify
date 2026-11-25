/* ==========================================================================
   Podify — Shared Layout, Session, Auth View & API Client Utilities (Common JS)
   ========================================================================== */

const PodifyUI = (() => {
  const TOKEN_KEY = 'podify_token';
  const USER_KEY = 'podify_user';
  let toastTimer = null;
  let onAuthChangeCb = null;
  let onNavigateAuthCb = null;
  let authTab = 'login';
  let demoUsersCache = null;

  function escapeHtml(value) {
    return String(value ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function showToast(message) {
    const toast = document.getElementById('podifyToast');
    if (!toast) return;
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 2800);
  }

  function fmtTime(sec) {
    const s = Math.max(0, Math.floor(Number(sec) || 0));
    const m = Math.floor(s / 60);
    const r = s % 60;
    return `${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`;
  }

  function fmtCurrency(amount) {
    return `${new Intl.NumberFormat('vi-VN').format(Number(amount) || 0)} đ`;
  }

  function getToken() {
    return localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY);
  }

  function getUser() {
    try {
      const raw = localStorage.getItem(USER_KEY) || sessionStorage.getItem(USER_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  function setSession(token, user, remember = true) {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(USER_KEY);

    const store = remember ? localStorage : sessionStorage;
    if (token) store.setItem(TOKEN_KEY, token);
    if (user) store.setItem(USER_KEY, JSON.stringify(user));
    syncUserPill();
    if (onAuthChangeCb) onAuthChangeCb(user);
  }

  function clearSession() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(USER_KEY);
    syncUserPill();
    if (onAuthChangeCb) onAuthChangeCb(null);
  }

  function syncUserPill() {
    const user = getUser();
    const letterEl = document.getElementById('userAvatarLetter');
    const nameEl = document.getElementById('userDisplayName');

    if (user) {
      const display = user.creator_display_name || user.full_name || user.username;
      if (letterEl) letterEl.textContent = display.trim().charAt(0).toUpperCase();
      if (nameEl) nameEl.textContent = `${user.username} (${user.role})`;
    } else {
      if (letterEl) letterEl.textContent = 'G';
      if (nameEl) nameEl.textContent = 'Đăng nhập';
    }
  }

  async function api(path, options = {}) {
    const headers = { ...(options.headers || {}) };
    if (options.body && !(options.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
    }
    const token = getToken();
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const res = await fetch(path, {
      ...options,
      headers,
      body:
        options.body && typeof options.body !== 'string' && !(options.body instanceof FormData)
          ? JSON.stringify(options.body)
          : options.body,
    });

    const data = await res.json().catch(() => ({ ok: false, error: `HTTP ${res.status}` }));
    if (!res.ok || data.ok === false) {
      const err = new Error(data.error || `Yêu cầu thất bại (${res.status})`);
      err.status = res.status;
      err.code = data.code;
      throw err;
    }
    return data.data;
  }

  async function verifyExistingSession() {
    const token = getToken();
    if (!token) return;
    try {
      const freshUser = await api('/api/content/auth/me');
      const remember = Boolean(localStorage.getItem(TOKEN_KEY));
      const store = remember ? localStorage : sessionStorage;
      store.setItem(USER_KEY, JSON.stringify(freshUser));
      syncUserPill();
    } catch (err) {
      if (err.status === 401) {
        clearSession();
      }
    }
  }

  function initThemeToggle() {
    const saved = localStorage.getItem('podify_theme') || 'light';
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

  function openAuthModal(tab = 'login') {
    authTab = tab === 'register' ? 'register' : 'login';
    if (onNavigateAuthCb) {
      onNavigateAuthCb('auth');
    }
  }

  function closeAuthModal() {
    if (onNavigateAuthCb) {
      onNavigateAuthCb('back');
    }
  }

  function openAccountModal() {
    const user = getUser();
    if (!user) {
      openAuthModal('login');
      return;
    }
    const modal = document.getElementById('accountModal');
    const body = document.getElementById('accountModalBody');
    if (!modal || !body) return;

    body.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;">
        <div>
          <strong style="font-size:15px;">${escapeHtml(user.full_name)}</strong>
          <div style="font-size:12px;color:var(--text-secondary);">@${escapeHtml(user.username)} · ${escapeHtml(user.email)}</div>
        </div>
        <span class="badge-verified">${escapeHtml(user.role).toUpperCase()}</span>
      </div>
      ${
        user.creator_id
          ? `<div style="border-top:1px solid var(--border-subtle);padding-top:8px;font-size:12.5px;">
               <div>Kênh Creator: <strong>${escapeHtml(user.creator_display_name)}</strong></div>
               <div style="color:var(--text-secondary);margin-top:2px;">${escapeHtml(user.creator_bio || 'Chưa có mô tả hồ sơ.')}</div>
             </div>`
          : ''
      }
    `;
    modal.hidden = false;
  }

  function closeAccountModal() {
    const modal = document.getElementById('accountModal');
    if (modal) modal.hidden = true;
  }

  async function quickLogin(username, remember = true) {
    const res = await api('/api/content/auth/login', {
      method: 'POST',
      body: { identifier: username, password: '123456' },
    });
    setSession(res.token, res.user, remember);
    showToast(`Đã đăng nhập: ${res.user.full_name} (${res.user.role})`);
    return res.user;
  }

  function logout() {
    closeAccountModal();
    clearSession();
    showToast('Đã đăng xuất khỏi tài khoản.');
  }

  async function loadDemoUsers() {
    if (demoUsersCache) return demoUsersCache;
    try {
      demoUsersCache = await api('/api/content/users/demo');
    } catch {
      demoUsersCache = [];
    }
    return demoUsersCache;
  }

  function _passwordStrength(pw) {
    if (!pw) return { pct: 0, label: 'Chưa nhập', color: 'var(--border-strong)' };
    let score = 0;
    if (pw.length >= 6) score += 1;
    if (pw.length >= 10) score += 1;
    if (/[A-Z]/.test(pw) && /[a-z]/.test(pw)) score += 1;
    if (/\d/.test(pw) || /[^a-zA-Z0-9]/.test(pw)) score += 1;
    if (score <= 1) return { pct: 25, label: 'Yếu', color: '#dc2626' };
    if (score === 2) return { pct: 55, label: 'Trung bình', color: '#d97706' };
    if (score === 3) return { pct: 80, label: 'Khá mạnh', color: 'var(--accent)' };
    return { pct: 100, label: 'Mạnh', color: 'var(--accent)' };
  }

  function _eyeIcon(open) {
    return open
      ? '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>'
      : '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.94 10.94 0 0 1 12 19c-7 0-11-7-11-7a21.77 21.77 0 0 1 5.06-5.94"/><path d="M9.9 4.24A10.94 10.94 0 0 1 12 4c7 0 11 7 11 7a21.8 21.8 0 0 1-3.16 4.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>';
  }

  async function renderAuthPage(container, onSuccessNavigate) {
    const demoUsers = await loadDemoUsers();
    const currentUser = getUser();

    const checkIcon =
      '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>';

    container.innerHTML = `
      <div class="auth-page-wrap">
        <a href="#home" id="authBackLink" class="auth-top-link">
          ← Quay lại ứng dụng
        </a>

        <div class="auth-shell">
          <aside class="auth-aside">
            <div>
              <span class="badge-verified">Podify Account</span>
              <h2>Đồng bộ trải nghiệm nghe &amp; quản lý kênh Podcast</h2>
              <p>Tài khoản xác thực trực tiếp qua MySQL 8.0 và phiên làm việc Bearer Token.</p>

              <ul class="auth-feature-list">
                <li>${checkIcon}<span>Lưu tiến trình nghe &amp; danh sách phát dở giữa các phiên.</span></li>
                <li>${checkIcon}<span>Theo dõi kênh, chấm điểm Episode và ủng hộ Creator.</span></li>
                <li>${checkIcon}<span>Vai trò Creator hỗ trợ tạo kênh, đăng tập &amp; quản lý AdSlots.</span></li>
              </ul>
            </div>

            <div class="auth-demo-panel">
              <h4>Đăng nhập nhanh (Mật khẩu: 123456)</h4>
              <div class="demo-acc-grid">
                ${
                  demoUsers.length
                    ? demoUsers
                        .slice(0, 6)
                        .map(
                          (u) => `
                        <button type="button" class="demo-acc-btn" data-quick-user="${escapeHtml(u.username)}">
                          <strong>${escapeHtml(u.username)}</strong>
                          <span>${escapeHtml(u.role)}${u.creator_display_name ? ` · ${escapeHtml(u.creator_display_name)}` : ''}</span>
                        </button>`
                        )
                        .join('')
                    : '<span style="font-size:12px;color:var(--text-muted);">Chưa kết nối được MySQL để tải tài khoản mẫu.</span>'
                }
              </div>
            </div>
          </aside>

          <div class="auth-main">
            ${
              currentUser
                ? `<div class="trigger-alert" style="margin-bottom:16px;display:flex;justify-content:space-between;align-items:center;gap:10px;">
                     <span>Đang đăng nhập: <strong>${escapeHtml(currentUser.full_name)}</strong> (<code>${escapeHtml(currentUser.username)}</code>)</span>
                     <button type="button" id="authLogoutInlineBtn" class="btn-secondary" style="padding:4px 10px;font-size:12px;">Đăng xuất</button>
                   </div>`
                : ''
            }

            <div class="auth-tabs" role="tablist">
              <button type="button" id="authTabLogin" class="auth-tab-btn ${authTab === 'login' ? 'active' : ''}">Đăng nhập</button>
              <button type="button" id="authTabRegister" class="auth-tab-btn ${authTab === 'register' ? 'active' : ''}">Tạo tài khoản</button>
            </div>

            <div id="authErrorBox" class="auth-alert" hidden style="margin-bottom:14px;"></div>

            <!-- Form Đăng nhập -->
            <form id="authLoginForm" class="auth-form" ${authTab === 'login' ? '' : 'hidden'}>
              <div class="form-field">
                <label for="loginIdentifier">Tên đăng nhập hoặc Email</label>
                <input id="loginIdentifier" type="text" autocomplete="username" placeholder="vd: manh_trithuc hoặc nam_nghe" required />
              </div>

              <div class="form-field">
                <label for="loginPassword">Mật khẩu</label>
                <div class="input-wrap">
                  <input id="loginPassword" type="password" autocomplete="current-password" placeholder="Nhập mật khẩu" required />
                  <button type="button" class="pw-toggle-btn" data-toggle-pw="loginPassword" aria-label="Hiện hoặc ẩn mật khẩu">
                    ${_eyeIcon(false)}
                  </button>
                </div>
              </div>

              <div class="auth-meta-row">
                <label class="checkbox-label">
                  <input id="loginRemember" type="checkbox" checked />
                  <span>Ghi nhớ đăng nhập trên trình duyệt này</span>
                </label>
              </div>

              <button id="loginSubmitBtn" class="btn-primary" type="submit" style="margin-top:4px;">Đăng nhập</button>
            </form>

            <!-- Form Đăng ký -->
            <form id="authRegisterForm" class="auth-form" ${authTab === 'register' ? '' : 'hidden'}>
              <div class="form-grid">
                <div class="form-field">
                  <label for="regUsername">Tên đăng nhập</label>
                  <input id="regUsername" type="text" autocomplete="username" placeholder="vd: linh_nguyen" required />
                </div>
                <div class="form-field">
                  <label for="regFullName">Họ và tên</label>
                  <input id="regFullName" type="text" autocomplete="name" placeholder="Nguyễn Thùy Linh" required />
                </div>
              </div>

              <div class="form-field">
                <label for="regEmail">Email</label>
                <input id="regEmail" type="email" autocomplete="email" placeholder="linh@example.com" required />
              </div>

              <div class="form-grid">
                <div class="form-field">
                  <label for="regPassword">Mật khẩu (≥ 6 ký tự)</label>
                  <div class="input-wrap">
                    <input id="regPassword" type="password" autocomplete="new-password" minlength="6" placeholder="Tối thiểu 6 ký tự" required />
                    <button type="button" class="pw-toggle-btn" data-toggle-pw="regPassword" aria-label="Hiện hoặc ẩn mật khẩu">
                      ${_eyeIcon(false)}
                    </button>
                  </div>
                  <div class="pw-meter">
                    <div class="pw-meter-track"><div id="regPwFill" class="pw-meter-fill"></div></div>
                    <span id="regPwLabel" class="pw-meter-label">Chưa nhập</span>
                  </div>
                </div>

                <div class="form-field">
                  <label for="regConfirmPassword">Xác nhận mật khẩu</label>
                  <div class="input-wrap">
                    <input id="regConfirmPassword" type="password" autocomplete="new-password" minlength="6" placeholder="Nhập lại mật khẩu" required />
                    <button type="button" class="pw-toggle-btn" data-toggle-pw="regConfirmPassword" aria-label="Hiện hoặc ẩn mật khẩu">
                      ${_eyeIcon(false)}
                    </button>
                  </div>
                </div>
              </div>

              <div class="form-field">
                <label for="regRole">Loại tài khoản</label>
                <select id="regRole">
                  <option value="user">Người nghe (User) — Nghe, theo dõi, đánh giá &amp; donate</option>
                  <option value="creator">Nhà sáng tạo (Creator) — Thêm quyền tạo Kênh, Tập &amp; Quảng cáo</option>
                </select>
              </div>

              <div id="regCreatorFields" class="creator-extra-box" hidden>
                <div class="form-field">
                  <label for="regCreatorName">Tên hiển thị Creator (Channel/Brand)</label>
                  <input id="regCreatorName" type="text" placeholder="vd: Linh Tech Podcast" />
                </div>
                <div class="form-field">
                  <label for="regCreatorBio">Giới thiệu ngắn</label>
                  <input id="regCreatorBio" type="text" placeholder="Chia sẻ về công nghệ và thiết kế sản phẩm..." />
                </div>
              </div>

              <button id="regSubmitBtn" class="btn-primary" type="submit" style="margin-top:4px;">Tạo tài khoản và Đăng nhập</button>
            </form>
          </div>
        </div>
      </div>
    `;

    const errBox = container.querySelector('#authErrorBox');
    const showErr = (msg) => {
      if (!errBox) return;
      errBox.textContent = msg;
      errBox.hidden = !msg;
    };

    const switchTab = (next) => {
      authTab = next;
      showErr('');
      container.querySelector('#authTabLogin')?.classList.toggle('active', next === 'login');
      container.querySelector('#authTabRegister')?.classList.toggle('active', next === 'register');
      const lf = container.querySelector('#authLoginForm');
      const rf = container.querySelector('#authRegisterForm');
      if (lf) lf.hidden = next !== 'login';
      if (rf) rf.hidden = next !== 'register';
    };

    container.querySelector('#authTabLogin')?.addEventListener('click', () => switchTab('login'));
    container.querySelector('#authTabRegister')?.addEventListener('click', () => switchTab('register'));

    container.querySelector('#authBackLink')?.addEventListener('click', (ev) => {
      ev.preventDefault();
      if (onSuccessNavigate) onSuccessNavigate('back');
    });

    container.querySelector('#authLogoutInlineBtn')?.addEventListener('click', () => {
      logout();
      renderAuthPage(container, onSuccessNavigate);
    });

    container.querySelectorAll('[data-toggle-pw]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const inp = container.querySelector(`#${btn.dataset.togglePw}`);
        if (!inp) return;
        const show = inp.type === 'password';
        inp.type = show ? 'text' : 'password';
        btn.innerHTML = _eyeIcon(show);
      });
    });

    const regPw = container.querySelector('#regPassword');
    regPw?.addEventListener('input', () => {
      const info = _passwordStrength(regPw.value);
      const fill = container.querySelector('#regPwFill');
      const lbl = container.querySelector('#regPwLabel');
      if (fill) {
        fill.style.width = `${info.pct}%`;
        fill.style.background = info.color;
      }
      if (lbl) lbl.textContent = info.label;
    });

    const roleSelect = container.querySelector('#regRole');
    const creatorFields = container.querySelector('#regCreatorFields');
    roleSelect?.addEventListener('change', () => {
      if (creatorFields) creatorFields.hidden = roleSelect.value !== 'creator';
    });

    container.querySelectorAll('[data-quick-user]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        showErr('');
        btn.disabled = true;
        try {
          await quickLogin(btn.dataset.quickUser, true);
          if (onSuccessNavigate) onSuccessNavigate('after-auth');
        } catch (err) {
          showErr(err.message);
        } finally {
          btn.disabled = false;
        }
      });
    });

    container.querySelector('#authLoginForm')?.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      showErr('');
      const submitBtn = container.querySelector('#loginSubmitBtn');
      const identifier = container.querySelector('#loginIdentifier').value.trim();
      const password = container.querySelector('#loginPassword').value;
      const remember = container.querySelector('#loginRemember').checked;

      if (!identifier || !password) {
        showErr('Vui lòng nhập đầy đủ tên đăng nhập/email và mật khẩu.');
        return;
      }
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'Đang đăng nhập...';
      }
      try {
        const res = await api('/api/content/auth/login', {
          method: 'POST',
          body: { identifier, password },
        });
        setSession(res.token, res.user, remember);
        showToast(`Chào mừng ${res.user.full_name}!`);
        if (onSuccessNavigate) onSuccessNavigate('after-auth');
      } catch (err) {
        showErr(err.message);
      } finally {
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.textContent = 'Đăng nhập';
        }
      }
    });

    container.querySelector('#authRegisterForm')?.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      showErr('');
      const submitBtn = container.querySelector('#regSubmitBtn');
      const username = container.querySelector('#regUsername').value.trim();
      const full_name = container.querySelector('#regFullName').value.trim();
      const email = container.querySelector('#regEmail').value.trim();
      const password = container.querySelector('#regPassword').value;
      const confirm_password = container.querySelector('#regConfirmPassword').value;
      const role = container.querySelector('#regRole').value;
      const display_name = container.querySelector('#regCreatorName').value.trim();
      const bio = container.querySelector('#regCreatorBio').value.trim();

      if (!/^[a-zA-Z0-9_]{3,50}$/.test(username)) {
        showErr('Tên đăng nhập phải dài 3–50 ký tự, chỉ gồm chữ cái, số hoặc dấu gạch dưới (_).');
        return;
      }
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
        showErr('Địa chỉ email không đúng định dạng (vd: ten@domain.com).');
        return;
      }
      if (password.length < 6) {
        showErr('Mật khẩu phải có ít nhất 6 ký tự.');
        return;
      }
      if (password !== confirm_password) {
        showErr('Mật khẩu xác nhận chưa khớp.');
        return;
      }
      if (role === 'creator' && !display_name) {
        showErr('Vui lòng nhập Tên hiển thị Creator.');
        return;
      }

      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = 'Đang tạo tài khoản...';
      }
      try {
        const res = await api('/api/content/auth/register', {
          method: 'POST',
          body: {
            username,
            full_name,
            email,
            password,
            confirm_password,
            role,
            display_name: display_name || full_name,
            bio,
          },
        });
        demoUsersCache = null;
        setSession(res.token, res.user, true);
        showToast(`Đã tạo tài khoản ${res.user.username} thành công!`);
        if (onSuccessNavigate) onSuccessNavigate('after-auth');
      } catch (err) {
        showErr(err.message);
      } finally {
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.textContent = 'Tạo tài khoản và Đăng nhập';
        }
      }
    });
  }

  async function openDonateModal(defaultCreatorId = null) {
    if (!getUser()) {
      showToast('Vui lòng đăng nhập trước khi thực hiện Donate.');
      openAuthModal('login');
      return;
    }
    const modal = document.getElementById('donateModal');
    const select = document.getElementById('donateCreatorSelect');
    if (!modal || !select) return;
    try {
      const creators = await api('/api/content/creators');
      select.innerHTML = creators
        .map(
          (c) =>
            `<option value="${c.creator_id}" ${String(defaultCreatorId) === String(c.creator_id) ? 'selected' : ''}>${escapeHtml(c.display_name)} (${escapeHtml(c.username)})</option>`
        )
        .join('');
      modal.hidden = false;
    } catch (err) {
      showToast(err.message);
    }
  }

  function closeDonateModal() {
    const modal = document.getElementById('donateModal');
    if (modal) modal.hidden = true;
  }

  async function checkBackendStatus() {
    const badge = document.getElementById('dbStatusBadge');
    if (!badge) return;
    try {
      const res = await fetch('/api/health?db=1');
      const data = await res.json();
      if (res.ok && data.database) {
        badge.textContent = `MySQL · ${data.database.table_count} bảng`;
        badge.className = 'badge-verified';
      } else {
        badge.textContent = 'MySQL chưa cấu hình';
        badge.className = 'badge-warn';
      }
    } catch {
      badge.textContent = 'Offline';
      badge.className = 'badge-warn';
    }
  }

  function bindGlobalModals() {
    document.getElementById('userPillBtn')?.addEventListener('click', () => {
      if (getUser()) openAccountModal();
      else openAuthModal('login');
    });

    document.getElementById('accountModal')?.addEventListener('click', (ev) => {
      if (ev.target.id === 'accountModal') closeAccountModal();
    });
    document.getElementById('donateModal')?.addEventListener('click', (ev) => {
      if (ev.target.id === 'donateModal') closeDonateModal();
    });
    document.getElementById('episodeDetailModal')?.addEventListener('click', (ev) => {
      if (ev.target.id === 'episodeDetailModal') ev.target.hidden = true;
    });

    document.getElementById('donateForm')?.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      try {
        const creator_id = String(document.getElementById('donateCreatorSelect').value || '');
        const amount = Number(document.getElementById('donateAmountInput').value);
        const message = document.getElementById('donateMessageInput').value.trim();
        await api('/api/analytics/donations', {
          method: 'POST',
          body: { creator_id, amount, message },
        });
        closeDonateModal();
        showToast(`Đã ủng hộ ${fmtCurrency(amount)} thành công!`);
        if (onAuthChangeCb) onAuthChangeCb(getUser());
      } catch (err) {
        showToast(err.message);
      }
    });
  }

  function initCommon({ onAuthChange, onNavigateAuth } = {}) {
    onAuthChangeCb = onAuthChange || null;
    onNavigateAuthCb = onNavigateAuth || null;
    initThemeToggle();
    syncUserPill();
    bindGlobalModals();
    checkBackendStatus();
    verifyExistingSession();
  }

  return {
    escapeHtml,
    showToast,
    fmtTime,
    fmtCurrency,
    api,
    getToken,
    getUser,
    setSession,
    clearSession,
    openAuthModal,
    closeAuthModal,
    openAccountModal,
    closeAccountModal,
    renderAuthPage,
    quickLogin,
    logout,
    openDonateModal,
    closeDonateModal,
    initCommon,
  };
})();
