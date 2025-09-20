// Dark mode toggle functionality
(function() {
    // Get the navigation theme toggle button
    const toggleButton = document.getElementById('theme-toggle');
    if (!toggleButton) return;

    const ICONS = {
        light: '<svg class="theme-icon" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79Z"/></svg>',
        dark: '<svg class="theme-icon" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"/><path d="M12 3v2m0 14v2m9-9h-2M5 12H3m15.3-6.3-1.4 1.4M7.1 16.9l-1.4 1.4M7.1 7.1 5.7 5.7M16.9 16.9l1.4 1.4"/></svg>'
    };

    const LABELS = {
        light: 'Switch to dark mode',
        dark: 'Switch to light mode'
    };

    function applyTheme(theme, persist = true) {
        document.documentElement.setAttribute('data-theme', theme);
        if (persist) {
            localStorage.setItem('theme', theme);
        }

        toggleButton.setAttribute('aria-label', LABELS[theme]);
        toggleButton.setAttribute('aria-pressed', theme === 'dark');
        toggleButton.innerHTML = ICONS[theme];
    }

    // Check for saved theme or default to light mode
    const storedTheme = localStorage.getItem('theme');
    const currentTheme = storedTheme === 'dark' ? 'dark' : 'light';
    applyTheme(currentTheme, false);

    // Toggle theme function
    function toggleTheme() {
        const activeTheme = document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
        const newTheme = activeTheme === 'dark' ? 'light' : 'dark';
        applyTheme(newTheme);
    }

    // Add click event listener
    toggleButton.addEventListener('click', toggleTheme);

    // Code block copy functionality
    function addCopyButtonsToCodeBlocks() {
        const codeBlocks = document.querySelectorAll('.org-src-container');
        const COPY_ICON = '<svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
        const CHECK_ICON = '<svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';

        codeBlocks.forEach(container => {
            if (container.dataset.copyHandlerAdded) return;

            const pre = container.querySelector('pre');
            if (!pre) return;

            const copyButton = document.createElement('button');
            copyButton.type = 'button';
            copyButton.className = 'copy-code-button';
            copyButton.setAttribute('aria-label', 'Copy code snippet to clipboard');
            copyButton.setAttribute('title', 'Copy code');
            copyButton.innerHTML = COPY_ICON;

            copyButton.addEventListener('click', event => {
                event.preventDefault();
                event.stopPropagation();

                const code = pre.textContent;
                if (!code) return;

                if (!navigator.clipboard || !navigator.clipboard.writeText) {
                    console.warn('Clipboard API unavailable; skipping copy action.');
                    return;
                }

                navigator.clipboard.writeText(code).then(() => {
                    copyButton.classList.add('is-copied');
                    copyButton.innerHTML = CHECK_ICON;

                    setTimeout(() => {
                        copyButton.classList.remove('is-copied');
                        copyButton.innerHTML = COPY_ICON;
                    }, 1500);
                }).catch(err => {
                    console.error('Failed to copy code: ', err);
                });
            });

            container.appendChild(copyButton);
            container.dataset.copyHandlerAdded = 'true';
        });
    }

    // Add copy buttons when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', addCopyButtonsToCodeBlocks);
    } else {
        addCopyButtonsToCodeBlocks();
    }
})();
