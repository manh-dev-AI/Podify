/* ==========================================================================
   Podify — Module 02: Listening & User Interaction (Frontend Mockup)
   Sau khi Backend Flask (/api/listening/*) sẵn sàng, thay dữ liệu mẫu bằng fetch().
   ========================================================================== */

(() => {
  const $ = (sel) => document.querySelector(sel);

  const PODCASTS = [
    {
      id: 1,
      title: 'The Daily',
      host: 'The New York Times',
      listens: '2.4M listens',
      cat: 'News',
      subscribed: true,
      bg: 'linear-gradient(160deg, #0d3b66 0%, #1d70b8 55%, #f4d35e 100%)',
      color: '#ffffff',
      mark: 'The\nDaily',
      latestEp: { id: 101, title: 'Inside the AI Race', dur: 1420 },
    },
    {
      id: 2,
      title: 'Stuff You Should Know',
      host: 'iHeartPodcasts',
      listens: '3.1M listens',
      cat: 'Education',
      subscribed: false,
      bg: 'linear-gradient(145deg, #c62828 0%, #e53935 100%)',
      color: '#111111',
      mark: 'STUFF\nYOU SHOULD\nKNOW',
      latestEp: { id: 102, title: 'How Memory Works', dur: 2150 },
    },
    {
      id: 3,
      title: 'Hidden Brain',
      host: 'Shankar Vedantam',
      listens: '1.8M listens',
      cat: 'Psychology',
      subscribed: false,
      bg: 'linear-gradient(155deg, #1b2845 0%, #274060 100%)',
      color: '#e8eef5',
      mark: 'HIDDEN\nBRAIN',
      latestEp: { id: 103, title: 'You 2.0: Decision Fatigue', dur: 1980 },
    },
    {
      id: 4,
      title: 'Radiolab',
      host: 'WNYC Studios',
      listens: '1.6M listens',
      cat: 'Science',
      subscribed: false,
      bg: 'linear-gradient(145deg, #f3f4f6 0%, #e5e7eb 100%)',
      color: '#18181b',
      accentDot: '#f97316',
      mark: 'RADIOLAB',
      latestEp: { id: 104, title: 'Colors Beyond Sight', dur: 2400 },
    },
    {
      id: 5,
      title: 'Planet Money',
      host: 'NPR',
      listens: '1.9M listens',
      cat: 'Economics',
      subscribed: true,
      bg: 'linear-gradient(155deg, #166534 0%, #15803d 100%)',
      color: '#ffffff',
      mark: 'Planet\nMoney',
      latestEp: { id: 105, title: 'Why Coffee Prices Spiked', dur: 1310 },
    },
  ];

  const EPISODES = [
    { id: 100, podcastId: 0, title: 'The Power of Small Habits', channel: 'TED Talks', dur: 1100, pos: 754, rating: 5, done: false, thumbBg: 'linear-gradient(135deg, #270e18, #78122b)' },
    { id: 101, podcastId: 1, title: 'Inside the AI Race', channel: 'The Daily', dur: 1420, pos: 310, rating: 4, done: false, thumbBg: 'linear-gradient(135deg, #0d3b66, #1d70b8)' },
    { id: 103, podcastId: 3, title: 'You 2.0: Decision Fatigue', channel: 'Hidden Brain', dur: 1980, pos: 640, rating: 0, done: false, thumbBg: 'linear-gradient(135deg, #1b2845, #274060)' },
    { id: 105, podcastId: 5, title: 'Why Coffee Prices Spiked', channel: 'Planet Money', dur: 1310, pos: 1310, rating: 5, done: true, thumbBg: 'linear-gradient(135deg, #166534, #15803d)' },
  ];

  const state = {
    view: 'home',
    libFilter: 'all',
    search: '',
    nowEpId: 100,
    playing: false,
    showPlayer: false,
    activities: [
      { type: 'star', title: 'You rated 5 stars', sub: 'on The Power of Small Habits', time: '2h ago' },
      { type: 'play', title: 'Started listening', sub: 'to Hidden Brain', time: '3h ago' },
      { type: 'sub',  title: 'Subscribed to', sub: 'The Daily', time: '1d ago' },
      { type: 'done', title: 'Finished listening', sub: 'to Planet Money', time: '1d ago' },
    ],
    ratingTargetId: null,
    selectedScore: 0,
  };

  const ICONS = {
    play: '<svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>',
    pause: '<svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M6 5h4v14H6zm8 0h4v14h-4z"/></svg>',
    headphone: '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/></svg>',
    star: '<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor"><path d="m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21 7 14.2 2 9.3l6.9-1z"/></svg>',
    rss: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 11a9 9 0 0 1 9 9"/><path d="M4 4a16 16 0 0 1 16 16"/><circle cx="5" cy="19" r="1"/></svg>',
    check: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>',
  };

  function getEp(id) {
    return EPISODES.find((e) => e.id === id) || EPISODES[0];
  }

  function renderPodcastCard(p) {
    const dot = p.accentDot
      ? `<span style="display:inline-block;width:30px;height:30px;border-radius:50%;background:${p.accentDot};margin-bottom:6px;"></span>`
      : '';
    return `
      <article class="pod-card" data-act="open-pod" data-id="${p.id}">
        <div class="pod-cover" style="background:${p.bg};color:${p.color};">
          ${dot}
          <div class="pod-cover-title" style="white-space:pre-line;">${p.mark}</div>
          <div class="pod-cover-sub">${p.cat}</div>
        </div>
        <h4>${p.title}</h4>
        <div class="pod-host">${p.host}</div>
        <div class="pod-listens">${ICONS.headphone}<span>${p.listens}</span></div>
      </article>
    `;
  }

  function renderHeroMicSVG() {
    return `
      <svg viewBox="0 0 220 160" width="210" height="150" aria-hidden="true">
        <defs>
          <radialGradient id="micGlow" cx="55%" cy="45%" r="55%">
            <stop offset="0%" stop-color="#8f6bff" stop-opacity="0.55"/>
            <stop offset="65%" stop-color="#4c2db8" stop-opacity="0.16"/>
            <stop offset="100%" stop-color="#1b1830" stop-opacity="0"/>
          </radialGradient>
          <linearGradient id="micBody" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stop-color="#d4d4e0"/>
            <stop offset="50%" stop-color="#7c7b94"/>
            <stop offset="100%" stop-color="#353447"/>
          </linearGradient>
        </defs>
        <circle cx="122" cy="74" r="72" fill="url(#micGlow)"/>
        <circle cx="46" cy="48" r="14" fill="#6d4aff" opacity="0.22"/>
        <circle cx="182" cy="112" r="18" fill="#6d4aff" opacity="0.18"/>
        <!-- Stand & Shock Mount -->
        <path d="M122 126 v28 M96 154 h52" stroke="#6c6b82" stroke-width="4" stroke-linecap="round"/>
        <path d="M88 86 a34 34 0 0 0 68 0" fill="none" stroke="#9b7dff" stroke-width="3" opacity="0.8"/>
        <line x1="88" y1="74" x2="156" y2="74" stroke="#6c6b82" stroke-width="2" opacity="0.5"/>
        <!-- Capsule -->
        <rect x="98" y="24" width="48" height="82" rx="24" fill="url(#micBody)" stroke="rgba(255,255,255,0.25)"/>
        <rect x="103" y="30" width="38" height="44" rx="18" fill="#232235" opacity="0.55"/>
        <line x1="106" y1="42" x2="138" y2="42" stroke="#b9b8ce" stroke-width="1.5" opacity="0.45"/>
        <line x1="106" y1="50" x2="138" y2="50" stroke="#b9b8ce" stroke-width="1.5" opacity="0.45"/>
        <line x1="106" y1="58" x2="138" y2="58" stroke="#b9b8ce" stroke-width="1.5" opacity="0.45"/>
        <line x1="106" y1="66" x2="138" y2="66" stroke="#b9b8ce" stroke-width="1.5" opacity="0.45"/>
      </svg>
    `;
  }

  function renderRightRail() {
    const actIcon = (t) => {
      if (t === 'star') return `<div class="act-icon star">${ICONS.star}</div>`;
      if (t === 'play') return `<div class="act-icon play">${ICONS.play}</div>`;
      if (t === 'sub')  return `<div class="act-icon sub">${ICONS.rss}</div>`;
      return `<div class="act-icon done">${ICONS.check}</div>`;
    };

    return `
      <aside class="right-col">
        <div class="promo-card">
          <div class="crown-badge">
            <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
              <path d="M5 16 3 6l5.5 4L12 4l3.5 6L21 6l-2 10H5zm0 2h14v2H5v-2z"/>
            </svg>
          </div>
          <h3>Premium User</h3>
          <p>Enjoy ad-free listening and support your favorite Creators!</p>
          <button class="btn-primary" data-act="upgrade">Upgrade Now</button>
        </div>

        <div class="activity-card">
          <div class="section-title" style="font-size:15px;">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>
            </svg>
            <span>Recent Activity</span>
          </div>
          <div class="activity-list">
            ${state.activities.slice(0, 4).map((a) => `
              <div class="activity-item">
                ${actIcon(a.type)}
                <div class="act-body">
                  <strong>${a.title}</strong>
                  <span>${a.sub}</span>
                  <small>${a.time}</small>
                </div>
              </div>
            `).join('')}
          </div>
        </div>
      </aside>
    `;
  }

  function renderHome() {
    const current = getEp(state.nowEpId);
    const pct = Math.min(100, Math.round((current.pos / current.dur) * 100));
    const q = state.search.trim().toLowerCase();
    const filteredPods = q
      ? PODCASTS.filter((p) => p.title.toLowerCase().includes(q) || p.host.toLowerCase().includes(q))
      : PODCASTS;

    let libItems = EPISODES;
    if (state.libFilter === 'channels') {
      libItems = PODCASTS.filter((p) => p.subscribed);
    } else if (state.libFilter === 'favorites') {
      libItems = EPISODES.filter((e) => e.rating >= 4);
    }

    const libMarkup = state.libFilter === 'channels'
      ? libItems.map((p) => `
          <div class="lib-mini-card">
            <div class="lib-mini-top">
              <span class="lib-badge">Channel</span>
              <button class="see-all" data-act="toggle-sub" data-id="${p.id}">Subscribed ✓</button>
            </div>
            <strong>${p.title}</strong>
            <span style="font-size:12px;color:var(--text-secondary)">${p.host}</span>
          </div>
        `).join('')
      : libItems.map((e) => `
          <div class="lib-mini-card">
            <div class="lib-mini-top">
              <span class="lib-badge">${e.done ? 'Completed' : 'In Progress'}</span>
              <button class="see-all" data-act="open-rate" data-id="${e.id}">
                ${e.rating ? `★ ${e.rating}/5` : 'Rate'}
              </button>
            </div>
            <strong style="font-size:13.5px;">${e.title}</strong>
            <span style="font-size:12px;color:var(--text-secondary)">${e.channel}</span>
          </div>
        `).join('');

    return `
      <div class="content-grid">
        <div class="feed-col">
          <!-- Hero -->
          <section class="hero-banner">
            <div class="hero-copy">
              <h1>Discover Amazing <span>Podcasts</span></h1>
              <p>Expand your knowledge, one episode at a time.</p>
              <div class="hero-cta">
                <button class="btn-primary" data-act="go-view" data-view="explore">
                  ${ICONS.play} Explore Now →
                </button>
              </div>
            </div>
            <div class="hero-visual">${renderHeroMicSVG()}</div>
            <div class="hero-dots"><i></i><i class="active"></i><i></i></div>
          </section>

          <!-- Continue Listening -->
          <section>
            <div class="section-head">
              <div class="section-title">
                <span class="title-badge">${ICONS.play}</span>
                <span>Continue Listening</span>
              </div>
              <a href="#history" class="see-all" data-act="go-view" data-view="history">See all →</a>
            </div>
            <div class="continue-card">
              <div class="ep-banner-thumb" style="background:${current.thumbBg};">
                <strong>TED</strong>
                <span>Talks</span>
              </div>
              <div class="continue-info">
                <h3>${current.title}</h3>
                <div class="channel-sub">${current.channel}</div>
                <div class="continue-progress">
                  <div class="progress-track">
                    <div class="progress-fill" id="homeProgressBar" style="width:${pct}%"></div>
                  </div>
                  <span id="homeProgressTime">${PodifyUI.fmtTime(current.pos)} / ${PodifyUI.fmtTime(current.dur)}</span>
                </div>
              </div>
              <div class="continue-actions">
                <button class="circle-play" data-act="toggle-play" aria-label="Play or Pause">
                  ${state.playing ? ICONS.pause : ICONS.play}
                </button>
                <button class="btn-primary" data-act="continue-ep" data-id="${current.id}">
                  ${state.playing ? 'Playing...' : 'Continue'}
                </button>
              </div>
            </div>
          </section>

          <!-- Popular Podcasts -->
          <section>
            <div class="section-head">
              <div class="section-title">
                <span class="title-badge fire">🔥</span>
                <span>Popular Podcasts</span>
              </div>
              <a href="#explore" class="see-all" data-act="go-view" data-view="explore">See all →</a>
            </div>
            <div class="podcast-grid">
              ${filteredPods.length ? filteredPods.map(renderPodcastCard).join('') : '<p style="color:var(--text-muted)">Không tìm thấy podcast phù hợp.</p>'}
            </div>
          </section>

          <!-- My Library -->
          <section>
            <div class="section-head">
              <div class="library-head-left">
                <div class="section-title">
                  <span class="title-badge">🔖</span>
                  <span>My Library</span>
                </div>
                <div class="filter-pills">
                  ${['all', 'episodes', 'channels', 'favorites'].map((f) => `
                    <button class="pill-tab ${state.libFilter === f ? 'active' : ''}" data-act="lib-filter" data-f="${f}">
                      ${f.charAt(0).toUpperCase() + f.slice(1)}
                    </button>
                  `).join('')}
                </div>
              </div>
              <a href="#library" class="see-all" data-act="go-view" data-view="library">View all →</a>
            </div>
            <div class="library-grid">${libMarkup}</div>
          </section>
        </div>

        ${renderRightRail()}
      </div>
    `;
  }

  function renderSubscriptions() {
    return `
      <div class="content-grid">
        <div class="feed-col">
          <div class="page-header">
            <div>
              <h1>Subscriptions</h1>
              <p>Quản lý danh sách kênh Podcast bạn đang theo dõi (Bảng Subscriptions — UNIQUE user &amp; channel).</p>
            </div>
          </div>
          <div class="data-list">
            ${PODCASTS.map((p) => `
              <div class="data-row">
                <div class="data-row-left">
                  <div class="mp-thumb" style="background:${p.bg};color:${p.color};">${p.title.slice(0, 2).toUpperCase()}</div>
                  <div>
                    <strong>${p.title}</strong>
                    <div style="font-size:12px;color:var(--text-secondary)">${p.host} · ${p.listens}</div>
                  </div>
                </div>
                <button class="${p.subscribed ? 'btn-secondary' : 'btn-primary'}" data-act="toggle-sub" data-id="${p.id}">
                  ${p.subscribed ? 'Subscribed ✓' : '+ Subscribe'}
                </button>
              </div>
            `).join('')}
          </div>
        </div>
        ${renderRightRail()}
      </div>
    `;
  }

  function renderHistory() {
    return `
      <div class="content-grid">
        <div class="feed-col">
          <div class="page-header">
            <div>
              <h1>Listening History</h1>
              <p>Theo dõi tiến trình nghe và phát tiếp từ vị trí dừng (Bảng ListeningHistory).</p>
            </div>
          </div>
          <div class="data-list">
            ${EPISODES.map((e) => {
              const pct = Math.round((e.pos / e.dur) * 100);
              return `
                <div class="data-row">
                  <div class="data-row-left" style="flex:1;">
                    <div class="mp-thumb" style="background:${e.thumbBg};">EP</div>
                    <div style="flex:1;min-width:0;">
                      <strong>${e.title}</strong>
                      <div style="font-size:12px;color:var(--text-secondary)">${e.channel} · ${PodifyUI.fmtTime(e.pos)} / ${PodifyUI.fmtTime(e.dur)} (${pct}%)</div>
                    </div>
                  </div>
                  <div style="display:flex;gap:10px;align-items:center;">
                    <button class="btn-secondary" data-act="open-rate" data-id="${e.id}">${e.rating ? `★ ${e.rating}/5` : 'Rate'}</button>
                    <button class="btn-primary" data-act="continue-ep" data-id="${e.id}">${e.done ? 'Replay' : 'Continue'}</button>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        </div>
        ${renderRightRail()}
      </div>
    `;
  }

  function renderRatings() {
    return `
      <div class="content-grid">
        <div class="feed-col">
          <div class="page-header">
            <div>
              <h1>Ratings</h1>
              <p>Đánh giá Episode từ 1–5 sao (Bảng Ratings — CHECK score BETWEEN 1 AND 5).</p>
            </div>
          </div>
          <div class="data-list">
            ${EPISODES.map((e) => `
              <div class="data-row">
                <div>
                  <strong>${e.title}</strong>
                  <div style="font-size:12px;color:var(--text-secondary)">${e.channel}</div>
                </div>
                <div style="display:flex;align-items:center;gap:14px;">
                  <span style="color:#fbbf24;font-weight:700;">${e.rating ? `★ ${e.rating}.0 / 5` : 'Chưa chấm'}</span>
                  <button class="btn-secondary" data-act="open-rate" data-id="${e.id}">Chấm điểm</button>
                </div>
              </div>
            `).join('')}
          </div>
        </div>
        ${renderRightRail()}
      </div>
    `;
  }

  function renderModulePlaceholder(title, owner, desc) {
    return `
      <div class="content-grid">
        <div class="feed-col">
          <div class="card-surface" style="padding:28px;">
            <span class="lib-badge">${owner}</span>
            <h1 style="margin-top:12px;font-size:24px;">${title}</h1>
            <p style="margin-top:8px;color:var(--text-secondary);">${desc}</p>
          </div>
        </div>
        ${renderRightRail()}
      </div>
    `;
  }

  function render() {
    const main = $('#mainContent');
    if (!main) return;

    if (state.view === 'home') main.innerHTML = renderHome();
    else if (state.view === 'subscriptions') main.innerHTML = renderSubscriptions();
    else if (state.view === 'history') main.innerHTML = renderHistory();
    else if (state.view === 'ratings') main.innerHTML = renderRatings();
    else if (state.view === 'library') { state.libFilter = 'all'; main.innerHTML = renderHome(); }
    else if (state.view === 'explore') {
      main.innerHTML = renderModulePlaceholder(
        'Explore & Content Discovery (Module 01)',
        'Phụ trách: Mạnh — frontend/pages/content/',
        'Mạnh sẽ gắn danh sách tất cả Podcast Channels, Episodes, tìm kiếm nâng cao và trang Creator Dashboard vào đây dùng chung theme.css & layout.js.'
      );
    } else if (state.view === 'analytics') {
      main.innerHTML = renderModulePlaceholder(
        'Advertisement & Analytics Dashboard (Module 03)',
        'Phụ trách: Quang — frontend/pages/analytics/',
        'Quang sẽ gắn trang quản lý hợp đồng quảng cáo, AdSlots, thống kê doanh thu và Donation vào đây.'
      );
    }

    document.querySelectorAll('.nav-item[data-view]').forEach((el) => {
      el.classList.toggle('active', el.dataset.view === state.view);
    });

    syncMiniPlayer();
  }

  function syncMiniPlayer() {
    const bar = $('#miniPlayer');
    if (!bar) return;
    bar.classList.toggle('hidden', !state.showPlayer);
    const ep = getEp(state.nowEpId);
    const pct = Math.min(100, (ep.pos / ep.dur) * 100);
    $('#mpThumb').style.background = ep.thumbBg;
    $('#mpTitle').textContent = ep.title;
    $('#mpChannel').textContent = ep.channel;
    $('#mpPlayBtn').innerHTML = state.playing ? ICONS.pause : ICONS.play;
    $('#mpPos').textContent = PodifyUI.fmtTime(ep.pos);
    $('#mpDur').textContent = PodifyUI.fmtTime(ep.dur);
    $('#mpBar').style.width = `${pct}%`;

    const hpBar = $('#homeProgressBar');
    const hpTime = $('#homeProgressTime');
    if (hpBar) hpBar.style.width = `${pct}%`;
    if (hpTime) hpTime.textContent = `${PodifyUI.fmtTime(ep.pos)} / ${PodifyUI.fmtTime(ep.dur)}`;
  }

  // Giả lập chạy tiến trình mỗi giây khi đang Play
  setInterval(() => {
    if (!state.playing) return;
    const ep = getEp(state.nowEpId);
    ep.pos = Math.min(ep.dur, ep.pos + 1);
    if (ep.pos >= ep.dur) {
      ep.done = true;
      state.playing = false;
      PodifyUI.showToast(`Đã nghe xong "${ep.title}"!`);
    }
    syncMiniPlayer();
  }, 1000);

  function openRateModal(epId) {
    const ep = getEp(epId);
    state.ratingTargetId = epId;
    state.selectedScore = ep.rating || 5;
    $('#rateModalTitle').textContent = ep.title;
    $('#rateModalSub').textContent = ep.channel;
    $('#rateStars').innerHTML = [1, 2, 3, 4, 5].map((n) =>
      `<button class="star-btn ${n <= state.selectedScore ? 'on' : ''}" data-act="pick-star" data-score="${n}">★</button>`
    ).join('');
    $('#rateModal').hidden = false;
  }

  document.addEventListener('click', (ev) => {
    if (ev.target.id === 'rateModal') { $('#rateModal').hidden = true; return; }
    const btn = ev.target.closest('[data-act], .nav-item[data-view]');
    if (!btn) return;

    if (btn.classList.contains('nav-item') && btn.dataset.view) {
      ev.preventDefault();
      state.view = btn.dataset.view;
      render();
      return;
    }

    const act = btn.dataset.act;
    if (act === 'go-view') {
      ev.preventDefault();
      state.view = btn.dataset.view;
      render();
    } else if (act === 'lib-filter') {
      state.libFilter = btn.dataset.f;
      render();
    } else if (act === 'continue-ep') {
      const id = Number(btn.dataset.id);
      if (state.nowEpId !== id) {
        state.nowEpId = id;
        state.playing = true;
      } else {
        state.playing = !state.playing;
      }
      state.showPlayer = true;
      render();
    } else if (act === 'toggle-play') {
      state.playing = !state.playing;
      state.showPlayer = true;
      render();
    } else if (act === 'skip') {
      const ep = getEp(state.nowEpId);
      ep.pos = Math.max(0, Math.min(ep.dur, ep.pos + Number(btn.dataset.delta)));
      syncMiniPlayer();
    } else if (act === 'toggle-sub') {
      const pod = PODCASTS.find((p) => p.id === Number(btn.dataset.id));
      if (!pod) return;
      pod.subscribed = !pod.subscribed;
      if (pod.subscribed) {
        state.activities.unshift({ type: 'sub', title: 'Subscribed to', sub: pod.title, time: 'Just now' });
        PodifyUI.showToast(`Đã đăng ký kênh "${pod.title}"`);
      } else {
        PodifyUI.showToast(`Đã hủy theo dõi "${pod.title}"`);
      }
      render();
    } else if (act === 'open-pod') {
      const pod = PODCASTS.find((p) => p.id === Number(btn.dataset.id));
      if (pod) PodifyUI.showToast(`${pod.title} — ${pod.listens}`);
    } else if (act === 'open-rate') {
      openRateModal(Number(btn.dataset.id));
    } else if (act === 'pick-star') {
      state.selectedScore = Number(btn.dataset.score);
      document.querySelectorAll('#rateStars .star-btn').forEach((s) => {
        s.classList.toggle('on', Number(s.dataset.score) <= state.selectedScore);
      });
    } else if (act === 'submit-rate') {
      const ep = getEp(state.ratingTargetId);
      ep.rating = state.selectedScore;
      state.activities.unshift({ type: 'star', title: `You rated ${ep.rating} stars`, sub: `on ${ep.title}`, time: 'Just now' });
      $('#rateModal').hidden = true;
      PodifyUI.showToast(`Đã lưu đánh giá ${ep.rating}★ cho "${ep.title}"`);
      render();
    } else if (act === 'close-rate') {
      $('#rateModal').hidden = true;
    } else if (act === 'upgrade') {
      PodifyUI.showToast('Khu vực này có thể gắn link tới Donations / Ads (Module 03 của Quang).');
    }
  });

  $('#searchInput')?.addEventListener('input', (ev) => {
    state.search = ev.target.value;
    if (state.view === 'home') render();
  });

  PodifyUI.initCommon();
  render();
})();
