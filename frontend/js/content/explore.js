/* ==========================================================================
   Podify — Module 01: Content Management & Discovery (Frontend JS)
   Owner: Member 1 - Mạnh
   ========================================================================== */

const PodifyContent = (() => {
  const state = {
    category: '',
    durationFilter: 'all', // all | q1 | short
    selectedChannelId: null,
    channels: [],
    episodes: [],
    loading: false,
    error: null,
  };

  async function loadData(searchQuery = '') {
    state.loading = true;
    state.error = null;
    try {
      const chParams = new URLSearchParams();
      if (searchQuery) chParams.set('q', searchQuery);
      if (state.category) chParams.set('category', state.category);

      const epParams = new URLSearchParams();
      if (searchQuery) epParams.set('q', searchQuery);
      if (state.category) epParams.set('category', state.category);
      if (state.durationFilter === 'q1') {
        epParams.set('min_duration', '900');
        epParams.set('max_duration', '1800');
      } else if (state.durationFilter === 'short') {
        epParams.set('max_duration', '1199');
      }

      const [channels, episodes] = await Promise.all([
        PodifyUI.api(`/api/content/channels?${chParams.toString()}`),
        PodifyUI.api(`/api/content/episodes?${epParams.toString()}`),
      ]);
      state.channels = channels || [];
      state.episodes = episodes || [];
    } catch (err) {
      state.error = err.message;
    } finally {
      state.loading = false;
    }
  }

  function renderCreatorStudio(user) {
    if (!user || (user.role !== 'creator' && user.role !== 'admin')) {
      return `
        <div class="studio-card">
          <h3>Creator Studio (Tạo Kênh &amp; Tập Podcast)</h3>
          <p style="font-size:13px;color:var(--text-secondary);">
            Đăng nhập bằng tài khoản <strong>Creator</strong> (ví dụ: <code>nguyenvan_a</code> hoặc <code>tranthi_b</code>) để tạo kênh Podcast, đăng tập mới hoặc quản lý nội dung của bạn.
          </p>
          <div>
            <button class="btn-primary" onclick="PodifyUI.openAuthModal()">Đăng nhập tài khoản Creator</button>
          </div>
        </div>
      `;
    }

    const myChannels = state.channels.filter(
      (c) => user.role === 'admin' || Number(c.creator_id) === Number(user.creator_id)
    );

    return `
      <div class="studio-grid">
        <form id="createChannelForm" class="studio-card">
          <h3>+ Tạo Podcast Channel mới</h3>
          <div class="form-grid">
            <div class="form-field full">
              <label>Tên kênh Podcast</label>
              <input name="title" required placeholder="vd: Kiến trúc hệ thống thực chiến" />
            </div>
            <div class="form-field">
              <label>Danh mục</label>
              <select name="category">
                <option value="Công nghệ">Công nghệ</option>
                <option value="Đời sống">Đời sống</option>
                <option value="Kinh doanh">Kinh doanh</option>
                <option value="Giáo dục">Giáo dục</option>
              </select>
            </div>
            <div class="form-field">
              <label>Mô tả ngắn</label>
              <input name="description" placeholder="Giới thiệu nội dung kênh..." />
            </div>
          </div>
          <div>
            <button class="btn-primary" type="submit">Tạo kênh</button>
          </div>
        </form>

        <form id="createEpisodeForm" class="studio-card">
          <h3>+ Đăng Episode mới</h3>
          <div class="form-grid">
            <div class="form-field">
              <label>Chọn Kênh</label>
              <select name="channel_id" required>
                ${
                  myChannels.length
                    ? myChannels
                        .map((c) => `<option value="${c.channel_id}">${PodifyUI.escapeHtml(c.title)}</option>`)
                        .join('')
                    : '<option value="">-- Tạo kênh trước --</option>'
                }
              </select>
            </div>
            <div class="form-field">
              <label>Thời lượng (giây)</label>
              <input name="duration_seconds" type="number" min="60" value="1200" required />
            </div>
            <div class="form-field full">
              <label>Tiêu đề Episode</label>
              <input name="title" required placeholder="vd: Tập 5: Trigger & Transaction trong MySQL" />
            </div>
            <div class="form-field">
              <label>File Audio mẫu</label>
              <select name="audio_url">
                <option value="/assets/audio/podcast_cuoc_song.mp3">Podcast: Cuộc sống (Giọng đọc VN)</option>
                <option value="/assets/audio/podcast_tinh_yeu.mp3">Podcast: Tình yêu (Giọng đọc VN)</option>
                <option value="/assets/audio/podcast_hoai_bao.mp3">Podcast: Hoài bão (Giọng đọc VN)</option>
                <option value="/assets/audio/nhac_dua_vai_anh.mp3">Nhạc: Dựa Vai Anh</option>
                <option value="/assets/audio/nhac_uoc_mo_cua_me.mp3">Nhạc: Ước Mơ Của Mẹ</option>
                <option value="/assets/audio/sample_1.mp3">Podcast Tech: sample_1.mp3</option>
                <option value="/assets/audio/sample_2.mp3">Podcast Tech: sample_2.mp3</option>
                <option value="/assets/audio/sample_ep99.mp3">Podcast Tech: sample_ep99.mp3</option>
              </select>
            </div>
            <div class="form-field">
              <label>Trạng thái</label>
              <select name="status">
                <option value="published">published</option>
                <option value="draft">draft</option>
              </select>
            </div>
          </div>
          <div>
            <button class="btn-primary" type="submit" ${myChannels.length ? '' : 'disabled'}>Đăng tập mới</button>
          </div>
        </form>
      </div>
    `;
  }

  function renderHTML(user) {
    const categories = ['', 'Công nghệ', 'Đời sống', 'Kinh doanh', 'Giáo dục'];
    const esc = PodifyUI.escapeHtml;

    const visibleEpisodes = state.selectedChannelId
      ? state.episodes.filter((e) => Number(e.channel_id) === Number(state.selectedChannelId))
      : state.episodes;

    const selectedChannel = state.selectedChannelId
      ? state.channels.find((c) => Number(c.channel_id) === Number(state.selectedChannelId))
      : null;

    return `
      <div style="padding:22px 28px 96px;display:flex;flex-direction:column;gap:22px;">
        <div class="page-header">
          <div>
            <h1>Explore &amp; Content Management (Module 01)</h1>
            <p>Khám phá kênh Podcast, lọc tập theo thời lượng (Q1: 15–30 phút) và quản lý nội dung cho Creator.</p>
          </div>
        </div>

        ${
          state.error
            ? `<div class="trigger-error-box">Không tải được dữ liệu từ MySQL: ${esc(state.error)}</div>`
            : ''
        }

        <div class="toolbar-row">
          <div class="filter-group">
            ${categories
              .map(
                (cat) => `
              <button class="pill-tab ${state.category === cat ? 'active' : ''}" data-content-cat="${esc(cat)}">
                ${cat || 'Tất cả danh mục'}
              </button>`
              )
              .join('')}
          </div>

          <div class="filter-group">
            <button class="pill-tab ${state.durationFilter === 'all' ? 'active' : ''}" data-content-dur="all">Mọi thời lượng</button>
            <button class="pill-tab ${state.durationFilter === 'q1' ? 'active' : ''}" data-content-dur="q1">15–30 phút (Q1)</button>
            <button class="pill-tab ${state.durationFilter === 'short' ? 'active' : ''}" data-content-dur="short">&lt; 20 phút (Trigger)</button>
          </div>
        </div>

        <section>
          <div class="section-head">
            <div class="section-title">
              <span>Podcast Channels (${state.channels.length})</span>
            </div>
            ${
              selectedChannel
                ? `<button class="see-all" data-content-channel="">Xem tất cả kênh</button>`
                : ''
            }
          </div>

          <div class="data-list">
            ${state.channels
              .map(
                (c) => `
              <div class="data-row">
                <div style="min-width:0;flex:1;">
                  <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
                    <strong>${esc(c.title)}</strong>
                    <span class="lib-badge">${esc(c.category)}</span>
                    ${c.creator_verified ? '<span class="badge-verified">✓ Verified</span>' : ''}
                  </div>
                  <div style="font-size:12px;color:var(--text-secondary);margin-top:3px;">
                    Creator: <strong>${esc(c.creator_name)}</strong> · ${c.episode_count} tập · ${c.subscriber_count} subscribers · ${c.total_listens} lượt nghe · ★ ${c.avg_rating || 0}
                  </div>
                </div>
                <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
                  <button class="btn-secondary" data-content-channel="${c.channel_id}">
                    ${Number(state.selectedChannelId) === Number(c.channel_id) ? 'Đang lọc' : 'Xem tập'}
                  </button>
                  <button class="${c.is_subscribed ? 'btn-secondary' : 'btn-primary'}"
                    data-act="toggle-sub-id" data-channel-id="${c.channel_id}" data-sub="${c.is_subscribed ? 1 : 0}">
                    ${c.is_subscribed ? 'Subscribed ✓' : '+ Subscribe'}
                  </button>
                  <button class="btn-secondary" onclick="PodifyUI.openDonateModal(${c.creator_id})">Donate</button>
                </div>
              </div>`
              )
              .join('')}
          </div>
        </section>

        <section>
          <div class="section-head">
            <div class="section-title">
              <span>${selectedChannel ? `Episodes — ${esc(selectedChannel.title)}` : 'Danh sách Episodes'} (${visibleEpisodes.length})</span>
            </div>
          </div>

          <div class="data-list">
            ${
              visibleEpisodes.length
                ? visibleEpisodes
                    .map((e) => {
                      const mins = Math.round(Number(e.duration_seconds) / 60);
                      const isUnder20 = Number(e.duration_seconds) < 1200;
                      const canDelete =
                        user && (user.role === 'admin' || Number(user.creator_id) === Number(e.creator_id));
                      return `
                      <div class="data-row">
                        <div style="min-width:0;flex:1;">
                          <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
                            <strong>${esc(e.title)}</strong>
                            <span class="lib-badge">${mins} phút (${e.duration_seconds}s)</span>
                            ${
                              isUnder20
                                ? `<span class="badge-warn">&lt; 20p · ${e.ad_contract_count}/3 HĐ QC</span>`
                                : `<span class="badge-verified">≥ 20p · ${e.ad_contract_count} HĐ QC</span>`
                            }
                          </div>
                          <div style="font-size:12px;color:var(--text-secondary);margin-top:3px;">
                            ${esc(e.channel_title)} · ${esc(e.creator_name)} · ${e.listen_count} lượt nghe · ★ ${e.avg_rating || 0} · Status: ${esc(e.status)}
                          </div>
                        </div>
                        <div style="display:flex;gap:8px;align-items:center;">
                          <button class="btn-primary" data-act="play-episode-id" data-ep-id="${e.episode_id}">▶ Nghe</button>
                          <button class="btn-secondary" data-act="open-rate" data-id="${e.episode_id}">★ Rate</button>
                          ${
                            canDelete
                              ? `<button class="btn-danger" data-content-del-ep="${e.episode_id}">Xóa</button>`
                              : ''
                          }
                        </div>
                      </div>`;
                    })
                    .join('')
                : '<div class="card-surface" style="padding:18px;color:var(--text-muted);">Không có tập Podcast nào khớp bộ lọc hiện tại.</div>'
            }
          </div>
        </section>

        ${renderCreatorStudio(user)}
      </div>
    `;
  }

  function bindEvents(container, onReload) {
    container.querySelectorAll('[data-content-cat]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        state.category = btn.dataset.contentCat;
        await onReload();
      });
    });

    container.querySelectorAll('[data-content-dur]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        state.durationFilter = btn.dataset.contentDur;
        await onReload();
      });
    });

    container.querySelectorAll('[data-content-channel]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        const val = btn.dataset.contentChannel;
        state.selectedChannelId = val ? Number(val) : null;
        await onReload(false);
      });
    });

    container.querySelectorAll('[data-content-del-ep]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await PodifyUI.api(`/api/content/episodes/${btn.dataset.contentDelEp}`, { method: 'DELETE' });
          PodifyUI.showToast('Đã xóa Episode.');
          await onReload();
        } catch (err) {
          PodifyUI.showToast(err.message);
        }
      });
    });

    const chForm = container.querySelector('#createChannelForm');
    chForm?.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const fd = new FormData(chForm);
      try {
        await PodifyUI.api('/api/content/channels', {
          method: 'POST',
          body: {
            title: fd.get('title'),
            category: fd.get('category'),
            description: fd.get('description'),
          },
        });
        PodifyUI.showToast('Đã tạo kênh Podcast mới!');
        await onReload();
      } catch (err) {
        PodifyUI.showToast(err.message);
      }
    });

    const epForm = container.querySelector('#createEpisodeForm');
    epForm?.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const fd = new FormData(epForm);
      try {
        await PodifyUI.api('/api/content/episodes', {
          method: 'POST',
          body: {
            channel_id: Number(fd.get('channel_id')),
            title: fd.get('title'),
            duration_seconds: Number(fd.get('duration_seconds')),
            audio_url: fd.get('audio_url'),
            status: fd.get('status'),
          },
        });
        PodifyUI.showToast('Đã đăng Episode mới!');
        await onReload();
      } catch (err) {
        PodifyUI.showToast(err.message);
      }
    });
  }

  function setSelectedChannel(channelId) {
    state.selectedChannelId = channelId ? Number(channelId) : null;
  }

  return { loadData, renderHTML, bindEvents, setSelectedChannel };
})();
