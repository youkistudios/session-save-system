(() => {
  const status = document.querySelector('#copy-status');

  const copyText = async (text) => {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return;
    }
    const area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    document.execCommand('copy');
    area.remove();
  };

  document.querySelectorAll('[data-copy-target]').forEach((button) => {
    button.addEventListener('click', async () => {
      const target = document.getElementById(button.dataset.copyTarget);
      if (!target) return;
      button.disabled = true;
      button.dataset.state = 'loading';
      button.textContent = 'Copying';
      try {
        await copyText(target.innerText.trim());
        button.dataset.state = 'success';
        button.textContent = 'Copied';
        button.setAttribute('aria-label', 'Install command copied');
        if (status) status.textContent = 'Install command copied to clipboard.';
      } catch (_) {
        button.dataset.state = 'error';
        button.textContent = 'Select text';
        button.setAttribute('aria-label', 'Copy failed; select the install command');
        if (status) status.textContent = 'Copy failed. Select the install command manually.';
      } finally {
        button.disabled = false;
      }
      window.setTimeout(() => {
        button.dataset.state = 'idle';
        button.textContent = 'Copy';
        button.setAttribute('aria-label', 'Copy install command');
      }, 1800);
    });
  });

  const tabs = [...document.querySelectorAll('[role="tab"]')];
  const panels = [...document.querySelectorAll('[role="tabpanel"]')];
  if (!tabs.length || tabs.length !== panels.length) return;

  const activate = (index, moveFocus = false) => {
    const current = (index + tabs.length) % tabs.length;
    tabs.forEach((tab, tabIndex) => {
      const active = tabIndex === current;
      tab.setAttribute('aria-selected', String(active));
      tab.tabIndex = active ? 0 : -1;
      if (active && moveFocus) tab.focus();
    });
    panels.forEach((panel, panelIndex) => {
      const active = panelIndex === current;
      panel.hidden = !active;
      panel.classList.toggle('active', active);
    });
  };

  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => activate(index));
    tab.addEventListener('keydown', (event) => {
      if (!['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault();
      if (event.key === 'Home') return activate(0, true);
      if (event.key === 'End') return activate(tabs.length - 1, true);
      const backwards = event.key === 'ArrowLeft' || event.key === 'ArrowUp';
      activate(index + (backwards ? -1 : 1), true);
    });
  });

  activate(0);
})();
