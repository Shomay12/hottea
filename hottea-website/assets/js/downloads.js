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
      if (!releases || releases.length === 0) {
        renderNoReleasesNotice(container);
      } else {
        renderLatestRelease(container, releases[0]);
      }
    })
    .catch(err => {
      console.warn('Could not fetch GitHub releases:', err);
      renderNoReleasesNotice(container, 'Unable to query release API at this time. Please check GitHub directly.');
    });
}

/**
 * Renders the honest "No official release has been published yet" state
 */
function renderNoReleasesNotice(container, customMessage) {
  container.innerHTML = `
    <div class="empty-release-banner">
      <div class="empty-release-icon">
        <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"></circle>
          <line x1="12" y1="8" x2="12" y2="12"></line>
          <line x1="12" y1="16" x2="12.01" y2="16"></line>
        </svg>
      </div>
      <div class="empty-release-content">
        <h3>No official release has been published yet.</h3>
        <p>${customMessage || 'HotTea is currently under active development. Pre-built binary packages (DMG, APK, AppImage, Installer) will appear here once official releases are tagged on GitHub.'}</p>
        <div class="empty-release-actions">
          <a href="${HOTTEA_CONFIG.githubUrl}" class="btn btn-secondary btn-sm" target="_blank" rel="noopener">
            View Source on GitHub
          </a>
          <a href="#build-from-source" class="btn btn-primary btn-sm">
            Build from Source Instructions
          </a>
        </div>
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
