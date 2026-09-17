(function () {
    'use strict';
    function initDashboardMobileNav() {
        var dashboard = document.querySelector('.admin-dashboard, .vendor-dashboard');
        var sidebar = dashboard ? dashboard.querySelector('.sidebar') : null;
        var topbar = document.querySelector('.admin-topbar, .vendor-topbar');
        if (!dashboard || !sidebar || !topbar || document.getElementById('dashboardMobileMenu')) return;

        var menu = document.createElement('button');
        menu.id = 'dashboardMobileMenu';
        menu.className = 'dashboard-mobile-menu';
        menu.type = 'button';
        menu.setAttribute('aria-label', 'فتح قائمة لوحة التحكم');
        menu.setAttribute('aria-expanded', 'false');
        menu.innerHTML = '<i class="fas fa-bars"></i>';
        topbar.insertBefore(menu, topbar.firstChild);

        var overlay = document.createElement('div');
        overlay.className = 'dashboard-sidebar-overlay';
        overlay.id = 'dashboardSidebarOverlay';
        document.body.appendChild(overlay);

        function closeMenu() {
            sidebar.classList.remove('mobile-open');
            overlay.classList.remove('active');
            menu.setAttribute('aria-expanded', 'false');
            menu.innerHTML = '<i class="fas fa-bars"></i>';
            document.body.style.overflow = '';
        }
        function openMenu() {
            sidebar.classList.add('mobile-open');
            overlay.classList.add('active');
            menu.setAttribute('aria-expanded', 'true');
            menu.innerHTML = '<i class="fas fa-times"></i>';
            document.body.style.overflow = 'hidden';
        }
        menu.addEventListener('click', function () {
            sidebar.classList.contains('mobile-open') ? closeMenu() : openMenu();
        });
        overlay.addEventListener('click', closeMenu);
        sidebar.querySelectorAll('.nav-item').forEach(function (item) {
            item.addEventListener('click', function () {
                if (window.innerWidth <= 768) closeMenu();
            });
        });
        window.addEventListener('resize', function () {
            if (window.innerWidth > 768) closeMenu();
        });
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') closeMenu();
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initDashboardMobileNav);
    } else {
        initDashboardMobileNav();
    }
})();
