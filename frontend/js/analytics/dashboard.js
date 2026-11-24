/* ==========================================================================
   Podify — Module 03: Advertisement, Donations & Business Analytics (Frontend JS)
   Owner: Member 3 - Quang
   ========================================================================== */

const PodifyAnalytics = (() => {
  const state = {
    tab: 'overview', // overview | ads | donations | queries
    overview: null,
    ads: [],
    contracts: [],
    slots: [],
    episodes: [],
    donations: [],
    queriesMeta: [],
    activeQueryId: 'Q8',
    queryResult: null,
    triggerFeedback: null,
    error: null,
  };

  async function loadData() {
    state.error = null;
    try {
      const [overview, ads, contracts, slots, episodes, donations, queriesMeta] = await Promise.all([
        PodifyUI.api('/api/analytics/reports/overview'),
        PodifyUI.api('/api/analytics/ads'),
        PodifyUI.api('/api/analytics/contracts'),
        PodifyUI.api('/api/analytics/slots'),
        PodifyUI.api('/api/content/episodes'),
        PodifyUI.api('/api/analytics/donations'),
        PodifyUI.api('/api/analytics/reports/queries'),
      ]);
      state.overview = overview;
      state.ads = ads || [];
      state.contracts = contracts || [];
      state.slots = slots || [];
      state.episodes = episodes || [];
      state.donations = donations || [];
      state.queriesMeta = queriesMeta || [];
      if (!state.queryResult) {
        state.queryResult = await PodifyUI.api(`/api/analytics/reports/queries/${state.activeQueryId}`);
      }
    } catch (err) {
      state.error = err.message;
    }
  }

  function renderOverviewTab() {
    const esc = PodifyUI.escapeHtml;
    const cumRows = state.overview?.cumulative_revenue || [];
    const topRows = state.overview?.top_podcasts || [];
    const maxCum = Math.max(1, ...cumRows.map((r) => Number(r.cumulative_revenue || 0)));

    return `
      <div class="analytics-panel">
        <div class="section-head" style="margin-bottom:0;">
          <div class="section-title"><span>Doanh thu quảng cáo tích lũy theo Creator qua từng tháng (Q8 — Window Function)</span></div>
          <span class="lib-badge">SUM() OVER (PARTITION BY creator_id ORDER BY revenue_month)</span>
        </div>
        <div class="table-wrap">
          <table class="podify-table">
            <thead>
              <tr>
                <th>Creator</th>
                <th>Tháng</th>
                <th>Impressions</th>
                <th>Doanh thu tháng</th>
                <th>Doanh thu tích lũy</th>
              </tr>
            </thead>
            <tbody>
              ${cumRows
                .map((r) => {
                  const pct = Math.round((Number(r.cumulative_revenue) / maxCum) * 100);
                  return `
                    <tr>
                      <td><strong>${esc(r.creator_name)}</strong></td>
                      <td>${esc(r.revenue_month)}</td>
                      <td>${Number(r.monthly_impressions).toLocaleString('vi-VN')}</td>
                      <td>${PodifyUI.fmtCurrency(r.monthly_revenue)}</td>
                      <td>
                        <span class="rev-bar-track"><span class="rev-bar-fill" style="width:${pct}%"></span></span>
                        <strong>${PodifyUI.fmtCurrency(r.cumulative_revenue)}</strong>
                      </td>
                    </tr>`;
                })
                .join('')}
            </tbody>
          </table>
        </div>
      </div>

      <div class="analytics-panel">
        <div class="section-head" style="margin-bottom:0;">
          <div class="section-title"><span>Bảng xếp hạng Top Podcast Channels</span></div>
        </div>
        <div class="table-wrap">
          <table class="podify-table">
            <thead>
              <tr>
                <th>Kênh Podcast</th>
                <th>Creator</th>
                <th>Danh mục</th>
                <th>Lượt nghe</th>
                <th>Subscribers</th>
                <th>Rating TB</th>
              </tr>
            </thead>
            <tbody>
              ${topRows
                .map(
                  (c) => `
                  <tr>
                    <td><strong>${esc(c.channel_title)}</strong></td>
                    <td>${esc(c.creator_name)}</td>
                    <td><span class="lib-badge">${esc(c.category)}</span></td>
                    <td>${c.total_listens}</td>
                    <td>${c.subscriber_count}</td>
                    <td>★ ${c.avg_rating}</td>
                  </tr>`
                )
                .join('')}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }

  function renderAdsTab(user) {
    const esc = PodifyUI.escapeHtml;
    const isCreator = user && (user.role === 'creator' || user.role === 'admin');

    return `
      <div class="trigger-alert">
        <strong>Kiểm chứng quy tắc nghiệp vụ (Backend Validation):</strong>
        Mỗi Episode có thời lượng <strong>&lt; 20 phút (&lt; 1200s)</strong> chỉ được gắn tối đa <strong>3 hợp đồng quảng cáo</strong>.
        Hiện <code>EP0011</code> (<em>Tập ngắn: Nhập môn SQL trong 15 phút — 900s</em>) đã có đủ 3/3 hợp đồng. Hãy thử gắn thêm hợp đồng <code>HD-2026-0004</code> (tài khoản <code>minh_ai</code>) để xem hệ thống chặn và báo lỗi ngay!
      </div>

      ${
        state.triggerFeedback
          ? `<div class="${state.triggerFeedback.ok ? 'badge-verified' : 'trigger-error-box'}" style="padding:12px 14px;display:block;">
              ${esc(state.triggerFeedback.text)}
             </div>`
          : ''
      }

      <div class="studio-grid">
        <form id="createSlotForm" class="studio-card">
          <h3>Gắn Hợp đồng vào Episode (AdSlots)</h3>
          <div class="form-grid">
            <div class="form-field">
              <label>Hợp đồng (AdContract)</label>
              <select name="contract_id" required>
                ${state.contracts
                  .map(
                    (c) =>
                      `<option value="${c.contract_id}">${esc(c.contract_code)} — ${esc(c.advertiser_name)} (${esc(c.creator_name)})</option>`
                  )
                  .join('')}
              </select>
            </div>
            <div class="form-field">
              <label>Episode</label>
              <select name="episode_id" required>
                ${state.episodes
                  .map(
                    (e) =>
                      `<option value="${e.episode_id}">#${e.episode_id} ${esc(e.title)} (${e.duration_seconds}s)</option>`
                  )
                  .join('')}
              </select>
            </div>
            <div class="form-field">
              <label>Vị trí (slot_position)</label>
              <select name="slot_position">
                <option value="pre-roll">pre-roll</option>
                <option value="mid-roll" selected>mid-roll</option>
                <option value="post-roll">post-roll</option>
              </select>
            </div>
            <div class="form-field">
              <label>Offset (giây)</label>
              <input name="start_offset_seconds" type="number" min="0" value="120" required />
            </div>
          </div>
          <div style="display:flex;gap:8px;flex-wrap:wrap;">
            <button class="btn-primary" type="submit" ${isCreator ? '' : 'disabled'}>Gắn AdSlot vào Episode</button>
            ${
              !isCreator
                ? '<button type="button" class="btn-secondary" onclick="PodifyUI.openAuthModal()">Cần đăng nhập Creator (minh_ai / manh_trithuc)</button>'
                : ''
            }
          </div>
        </form>

        <form id="createAdForm" class="studio-card">
          <h3>+ Tạo Chiến dịch Quảng cáo (Advertisements)</h3>
          <div class="form-grid">
            <div class="form-field">
              <label>Nhà quảng cáo</label>
              <input name="advertiser_name" required placeholder="vd: VNG Cloud" />
            </div>
            <div class="form-field">
              <label>Thời lượng (giây)</label>
              <input name="duration_seconds" type="number" min="5" value="25" required />
            </div>
            <div class="form-field full">
              <label>Tiêu đề quảng cáo</label>
              <input name="title" required placeholder="vd: VNG Cloud - Giải pháp lưu trữ Audio" />
            </div>
          </div>
          <div>
            <button class="btn-primary" type="submit" ${isCreator ? '' : 'disabled'}>Lưu quảng cáo</button>
          </div>
        </form>
      </div>

      <div class="analytics-panel">
        <div class="section-head" style="margin-bottom:0;">
          <div class="section-title"><span>Danh sách AdSlots đang gắn trên các Episode (${state.slots.length})</span></div>
        </div>
        <div class="table-wrap">
          <table class="podify-table">
            <thead>
              <tr>
                <th>Episode</th>
                <th>Thời lượng Ep</th>
                <th>Vị trí</th>
                <th>Offset</th>
                <th>Mã HĐ</th>
                <th>Nhà quảng cáo</th>
                <th>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              ${state.slots
                .map(
                  (s) => `
                  <tr>
                    <td><strong>#${s.episode_id} ${esc(s.episode_title)}</strong></td>
                    <td>${s.episode_duration_seconds}s (${Math.round(s.episode_duration_seconds / 60)}p)</td>
                    <td><span class="lib-badge">${esc(s.slot_position)}</span></td>
                    <td>${PodifyUI.fmtTime(s.start_offset_seconds)}</td>
                    <td><code>${esc(s.contract_code)}</code></td>
                    <td>${esc(s.advertiser_name)}</td>
                    <td>
                      ${
                        isCreator
                          ? `<button class="btn-secondary" style="padding:4px 10px;font-size:11.5px;" data-del-slot="${s.slot_id}">Gỡ</button>`
                          : '—'
                      }
                    </td>
                  </tr>`
                )
                .join('')}
            </tbody>
          </table>
        </div>
      </div>

      <div class="analytics-panel">
        <div class="section-head" style="margin-bottom:0;">
          <div class="section-title"><span>Hợp đồng quảng cáo (AdContracts)</span></div>
        </div>
        <div class="table-wrap">
          <table class="podify-table">
            <thead>
              <tr>
                <th>Mã HĐ</th>
                <th>Nhà quảng cáo</th>
                <th>Creator</th>
                <th>Giá trị HĐ</th>
                <th>CPM</th>
                <th>Số AdSlots</th>
                <th>Doanh thu thực tế</th>
              </tr>
            </thead>
            <tbody>
              ${state.contracts
                .map(
                  (c) => `
                  <tr>
                    <td><code>${esc(c.contract_code)}</code></td>
                    <td>${esc(c.advertiser_name)}</td>
                    <td>${esc(c.creator_name)}</td>
                    <td>${PodifyUI.fmtCurrency(c.contract_value)}</td>
                    <td>${PodifyUI.fmtCurrency(c.cpm_rate)}</td>
                    <td>${c.assigned_slots_count}</td>
                    <td><strong>${PodifyUI.fmtCurrency(c.realized_revenue)}</strong></td>
                  </tr>`
                )
                .join('')}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }

  function renderDonationsTab() {
    const esc = PodifyUI.escapeHtml;
    return `
      <div class="analytics-panel">
        <div class="section-head" style="margin-bottom:0;">
          <div class="section-title"><span>Lịch sử Ủng hộ Creator (Donations)</span></div>
          <button class="btn-primary" onclick="PodifyUI.openDonateModal()">+ Ủng hộ ngay</button>
        </div>
        <div class="table-wrap">
          <table class="podify-table">
            <thead>
              <tr>
                <th>Người ủng hộ</th>
                <th>Creator nhận</th>
                <th>Số tiền</th>
                <th>Lời nhắn</th>
                <th>Thời gian</th>
              </tr>
            </thead>
            <tbody>
              ${state.donations
                .map(
                  (d) => `
                  <tr>
                    <td><strong>${esc(d.donor_name)}</strong> (${esc(d.donor_username)})</td>
                    <td>${esc(d.creator_name)}</td>
                    <td><strong style="color:var(--accent-text);">${PodifyUI.fmtCurrency(d.amount)}</strong></td>
                    <td>${esc(d.message || '—')}</td>
                    <td>${esc(String(d.donated_at).slice(0, 16).replace('T', ' '))}</td>
                  </tr>`
                )
                .join('')}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }

  function renderQueriesTab() {
    const esc = PodifyUI.escapeHtml;
    const qr = state.queryResult;
    const rows = qr?.rows || [];
    const cols = rows.length ? Object.keys(rows[0]) : [];

    return `
      <div class="analytics-panel">
        <div class="section-head" style="margin-bottom:0;">
          <div class="section-title"><span>SQL Query Inspector (Q1 – Q8 Nghiệp vụ bắt buộc)</span></div>
        </div>
        <div class="filter-group">
          ${state.queriesMeta
            .map(
              (q) => `
            <button class="pill-tab ${state.activeQueryId === q.id ? 'active' : ''}" data-run-q="${q.id}">
              ${esc(q.id)} (${esc(q.owner)})
            </button>`
            )
            .join('')}
        </div>

        ${
          qr
            ? `
          <div style="display:flex;flex-direction:column;gap:12px;">
            <div>
              <h3 style="font-size:15px;">${esc(qr.id)}: ${esc(qr.title)}</h3>
              <p style="font-size:12px;color:var(--text-secondary);">Phụ trách: <strong>${esc(qr.owner)}</strong> · Khái niệm SQL: <code>${esc(qr.concepts)}</code> · Kết quả: <strong>${qr.row_count} dòng</strong></p>
            </div>
            <pre class="sql-preview">${esc(qr.sql)}</pre>
            <div class="table-wrap">
              ${
                rows.length
                  ? `<table class="podify-table">
                      <thead><tr>${cols.map((c) => `<th>${esc(c)}</th>`).join('')}</tr></thead>
                      <tbody>
                        ${rows
                          .map(
                            (r) => `<tr>${cols.map((c) => `<td>${esc(r[c] ?? 'NULL')}</td>`).join('')}</tr>`
                          )
                          .join('')}
                      </tbody>
                    </table>`
                  : '<p style="color:var(--text-muted);font-size:13px;">Truy vấn trả về 0 dòng.</p>'
              }
            </div>
          </div>`
            : ''
        }
      </div>
    `;
  }

  function renderHTML(user) {
    const esc = PodifyUI.escapeHtml;
    const k = state.overview?.kpis || {};

    return `
      <div style="padding:22px 28px 96px;display:flex;flex-direction:column;gap:20px;">
        <div class="page-header">
          <div>
            <h1>Advertisement &amp; Business Analytics (Module 03)</h1>
            <p>Quản lý quảng cáo, hợp đồng, AdSlots (giới hạn 3 hợp đồng &lt; 20p), Donation và 8 câu truy vấn phân tích Q1–Q8.</p>
          </div>
        </div>

        ${
          state.error
            ? `<div class="trigger-error-box">Lỗi tải dữ liệu Analytics: ${esc(state.error)}</div>`
            : ''
        }

        <div class="kpi-grid">
          <div class="kpi-card">
            <span>Tổng lượt nghe (ListeningHistory)</span>
            <strong>${Number(k.total_listens || 0).toLocaleString('vi-VN')}</strong>
            <small>${k.total_episodes || 0} tập trên ${k.total_channels || 0} kênh</small>
          </div>
          <div class="kpi-card">
            <span>Tổng doanh thu quảng cáo</span>
            <strong>${PodifyUI.fmtCurrency(k.total_ad_revenue || 0)}</strong>
            <small>${k.active_contracts || 0} hợp đồng đang hoạt động</small>
          </div>
          <div class="kpi-card">
            <span>Tổng tiền ủng hộ (Donations)</span>
            <strong>${PodifyUI.fmtCurrency(k.total_donations || 0)}</strong>
            <small>Từ cộng đồng người nghe</small>
          </div>
          <div class="kpi-card">
            <span>Người dùng &amp; Creators</span>
            <strong>${k.total_users || 0} Users</strong>
            <small>${k.total_creators || 0} Creators đã xác minh</small>
          </div>
        </div>

        <div class="filter-group">
          <button class="pill-tab ${state.tab === 'overview' ? 'active' : ''}" data-an-tab="overview">Tổng quan &amp; Q8</button>
          <button class="pill-tab ${state.tab === 'ads' ? 'active' : ''}" data-an-tab="ads">Quảng cáo, Hợp đồng &amp; Trigger</button>
          <button class="pill-tab ${state.tab === 'donations' ? 'active' : ''}" data-an-tab="donations">Donations</button>
          <button class="pill-tab ${state.tab === 'queries' ? 'active' : ''}" data-an-tab="queries">SQL Queries (Q1–Q8)</button>
        </div>

        ${state.tab === 'overview' ? renderOverviewTab() : ''}
        ${state.tab === 'ads' ? renderAdsTab(user) : ''}
        ${state.tab === 'donations' ? renderDonationsTab() : ''}
        ${state.tab === 'queries' ? renderQueriesTab() : ''}
      </div>
    `;
  }

  function bindEvents(container, onReload) {
    container.querySelectorAll('[data-an-tab]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.tab = btn.dataset.anTab;
        onReload(false);
      });
    });

    container.querySelectorAll('[data-run-q]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        state.activeQueryId = btn.dataset.runQ;
        try {
          state.queryResult = await PodifyUI.api(`/api/analytics/reports/queries/${state.activeQueryId}`);
          onReload(false);
        } catch (err) {
          PodifyUI.showToast(err.message);
        }
      });
    });

    const slotForm = container.querySelector('#createSlotForm');
    slotForm?.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const fd = new FormData(slotForm);
      try {
        await PodifyUI.api('/api/analytics/slots', {
          method: 'POST',
          body: {
            contract_id: String(fd.get('contract_id') || ''),
            episode_id: String(fd.get('episode_id') || ''),
            slot_position: fd.get('slot_position'),
            start_offset_seconds: Number(fd.get('start_offset_seconds')),
          },
        });
        state.triggerFeedback = { ok: true, text: 'Thành công! Đã chèn AdSlot mới vào MySQL.' };
        PodifyUI.showToast('Đã gắn AdSlot thành công!');
        await onReload(true);
      } catch (err) {
        state.triggerFeedback = { ok: false, text: `Bị từ chối bởi MySQL / API: ${err.message}` };
        PodifyUI.showToast(err.message);
        onReload(false);
      }
    });

    const adForm = container.querySelector('#createAdForm');
    adForm?.addEventListener('submit', async (ev) => {
      ev.preventDefault();
      const fd = new FormData(adForm);
      try {
        await PodifyUI.api('/api/analytics/ads', {
          method: 'POST',
          body: {
            advertiser_name: fd.get('advertiser_name'),
            title: fd.get('title'),
            duration_seconds: Number(fd.get('duration_seconds')),
          },
        });
        PodifyUI.showToast('Đã tạo quảng cáo mới!');
        await onReload(true);
      } catch (err) {
        PodifyUI.showToast(err.message);
      }
    });

    container.querySelectorAll('[data-del-slot]').forEach((btn) => {
      btn.addEventListener('click', async () => {
        try {
          await PodifyUI.api(`/api/analytics/slots/${btn.dataset.delSlot}`, { method: 'DELETE' });
          state.triggerFeedback = { ok: true, text: 'Đã gỡ AdSlot khỏi Episode.' };
          PodifyUI.showToast('Đã gỡ AdSlot.');
          await onReload(true);
        } catch (err) {
          PodifyUI.showToast(err.message);
        }
      });
    });
  }

  return { loadData, renderHTML, bindEvents };
})();
