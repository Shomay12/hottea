# HotTea Official Website

This directory contains the complete source code for the official HotTea website, built purely using semantic **HTML5**, **CSS3**, and **Vanilla JavaScript** without external runtime dependencies, frontend compilation frameworks, or build tooling.

---

## 📁 Directory Structure

```text
hottea-website/
├── index.html                 # Homepage with live mockup, capabilities matrix, and architecture
├── downloads.html             # Downloads portal with dynamic GitHub Releases API integration
├── docs.html                  # Documentation hub with local client-side search & scrollspy
├── privacy.html               # Comprehensive privacy and data control specification
├── about.html                 # Project mission, technical foundations, and roadmap
├── 404.html                   # Custom 404 error page
├── CNAME                      # Custom domain configuration file
├── robots.txt                 # SEO crawler directives
├── sitemap.xml                # Search engine sitemap index
├── LICENSE                    # Apache 2.0 license
├── README.md                  # This documentation file
├── assets/
│   ├── css/
│   │   ├── style.css          # Design system, CSS variables, dark/light themes, typography
│   │   ├── responsive.css     # Mobile (320px+), tablet, and desktop media queries
│   │   └── docs.css           # Documentation hub sidebar, TOC, and markdown typography
│   └── js/
│       ├── main.js            # Theme switcher, mobile nav, copy buttons, live repo stars
│       ├── downloads.js       # GitHub Releases API, OS detection, CLI tab switcher
│       └── docs.js            # In-DOM local documentation search and scrollspy TOC
└── docs/
    ├── installation.md        # Detailed installation reference
    ├── cli-installation.md    # CLI commands for macOS, iOS, Android, Linux, Windows
    ├── troubleshooting.md     # Verified solutions for build & runtime issues
    └── contributing.md        # Open-source contributing guidelines & security policy
```

---

## 🚀 Local Development & Preview

Because the site uses purely static web standards, no compilation or Node.js environment is required. You can serve the directory using any static file server:

### Python 3 Built-in HTTP Server
```bash
cd hottea-website
python3 -m http.server 8080
```
Open [http://localhost:8080](http://localhost:8080) in your web browser.

---

## ⚙️ Configuration & GitHub API Integration

The website is pre-configured for the official HotTea GitHub repository:
* **Creator & Lead Maintainer**: `Shomayyy12` ([@Shomay12](https://github.com/Shomay12))
* **Repository Owner**: `Shomay12`
* **Repository Name**: `HotTea`
* **URL**: `https://github.com/Shomay12/hottea`

### Modifying the Repository Configuration
If you fork the repository or deploy under a different organization, update the configuration in [assets/js/main.js](assets/js/main.js):

```javascript
const HOTTEA_CONFIG = {
  repoOwner: 'YourUsername',
  repoName: 'hottea',
  githubUrl: 'https://github.com/YourUsername/hottea',
  // ...
};
```

---

## 📦 How Release Downloads Are Detected

1. [assets/js/downloads.js](assets/js/downloads.js) queries `https://api.github.com/repos/Shomay12/hottea/releases`.
2. **If no official release exists (Current State)**:
   - The page displays a banner: *"No official release has been published yet."*
   - Explains that HotTea is under active development and directs developers to the factual *Build from Source* instructions.
3. **When a release is tagged on GitHub**:
   - The latest release tag, publication date, changelog link, and downloadable binary assets (.dmg, .apk, .AppImage, .deb, .exe) are parsed and rendered with file sizes.
   - SHA-256 checksums from `SHA256SUMS.txt` can be verified by users.

---

## 🌐 Deployment Options

### 1. GitHub Pages
1. In your GitHub repository settings, navigate to **Pages**.
2. Under **Build and deployment**:
   - **Source**: Select *Deploy from a branch*.
   - **Branch**: Select `main` (or a dedicated `gh-pages` branch) and select `/hottea-website` as the folder (or place the contents in the root of your `gh-pages` branch).
3. The site will publish at `https://shomay12.github.io/hottea/`.

### 2. Cloudflare Pages / Netlify / Vercel
1. Set the **Build Command** to empty (no build step).
2. Set the **Publish Directory** to `hottea-website`.
3. Deploy.
