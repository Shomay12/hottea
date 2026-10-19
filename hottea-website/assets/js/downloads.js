/**
 * HotTea Official Website - Downloads Portal Logic
 * Queries GitHub Releases API, handles empty/missing releases gracefully,
 * detects visitor OS, and manages CLI installation instructions.
 */

document.addEventListener('DOMContentLoaded', () => {
  initDownloadsPage();
  detectVisitorOS();
  initCliTabs();
});

function initDownloadsPage() {
  const container = document.getElementById('releases-container');
  if (!container) return;

  const url = `https://api.github.com/repos/${HOTTEA_CONFIG.repoOwner}/${HOTTEA_CONFIG.repoName}/releases`;

  fetch(url)
    .then(res => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    })
    .then(releases => {
      if (releases && releases.length > 0 && releases[0].assets && releases[0].assets.length > 0) {
        renderLatestRelease(container, releases[0]);
      } else {
        renderFeaturedReleases(container);
      }
    })
    .catch(err => {
      console.warn('Could not fetch GitHub releases, showing bundled releases:', err);
      renderFeaturedReleases(container);
    });
}

/**
 * Renders the official HotTea macOS DMG and Android APK release banner
 */
function renderFeaturedReleases(container) {
  container.innerHTML = `
    <div class="featured-release-banner">
      <div class="featured-release-header">
        <div>
          <div class="featured-release-badges">
            <span class="badge-apk-avail">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
              Official Releases Available
            </span>
            <span class="badge-apk-ver">v0.1.0</span>
            <span class="badge-apk-avail" style="background:rgba(212,139,71,0.15); color:var(--accent-primary); border-color:rgba(212,139,71,0.3);">macOS DMG &amp; Android APK</span>
          </div>
          <h2 class="featured-release-title">HotTea v0.1.0 — macOS DMG &amp; Android APK</h2>
        </div>
        <a href="${HOTTEA_CONFIG.githubUrl}" class="btn btn-secondary btn-sm" target="_blank" rel="noopener">
          View on GitHub
        </a>
      </div>

      <p class="featured-release-desc">
        Download official, production-ready release packages for <strong>macOS</strong> (Apple Disk Image <code>.dmg</code>) and <strong>Android</strong> (Package <code>.apk</code>). Built with the state-of-the-art <strong>Glassmorphic UI System</strong>, tab isolation, offline SQLite research vault, and native WebKit/WebView integration.
      </p>

      <div class="featured-release-meta">
        <div class="meta-chip">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
          <span>Mac DMG: <strong>HotTea.dmg</strong> (11 MB)</span>
        </div>
        <div class="meta-chip">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"></rect><line x1="12" y1="18" x2="12.01" y2="18"></line></svg>
          <span>Android APK: <strong>app-release.apk</strong> (56 MB)</span>
        </div>
        <div class="meta-chip">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
          <span>DMG SHA-256: <code class="checksum-snippet" title="9f9db6144584acf7f323ed555cc0f745867ec882ab06c3d70eac3f7c4fb1a68b">9f9db614...a68b</code></span>
        </div>
        <div class="meta-chip">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
          <span>APK SHA-256: <code class="checksum-snippet" title="e09b7f45b5118df459debc1cf47a60a6ce1189653a682b8430a201f82277ca12">e09b7f45...ca12</code></span>
        </div>
      </div>

      <div class="featured-release-actions">
        <a href="downloads/HotTea.dmg" download="HotTea.dmg" class="btn btn-primary btn-lg" id="featured-mac-download-btn">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
            <polyline points="7 10 12 15 17 10"></polyline>
            <line x1="12" y1="15" x2="12" y2="3"></line>
          </svg>
          Download for Mac (DMG 11 MB)
        </a>
        <a href="downloads/app-release.apk" download="hottea-app-release.apk" class="btn btn-secondary btn-lg" id="featured-apk-download-btn">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
            <polyline points="7 10 12 15 17 10"></polyline>
            <line x1="12" y1="15" x2="12" y2="3"></line>
          </svg>
          Download Android APK (56 MB)
        </a>
        <button class="btn btn-secondary btn-lg copy-btn" data-clipboard="9f9db6144584acf7f323ed555cc0f745867ec882ab06c3d70eac3f7c4fb1a68b">
          Copy DMG SHA-256
        </button>
      </div>
    </div>
  `;
}

/**
 * Renders verified releases when present
 */
function renderLatestRelease(container, release) {
  const publishedDate = new Date(release.published_at).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });

  let assetsHtml = '<ul class="release-assets-list">';
  if (release.assets && release.assets.length > 0) {
    release.assets.forEach(asset => {
      const sizeMb = (asset.size / (1024 * 1024)).toFixed(1);
      assetsHtml += `
        <li class="asset-item">
          <span class="asset-name"><strong>${asset.name}</strong> (${sizeMb} MB)</span>
          <a href="${asset.browser_download_url}" class="btn btn-sm btn-primary" download>
            Download
          </a>
        </li>
      `;
    });
  } else {
    assetsHtml += '<li class="asset-item">No binary artifacts attached to this release.</li>';
  }
  assetsHtml += '</ul>';

  container.innerHTML = `
    <div class="latest-release-card">
      <div class="release-header">
        <div>
          <span class="release-version-tag">${release.tag_name}</span>
          <span class="release-date">Published on ${publishedDate}</span>
        </div>
        <a href="${release.html_url}" class="btn btn-secondary btn-sm" target="_blank" rel="noopener">
          Release Notes & Chamelog
        </a>
      </div>
      <div class="release-assets">
        <h4 style="margin-bottom: 12px; font-size: 0.95rem;">Available Download Packages:</h4>
        ${assetsHtml}
      </div>
    </div>
  `;
}

/**
 * Detect Visitor OS to highlight appropriate instructions
 */
function detectVisitorOS() {
  const userAgent = window.navigator.userAgent.toLowerCase();
  let detectedPlatform = 'source';

  if (userAgent.indexOf('mac') !== -1) detectedPlatform = 'macos';
  else if (userAgent.indexOf('win') !== -1) detectedPlatform = 'windows';
  else if (userAgent.indexOf('android') !== -1) detectedPlatform = 'android';
  else if (userAgent.indexOf('iphone') !== -1 || userAgent.indexOf('ipad') !== -1) detectedPlatform = 'ios';
  else if (userAgent.indexOf('linux') !== -1) detectedPlatform = 'linux';

  const badge = document.getElementById('detected-os-badge');
  if (badge) {
    const platformNames = {
      macos: 'macOS',
      windows: 'Windows',
      linux: 'Linux',
      android: 'Android',
      ios: 'iOS',
      source: 'Source Build'
    };
    badge.innerText = `Detected Platform: ${platformNames[detectedPlatform] || 'Desktop'}`;
  }

  // Activate matching CLI tab if present
  const matchingTabBtn = document.querySelector(`.cli-tab-btn[data-platform="${detectedPlatform}"]`);
  if (matchingTabBtn) {
    matchingTabBtn.click();
  }
}

/**
 * CLI Tabs Interaction
 */
function initCliTabs() {
  const tabs = document.querySelectorAll('.cli-tab-btn');
  const panels = document.querySelectorAll('.cli-tab-panel');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetPlatform = tab.getAttribute('data-platform');

      tabs.forEach(t => t.classList.remove('active'));
      panels.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const targetPanel = document.getElementById(`cli-panel-${targetPlatform}`);
      if (targetPanel) {
        targetPanel.classList.add('active');
      }
    });
  });
}
