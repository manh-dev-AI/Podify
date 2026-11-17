/* ==========================================================================
   Podify — Module 02: Dedicated Library Workspace (Frontend JS)
   Quản lý kho nội dung cá nhân: Tìm kiếm, Phân loại, Xem chi tiết, Lưu/Xóa
   ========================================================================== */

const PodifyLibrary = (() => {
  const esc = PodifyUI.escapeHtml;

  const state = {
    tab: 'all', // all | saved | in_progress | completed | favorites | channels
    query: '',
    category: '',
    sortBy: 'recent', // recent | listens | duration | rating
    viewMode: 'table', // table | grid
    channels: [],
    episodes: [],
    history: [],
    loading: false,
    error: null,
  };

  function _savedStorageKey() {
    const user = PodifyUI.getUser();
    return `podify_saved_eps_${user ? user.user_id : 'guest'}`;
  }

  function getSavedIds() {
    try {
      const raw = localStorage.getItem(_savedStorageKey());
      const arr = raw ? JSON.parse(raw) : [1, 5]; // Default sample bookmarks for first visit
      return new Set(arr.map(Number));
    } catch {
      return new Set();
    }
  }

  function toggleSavedId(epId) {
    const set = getSavedIds();
    const num = Number(epId);
    let added = false;
    if (set.has(num)) {
      set.delete(num);
    } else {
      set.add(num);
      added = true;
    }
    localStorage.setItem(_savedStorageKey(), JSON.stringify([...set]));
    PodifyUI.showToast(added ? 'Đã lưu tập vào Thư viện.' : 'Đã bỏ lưu khỏi Thư viện.');
    return added;
  }

  async function loadData() {
    state.loading = true;
    state.error = null;
    try {
      const home = await PodifyUI.api('/api/listening/home');
      state.channels = home.channels || [];
      state.episodes = home.episodes || [];
      state.history = home.history || [];
    } catch (err) {
      state.error = err.message;
    } finally {
      state.loading = false;
    }
  }

  function _historyMapByEpisode() {
    const map = new Map();
    for (const h of state.history) {
      if (!map.has(Number(h.episode_id))) {
        map.set(Number(h.episode_id), h);
      }
    }
    return map;
  }

  function _filterAndSortEpisodes() {
    const savedSet = getSavedIds();
    const histMap = _historyMapByEpisode();
    const q = state.query.trim().toLowerCase();

    let items = state.episodes.map((e) => {
      const hist = histMap.get(Number(e.episode_id)) || null;
      return {
        ...e,
        is_saved: savedSet.has(Number(e.episode_id)),
        history_item: hist,
      };
    });

    if (state.tab === 'saved') {
      items = items.filter((e) => e.is_saved);
    } else if (state.tab === 'in_progress') {
      items = items.filter((e) => e.history_item && !e.history_item.is_completed);
    } else if (state.tab === 'completed') {
      items = items.filter((e) => e.history_item && e.history_item.is_completed);
    } else if (state.tab === 'favorites') {
      items = items.filter((e) => Number(e.my_rating || 0) >= 4 || Number(e.avg_rating || 0) >= 4);
    }

    if (state.category) {
      items = items.filter((e) => e.category === state.category);
    }
    if (q) {
      items = items.filter(
        (e) =>
          e.title.toLowerCase().includes(q) ||
          e.channel_title.toLowerCase().includes(q) ||
          e.creator_name.toLowerCase().includes(q) ||
          (e.category || '').toLowerCase().includes(q)
      );
    }

    if (state.sortBy === 'listens') {
      items.sort((a, b) => Number(b.listen_count) - Number(a.listen_count));
    } else if (state.sortBy === 'duration') {
      items.sort((a, b) => Number(a.duration_seconds) - Number(b.duration_seconds));
    } else if (state.sortBy === 'rating') {
      items.sort((a, b) => Number(b.avg_rating || 0) - Number(a.avg_rating || 0));
    } else {
      items.sort((a, b) => Number(b.episode_id) - Number(a.episode_id));
    }
    return items;
  }

  function _filterChannels() {
    const q = state.query.trim().toLowerCase();
    let list = state.channels.filter((c) => c.subscribed);
    if (state.category) list = list.filter((c) => c.category === state.category);
    if (q) {
      list = list.filter(
        (c) =>
          c.title.toLowerCase().includes(q) ||
          c.creator_name.toLowerCase().includes(q) ||
          (c.category || '').toLowerCase().includes(q)
      );
    }
    return list;
  }

  async function openEpisodeDetail(epId) {
    const modal = document.getElementById('episodeDetailModal');
    const body = document.getElementById('episodeDetailBody');
    const titleEl = document.getElementById('episodeDetailTitle');
    if (!modal || !body || !titleEl) return;

    titleEl.textContent = 'Đang tải chi tiết...';
    body.innerHTML = '<p style="color:var(--text-secondary);font-size:13px;">Đang truy xuất dữ liệu từ MySQL...</p>';
    modal.hidden = false;

    try {
      const ep = await PodifyUI.api(`/api/content/episodes/${epId}`);
      const isSaved = getSavedIds().has(Number(ep.episode_id));
      const slots = ep.ad_slots || [];

      titleEl.textContent = ep.title;
      body.innerHTML = `
        <div style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px;">
          <span class="lib-badge">${esc(ep.category)}</span>
          <span class="lib-badge">${PodifyUI.fmtTime(ep.duration_seconds)} (${ep.duration_seconds}s)</span>
          <span class="badge-verified">${ep.listen_count} lượt nghe · ★ ${ep.avg_rating || 0}</span>
        </div>
        <div style="font-size:13px;color:var(--text-secondary);margin-bottom:10px;">
          Kênh: <strong>${esc(ep.channel_title)}</strong> · Creator: <strong>${esc(ep.creator_name)}</strong>
        </div>
        <p style="font-size:13px;line-height:1.55;margin-bottom:14px;">
          ${esc(ep.description || 'Chưa có mô tả chi tiết cho tập Podcast này.')}
        </p>
        <div style="border-top:1px solid var(--border-subtle);padding-top:10px;margin-bottom:14px;">
          <strong style="font-size:12.5px;display:block;margin-bottom:6px;">Quảng cáo gắn trong tập (${slots.length})</strong>
          ${
            slots.length
              ? slots
                  .map(
                    (s) => `
                  <div style="font-size:12px;color:var(--text-secondary);display:flex;justify-content:space-between;padding:4px 0;border-bottom:1px solid var(--border-subtle);">
                    <span><code>${esc(s.slot_position)}</code> (${PodifyUI.fmtTime(s.start_offset_seconds)}) · ${esc(s.advertiser_name)}</span>
                    <span>${esc(s.contract_code)}</span>
                  </div>`
                  )
                  .join('')
              : '<span style="font-size:12px;color:var(--text-muted);">Không có quảng cáo nào được gắn.</span>'
          }
        </div>
        <div style="display:flex;gap:8px;flex-wrap:wrap;">
          <button class="btn-primary" data-act="play-episode-id" data-ep-id="${ep.episode_id}" onclick="document.getElementById('episodeDetailModal').hidden=true;">▶ Nghe tập này</button>
          <button class="btn-secondary" data-lib-save-modal="${ep.episode_id}">${isSaved ? '✓ Bỏ lưu khỏi Thư viện' : '+ Lưu vào Thư viện'}</button>
          <button class="btn-secondary" data-act="open-rate" data-id="${ep.episode_id}">★ Đánh giá</button>
          <button class="btn-secondary" onclick="PodifyUI.openDonateModal(${ep.creator_id})">Donate Creator</button>
        </div>
      `;

      body.querySelector('[data-lib-save-modal]')?.addEventListener('click', () => {
        toggleSavedId(ep.episode_id);
        openEpisodeDetail(ep.episode_id);
      });
    } catch (err) {
      body.innerHTML = `<div class="trigger-error-box">${esc(err.message)}</div>`;
    }
  }

  function renderEpisodesTable(items, playingEpId, isPlaying) {
    if (!items.length) {
      return '<div class="card-surface" style="padding:20px;color:var(--text-muted);">Không tìm thấy mục nào khớp với bộ lọc hiện tại trong Thư viện.</div>';
    }

    return `
      <div class="lib-table-card">
        <div class="table-wrap">
          <table class="podify-table">
            <thead>
              <tr>
                <th>Tên tập Podcast</th>
                <th>Kênh / Danh mục</th>
                <th>Thời lượng</th>
                <th>Tiến trình của bạn</th>
                <th>Đánh giá</th>
                <th>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              ${items
                .map((e) => {
                  const playingNow = isPlaying && Number(playingEpId) === Number(e.episode_id);
                  const hist = e.history_item;
                  const pct = hist
                    ? Math.min(100, Math.round((Number(hist.last_position_seconds) / Number(e.duration_seconds || 1)) * 100))
                    : 0;
                  return `
                    <tr>
                      <td>
                        <div style="font-weight:600;max-width:260px;overflow:hidden;text-overflow:ellipsis;">${esc(e.title)}</div>
                        <div style="font-size:11.5px;color:var(--text-muted);">${esc(e.creator_name)} · ${e.listen_count} lượt nghe</div>
                      </td>
                      <td>
                        <div>${esc(e.channel_title)}</div>
                        <span class="lib-badge" style="margin-top:3px;">${esc(e.category)}</span>
                      </td>
                      <td>${PodifyUI.fmtTime(e.duration_seconds)}</td>
                      <td>
                        ${
                          hist
                            ? `<div class="progress-inline">
                                 <span class="progress-inline-bar"><span style="width:${pct}%"></span></span>
                                 <span>${hist.is_completed ? 'Đã xong' : `${pct}%`}</span>
                               </div>`
                            : '<span style="color:var(--text-muted);font-size:12px;">Chưa nghe</span>'
                        }
                      </td>
                      <td>
                        <span style="font-weight:600;color:${e.my_rating ? 'var(--accent-text)' : 'var(--text-secondary)'};">
                          ${e.my_rating ? `★ ${e.my_rating}/5 (bạn)` : `★ ${e.avg_rating || 0}`}
                        </span>
                      </td>
                      <td>
                        <div style="display:flex;gap:6px;align-items:center;">
                          <button class="${playingNow ? 'btn-secondary' : 'btn-primary'} btn-xs" data-act="play-episode-id" data-ep-id="${e.episode_id}" ${hist && !hist.is_completed ? `data-resume="${hist.last_position_seconds}"` : ''}>
                            ${playingNow ? '⏸ Tạm dừng' : hist && !hist.is_completed ? '▶ Tiếp tục' : '▶ Nghe'}
                          </button>
                          <button class="btn-secondary btn-xs" data-lib-detail="${e.episode_id}">Chi tiết</button>
                          <button class="btn-secondary btn-xs" data-lib-save="${e.episode_id}">${e.is_saved ? '✓ Đã lưu' : '+ Lưu'}</button>
                          <button class="btn-secondary btn-xs" data-act="open-rate" data-id="${e.episode_id}">★</button>
                          ${
                            hist && (state.tab === 'in_progress' || state.tab === 'completed')
                              ? `<button class="btn-danger btn-xs" data-lib-del-hist="${hist.history_id}">Xóa</button>`
                              : e.my_rating && state.tab === 'favorites'
                              ? `<button class="btn-danger btn-xs" data-lib-del-rate="${e.episode_id}">Bỏ ★</button>`
                              : ''
                          }
                        </div>
                      </td>
                    </tr>`;
                })
                .join('')}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }

  function renderEpisodesGrid(items, playingEpId, isPlaying) {
    if (!items.length) {
      return '<div class="card-surface" style="padding:20px;color:var(--text-muted);">Không tìm thấy mục nào khớp với bộ lọc hiện tại trong Thư viện.</div>';
    }
    return `
      <div class="lib-dense-grid">
        ${items
          .map((e) => {
            const playingNow = isPlaying && Number(playingEpId) === Number(e.episode_id);
            const hist = e.history_item;
            return `
              <div class="lib-item-card">
                <div class="lib-mini-top">
                  <span class="lib-badge">${esc(e.category)} · ${PodifyUI.fmtTime(e.duration_seconds)}</span>
                  <span style="font-size:12px;font-weight:600;color:var(--accent-text);">${e.my_rating ? `★ ${e.my_rating}/5` : `★ ${e.avg_rating || 0}`}</span>
                </div>
                <strong style="font-size:14px;">${esc(e.title)}</strong>
                <div style="font-size:12px;color:var(--text-secondary);">
                  ${esc(e.channel_title)} · ${esc(e.creator_name)} · ${e.listen_count} lượt nghe
                </div>
                ${
                  hist
                    ? `<div style="font-size:11.5px;color:var(--text-muted);">Tiến trình: ${PodifyUI.fmtTime(hist.last_position_seconds)} / ${PodifyUI.fmtTime(e.duration_seconds)}</div>`
                    : ''
                }
                <div class="lib-item-actions">
                  <button class="${playingNow ? 'btn-secondary' : 'btn-primary'} btn-xs" data-act="play-episode-id" data-ep-id="${e.episode_id}">
                    ${playingNow ? '⏸ Tạm dừng' : '▶ Nghe'}
                  </button>
                  <button class="btn-secondary btn-xs" data-lib-detail="${e.episode_id}">Chi tiết</button>
                  <button class="btn-secondary btn-xs" data-lib-save="${e.episode_id}">${e.is_saved ? '✓ Đã lưu' : '+ Lưu'}</button>
                </div>
              </div>`;
          })
          .join('')}
      </div>
    `;
  }

  function renderChannelsList(channels) {
    if (!PodifyUI.getUser()) {
      return `<div class="trigger-alert">Hãy <a href="#auth" data-act="go-view" data-view="auth" style="text-decoration:underline;font-weight:700;color:var(--accent-text);">đăng nhập</a> để xem danh sách kênh bạn đã theo dõi trong Thư viện.</div>`;
    }
    if (!channels.length) {
      return '<div class="card-surface" style="padding:20px;color:var(--text-muted);">Bạn chưa theo dõi kênh Podcast nào (hoặc không khớp bộ lọc).</div>';
    }
    return `
      <div class="data-list">
        ${channels
          .map(
            (c) => `
          <div class="data-row">
            <div>
              <div style="display:flex;align-items:center;gap:8px;">
                <strong>${esc(c.title)}</strong>
                <span class="lib-badge">${esc(c.category)}</span>
              </div>
              <div style="font-size:12px;color:var(--text-secondary);margin-top:2px;">
                Creator: ${esc(c.creator_name)} · ${c.total_listens} lượt nghe · ★ ${c.avg_rating || 0}
              </div>
            </div>
            <div style="display:flex;gap:8px;align-items:center;">
              <button class="btn-secondary btn-xs" data-act="go-explore-ch" data-channel-id="${c.channel_id}">Xem các tập</button>
              <button class="btn-danger btn-xs" data-act="toggle-sub-id" data-channel-id="${c.channel_id}" data-sub="1">Bỏ theo dõi</button>
            </div>
          </div>`
          )
          .join('')}
      </div>
    `;
  }

  function renderHTML(playingEpId, isPlaying) {
    const savedSet = getSavedIds();
    const histMap = _historyMapByEpisode();
    const categories = [...new Set(state.episodes.map((e) => e.category).filter(Boolean))];
    const subChannelsCount = state.channels.filter((c) => c.subscribed).length;
    const completedCount = [...histMap.values()].filter((h) => h.is_completed).length;
    const filteredEpisodes = _filterAndSortEpisodes();
    const filteredChannels = _filterChannels();

    return `
      <div class="library-page">
        <div class="page-header">
          <div>
            <h1>Thư viện nội dung (My Library)</h1>
            <p>Không gian lưu trữ, phân loại và tra cứu nhanh các tập đã lưu, tiến trình nghe và kênh theo dõi.</p>
          </div>
          <button class="btn-secondary" data-act="go-view" data-view="explore">+ Khám phá thêm tập</button>
        </div>

        ${
          state.error
            ? `<div class="trigger-error-box">Lỗi tải Thư viện: ${esc(state.error)}</div>`
            : ''
        }

        <div class="lib-stats-row">
          <div class="lib-stat-box">
            <span>Kho tập hiện có</span>
            <strong>${state.episodes.length} tập</strong>
          </div>
          <div class="lib-stat-box">
            <span>Đã lưu (Bookmark)</span>
            <strong>${savedSet.size} tập</strong>
          </div>
          <div class="lib-stat-box">
            <span>Kênh đang theo dõi</span>
            <strong>${subChannelsCount} kênh</strong>
          </div>
          <div class="lib-stat-box">
            <span>Đã nghe hoàn thành</span>
            <strong>${completedCount} tập</strong>
          </div>
        </div>

        <div class="lib-controls-bar">
          <div class="lib-search-input">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
            <input id="libSearchInput" type="search" value="${esc(state.query)}" placeholder="Lọc theo tên tập, kênh, creator..." />
          </div>

          <div style="display:flex;flex-wrap:wrap;gap:8px;align-items:center;">
            <select id="libCategorySelect" class="lib-select" aria-label="Lọc danh mục">
              <option value="">Tất cả danh mục</option>
              ${categories
                .map((cat) => `<option value="${esc(cat)}" ${state.category === cat ? 'selected' : ''}>${esc(cat)}</option>`)
                .join('')}
            </select>

            ${
              state.tab !== 'channels'
                ? `<select id="libSortSelect" class="lib-select" aria-label="Sắp xếp">
                     <option value="recent" ${state.sortBy === 'recent' ? 'selected' : ''}>Mới nhất</option>
                     <option value="listens" ${state.sortBy === 'listens' ? 'selected' : ''}>Lượt nghe nhiều</option>
                     <option value="duration" ${state.sortBy === 'duration' ? 'selected' : ''}>Thời lượng ngắn → dài</option>
                     <option value="rating" ${state.sortBy === 'rating' ? 'selected' : ''}>Đánh giá cao</option>
                   </select>
                   <div class="lib-view-switch">
                     <button type="button" class="lib-view-btn ${state.viewMode === 'table' ? 'active' : ''}" data-lib-mode="table">Bảng</button>
                     <button type="button" class="lib-view-btn ${state.viewMode === 'grid' ? 'active' : ''}" data-lib-mode="grid">Lưới</button>
                   </div>`
                : ''
            }
          </div>
        </div>

        <div class="filter-group">
          ${[
            ['all', `Tất cả (${state.episodes.length})`],
            ['saved', `Đã lưu (${savedSet.size})`],
            ['in_progress', 'Đang nghe dở'],
            ['completed', `Đã nghe xong (${completedCount})`],
            ['favorites', 'Đánh giá cao (≥ 4★)'],
            ['channels', `Kênh theo dõi (${subChannelsCount})`],
          ]
            .map(
              ([id, label]) => `
            <button type="button" class="pill-tab ${state.tab === id ? 'active' : ''}" data-lib-tab="${id}">${label}</button>`
            )
            .join('')}
        </div>

        ${
          state.tab === 'channels'
            ? renderChannelsList(filteredChannels)
            : state.viewMode === 'table'
            ? renderEpisodesTable(filteredEpisodes, playingEpId, isPlaying)
            : renderEpisodesGrid(filteredEpisodes, playingEpId, isPlaying)
        }
      </div>
    `;
  }

  function bindEvents(container, onReload) {
    container.querySelectorAll('[data-lib-tab]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.tab = btn.dataset.libTab;
        onReload(false);
      });
    });

    container.querySelectorAll('[data-lib-mode]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.viewMode = btn.dataset.libMode;
        onReload(false);
      });
    });

    container.querySelector('#libCategorySelect')?.addEventListener('change', (ev) => {
      state.category = ev.target.value;
      onReload(false);
    });

    container.querySelector('#libSortSelect')?.addEventListener('change', (ev) => {
      state.sortBy = ev.target.value;
      onReload(false);
    });

    const searchInput = container.querySelector('#libSearchInput');
    searchInput?.addEventListener('input', (ev) => {
      const pos = ev.target.selectionStart;
      state.query = ev.target.value;
      onReload(false);
      const nextInput = document.querySelector('#libSearchInput');
      if (nextInput) {
        nextInput.focus();
        if (typeof pos === 'number') nextInput.setSelectionRange(pos, pos);
      }
    });

    container.querySelectorAll('[data-lib-save]').forEach((btn) => {
      btn.addEventListener('click', () => {
        toggleSavedId(btn.dataset.libSave);
        onReload(false);
      });
    });

    container.querySelectorAll('[data-lib-detail]').forEach((btn) => {
      btn.addEventListener('click', () => {
        openEpisodeDetail(btn.dataset.libDetail);
      });
    });

    container.querySelectorAll('[data-lib-del-hist]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await PodifyUI.api(`/api/listening/history/${btn.dataset.libDelHist}`, { method: 'DELETE' });
          PodifyUI.showToast('Đã xóa mục khỏi lịch sử nghe.');
          await onReload(true);
        } catch (err) {
          PodifyUI.showToast(err.message);
        }
      });
    });

    container.querySelectorAll('[data-lib-del-rate]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await PodifyUI.api(`/api/listening/ratings/${btn.dataset.libDelRate}`, { method: 'DELETE' });
          PodifyUI.showToast('Đã xóa đánh giá của bạn.');
          await onReload(true);
        } catch (err) {
          PodifyUI.showToast(err.message);
        }
      });
    });
  }

  return { loadData, renderHTML, bindEvents, openEpisodeDetail };
})();
