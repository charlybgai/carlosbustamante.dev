/*
 * carlosbustamante.dev: shared script for the English (/) and Spanish (/es/) pages.
 *
 * - The language comes from <html lang>. All UI strings live in STRINGS below.
 * - The API endpoint is the contact form's `action` attribute and the reCAPTCHA
 *   site key is its `data-recaptcha-key` attribute, so there are no URLs or keys here.
 * - Sections are shown one at a time. The URL hash (#about_me, ...) selects the
 *   section, so sections can be bookmarked and back/forward works.
 */
(function () {
    'use strict';

    const LANG = (document.documentElement.lang || 'en').toLowerCase().startsWith('es') ? 'es' : 'en';

    const STRINGS = {
        en: {
            roles: ['AI & MLOps Engineer', 'Machine Learning Engineer', 'AI Infrastructure Engineer'],
            viewProject: 'View project',
            showing: (n) => `Showing ${n} ${n === 1 ? 'project' : 'projects'}`,
            sending: 'Sending your message…',
            success: "Thanks! Your message was sent. I'll get back to you soon.",
            missing: 'Please fill in every field before sending.',
            rejected: "Your message couldn't be verified. Please check the fields and try again.",
            failed: "Something went wrong and your message wasn't sent. Please try again in a moment.",
            captcha: "The spam check didn't load, so the message can't be sent right now.",
            timeout: 'The server took too long to respond. Please try again.',
            busy: 'Too many messages are being sent right now. Please wait a minute and try again.',
            pauseMotion: 'Pause animations',
            playMotion: 'Play animations',
            unavailable: 'The contact service is temporarily unavailable, so your message wasn\'t sent. Please try again later.',
            fallback: 'You can also email me at',
        },
        es: {
            roles: ['Ingeniero de IA y MLOps', 'Ingeniero de Machine Learning', 'Ingeniero de Infraestructura de IA'],
            viewProject: 'Ver proyecto',
            showing: (n) => `Mostrando ${n} ${n === 1 ? 'proyecto' : 'proyectos'}`,
            sending: 'Enviando tu mensaje…',
            success: '¡Gracias! Tu mensaje se envió. Te responderé pronto.',
            missing: 'Completa todos los campos antes de enviar.',
            rejected: 'No se pudo verificar tu mensaje. Revisa los campos e inténtalo de nuevo.',
            failed: 'Algo salió mal y tu mensaje no se envió. Inténtalo de nuevo en un momento.',
            captcha: 'La verificación antispam no cargó, así que por ahora no se puede enviar el mensaje.',
            timeout: 'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
            busy: 'Se están enviando demasiados mensajes en este momento. Espera un minuto e inténtalo de nuevo.',
            pauseMotion: 'Pausar animaciones',
            playMotion: 'Reproducir animaciones',
            unavailable: 'El servicio de contacto no está disponible por ahora, así que tu mensaje no se envió. Inténtalo más tarde.',
            fallback: 'También puedes escribirme a',
        },
    }[LANG];

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

    // The CDN libraries (Bootstrap, Typed.js, Shuffle.js) load with `async`, so this script
    // never waits for them: a slow or blocked CDN can't break navigation. Each feature starts
    // as soon as its library arrives, and simply stays in its plain fallback if it never does.
    function whenLibraryLoads(isReady, src, start) {
        if (isReady()) {
            start();
            return;
        }
        const tag = document.querySelector(`script[src*="${src}"]`);
        if (tag) tag.addEventListener('load', () => { if (isReady()) start(); }, { once: true });
    }

    /* ------------------------------------------------------------------ *
     * Section routing
     * ------------------------------------------------------------------ */
    const DEFAULT_SECTION = 'home';
    const sections = Array.from(document.querySelectorAll('main > section[id]'));
    const sectionIds = sections.map((section) => section.id);
    const navLinks = Array.from(document.querySelectorAll('#sidebar nav a[href^="#"]'));
    const langLinks = Array.from(document.querySelectorAll('[data-lang-link]'));
    let currentId = null;

    langLinks.forEach((link) => {
        link.dataset.base = link.getAttribute('href');
    });

    function sectionFromHash(hash) {
        let id = (hash || '').replace(/^#/, '');
        try {
            id = decodeURIComponent(id);
        } catch (error) {
            return null;
        }
        return sectionIds.includes(id) ? id : null;
    }

    function showSection(id, { moveFocus = false } = {}) {
        const target = document.getElementById(id);
        if (!target) return;
        currentId = id;

        sections.forEach((section) => section.classList.toggle('active', section === target));

        navLinks.forEach((link) => {
            const isActive = link.getAttribute('href') === `#${id}`;
            link.classList.toggle('active', isActive);
            if (isActive) link.setAttribute('aria-current', 'page');
            else link.removeAttribute('aria-current');
        });

        // Keep the section when switching language
        const suffix = id === DEFAULT_SECTION ? '' : `#${id}`;
        langLinks.forEach((link) => {
            link.setAttribute('href', link.dataset.base + suffix);
        });

        window.scrollTo(0, 0);
        if (moveFocus) target.focus({ preventScroll: true });
        if (id === 'my_work') relayoutWork();
    }

    function navigate(id) {
        if (!sectionIds.includes(id)) return;
        if (id !== currentId) {
            const url = id === DEFAULT_SECTION ? location.pathname + location.search : `#${id}`;
            history.pushState({ section: id }, '', url);
        }
        showSection(id, { moveFocus: true });
    }

    // Any same-page link to a section (nav, logo, "View projects", "Message me", ...)
    document.addEventListener('click', (event) => {
        if (event.defaultPrevented || event.button !== 0) return;
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
        const link = event.target.closest('a[href^="#"]');
        if (!link) return;
        const id = sectionFromHash(link.getAttribute('href'));
        if (!id) return; // e.g. the skip link (#main) keeps its default behavior
        event.preventDefault();
        navigate(id);
    });

    window.addEventListener('popstate', () => {
        const id = sectionFromHash(location.hash) || (location.hash ? null : DEFAULT_SECTION);
        if (id && id !== currentId) showSection(id);
    });

    /* ------------------------------------------------------------------ *
     * Hero role animation (skipped when the user prefers reduced motion)
     * ------------------------------------------------------------------ */
    const typedTarget = document.querySelector('#home .typed');
    let typed = null;
    let motionPaused = false;
    if (typedTarget && !reduceMotion.matches) {
        whenLibraryLoads(() => typeof window.Typed === 'function', 'typed.js', () => {
            // The markup holds the first role as a fallback (no JS / reduced motion / CDN down).
            // Typed.js treats existing text as an already-typed extra string, which would make
            // the first role appear all at once, so clear it before starting.
            typedTarget.textContent = '';
            typed = new window.Typed(typedTarget, {
                strings: STRINGS.roles,
                contentType: null,
                autoInsertCss: false, // Cursor styles live in SCSS so CSP needs no inline CSS.
                loop: true,
                typeSpeed: 70,
                backSpeed: 30,
                backDelay: 1800,
                startDelay: 300,
            });
            if (motionPaused) typed.stop();
        });
    }

    // Pause control for everything in the hero that moves on its own (WCAG 2.2.2): the typing
    // loop, the drifting glow and the status pulse. Not shown when reduced motion is preferred,
    // because nothing moves then.
    const motionToggle = document.querySelector('#home .motion-toggle');
    if (motionToggle && !reduceMotion.matches) {
        const label = motionToggle.querySelector('.label');
        const render = () => {
            motionToggle.setAttribute('aria-pressed', String(motionPaused));
            label.textContent = motionPaused ? STRINGS.playMotion : STRINGS.pauseMotion;
            motionToggle.querySelector('use').setAttribute('href', motionToggle.dataset[motionPaused ? 'playIcon' : 'pauseIcon']);
            document.getElementById('home').classList.toggle('motion-paused', motionPaused);
        };
        motionToggle.addEventListener('click', () => {
            motionPaused = !motionPaused;
            if (typed) {
                if (motionPaused) typed.stop();
                else typed.start();
            }
            render();
        });
        motionToggle.hidden = false;
        render();
    }

    /* ------------------------------------------------------------------ *
     * Portfolio filters (Shuffle.js, with a plain fallback if the CDN fails)
     * ------------------------------------------------------------------ */
    const grid = document.querySelector('#my_work .work-items');
    const workItems = grid ? Array.from(grid.querySelectorAll('.item')) : [];
    const filterButtons = Array.from(document.querySelectorAll('#my_work .filters button[data-group]'));
    const filterStatus = document.querySelector('#my_work .filter-status');
    let shuffle = null;
    let activeGroup = 'all';

    if (grid) {
        whenLibraryLoads(() => typeof window.Shuffle === 'function', 'shuffle', () => {
            // Items hidden by the plain fallback filter are handed back to Shuffle
            workItems.forEach((item) => { item.hidden = false; });
            shuffle = new window.Shuffle(grid, {
                itemSelector: '.item',
                speed: reduceMotion.matches ? 0 : 300,
                group: activeGroup === 'all' ? window.Shuffle.ALL_ITEMS : activeGroup,
            });
            if (currentId === 'my_work') relayoutWork();
        });
    }

    // Give every card the height of the tallest one, but only when cards sit side by
    // side. In a single column, equal heights would just add empty space.
    function equalizeCards() {
        const cards = workItems.map((item) => item.querySelector('.wrap')).filter(Boolean);
        cards.forEach((card) => { card.style.minHeight = ''; });
        if (!grid || cards.length < 2) return;
        const columns = Math.round(grid.clientWidth / Math.max(1, workItems[0].getBoundingClientRect().width));
        if (columns < 2) return;
        const tallest = Math.max(...cards.map((card) => card.getBoundingClientRect().height));
        cards.forEach((card) => { card.style.minHeight = `${Math.ceil(tallest)}px`; });
    }

    function relayoutWork() {
        if (!grid) return;
        // Wait for the section to be displayed so the items can be measured
        requestAnimationFrame(() => {
            equalizeCards();
            if (shuffle) {
                shuffle.update();
                shuffle.layout();
            }
        });
    }

    let resizeTimer = null;
    window.addEventListener('resize', () => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => {
            if (currentId === 'my_work') relayoutWork();
        }, 150);
    });

    function itemGroups(item) {
        try {
            return JSON.parse(item.dataset.groups || '[]');
        } catch (error) {
            return [];
        }
    }

    filterButtons.forEach((button) => {
        button.addEventListener('click', () => {
            const group = button.dataset.group;
            activeGroup = group;
            filterButtons.forEach((other) => other.setAttribute('aria-pressed', String(other === button)));

            let visible;
            if (shuffle) {
                shuffle.filter(group === 'all' ? window.Shuffle.ALL_ITEMS : group);
                visible = shuffle.visibleItems;
            } else {
                visible = 0;
                workItems.forEach((item) => {
                    const show = group === 'all' || itemGroups(item).includes(group);
                    item.hidden = !show;
                    if (show) visible += 1;
                });
            }
            if (filterStatus) filterStatus.textContent = STRINGS.showing(visible);
        });
    });

    if (document.fonts && document.fonts.ready) document.fonts.ready.then(relayoutWork);
    window.addEventListener('load', relayoutWork);

    /* ------------------------------------------------------------------ *
     * Project modal (Bootstrap handles the focus trap and Escape)
     * ------------------------------------------------------------------ */
    const modalEl = document.getElementById('workModal');
    let lastTrigger = null;

    // Created on first use, because Bootstrap loads asynchronously
    function getModal() {
        return modalEl && window.bootstrap ? window.bootstrap.Modal.getOrCreateInstance(modalEl) : null;
    }

    function openProject(card, trigger) {
        const modal = getModal();
        if (!modal) {
            // Bootstrap didn't load: go straight to the project link (if the card has one)
            const href = (card.dataset.projectLink || '').trim();
            if (href && href !== '#') window.open(href, '_blank', 'noopener');
            return;
        }
        const data = card.dataset;
        const image = modalEl.querySelector('.modal-media img');
        image.src = data.image || '';
        image.alt = '';
        // Optional focal point for the wide popup header, e.g. data-image-position="center 42%"
        image.style.objectPosition = data.imagePosition || '';

        modalEl.querySelector('.modal-type').textContent = data.type || '';
        modalEl.querySelector('.modal-project-title').textContent = data.title || '';
        modalEl.querySelector('.description').textContent = data.description || '';
        modalEl.querySelector('.type-value').textContent = data.type || '';
        modalEl.querySelector('.completed-value').textContent = data.completed || '';

        const tools = modalEl.querySelector('.tools-value');
        const chips = (data.skills || '')
            .split(',')
            .map((skill) => skill.trim())
            .filter(Boolean)
            .map((skill) => {
                const chip = document.createElement('li');
                chip.className = 'chip';
                chip.textContent = skill;
                return chip;
            });
        tools.replaceChildren(...chips);

        const link = modalEl.querySelector('.project-link');
        const href = (data.projectLink || '').trim();
        if (href && href !== '#') {
            link.href = href;
            link.querySelector('.label').textContent = data.linkLabel || STRINGS.viewProject;
            link.hidden = false;
        } else {
            link.removeAttribute('href');
            link.hidden = true;
        }

        lastTrigger = trigger;
        modal.show();
    }

    document.querySelectorAll('#my_work .wrap').forEach((card) => {
        const trigger = card.querySelector('.card-open');
        if (!trigger) return;
        trigger.addEventListener('click', () => openProject(card, trigger));
        whenLibraryLoads(() => !!window.bootstrap, 'bootstrap', () => trigger.setAttribute('aria-haspopup', 'dialog'));
    });

    if (modalEl) {
        modalEl.addEventListener('shown.bs.modal', () => {
            const closeButton = modalEl.querySelector('.modal-close-button');
            if (closeButton) closeButton.focus();
        });
        modalEl.addEventListener('hidden.bs.modal', () => {
            if (lastTrigger) lastTrigger.focus();
            lastTrigger = null;
        });
        // Bootstrap keeps focus out of the page behind the dialog. This also wraps
        // Tab / Shift+Tab around the dialog's own controls instead of leaving the document.
        modalEl.addEventListener('keydown', (event) => {
            if (event.key !== 'Tab') return;
            const focusable = Array.from(modalEl.querySelectorAll('button, [href], input, textarea, select, [tabindex]:not([tabindex="-1"])'))
                .filter((el) => !el.hidden && !el.disabled && el.offsetParent !== null);
            if (!focusable.length) return;
            const first = focusable[0];
            const last = focusable[focusable.length - 1];
            if (event.shiftKey && document.activeElement === first) {
                event.preventDefault();
                last.focus();
            } else if (!event.shiftKey && document.activeElement === last) {
                event.preventDefault();
                first.focus();
            }
        });
    }

    /* ------------------------------------------------------------------ *
     * Contact form
     * ------------------------------------------------------------------ */
    const form = document.getElementById('contactForm');
    const FIELDS = ['name', 'email', 'subject', 'message'];

    function fail(code) {
        const error = new Error(code);
        error.code = code;
        return error;
    }

    function waitFor(check, timeoutMs) {
        return new Promise((resolve, reject) => {
            const started = Date.now();
            (function poll() {
                const value = check();
                if (value) resolve(value);
                else if (Date.now() - started > timeoutMs) reject(fail('captcha'));
                else setTimeout(poll, 200);
            })();
        });
    }

    async function getRecaptchaToken(siteKey) {
        if (!siteKey) throw fail('captcha');
        const api = await waitFor(() => window.grecaptcha && window.grecaptcha.enterprise, 5000);
        return new Promise((resolve, reject) => {
            const timer = setTimeout(() => reject(fail('captcha')), 10000);
            api.ready(() => {
                api.execute(siteKey, { action: 'submit' }).then(
                    (token) => {
                        clearTimeout(timer);
                        resolve(token);
                    },
                    () => {
                        clearTimeout(timer);
                        reject(fail('captcha'));
                    }
                );
            });
        });
    }

    // 400/413: the request itself was refused. 429: API throttling. 503: reCAPTCHA or SES is
    // down (the Lambda reports it separately so it isn't shown as a validation problem).
    function statusCode(status) {
        if (status === 429) return 'busy';
        if (status === 503) return 'unavailable';
        if (status >= 400 && status < 500) return 'rejected';
        return 'failed';
    }

    async function postJson(url, payload, timeoutMs) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeoutMs);
        try {
            return await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
                signal: controller.signal,
            });
        } catch (error) {
            throw fail(error && error.name === 'AbortError' ? 'timeout' : 'failed');
        } finally {
            clearTimeout(timer);
        }
    }

    if (form) {
        const status = form.querySelector('.form-status');
        const submitButton = form.querySelector('button[type="submit"]');
        const endpoint = form.getAttribute('action');
        const siteKey = form.dataset.recaptchaKey;
        const mailLink = document.querySelector('#contact_me a[href^="mailto:"]');
        let sending = false;

        const setStatus = (kind, message, withFallback = false) => {
            status.className = `form-status is-${kind}`;
            status.replaceChildren(document.createTextNode(message));
            if (withFallback && mailLink) {
                const link = document.createElement('a');
                link.href = mailLink.getAttribute('href');
                link.textContent = mailLink.getAttribute('href').replace(/^mailto:/, '');
                status.append(` ${STRINGS.fallback} `, link, '.');
            }
        };

        const setBusy = (busy) => {
            sending = busy;
            submitButton.disabled = busy;
            submitButton.classList.toggle('is-loading', busy);
            form.setAttribute('aria-busy', String(busy));
        };

        // The submit event only fires after the browser's built-in validation passes
        form.addEventListener('submit', async (event) => {
            event.preventDefault();
            if (sending) return;

            const values = {};
            FIELDS.forEach((name) => {
                values[name] = (form.elements[name].value || '').trim();
            });

            // `required` accepts whitespace-only input; the Lambda doesn't
            const firstEmpty = FIELDS.find((name) => !values[name]);
            if (firstEmpty) {
                setStatus('error', STRINGS.missing);
                form.elements[firstEmpty].focus();
                return;
            }

            setBusy(true);
            setStatus('info', STRINGS.sending);

            try {
                const token = await getRecaptchaToken(siteKey);
                const response = await postJson(endpoint, { ...values, 'g-recaptcha-response': token }, 15000);
                if (!response.ok) throw fail(statusCode(response.status));
                form.reset();
                setStatus('success', STRINGS.success);
            } catch (error) {
                const code = error && STRINGS[error.code] ? error.code : 'failed';
                setStatus('error', STRINGS[code], true);
            } finally {
                setBusy(false);
            }
        });
    }

    /* ------------------------------------------------------------------ *
     * Back-to-top button and footer year
     * ------------------------------------------------------------------ */
    const scrollTopButton = document.getElementById('scrollTop');
    if (scrollTopButton) {
        let ticking = false;
        const update = () => {
            scrollTopButton.classList.toggle('visible', window.scrollY > 400);
            ticking = false;
        };
        window.addEventListener('scroll', () => {
            if (!ticking) {
                ticking = true;
                requestAnimationFrame(update);
            }
        }, { passive: true });
        scrollTopButton.addEventListener('click', () => {
            window.scrollTo({ top: 0, behavior: reduceMotion.matches ? 'auto' : 'smooth' });
            // The button hides at the top, so move focus somewhere sensible
            const section = currentId && document.getElementById(currentId);
            if (section) section.focus({ preventScroll: true });
        });
        update();
    }

    document.querySelectorAll('[data-year]').forEach((element) => {
        element.textContent = String(new Date().getFullYear());
    });

    /* ------------------------------------------------------------------ *
     * Initial section from the URL
     * ------------------------------------------------------------------ */
    showSection(sectionFromHash(location.hash) || DEFAULT_SECTION);
})();
