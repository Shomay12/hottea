/**
 * HotTea Official Website - Core JavaScript
 * Handles Theme Switching, Navigation, Live GitHub Metadata, and Copy Buttons
 */

// Configuration Constants
const HOTTEA_CONFIG = {
  repoOwner: 'Shomay12',
  repoName: 'hottea',
  githubUrl: 'https://github.com/Shomay12/hottea',
  issuesUrl: 'https://github.com/Shomay12/hottea/issues',
  licenseUrl: 'https://github.com/Shomay12/hottea/blob/main/LICENSE'
};

document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  initMobileNav();
  initCopyButtons();
  fetchGitHubRepoStats();
  fetchContributors();
  highlightActiveNavLink();
});

/**
 * Theme Management (Dark / Light)
 */
function initTheme() {
  const themeToggle = document.getElementById('theme-toggle');
  const storedTheme = localStorage.getItem('hottea-theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

  const initialTheme = storedTheme || (prefersDark ? 'dark' : 'dark'); // Default to dark per spec
  setTheme(initialTheme);

  if (themeToggle) {
    themeToggle.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme') || 'dark';
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
      setTheme(newTheme);
      localStorage.setItem('hottea-theme', newTheme);
    });
  }

  // Listen to system changes if no manual preference stored
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    if (!localStorage.getItem('hottea-theme')) {
      setTheme(e.matches ? 'dark' : 'light');
    }
  });
}

function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  const themeToggle = document.getElementById('theme-toggle');
  if (themeToggle) {
    themeToggle.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
    themeToggle.innerHTML = theme === 'dark' 
      ? `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></svg>`
      : `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>`;
  }
}

/**
 * Mobile Navigation Toggle with Touch Locking & Auto-Close
 */
function initMobileNav() {
  const menuBtn = document.getElementById('mobile-menu-btn');
  const navMenu = document.getElementById('nav-menu');

  if (menuBtn && navMenu) {
    const updateMenuIcon = (isOpen) => {
      menuBtn.setAttribute('aria-expanded', isOpen);
      menuBtn.innerHTML = isOpen
        ? `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>`
        : `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="6" x2="21" y2="6"></line><line x1="3" y1="18" x2="21" y2="18"></line></svg>`;
      document.body.style.overflow = isOpen ? 'hidden' : '';
    };

    menuBtn.addEventListener('click', () => {
      const isOpen = navMenu.classList.toggle('open');
      updateMenuIcon(isOpen);
    });

    // Auto-close menu when tapping any navigation link
    navMenu.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', () => {
        if (navMenu.classList.contains('open')) {
          navMenu.classList.remove('open');
          updateMenuIcon(false);
        }
      });
    });

    // Close menu when tapping outside
    document.addEventListener('click', (e) => {
      if (!navMenu.contains(e.target) && !menuBtn.contains(e.target) && navMenu.classList.contains('open')) {
        navMenu.classList.remove('open');
        updateMenuIcon(false);
      }
    });
  }
}

/**
 * Active Navigation Link Spy
 */
function highlightActiveNavLink() {
  const currentPath = window.location.pathname;
  const navLinks = document.querySelectorAll('.nav-link');

  navLinks.forEach(link => {
    const href = link.getAttribute('href');
    if (href && (currentPath.endsWith(href) || (currentPath.endsWith('/') && href === 'index.html'))) {
      link.classList.add('active');
    }
  });
}

/**
 * Copy to Clipboard for Terminal / Code Blocks
 */
function initCopyButtons() {
  const copyButtons = document.querySelectorAll('.copy-btn');

  copyButtons.forEach(button => {
    button.addEventListener('click', () => {
      const targetId = button.getAttribute('data-target');
      const textToCopy = targetId 
        ? document.getElementById(targetId)?.innerText 
        : button.parentElement.nextElementSibling?.innerText || button.getAttribute('data-clipboard');

      if (textToCopy) {
        navigator.clipboard.writeText(textToCopy.trim()).then(() => {
          const originalText = button.innerText;
          button.innerText = 'Copied!';
          button.style.borderColor = 'var(--accent-primary)';
          button.style.color = 'var(--accent-primary)';
          setTimeout(() => {
            button.innerText = originalText;
            button.style.borderColor = '';
            button.style.color = '';
          }, 2000);
        }).catch(err => {
          console.warn('Clipboard write failed:', err);
        });
      }
    });
  });
}

/**
 * Live GitHub Repository Stats (Public API)
 * Degrades gracefully if offline or rate-limited.
 */
function fetchGitHubRepoStats() {
  const starsBadge = document.getElementById('github-stars-count');
  if (!starsBadge) return;

  const cacheKey = `gh_stats_${HOTTEA_CONFIG.repoOwner}_${HOTTEA_CONFIG.repoName}`;
  const cached = sessionStorage.getItem(cacheKey);

  if (cached) {
    try {
      const data = JSON.parse(cached);
      renderStats(data);
      return;
    } catch (e) {
      // Ignore cache parse error
    }
  }

  fetch(`https://api.github.com/repos/${HOTTEA_CONFIG.repoOwner}/${HOTTEA_CONFIG.repoName}`)
    .then(res => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    })
    .then(data => {
      sessionStorage.setItem(cacheKey, JSON.stringify({
        stars: data.stargazers_count,
        forks: data.forks_count
      }));
      renderStats({ stars: data.stargazers_count, forks: data.forks_count });
    })
    .catch(() => {
      // Degrade gracefully - display nothing or a fallback star indicator
      starsBadge.style.display = 'none';
    });

  function renderStats(stats) {
    if (typeof stats.stars === 'number') {
      starsBadge.innerText = `★ ${stats.stars}`;
      starsBadge.style.display = 'inline-block';
    }
  }
}

/**
 * Fetch and Render Project Contributors
 */
function fetchContributors() {
  const container = document.getElementById('dynamic-contributors');
  if (!container) return;

  fetch(`https://api.github.com/repos/${HOTTEA_CONFIG.repoOwner}/${HOTTEA_CONFIG.repoName}/contributors`)
    .then(res => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    })
    .then(contributors => {
      if (!Array.isArray(contributors)) return;

      // Filter out Shomay12 since Shomayyy12 is already featured in the spotlight card
      const others = contributors.filter(c => c.login.toLowerCase() !== 'shomay12');
      if (others.length === 0) return;

      others.forEach(c => {
        const card = document.createElement('a');
        card.href = c.html_url;
        card.target = '_blank';
        card.rel = 'noopener';
        card.className = 'contributor-card';
        card.innerHTML = `
          <img src="${c.avatar_url}" alt="${c.login}" class="contributor-avatar" loading="lazy">
          <div class="contributor-info">
            <span class="contributor-name">${c.login}</span>
            <span class="contributor-role">Contributor</span>
            <span class="contributor-handle">@${c.login} · ${c.contributions} commits</span>
          </div>
        `;
        container.appendChild(card);
      });
    })
    .catch(() => {
      // Degrade silently; static maintainer card remains fully intact
    });
}

