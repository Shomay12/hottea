/**
 * HotTea Official Website - Documentation Hub Logic
 * Client-side local search, section scrollspy, and active TOC highlighting.
 */

document.addEventListener('DOMContentLoaded', () => {
  initDocsSearch();
  initDocsScrollSpy();
  buildTableOfContents();
});

/**
 * Fast Client-Side Documentation Search
 * Searches strictly within the local page DOM content
 */
function initDocsSearch() {
  const searchInput = document.getElementById('docs-search');
  if (!searchInput) return;

  const docSections = document.querySelectorAll('.docs-body section');

  searchInput.addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase().trim();

    if (!query) {
      docSections.forEach(section => {
        section.style.display = '';
      });
      return;
    }

    docSections.forEach(section => {
      const text = section.innerText.toLowerCase();
      if (text.includes(query)) {
        section.style.display = '';
      } else {
        section.style.display = 'none';
      }
    });
  });
}

/**
 * Table of Contents Generator & ScrollSpy
 */
function buildTableOfContents() {
  const tocList = document.getElementById('toc-list');
  if (!tocList) return;

  const headings = document.querySelectorAll('.docs-body h2, .docs-body h3');
  tocList.innerHTML = '';

  headings.forEach((heading, index) => {
    if (!heading.id) {
      heading.id = `heading-${index}`;
    }

    const li = document.createElement('li');
    const a = document.createElement('a');
    a.href = `#${heading.id}`;
    a.className = 'toc-link';
    a.innerText = heading.innerText;
    if (heading.tagName === 'H3') {
      a.style.paddingLeft = '12px';
      a.style.fontSize = '0.8rem';
    }

    li.appendChild(a);
    tocList.appendChild(li);
  });
}

function initDocsScrollSpy() {
  const headings = document.querySelectorAll('.docs-body h2, .docs-body h3');
  const tocLinks = document.querySelectorAll('.toc-link');

  if (headings.length === 0 || tocLinks.length === 0) return;

  window.addEventListener('scroll', () => {
    let currentId = '';
    const scrollPos = window.scrollY + 120;

    headings.forEach(heading => {
      if (heading.offsetTop <= scrollPos) {
        currentId = heading.id;
      }
    });

    tocLinks.forEach(link => {
      if (link.getAttribute('href') === `#${currentId}`) {
        link.classList.add('active');
      } else {
        link.classList.remove('active');
      }
    });
  });
}
