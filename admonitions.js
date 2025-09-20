(function () {
  const TYPES = {
    note: { label: 'Note', tone: 'info', icon: '📝' },
    tip: { label: 'Tip', tone: 'info', icon: '💡' },
    info: { label: 'Info', tone: 'info', icon: 'ℹ️' },
    important: { label: 'Important', tone: 'warn', icon: '⚠️' },
    warning: { label: 'Warning', tone: 'warn', icon: '⚠️' },
    caution: { label: 'Caution', tone: 'warn', icon: '⚠️' },
    attention: { label: 'Attention', tone: 'warn', icon: '⚠️' }
  };

  function escapeForRegex(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function buildTitle(label, icon) {
    const title = document.createElement('div');
    title.className = 'admonition__title';
    if (icon) {
      const iconSpan = document.createElement('span');
      iconSpan.className = 'admonition__icon';
      iconSpan.setAttribute('aria-hidden', 'true');
      iconSpan.textContent = icon;
      title.appendChild(iconSpan);
    }
    const textSpan = document.createElement('span');
    textSpan.textContent = label;
    title.appendChild(textSpan);
    return title;
  }

  function trimLeadingLabel(paragraph, label) {
    if (!paragraph) {
      return;
    }
    const regex = new RegExp('^' + escapeForRegex(label) + '\\s*:?', 'i');
    const firstChild = paragraph.firstChild;
    if (!firstChild) {
      return;
    }
    if (firstChild.nodeType === Node.ELEMENT_NODE && (firstChild.tagName === 'STRONG' || firstChild.tagName === 'B')) {
      if (regex.test(firstChild.textContent.trim())) {
        paragraph.removeChild(firstChild);
      }
    }
    const newFirstChild = paragraph.firstChild;
    if (newFirstChild && newFirstChild.nodeType === Node.TEXT_NODE) {
      newFirstChild.textContent = newFirstChild.textContent.replace(regex, '').replace(/^\s*:?\s*/, '');
    }
  }

  function decorateBlock(element, config) {
    if (element.classList.contains('admonition')) {
      return;
    }

    const toneClass = config.tone === 'warn' ? 'admonition--warn' : 'admonition--info';
    element.classList.add('admonition', toneClass);
    element.setAttribute('data-admonition', config.label.toLowerCase());
    element.setAttribute('role', config.tone === 'warn' ? 'alert' : 'note');

    const originalNodes = Array.from(element.childNodes);
    element.textContent = '';

    const title = buildTitle(config.label, config.icon);
    element.appendChild(title);

    const body = document.createElement('div');
    body.className = 'admonition__body';

    originalNodes.forEach(node => {
      if (node.nodeType === Node.TEXT_NODE && !node.textContent.trim()) {
        return;
      }
      body.appendChild(node);
    });

    if (!body.childNodes.length) {
      body.appendChild(document.createElement('p'));
    }

    const firstParagraph = body.querySelector('p');
    trimLeadingLabel(firstParagraph, config.label);

    element.appendChild(body);
  }

  function init() {
    Object.entries(TYPES).forEach(([className, config]) => {
      document.querySelectorAll('div.' + className).forEach(block => {
        decorateBlock(block, config);
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init, { once: true });
  } else {
    init();
  }
})();
