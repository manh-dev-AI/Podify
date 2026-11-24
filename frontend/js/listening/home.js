/* ==========================================================================
   Podify — Module 02: Listening & App Router (Connected to Flask + MySQL)
   Owner: Member 2 - Quân (tích hợp cùng Content, Analytics & Auth)
   ========================================================================== */

(() => {
  const $ = (sel) => document.querySelector(sel);
  const esc = PodifyUI.escapeHtml;

  const CHANNEL_THEMES = [
    { bg: '#162922', color: '#f3f7f4', cover: '/assets/images/cover_tech.svg' },
    { bg: '#182229', color: '#f4f6f8', cover: '/assets/images/cover_ai.svg' },
    { bg: '#232c26', color: '#f3f7f4', cover: '/assets/images/cover_life.svg' },
    { bg: '#1d2621', color: '#f1f5f7', cover: '/assets/images/cover_default.svg' },
    { bg: '#263238', color: '#f9fafb', cover: '/assets/images/cover_default.svg' },
  ];

  const ICONS = {
    play: '<svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>',
    pause: '<svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M6 5h4v14H6zm8 0h4v14h-4z"/></svg>',
    headphone:
      '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/></svg>',
    star: '<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor"><path d="m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21 7 14.2 2 9.3l6.9-1z"/></svg>',
    rss: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 11a9 9 0 0 1 9 9"/><path d="M4 4a16 16 0 0 1 16 16"/><circle cx="5" cy="19" r="1"/></svg>',
    check:
      '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6 9 17l-5-5"/></svg>',
  };

  const state = {
    view: 'home',
    returnView: 'home',
    libFilter: 'all',
    search: '',
    channels: [],
    episodes: [],
    history: [],
    ratingsList: [],
    apiError: null,
    nowEpId: null,
    activeHistoryId: null,
    playing: false,
    showPlayer: false,
    posSeconds: 0,
    ratingTargetId: null,
    selectedScore: 5,
    activities: [],
  };

  const audio = $('#podifyAudio');
  let lastProgressSyncAt = 0;
  let renderSeq = 0;

  function findEpExact(id) {
    return state.episodes.find((e) => String(e.episode_id) === String(id)) || null;
  }

  function getEp(id) {
    return findEpExact(id) || state.episodes[0] || null;
  }

  function channelTheme(channelId) {
    const match = String(channelId || '1').match(/\d+/);
    const num = match ? Math.max(1, parseInt(match[0], 10)) : 1;
    return CHANNEL_THEMES[(num - 1) % CHANNEL_THEMES.length];
  }

  function renderHeroWaveSVG() {
    return `
      <svg viewBox="0 0 140 88" width="132" height="84" fill="none" aria-hidden="true">
        <rect x="10" y="34" width="8" height="20" rx="2" fill="currentColor" opacity="0.35"/>
        <rect x="26" y="22" width="8" height="44" rx="2" fill="currentColor" opacity="0.55"/>
        <rect x="42" y="10" width="8" height="68" rx="2" fill="currentColor" opacity="0.85"/>
        <rect x="58" y="26" width="8" height="36" rx="2" fill="currentColor" opacity="0.65"/>
        <rect x="74" y="6"  width="8" height="76" rx="2" fill="currentColor"/>
        <rect x="90" y="20" width="8" height="48" rx="2" fill="currentColor" opacity="0.75"/>
        <rect x="106" y="30" width="8" height="28" rx="2" fill="currentColor" opacity="0.5"/>
        <rect x="122" y="38" width="8" height="12" rx="2" fill="currentColor" opacity="0.3"/>
      </svg>
    `;
  }

  function buildActivities() {
    const acts = [];
    for (const h of state.history.slice(0, 3)) {
      acts.push({
        type: h.is_completed ? 'done' : 'play',
        title: h.is_completed ? 'Đã nghe xong' : 'Đang nghe dở',
        sub: h.episode_title,
        time: `${PodifyUI.fmtTime(h.last_position_seconds)} / ${PodifyUI.fmtTime(h.duration_seconds)}`,
      });
    }
    for (const c of state.channels.filter((x) => x.subscribed).slice(0, 2)) {
      acts.push({
        type: 'sub',
        title: 'Đã theo dõi kênh',
        sub: c.title,
        time: c.creator_name,
      });
    }
    if (!acts.length) {
      acts.push({
        type: 'play',
        title: 'Chế độ Khách',
        sub: 'Đăng nhập để đồng bộ lịch sử nghe & đánh giá',
        time: 'MySQL Ready',
      });
    }
    state.activities = acts.slice(0, 4);
  }

  async function loadListeningData() {
    state.apiError = null;
    try {
      const home = await PodifyUI.api('/api/listening/home');
      state.channels = home.channels || [];
      state.episodes = home.episodes || [];
      state.history = home.history || [];

      if (!state.nowEpId && home.continue_episode) {
        state.nowEpId = home.continue_episode.episode_id;
        state.posSeconds = home.continue_episode.last_position_seconds || 0;
        state.activeHistoryId = home.continue_episode.history_id || null;
      }

      if (state.view === 'ratings') {
        state.ratingsList = await PodifyUI.api('/api/listening/ratings');
      }
      buildActivities();
    } catch (err) {
      state.apiError = err.message;
    }
  }

  function renderRightRail() {
    const actIcon = (t) => {
      if (t === 'star') return `<div class="act-icon star">${ICONS.star}</div>`;
      if (t === 'play') return `<div class="act-icon play">${ICONS.play}</div>`;
      if (t === 'sub') return `<div class="act-icon sub">${ICONS.rss}</div>`;
      return `<div class="act-icon done">${ICONS.check}</div>`;
    };

    return `
      <aside class="right-col">
        <div class="promo-card">
          <div class="crown-badge">
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 21s-7-4.5-9-9a5 5 0 0 1 9-4 5 5 0 0 1 9 4c-2 4.5-9 9-9 9z"/>
            </svg>
          </div>
          <h3>Ủng hộ Creator</h3>
          <p>Đóng góp trực tiếp tới nhà sáng tạo nội dung bạn yêu thích và theo dõi bảng Donations.</p>
          <button class="btn-primary" onclick="PodifyUI.openDonateModal()">Donate Ngay</button>
        </div>

        <div class="activity-card">
          <div class="section-title" style="font-size:14.5px;">
            <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>
            </svg>
            <span>Hoạt động gần đây</span>
          </div>
          <div class="activity-list">
            ${state.activities
              .map(
                (a) => `
              <div class="activity-item">
                ${actIcon(a.type)}
                <div class="act-body">
                  <strong>${esc(a.title)}</strong>
                  <span>${esc(a.sub)}</span>
                  <small>${esc(a.time)}</small>
                </div>
              </div>`
              )
              .join('')}
          </div>
        </div>
      </aside>
    `;
  }

  function renderPodcastCard(c) {
    const th = channelTheme(c.channel_id);
    const coverImg = c.cover_image_url || th.cover;
    return `
      <article class="pod-card" data-act="go-explore-ch" data-channel-id="${c.channel_id}">
        <div class="pod-cover" style="background:${th.bg} url('${esc(coverImg)}') center/cover no-repeat;color:${th.color};">
          <div class="pod-cover-title">${esc(c.title)}</div>
          <div class="pod-cover-sub">${esc(c.category)} · ★ ${c.avg_rating || 0}</div>
        </div>
        <h4>${esc(c.title)}</h4>
        <div class="pod-host">${esc(c.creator_name)}</div>
        <div class="pod-listens">${ICONS.headphone}<span>${c.total_listens} lượt nghe · ${c.subscriber_count} theo dõi</span></div>
      </article>
    `;
  }

  function renderHome() {
    const current = getEp(state.nowEpId);
    const dur = current ? Number(current.duration_seconds) : 1;
    const pos = current ? Math.min(dur, state.posSeconds) : 0;
    const pct = Math.min(100, Math.round((pos / dur) * 100));

    const q = state.search.trim().toLowerCase();
    const filteredChannels = q
      ? state.channels.filter(
          (c) =>
            c.title.toLowerCase().includes(q) ||
            c.creator_name.toLowerCase().includes(q) ||
            c.category.toLowerCase().includes(q)
        )
      : state.channels;

    let libMarkup = '';
    if (state.libFilter === 'channels') {
      const subs = state.channels.filter((c) => c.subscribed);
      libMarkup = subs.length
        ? subs
            .map(
              (c) => `
            <div class="lib-mini-card" data-act="go-explore-ch" data-channel-id="${c.channel_id}">
              <div class="lib-mini-top">
                <span class="lib-badge">${esc(c.category)}</span>
                <button class="see-all" data-act="toggle-sub-id" data-channel-id="${c.channel_id}" data-sub="1">Đang theo dõi ✓</button>
              </div>
              <strong>${esc(c.title)}</strong>
              <span style="font-size:12px;color:var(--text-secondary)">${esc(c.creator_name)}</span>
            </div>`
            )
            .join('')
        : '<p style="color:var(--text-muted);grid-column:1/-1;">Chưa theo dõi kênh nào (hoặc chưa đăng nhập).</p>';
    } else {
      const eps =
        state.libFilter === 'favorites'
          ? state.episodes.filter((e) => Number(e.my_rating || e.avg_rating) >= 4)
          : state.episodes;
      libMarkup = eps
        .slice(0, 8)
        .map((e) => {
          const isCurrentPlaying = state.playing && String(state.nowEpId) === String(e.episode_id);
          return `
          <div class="lib-mini-card ${isCurrentPlaying ? 'playing' : ''}" data-act="play-episode-id" data-ep-id="${e.episode_id}">
            <div class="lib-mini-top">
              <span class="lib-badge">${PodifyUI.fmtTime(e.duration_seconds)}</span>
              <button class="see-all" data-act="open-rate" data-id="${e.episode_id}">
                ${e.my_rating ? `★ ${e.my_rating}/5` : `★ ${e.avg_rating || 'Đánh giá'}`}
              </button>
            </div>
            <strong style="font-size:13.5px;">${esc(e.title)}</strong>
            <span style="font-size:12px;color:var(--text-secondary)">${esc(e.channel_title)} · ${e.listen_count} lượt nghe</span>
            <div class="lib-mini-foot">
              <span class="lib-play-pill">
                ${isCurrentPlaying ? `${ICONS.pause} Đang phát` : `${ICONS.play} Nghe tập này`}
              </span>
            </div>
          </div>`;
        })
        .join('');
    }

    return `
      <div class="content-grid">
        <div class="feed-col">
          ${
            state.apiError
              ? `<div class="trigger-error-box">Chưa kết nối được MySQL (${esc(state.apiError)}). Hãy kiểm tra file <code>.env</code> và chạy <code>reset_db.bat</code>.</div>`
              : ''
          }

          <section class="hero-banner">
            <div class="hero-copy">
              <span class="hero-eyebrow">Podify Audio Workspace</span>
              <h1>Nghe, khám phá và quản lý <span>Podcast</span></h1>
              <p>Nền tảng quản trị nội dung số chuẩn hóa 3NF — kết nối trực tiếp MySQL 8.0 và Flask REST API.</p>
              <div class="hero-cta">
                <button class="btn-primary" data-act="go-view" data-view="explore">
                  ${ICONS.play} Khám phá &amp; Studio
                </button>
                <button class="btn-secondary" data-act="go-view" data-view="analytics">
                  Quảng cáo &amp; SQL Reports
                </button>
              </div>
            </div>
            <div class="hero-visual">${renderHeroWaveSVG()}</div>
          </section>

          ${
            current
              ? `
            <section>
              <div class="section-head">
                <div class="section-title">
                  <span class="title-badge">${ICONS.play}</span>
                  <span>Tiếp tục nghe</span>
                </div>
                <a href="#history" class="see-all" data-act="go-view" data-view="history">Xem lịch sử →</a>
              </div>
              <div class="continue-card">
                <div class="ep-banner-thumb" style="background:${channelTheme(current.channel_id).bg} url('${esc(channelTheme(current.channel_id).cover)}') center/cover no-repeat;">
                  <strong>POD</strong>
                  <span>${esc(current.category || 'Audio')}</span>
                </div>
                <div class="continue-info">
                  <h3>${esc(current.title)}</h3>
                  <div class="channel-sub">${esc(current.channel_title)} · ${esc(current.creator_name)}</div>
                  <div class="continue-progress">
                    <div class="progress-track">
                      <div class="progress-fill" id="homeProgressBar" style="width:${pct}%"></div>
                    </div>
                    <span id="homeProgressTime">${PodifyUI.fmtTime(pos)} / ${PodifyUI.fmtTime(dur)}</span>
                  </div>
                </div>
                <div class="continue-actions">
                  <button class="circle-play" data-act="play-episode-id" data-ep-id="${current.episode_id}" aria-label="Play or Pause">
                    ${state.playing ? ICONS.pause : ICONS.play}
                  </button>
                  <button class="btn-primary" data-act="play-episode-id" data-ep-id="${current.episode_id}">
                    ${state.playing ? 'Đang phát' : 'Nghe ngay'}
                  </button>
                </div>
              </div>
            </section>`
              : ''
          }

          <section>
            <div class="section-head">
              <div class="section-title">
                <span>Kênh Podcast nổi bật</span>
              </div>
              <a href="#explore" class="see-all" data-act="go-view" data-view="explore">Tất cả kênh →</a>
            </div>
            <div class="podcast-grid">
              ${
                filteredChannels.length
                  ? filteredChannels.map(renderPodcastCard).join('')
                  : '<p style="color:var(--text-muted)">Chưa có kênh Podcast nào.</p>'
              }
            </div>
          </section>

          <section>
            <div class="section-head">
              <div class="library-head-left">
                <div class="section-title">
                  <span>Thư viện</span>
                </div>
                <div class="filter-pills">
                  ${[
                    ['all', 'Tất cả'],
                    ['episodes', 'Tập'],
                    ['channels', 'Đang theo dõi'],
                    ['favorites', 'Nổi bật'],
                  ]
                    .map(
                      ([key, label]) => `
                    <button class="pill-tab ${state.libFilter === key ? 'active' : ''}" data-act="lib-filter" data-f="${key}">
                      ${label}
                    </button>`
                    )
                    .join('')}
                </div>
              </div>
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
              <h1>Kênh đang theo dõi</h1>
              <p>Quản lý đăng ký kênh trong bảng <code>Subscriptions</code> (<code>UNIQUE(user_id, channel_id)</code>).</p>
            </div>
          </div>
          ${
            !PodifyUI.getUser()
              ? `<div class="trigger-alert">Bạn chưa đăng nhập. Hãy <a href="#auth" data-act="go-view" data-view="auth" style="text-decoration:underline;font-weight:700;color:var(--accent-text);">đăng nhập</a> để xem và thay đổi kênh theo dõi.</div>`
              : ''
          }
          <div class="data-list">
            ${state.channels
              .map((c) => {
                const th = channelTheme(c.channel_id);
                return `
                  <div class="data-row">
                    <div class="data-row-left">
                      <div class="mp-thumb" style="background:${th.bg};color:${th.color};">${esc(c.title.slice(0, 2).toUpperCase())}</div>
                      <div>
                        <strong>${esc(c.title)}</strong>
                        <div style="font-size:12px;color:var(--text-secondary)">${esc(c.creator_name)} · ${esc(c.category)} · ${c.subscriber_count} subscribers</div>
                      </div>
                    </div>
                    <button class="${c.subscribed ? 'btn-secondary' : 'btn-primary'}"
                      data-act="toggle-sub-id" data-channel-id="${c.channel_id}" data-sub="${c.subscribed ? 1 : 0}">
                      ${c.subscribed ? 'Đang theo dõi ✓' : '+ Theo dõi'}
                    </button>
                  </div>`;
              })
              .join('')}
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
              <h1>Lịch sử nghe</h1>
              <p>Tiến trình các phiên nghe được lưu trực tiếp trong bảng <code>ListeningHistory</code>.</p>
            </div>
          </div>
          ${
            !PodifyUI.getUser()
              ? `<div class="trigger-alert">Hãy <a href="#auth" data-act="go-view" data-view="auth" style="text-decoration:underline;font-weight:700;color:var(--accent-text);">đăng nhập</a> để xem lịch sử nghe riêng của bạn.</div>`
              : ''
          }
          <div class="data-list">
            ${
              state.history.length
                ? state.history
                    .map((h) => {
                      const pct = Math.min(100, Math.round((h.last_position_seconds / h.duration_seconds) * 100));
                      const th = channelTheme(h.channel_id);
                      return `
                        <div class="data-row">
                          <div class="data-row-left" style="flex:1;">
                            <div class="mp-thumb" style="background:${th.bg};">EP</div>
                            <div style="flex:1;min-width:0;">
                              <strong>${esc(h.episode_title)}</strong>
                              <div style="font-size:12px;color:var(--text-secondary)">
                                ${esc(h.channel_title)} · ${PodifyUI.fmtTime(h.last_position_seconds)} / ${PodifyUI.fmtTime(h.duration_seconds)} (${pct}%) · ${h.is_completed ? 'Hoàn thành' : 'Đang nghe dở'}
                              </div>
                            </div>
                          </div>
                          <div style="display:flex;gap:8px;align-items:center;">
                            <button class="btn-secondary" data-act="open-rate" data-id="${h.episode_id}">${h.my_rating ? `★ ${h.my_rating}/5` : 'Đánh giá'}</button>
                            <button class="btn-primary" data-act="play-episode-id" data-ep-id="${h.episode_id}" data-resume="${h.last_position_seconds}">${h.is_completed ? 'Nghe lại' : 'Tiếp tục'}</button>
                          </div>
                        </div>`;
                    })
                    .join('')
                : '<div class="card-surface" style="padding:18px;color:var(--text-muted);">Chưa có lịch sử nghe nào.</div>'
            }
          </div>
        </div>
        ${renderRightRail()}
      </div>
    `;
  }

  function renderRatings() {
    const list = state.ratingsList.length ? state.ratingsList : state.episodes;
    return `
      <div class="content-grid">
        <div class="feed-col">
          <div class="page-header">
            <div>
              <h1>Đánh giá Episode</h1>
              <p>Chấm điểm từ 1–5 sao (Bảng <code>Ratings</code> — <code>CHECK score BETWEEN 1 AND 5</code>).</p>
            </div>
          </div>
          <div class="data-list">
            ${list
              .map(
                (e) => `
              <div class="data-row">
                <div>
                  <strong>${esc(e.episode_title || e.title)}</strong>
                  <div style="font-size:12px;color:var(--text-secondary)">${esc(e.channel_title)} · Trung bình: ★ ${e.avg_rating || 0} (${e.rating_count || 0} lượt)</div>
                </div>
                <div style="display:flex;align-items:center;gap:12px;">
                  <span style="color:#d97706;font-weight:700;font-size:13px;">${e.my_score || e.my_rating ? `Bạn chấm: ★ ${e.my_score || e.my_rating}/5` : 'Chưa chấm'}</span>
                  <button class="btn-secondary" data-act="open-rate" data-id="${e.episode_id}">Chấm điểm</button>
                </div>
              </div>`
              )
              .join('')}
          </div>
        </div>
        ${renderRightRail()}
      </div>
    `;
  }

  async function render(reloadFromServer = true) {
    const main = $('#mainContent');
    if (!main) return;
    const seq = ++renderSeq;
    const user = PodifyUI.getUser();

    document.querySelectorAll('.nav-item[data-view]').forEach((el) => {
      el.classList.toggle('active', el.dataset.view === state.view);
    });

    if (state.view === 'auth') {
      await PodifyUI.renderAuthPage(main, async (action) => {
        if (action === 'back' || action === 'after-auth') {
          state.view = state.returnView === 'auth' ? 'home' : state.returnView;
          await render(true);
        }
      });
    } else if (state.view === 'explore') {
      if (reloadFromServer) await PodifyContent.loadData(state.search);
      if (seq !== renderSeq) return;
      main.innerHTML = PodifyContent.renderHTML(user);
      PodifyContent.bindEvents(main, async (refetch = true) => render(refetch));
    } else if (state.view === 'library') {
      if (reloadFromServer) await PodifyLibrary.loadData();
      if (seq !== renderSeq) return;
      main.innerHTML = PodifyLibrary.renderHTML(state.nowEpId, state.playing);
      PodifyLibrary.bindEvents(main, async (refetch = true) => render(refetch));
    } else if (state.view === 'analytics') {
      if (reloadFromServer) await PodifyAnalytics.loadData();
      if (seq !== renderSeq) return;
      main.innerHTML = PodifyAnalytics.renderHTML(user);
      PodifyAnalytics.bindEvents(main, async (refetch = true) => render(refetch));
    } else {
      if (reloadFromServer) await loadListeningData();
      if (seq !== renderSeq) return;
      if (state.view === 'home') {
        main.innerHTML = renderHome();
      } else if (state.view === 'subscriptions') {
        main.innerHTML = renderSubscriptions();
      } else if (state.view === 'history') {
        main.innerHTML = renderHistory();
      } else if (state.view === 'ratings') {
        main.innerHTML = renderRatings();
      }
    }

    if (seq === renderSeq) syncMiniPlayer();
  }

  function syncMiniPlayer() {
    const bar = $('#miniPlayer');
    const ep = getEp(state.nowEpId);
    if (!bar || !ep) return;
    bar.classList.toggle('hidden', !state.showPlayer);

    const dur = Number(ep.duration_seconds) || 1;
    const pct = Math.min(100, (state.posSeconds / dur) * 100);
    const th = channelTheme(ep.channel_id);

    $('#mpThumb').style.background = th.bg;
    $('#mpTitle').textContent = ep.title;
    $('#mpChannel').textContent = `${ep.channel_title} · ${ep.creator_name}`;
    $('#mpPlayBtn').innerHTML = state.playing ? ICONS.pause : ICONS.play;
    $('#mpPos').textContent = PodifyUI.fmtTime(state.posSeconds);
    $('#mpDur').textContent = PodifyUI.fmtTime(dur);
    $('#mpBar').style.width = `${pct}%`;

    const hpBar = $('#homeProgressBar');
    const hpTime = $('#homeProgressTime');
    if (hpBar) hpBar.style.width = `${pct}%`;
    if (hpTime) hpTime.textContent = `${PodifyUI.fmtTime(state.posSeconds)} / ${PodifyUI.fmtTime(dur)}`;

    const muteBtn = $('#mpMuteBtn');
    if (muteBtn && audio) {
      muteBtn.textContent = audio.muted ? '🔇 Đã tắt tiếng' : '🔊 Âm thanh';
    }
  }

  async function syncProgressToServer(newSession = false, forceCompleted = false) {
    if (!PodifyUI.getUser() || !state.nowEpId) return;
    try {
      const res = await PodifyUI.api('/api/listening/progress', {
        method: 'POST',
        body: {
          episode_id: state.nowEpId,
          position_seconds: Math.floor(state.posSeconds),
          is_completed: forceCompleted,
          history_id: newSession ? null : state.activeHistoryId,
          new_session: newSession,
        },
      });
      state.activeHistoryId = res.history_id;
    } catch {
      // Ignore silent background progress sync errors
    }
  }

  async function playEpisode(epId, resumePos = null) {
    let ep = findEpExact(epId);
    if (!ep) {
      await loadListeningData();
      ep = findEpExact(epId);
      if (!ep) {
        try {
          ep = await PodifyUI.api(`/api/content/episodes/${epId}`);
        } catch {
          PodifyUI.showToast('Không tìm thấy tập Podcast để phát.');
          return;
        }
      }
    }

    const isSame = String(state.nowEpId) === String(ep.episode_id);
    if (isSame && state.showPlayer && resumePos === null) {
      if (state.playing) {
        audio.pause();
        state.playing = false;
        syncProgressToServer(false, false);
      } else {
        audio.muted = false;
        audio.volume = 1.0;
        await audio.play().catch((err) => {
          if (err && err.name !== 'AbortError') {
            PodifyUI.showToast('Không thể phát âm thanh: ' + (err.message || 'Bị trình duyệt chặn'));
          }
        });
        state.playing = !audio.paused;
      }
      render(false);
      return;
    }

    state.nowEpId = ep.episode_id;
    state.showPlayer = true;
    state.posSeconds = resumePos !== null ? Number(resumePos) : 0;

    if (audio) {
      const targetSrc = ep.audio_url || '/assets/audio/sample_1.mp3';
      audio.loop = true;
      audio.muted = false;
      audio.volume = 1.0;
      audio.src = targetSrc;
      audio.load();
      try {
        await audio.play();
        state.playing = !audio.paused;
      } catch (err) {
        state.playing = false;
        if (err && err.name !== 'AbortError') {
          PodifyUI.showToast('Trình duyệt tạm chặn phát tự động, hãy bấm nút Play trên thanh phát dưới cùng.');
        }
      }
    }

    await syncProgressToServer(resumePos === null, false);
    render(false);
  }

  if (audio) {
    audio.addEventListener('error', () => {
      if (audio.src && !audio.src.includes('/assets/audio/podcast_cuoc_song.mp3')) {
        audio.src = '/assets/audio/podcast_cuoc_song.mp3';
        audio.load();
        audio.play().then(() => {
          state.playing = !audio.paused;
          syncMiniPlayer();
        }).catch(() => {
          state.playing = false;
          syncMiniPlayer();
        });
        return;
      }
      state.playing = false;
      syncMiniPlayer();
      PodifyUI.showToast(`Không tải được tệp audio (${audio.currentSrc || 'URL không hợp lệ'}).`);
    });
  }

  // Smoothly advance episode progress while audio is actively playing
  setInterval(async () => {
    if (!state.playing || !audio || audio.paused) return;
    const ep = getEp(state.nowEpId);
    if (!ep) return;
    const dur = Number(ep.duration_seconds) || 1;
    state.posSeconds = Math.min(dur, state.posSeconds + 1);
    syncMiniPlayer();

    const now = Date.now();
    if (now - lastProgressSyncAt > 5000) {
      lastProgressSyncAt = now;
      syncProgressToServer(false, state.posSeconds >= dur);
    }

    if (state.posSeconds >= dur) {
      audio.pause();
      state.playing = false;
      await syncProgressToServer(false, true);
      PodifyUI.showToast(`Đã hoàn thành nghe "${ep.title}"!`);
      render(false);
    }
  }, 1000);

  async function openRateModal(epId) {
    if (!PodifyUI.getUser()) {
      PodifyUI.showToast('Vui lòng đăng nhập để đánh giá Episode.');
      PodifyUI.openAuthModal('login');
      return;
    }
    let ep = findEpExact(epId);
    if (!ep) {
      try {
        ep = await PodifyUI.api(`/api/content/episodes/${epId}`);
      } catch {
        return;
      }
    }
    state.ratingTargetId = ep.episode_id;
    state.selectedScore = Number(ep.my_rating || 5);
    $('#rateModalTitle').textContent = ep.title;
    $('#rateModalSub').textContent = ep.channel_title;
    $('#rateCommentInput').value = ep.my_comment || '';
    $('#rateStars').innerHTML = [1, 2, 3, 4, 5]
      .map(
        (n) =>
          `<button class="star-btn ${n <= state.selectedScore ? 'on' : ''}" data-act="pick-star" data-score="${n}">★</button>`
      )
      .join('');
    $('#rateModal').hidden = false;
  }

  document.addEventListener('click', async (ev) => {
    if (ev.target.id === 'rateModal') {
      $('#rateModal').hidden = true;
      return;
    }

    if (ev.target.closest('#mpProgressTrack')) {
      const track = $('#mpProgressTrack');
      const rect = track.getBoundingClientRect();
      const ratio = Math.max(0, Math.min(1, (ev.clientX - rect.left) / rect.width));
      const ep = getEp(state.nowEpId);
      if (ep && audio) {
        const audioDur = Number.isFinite(audio.duration) ? audio.duration : Number(ep.duration_seconds);
        audio.currentTime = ratio * audioDur;
        state.posSeconds = Math.floor(ratio * Number(ep.duration_seconds));
        syncMiniPlayer();
      }
      return;
    }

    const btn = ev.target.closest('[data-act], .nav-item[data-view]');
    if (!btn) return;

    if (btn.classList.contains('nav-item') && btn.dataset.view) {
      ev.preventDefault();
      if (state.view !== 'auth') state.returnView = state.view;
      state.view = btn.dataset.view;
      await render(true);
      return;
    }

    const act = btn.dataset.act;
    if (act === 'go-view') {
      ev.preventDefault();
      if (state.view !== 'auth') state.returnView = state.view;
      state.view = btn.dataset.view;
      await render(true);
    } else if (act === 'go-explore-ch') {
      PodifyContent.setSelectedChannel(btn.dataset.channelId || null);
      state.view = 'explore';
      await render(true);
    } else if (act === 'lib-filter') {
      state.libFilter = btn.dataset.f;
      render(false);
    } else if (act === 'play-episode-id') {
      const epId = btn.dataset.epId;
      const resume = btn.dataset.resume !== undefined ? Number(btn.dataset.resume) : null;
      await playEpisode(epId, resume);
    } else if (act === 'toggle-play') {
      if (!state.nowEpId && state.episodes.length) {
        await playEpisode(state.episodes[0].episode_id, null);
      } else if (state.nowEpId) {
        await playEpisode(state.nowEpId, null);
      }
    } else if (act === 'toggle-mute') {
      if (audio) {
        audio.muted = !audio.muted;
        syncMiniPlayer();
      }
    } else if (act === 'skip') {
      const delta = Number(btn.dataset.delta);
      const ep = getEp(state.nowEpId);
      if (ep && audio) {
        const audioDur = Number.isFinite(audio.duration) && audio.duration > 0 ? audio.duration : 16;
        audio.currentTime = (((audio.currentTime + delta) % audioDur) + audioDur) % audioDur;
        state.posSeconds = Math.max(0, Math.min(Number(ep.duration_seconds), state.posSeconds + delta));
        syncMiniPlayer();
        syncProgressToServer(false, false);
      }
    } else if (act === 'toggle-sub-id') {
      if (!PodifyUI.getUser()) {
        PodifyUI.showToast('Vui lòng đăng nhập để đăng ký kênh.');
        PodifyUI.openAuthModal('login');
        return;
      }
      const chId = btn.dataset.channelId;
      const isSub = Number(btn.dataset.sub) === 1;
      try {
        if (isSub) {
          await PodifyUI.api(`/api/listening/subscriptions/${chId}`, { method: 'DELETE' });
          PodifyUI.showToast('Đã hủy theo dõi kênh.');
        } else {
          await PodifyUI.api('/api/listening/subscriptions', {
            method: 'POST',
            body: { channel_id: chId },
          });
          PodifyUI.showToast('Đã đăng ký kênh thành công!');
        }
        await render(true);
      } catch (err) {
        PodifyUI.showToast(err.message);
      }
    } else if (act === 'open-rate') {
      openRateModal(btn.dataset.id);
    } else if (act === 'open-rate-current') {
      if (state.nowEpId) openRateModal(state.nowEpId);
    } else if (act === 'pick-star') {
      state.selectedScore = Number(btn.dataset.score);
      document.querySelectorAll('#rateStars .star-btn').forEach((s) => {
        s.classList.toggle('on', Number(s.dataset.score) <= state.selectedScore);
      });
    } else if (act === 'submit-rate') {
      try {
        const comment = $('#rateCommentInput').value.trim();
        await PodifyUI.api('/api/listening/ratings', {
          method: 'POST',
          body: {
            episode_id: state.ratingTargetId,
            score: state.selectedScore,
            comment,
          },
        });
        $('#rateModal').hidden = true;
        PodifyUI.showToast(`Đã lưu đánh giá ${state.selectedScore}★ vào MySQL!`);
        await render(true);
      } catch (err) {
        PodifyUI.showToast(err.message);
      }
    } else if (act === 'close-rate') {
      $('#rateModal').hidden = true;
    }
  });

  let searchTimer = null;
  $('#searchInput')?.addEventListener('input', (ev) => {
    state.search = ev.target.value;
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      if (state.view === 'explore') render(true);
      else if (state.view === 'home') render(false);
    }, 220);
  });

  PodifyUI.initCommon({
    onAuthChange: async () => {
      if (state.view !== 'auth') {
        await render(true);
      }
    },
    onNavigateAuth: async (action) => {
      if (action === 'auth') {
        if (state.view !== 'auth') state.returnView = state.view;
        state.view = 'auth';
        await render(false);
      } else if (action === 'back') {
        state.view = state.returnView === 'auth' ? 'home' : state.returnView;
        await render(true);
      }
    },
  });
  render(true);
})();
