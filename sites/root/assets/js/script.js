let navLinks = document.querySelectorAll('a.inner-link');

navLinks.forEach((item) => {
    item.addEventListener('click', function (e) {
        e.preventDefault();
        const targetId = item.getAttribute('href');
        const targetSection = document.querySelector(`main > section${targetId}`);

        if (!targetSection) return;

        // 1. Update Navigation UI
        const currentActiveLink = document.querySelector('nav ul li a.active');
        if (currentActiveLink) currentActiveLink.classList.remove('active');
        item.classList.add('active');

        // 2. Hide ALL sections and remove active class
        document.querySelectorAll('main > section').forEach(section => {
            section.classList.remove('active');
            section.style.display = 'none';
        });

        // 3. Show target section
        targetSection.classList.add('active');
        targetSection.style.display = 'block';

        // 4. Reset scroll to top
        window.scrollTo({ top: 0, behavior: 'instant' });

        // 5. Fix: Force Shuffle layout update when switching to Portfolio section
        if (targetId === '#my_work' && typeof shuffleInstance !== 'undefined') {
            // Wait for display:block to take effect so DOM can calculate sizes
            requestAnimationFrame(() => {
                setTimeout(() => {
                    shuffleInstance.update();
                    shuffleInstance.layout();
                }, 50);
            });
        }
    });
});

document.querySelector('#sidebar .toggle-sidebar').addEventListener('click', function () {
    document.querySelector('#sidebar').classList.toggle('open');
});

var options = {
    strings: ['Machine Learning Engineer', 'Data Scientist', 'AI Specialist'],
    loop: true,
    typeSpeed: 80,
    backSpeed: 10
};

new Typed('.field h2', options);

const shuffleInstance = new Shuffle(document.querySelector('#my_work .work-items'), {
    itemSelector: '.item',
});

const filterButtons = document.querySelectorAll('#my_work .filters button');
filterButtons.forEach((item) => {
    item.addEventListener('click', workFilter);
});

function workFilter(event) {
    const clickedButton = event.currentTarget;
    const clickedButtonGroup = clickedButton.getAttribute('data-group');
    const activeButton = document.querySelector('#my_work .filters button.active');

    if (activeButton) activeButton.classList.remove('active');
    clickedButton.classList.add("active");

    shuffleInstance.filter(clickedButtonGroup);
}

var workModal = new bootstrap.Modal(document.getElementById('workModal'));
const workElements = document.querySelectorAll("#my_work .work-items .wrap");

workElements.forEach((item) => {
    item.addEventListener('click', function () {
        document.querySelector('#workModal .modal-body img').setAttribute('src', item.getAttribute('data-image'));
        document.querySelector('#workModal .modal-body .title').innerText = item.getAttribute('data-title');
        document.querySelector('#workModal .modal-body .description').innerText = item.getAttribute('data-description');
        document.querySelector('#workModal .modal-body .type .value').innerText = item.getAttribute('data-type');
        document.querySelector('#workModal .modal-body .completed .value').innerText = item.getAttribute('data-completed');
        document.querySelector('#workModal .modal-body .skills .value').innerText = item.getAttribute('data-skills');
        document.querySelector('#workModal .modal-body .project-link a').setAttribute('href', item.getAttribute('data-project-link'));

        workModal.show();
        // focus management: move focus to close button for accessibility
        setTimeout(() => {
            const closeBtn = document.querySelector("#workModal .modal-close-button");
            if (closeBtn) closeBtn.focus();
        }, 200);
    });
});

var workModalElement = document.getElementById('workModal');
workModalElement.addEventListener('show.bs.modal', function (event) {
    document.getElementById('my_work').classList.add('blur');
    document.getElementById('sidebar').classList.add('blur');
    // trap focus inside modal
    document.addEventListener('focus', trapFocus, true);
});

workModalElement.addEventListener('hide.bs.modal', function (event) {
    document.getElementById('my_work').classList.remove('blur');
    document.getElementById('sidebar').classList.remove('blur');
    document.removeEventListener('focus', trapFocus, true);
});

let contactFromItems = document.querySelectorAll('#contact_me .form input, #contact_me .form textarea');

contactFromItems.forEach((item) => {
    item.addEventListener('focus', function () {
        item.parentElement.classList.add('focus');
    });

    item.addEventListener('blur', function () {
        if (!item.value) {
            item.parentElement.classList.remove('focus');
        }
    });
});

function onSubmit(e) {
    e.preventDefault();

    grecaptcha.ready(function () {
        grecaptcha.execute('6LdBoB8qAAAAAHqcXpmWKGEV2CrpMJGJrHjUv1PU', { action: 'submit' }).then(function (token) {
            const data = {
                name: document.getElementById("name").value,
                email: document.getElementById("email").value,
                subject: document.getElementById("subject").value,
                message: document.getElementById("message").value,
                'g-recaptcha-response': token
            };

            fetch("https://w8e7rbc1of.execute-api.us-east-1.amazonaws.com/prod/sendemail", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify(data)
            })
                .then(response => response.json())
                .then(data => {
                    console.log("Response data:", data);
                    document.querySelector('.form').innerHTML = `
                        <div class="text-center form-success">
                            <h3>Thank you for your message!</h3>
                            <p>Your message has been sent successfully. A response will be provided shortly.</p>
                        </div>
                    `;
                })
                .catch(error => {
                    console.error("Error:", error);
                    document.querySelector('.form').innerHTML = `
                        <div class="text-center form-error">
                            <h3>An error occurred!</h3>
                            <p>There was an issue sending your message. Please try again later.</p>
                        </div>
                    `;
                });
        });
    });
}

function trapFocus(e) {
    const modal = document.getElementById('workModal');
    if (!modal) return;
    if (modal.contains(e.target)) return;
    const focusable = modal.querySelectorAll('button, [href], input, textarea, select, [tabindex]:not([tabindex="-1"])');
    if (focusable.length) { focusable[0].focus(); e.preventDefault(); }
}
