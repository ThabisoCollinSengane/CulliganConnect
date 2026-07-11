// Applies the saved theme and injects a 🌙/☀️ toggle into the header.
// Imported for its side effects by every page.
const KEY = 'culligan-theme';

function currentTheme() {
  return localStorage.getItem(KEY) || 'light';
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
}

applyTheme(currentTheme());

let toggleEl;

function refreshLabel() {
  if (toggleEl) toggleEl.textContent = currentTheme() === 'dark' ? '☀️' : '🌙';
}

function injectToggle() {
  toggleEl = document.createElement('a');
  toggleEl.href = '#';
  toggleEl.title = 'Toggle dark mode';
  toggleEl.setAttribute('aria-label', 'Toggle dark mode');
  toggleEl.addEventListener('click', (e) => {
    e.preventDefault();
    const next = currentTheme() === 'dark' ? 'light' : 'dark';
    localStorage.setItem(KEY, next);
    applyTheme(next);
    refreshLabel();
  });

  const nav = document.querySelector('.app-header nav');
  if (nav) {
    nav.appendChild(toggleEl);
  } else {
    toggleEl.style.cssText = 'position:fixed; top:14px; right:14px; z-index:100; text-decoration:none; font-size:1.2rem;';
    document.body.appendChild(toggleEl);
  }
  refreshLabel();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', injectToggle);
} else {
  injectToggle();
}
