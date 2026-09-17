// ========== متغيرات عامة ==========
let cart = JSON.parse(localStorage.getItem('cart')) || [];
let wishlist = JSON.parse(localStorage.getItem('wishlist')) || [];
let currentFilter = 'all';
let currentSubFilter = 'all';
let products = [];
let currentUser = null;
let currentVendor = null;
let isAdminUser = localStorage.getItem('isAdmin') === 'true';

// ========== تعريف التصنيفات الفرعية ==========
const subCategories = {
    'electronics': [
        { id: 'phones', name: 'هواتف ذكية', icon: 'fa-mobile-screen' },
        { id: 'tablets', name: 'آيباد وتابلت', icon: 'fa-tablet-screen-button' },
        { id: 'computers', name: 'أجهزة كمبيوتر', icon: 'fa-desktop' },
        { id: 'laptops', name: 'لابتوبات', icon: 'fa-laptop' },
        { id: 'headphones', name: 'سماعات', icon: 'fa-headphones' },
        { id: 'cameras', name: 'كاميرات', icon: 'fa-camera' },
        { id: 'tv', name: 'شاشات وتلفزيون', icon: 'fa-tv' },
        { id: 'gaming', name: 'أجهزة ألعاب', icon: 'fa-gamepad' }
    ],
    'sports': [
        { id: 'equipment', name: 'أدوات رياضية', icon: 'fa-dumbbell' },
        { id: 'clothing', name: 'ملابس رياضية', icon: 'fa-shirt' },
        { id: 'shoes', name: 'أحذية رياضية', icon: 'fa-shoe-prints' },
        { id: 'nutrition', name: 'مكملات غذائية', icon: 'fa-apple-whole' },
        { id: 'yoga', name: 'يوغا ولياقة', icon: 'fa-spa' }
    ],
    'accessories': [
        { id: 'beauty', name: 'أدوات تجميل', icon: 'fa-spray-can-sparkles' },
        { id: 'perfumes', name: 'عطور', icon: 'fa-wine-bottle' },
        { id: 'watches', name: 'ساعات', icon: 'fa-clock' },
        { id: 'glasses', name: 'نظارات', icon: 'fa-glasses' },
        { id: 'bags', name: 'حقائب', icon: 'fa-bag-shopping' },
        { id: 'phone-accessories', name: 'إكسسوارات هواتف', icon: 'fa-mobile-screen-button' },
        { id: 'jewelry', name: 'مجوهرات', icon: 'fa-gem' }
    ],
    'furniture-office': [
        { id: 'desks', name: 'مكاتب', icon: 'fa-table' },
        { id: 'chairs', name: 'كراسي', icon: 'fa-chair' },
        { id: 'shelves', name: 'رفوف وخزائن', icon: 'fa-box-archive' },
        { id: 'stationery', name: 'أدوات كتابية', icon: 'fa-pen' },
        { id: 'printers', name: 'طابعات', icon: 'fa-print' }
    ],
    'furnishings': [
        { id: 'carpets', name: 'سجاد', icon: 'fa-rug' },
        { id: 'curtains', name: 'ستائر', icon: 'fa-bars-staggered' },
        { id: 'bedding', name: 'أغطية ومفارش', icon: 'fa-bed' },
        { id: 'cushions', name: 'مخدات وديكور', icon: 'fa-couch' },
        { id: 'lighting', name: 'إنارة', icon: 'fa-lightbulb' }
    ],
    'home-appliances': [
        { id: 'fridge', name: 'ثلاجات', icon: 'fa-box' },
        { id: 'washer', name: 'غسالات', icon: 'fa-soap' },
        { id: 'juicer', name: 'عصارات', icon: 'fa-blender' },
        { id: 'ac', name: 'مكيفات', icon: 'fa-fan' },
        { id: 'home-tv', name: 'شاشات منزلية', icon: 'fa-tv' },
        { id: 'microwave', name: 'أفران ومايكروويف', icon: 'fa-fire-burner' },
        { id: 'vacuum', name: 'مكنسات', icon: 'fa-broom' }
    ]
};

// ========== عناصر DOM ==========
const productsGrid = document.getElementById('productsGrid');
const cartBtn = document.getElementById('cartBtn');
const cartSidebar = document.getElementById('cartSidebar');
const cartOverlay = document.getElementById('cartOverlay');
const closeCart = document.getElementById('closeCart');
const cartItems = document.getElementById('cartItems');
const cartCount = document.getElementById('cartCount');
const cartTotal = document.getElementById('cartTotal');
const cartFooter = document.getElementById('cartFooter');
const themeToggle = document.getElementById('themeToggle');
const searchInput = document.getElementById('searchInput');
const toast = document.getElementById('toast');
const toastMessage = document.getElementById('toastMessage');
const checkoutBtn = document.getElementById('checkoutBtn');
const wishlistBtn = document.getElementById('wishlistBtn');
const wishlistBtnHeader = document.getElementById('wishlistBtnHeader');
const wishlistSidebar = document.getElementById('wishlistSidebar');
const closeWishlist = document.getElementById('closeWishlist');
const wishlistItems = document.getElementById('wishlistItems');
const wishlistCount = document.getElementById('wishlistCount');
const wishlistCountHeader = document.getElementById('wishlistCountHeader');
const scrollTop = document.getElementById('scrollTop');
const loader = document.getElementById('loader');
const accountLink = document.getElementById('accountLink');
const accountText = document.getElementById('accountText');
const adminLink = document.getElementById('adminLink');
const logoutLink = document.getElementById('logoutLink');

// ========== شاشة التحميل ==========
window.addEventListener('load', () => {
    setTimeout(() => {
        if (loader) {
            loader.classList.add('hidden');
            setTimeout(() => loader.remove(), 500);
        }
    }, 1500);
});

// ========== تحميل المنتجات من Supabase ==========
async function loadProductsFromDatabase() {
    try {
        if (typeof supabaseClient === 'undefined') {
            products = [];
            renderProducts();
            updateCategoryCounts();
            return;
        }

        const { data, error } = await supabaseClient
            .from('products')
            .select('*, product_images(*), vendors(store_name)')
            .eq('is_active', true)
            .order('created_at', { ascending: false });

        if (error) throw error;

        if (data && data.length > 0) {
            products = data.map(p => ({
                id: p.id,
                name: p.name,
                category: p.category,
                subCategory: p.sub_category || '',
                price: parseFloat(p.price),
                oldPrice: p.old_price ? parseFloat(p.old_price) : null,
                icon: p.icon || 'fa-box',
                rating: parseFloat(p.rating) || 0,
                reviews: p.reviews_count || 0,
                badge: p.badge || '',
                description: p.description || '',
                features: p.features || [],
                specs: p.specs || {},
                mainImage: p.main_image || '',
                images: p.product_images || [],
                shopNote: p.shop_note || '',
                offerType: p.offer_type || '',
                offerDuration: p.offer_duration || 0,
                offerEndDate: p.offer_end_date || null,
                vendorId: p.vendor_id,
                vendorName: p.vendors?.store_name || '',
                isVendorProduct: p.is_vendor_product || false
            }));
        } else {
            products = [];
        }

        renderProducts();
        renderOffers();
        updateCategoryCounts();
        updateStats();
        
    } catch (error) {
        console.error('Error loading products:', error);
        products = [];
        renderProducts();
        updateCategoryCounts();
    }
}

// ========== تحديث إحصائيات التصنيفات ==========
function updateCategoryCounts() {
    const categories = ['websites', 'mobile-apps', 'ai-tools', 'tech-services', 'electronics', 'sports', 'accessories', 'furniture-office', 'furnishings', 'home-appliances'];
    
    categories.forEach(cat => {
        const count = products.filter(p => p.category === cat).length;
        const element = document.getElementById(`count-${cat}`);
        if (element) {
            element.textContent = `${count} منتج`;
        }
    });
}

// ========== تحديث الإحصائيات الرئيسية ==========
async function updateStats() {
    try {
        const { count: customerCount } = await supabaseClient.from('users').select('id', { count: 'exact', head: true });
        document.getElementById('statCustomers').textContent = customerCount;
        document.getElementById('statProducts').textContent = products.length;
        
        const { data: projects } = await supabaseClient.from('custom_requests').select('id').eq('status', 'completed');
        const projectCount = projects?.length || 0;
        document.getElementById('statProjects').textContent = projectCount;
        
    } catch (error) {
        console.error('Error updating stats:', error);
    }
}

// ========== عرض التصنيفات الفرعية ==========
function showSubCategories(category) {
    const container = document.getElementById('subCategoriesContainer');
    
    if (subCategories[category] && subCategories[category].length > 0) {
        container.style.display = 'flex';
        container.innerHTML = `
            <button class="sub-category-btn active" data-sub="all" onclick="filterBySubCategory('all', this)">الكل</button>
            ${subCategories[category].map(sub => `
                <button class="sub-category-btn" data-sub="${sub.id}" onclick="filterBySubCategory('${sub.id}', this)">
                    <i class="fas ${sub.icon}"></i> ${sub.name}
                </button>
            `).join('')}
        `;
    } else {
        container.style.display = 'none';
        container.innerHTML = '';
    }
    
    currentSubFilter = 'all';
}

function filterBySubCategory(subId, button) {
    currentSubFilter = subId;
    
    document.querySelectorAll('.sub-category-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    button.classList.add('active');
    
    renderProducts(currentFilter, searchInput.value);
}

// ========== عرض المنتجات ==========
function renderProducts(filter = 'all', searchTerm = '') {
    if (!productsGrid) return;
    
    let filtered = products;

    if (filter !== 'all') {
        filtered = filtered.filter(p => p.category === filter);
    }

    if (currentSubFilter !== 'all') {
        filtered = filtered.filter(p => p.subCategory === currentSubFilter);
    }

    if (searchTerm) {
        filtered = filtered.filter(p =>
            p.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
            getCategoryName(p.category).includes(searchTerm)
        );
    }

    if (filtered.length === 0) {
        productsGrid.innerHTML = `
            <div style="grid-column: 1/-1; text-align: center; padding: 60px 20px; color: var(--text-light);">
                <i class="fas fa-search" style="font-size: 3rem; margin-bottom: 15px; opacity: 0.3;"></i>
                <h3>لا توجد منتجات مطابقة</h3>
                <p>جرب البحث بكلمات مختلفة أو اختر تصنيف آخر</p>
            </div>
        `;
        return;
    }

    productsGrid.innerHTML = filtered.map(product => {
        const isInWishlist = wishlist.some(item => item.id === product.id);
        const imageHtml = product.mainImage ? 
            `<img src="${product.mainImage}" style="width:100%;height:100%;object-fit:cover;" alt="${product.name}">` :
            `<i class="fas ${product.icon}"></i>`;
        
        const shopNoteHtml = isAdminUser && product.shopNote ? 
            `<div style="position: absolute; top: 12px; left: 12px; background: var(--warning); color: white; padding: 5px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 700; z-index: 3;">
                <i class="fas fa-store"></i> ${product.shopNote}
            </div>` : '';
        
        const offerBadge = product.offerType === 'offer' ? 
            `<div style="position: absolute; bottom: 12px; left: 12px; background: var(--danger); color: white; padding: 5px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 700; z-index: 3;">
                <i class="fas fa-fire"></i> عرض
            </div>` : '';
        
        const vendorBadge = product.vendorName ? 
            `<div style="position: absolute; top: 12px; right: 12px; background: var(--primary); color: white; padding: 5px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 700; z-index: 3;">
                <i class="fas fa-store"></i> ${product.vendorName}
            </div>` : '';
        
        return `
        <div class="product-card" data-id="${product.id}">
            <div class="product-image">
                ${product.badge ? `<span class="product-badge">${product.badge}</span>` : ''}
                ${shopNoteHtml}
                ${offerBadge}
                ${vendorBadge}
                <button class="wishlist-btn ${isInWishlist ? 'active' : ''}" onclick="event.stopPropagation(); toggleWishlist('${product.id}')">
                    <i class="${isInWishlist ? 'fas' : 'far'} fa-heart"></i>
                </button>
                ${imageHtml}
                <button class="quick-view-btn" onclick="event.stopPropagation(); window.location.href='product-details.html?id=${product.id}'">
                    <i class="fas fa-eye"></i> معاينة سريعة
                </button>
            </div>
            <div class="product-info">
                <div class="product-category">${getCategoryName(product.category)}</div>
                <h3>${product.name}</h3>
                <div class="product-rating">
                    ${product.reviews > 0 ? '★'.repeat(Math.floor(product.rating)) + '☆'.repeat(5 - Math.floor(product.rating)) : '☆☆☆☆☆'}
                    <span>(${product.reviews} تقييم)</span>
                </div>
                <div class="product-footer">
                    <div class="product-price">
                        <span class="price-current">${formatPrice(product.price)}</span>
                        ${product.oldPrice ? `<span class="price-old">${formatPrice(product.oldPrice)}</span>` : ''}
                    </div>
                    <button class="add-to-cart" onclick="event.stopPropagation(); addToCart('${product.id}')" title="أضف للسلة">
                        <i class="fas fa-plus"></i>
                    </button>
                </div>
            </div>
        </div>
    `}).join('');

    document.querySelectorAll('.product-card').forEach(card => {
        card.addEventListener('click', () => {
            window.location.href = `product-details.html?id=${card.dataset.id}`;
        });
    });
}

// ========== عرض العروض ==========
function renderOffers() {
    const offersGrid = document.getElementById('offersGrid');
    if (!offersGrid) return;
    
    const now = new Date();
    const offers = products.filter(p => {
        if (p.offerType !== 'offer') return false;
        if (p.offerEndDate) {
            return new Date(p.offerEndDate) > now;
        }
        return true;
    });
    
    if (offers.length === 0) {
        offersGrid.innerHTML = `
            <div style="grid-column: 1/-1; text-align: center; padding: 60px 20px; color: var(--text-light);">
                <i class="fas fa-tag" style="font-size: 3rem; margin-bottom: 15px; opacity: 0.3;"></i>
                <h3>لا توجد عروض حالياً</h3>
                <p>تابعنا لمعرفة أحدث العروض</p>
            </div>
        `;
        return;
    }
    
    offersGrid.innerHTML = offers.map(product => {
        const imageHtml = product.mainImage ? 
            `<img src="${product.mainImage}" style="width:100%;height:100%;object-fit:cover;" alt="${product.name}">` :
            `<i class="fas ${product.icon}"></i>`;
        
        let timeLeft = '';
        if (product.offerEndDate) {
            const endDate = new Date(product.offerEndDate);
            const diff = endDate - now;
            const days = Math.floor(diff / (1000 * 60 * 60 * 24));
            const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
            timeLeft = `<div style="color: var(--danger); font-weight: 700; margin-top: 5px;">
                <i class="fas fa-clock"></i> ${days > 0 ? days + ' يوم' : hours + ' ساعة'} متبقية
            </div>`;
        }
        
        return `
        <div class="product-card" data-id="${product.id}">
            <div class="product-image">
                <span class="product-badge" style="background: var(--danger);">🔥 عرض</span>
                ${imageHtml}
            </div>
            <div class="product-info">
                <div class="product-category">${getCategoryName(product.category)}</div>
                <h3>${product.name}</h3>
                ${timeLeft}
                <div class="product-footer">
                    <div class="product-price">
                        <span class="price-current">${formatPrice(product.price)}</span>
                        ${product.oldPrice ? `<span class="price-old">${formatPrice(product.oldPrice)}</span>` : ''}
                    </div>
                    <button class="add-to-cart" onclick="event.stopPropagation(); addToCart('${product.id}')">
                        <i class="fas fa-plus"></i>
                    </button>
                </div>
            </div>
        </div>
    `}).join('');
    
    document.querySelectorAll('#offersGrid .product-card').forEach(card => {
        card.addEventListener('click', () => {
            window.location.href = `product-details.html?id=${card.dataset.id}`;
        });
    });
}

function getCategoryName(cat) {
    const names = {
        'websites': 'مواقع إلكترونية',
        'mobile-apps': 'تطبيقات موبايل',
        'ai-tools': 'ذكاء اصطناعي',
        'tech-services': 'خدمات برمجية',
        'electronics': 'إلكترونيات',
        'sports': 'رياضة ولياقة',
        'accessories': 'إكسسوارات',
        'furniture-office': 'الأثاث والمكتبي',
        'furnishings': 'المفروشات',
        'home-appliances': 'الأدوات المنزلية'
    };
    return names[cat] || cat;
}

// ========== فلترة ==========
document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentFilter = btn.dataset.filter;
        showSubCategories(currentFilter);
        renderProducts(currentFilter, searchInput.value);
    });
});

searchInput.addEventListener('input', (e) => {
    renderProducts(currentFilter, e.target.value);
});

// ========== سلة التسوق ==========
function addToCart(productId) {
    const product = products.find(p => p.id === productId);
    if (!product) return;
    
    const existingItem = cart.find(item => item.id === productId);

    if (existingItem) {
        existingItem.quantity++;
    } else {
        cart.push({ ...product, quantity: 1 });
    }

    saveCart();
    updateCartUI();
    showToast(`تمت إضافة "${product.name}" إلى السلة ✓`);
}

function removeFromCart(productId) {
    cart = cart.filter(item => item.id !== productId);
    saveCart();
    updateCartUI();
}

function updateQuantity(productId, change) {
    const item = cart.find(i => i.id === productId);
    if (item) {
        item.quantity += change;
        if (item.quantity <= 0) removeFromCart(productId);
        else { saveCart(); updateCartUI(); }
    }
}

function saveCart() {
    localStorage.setItem('cart', JSON.stringify(cart));
}

function updateCartUI() {
    const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);
    const totalPrice = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);

    cartCount.textContent = totalItems;
    cartTotal.textContent = formatPrice(totalPrice);

    if (cart.length === 0) {
        cartItems.innerHTML = `
            <div class="empty-cart">
                <i class="fas fa-shopping-cart"></i>
                <h3>السلة فارغة</h3>
                <p>ابدأ بإضافة منتجات إلى سلتك</p>
            </div>
        `;
        cartFooter.style.display = 'none';
    } else {
        cartFooter.style.display = 'block';
        cartItems.innerHTML = cart.map(item => `
            <div class="cart-item">
                <div class="cart-item-image"><i class="fas ${item.icon}"></i></div>
                <div class="cart-item-info">
                    <h4>${item.name}</h4>
                    <div class="price">${formatPrice(item.price)}</div>
                    <div class="quantity-controls">
                        <button onclick="updateQuantity('${item.id}', -1)">-</button>
                        <span>${item.quantity}</span>
                        <button onclick="updateQuantity('${item.id}', 1)">+</button>
                    </div>
                </div>
                <button class="remove-item" onclick="removeFromCart('${item.id}')">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        `).join('');
    }
}

cartBtn.addEventListener('click', () => {
    cartSidebar.classList.add('active');
    cartOverlay.classList.add('active');
});

function closeCartSidebar() {
    cartSidebar.classList.remove('active');
    cartOverlay.classList.remove('active');
}

closeCart.addEventListener('click', closeCartSidebar);
cartOverlay.addEventListener('click', () => {
    closeCartSidebar();
    closeWishlistSidebar();
});

checkoutBtn.addEventListener('click', async () => {
    if (cart.length === 0) {
        showToast('السلة فارغة!');
        return;
    }
    
    const { data: { user } } = await supabaseClient.auth.getUser();
    
    if (!user || user.is_anonymous) {
        showToast('أنشئ حساباً لإتمام الشراء');
        const authModal = document.getElementById('authModal');
        if (authModal) {
            authModal.classList.add('active');
            const registerTab = document.querySelector('.auth-tab[data-tab="register"]');
            if (registerTab) registerTab.click();
        }
        return;
    }
    
    window.location.href = 'checkout.html';
});

// ========== المفضلة ==========
function toggleWishlist(productId) {
    const product = products.find(p => p.id === productId);
    if (!product) return;
    
    const index = wishlist.findIndex(item => item.id === productId);

    if (index > -1) {
        wishlist.splice(index, 1);
        showToast(`تمت إزالة "${product.name}" من المفضلة`);
    } else {
        wishlist.push(product);
        showToast(`تمت إضافة "${product.name}" إلى المفضلة ❤️`);
    }

    localStorage.setItem('wishlist', JSON.stringify(wishlist));
    updateWishlistUI();
    renderProducts(currentFilter, searchInput.value);
}

function updateWishlistUI() {
    const count = wishlist.length;
    wishlistCount.textContent = count;
    wishlistCountHeader.textContent = count;

    if (count === 0) {
        wishlistItems.innerHTML = `
            <div class="empty-cart">
                <i class="fas fa-heart"></i>
                <h3>المفضلة فارغة</h3>
                <p>أضف منتجاتك المفضلة هنا</p>
            </div>
        `;
    } else {
        wishlistItems.innerHTML = wishlist.map(item => `
            <div class="cart-item">
                <div class="cart-item-image"><i class="fas ${item.icon}"></i></div>
                <div class="cart-item-info">
                    <h4>${item.name}</h4>
                    <div class="price">${formatPrice(item.price)}</div>
                    <button class="btn btn-primary" style="padding: 6px 12px; font-size: 0.8rem; margin-top: 8px;" onclick="addToCart('${item.id}'); toggleWishlist('${item.id}');">
                        <i class="fas fa-cart-plus"></i> أضف للسلة
                    </button>
                </div>
                <button class="remove-item" onclick="toggleWishlist('${item.id}')">
                    <i class="fas fa-times"></i>
                </button>
            </div>
        `).join('');
    }
}

function openWishlistSidebar() {
    wishlistSidebar.classList.add('active');
    cartOverlay.classList.add('active');
}

function closeWishlistSidebar() {
    wishlistSidebar.classList.remove('active');
    cartOverlay.classList.remove('active');
}

if (wishlistBtn) wishlistBtn.addEventListener('click', (e) => { e.preventDefault(); openWishlistSidebar(); });
if (wishlistBtnHeader) wishlistBtnHeader.addEventListener('click', openWishlistSidebar);
if (closeWishlist) closeWishlist.addEventListener('click', closeWishlistSidebar);


// ========== واجهة تطبيق الهاتف ==========
const mobileMenuBtn = document.getElementById('mobileMenuBtn');
const mobileAppDrawer = document.getElementById('mobileAppDrawer');
const mobileAppOverlay = document.getElementById('mobileAppOverlay');
const mobileDrawerClose = document.getElementById('mobileDrawerClose');
const mobileBottomCart = document.getElementById('mobileBottomCart');
const mobileBottomWishlist = document.getElementById('mobileBottomWishlist');
const mobileBottomAccount = document.getElementById('mobileBottomAccount');
const mobileBottomCategories = document.getElementById('mobileBottomCategories');
const mobileDrawerAccountBtn = document.getElementById('mobileDrawerAccountBtn');
const mobileDrawerLogoutBtn = document.getElementById('mobileDrawerLogoutBtn');
const mobileDrawerAdminLink = document.getElementById('mobileDrawerAdminLink');

function openMobileDrawer() {
    if (!mobileAppDrawer || !mobileAppOverlay) return;
    mobileAppDrawer.classList.add('active');
    mobileAppOverlay.classList.add('active');
    mobileAppDrawer.setAttribute('aria-hidden', 'false');
    document.body.classList.add('mobile-drawer-open');
}
function closeMobileDrawer() {
    if (!mobileAppDrawer || !mobileAppOverlay) return;
    mobileAppDrawer.classList.remove('active');
    mobileAppOverlay.classList.remove('active');
    mobileAppDrawer.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('mobile-drawer-open');
}
function updateMobileAccountUI() {
    const name = document.getElementById('mobileDrawerAccountName');
    const state = document.getElementById('mobileDrawerAccountState');
    if (!name || !state) return;
    if (!currentUser || currentUser.is_anonymous) {
        name.textContent = 'حسابي';
        state.textContent = 'تسجيل الدخول أو إنشاء حساب';
        if (mobileDrawerLogoutBtn) mobileDrawerLogoutBtn.style.display = 'none';
        if (mobileDrawerAdminLink) mobileDrawerAdminLink.style.display = 'none';
    } else if (isAdminUser) {
        name.textContent = '👑 الأدمن';
        state.textContent = currentUser.email || 'حساب الإدارة';
        if (mobileDrawerLogoutBtn) mobileDrawerLogoutBtn.style.display = 'flex';
        if (mobileDrawerAdminLink) mobileDrawerAdminLink.style.display = 'flex';
    } else {
        name.textContent = currentUser.user_metadata?.full_name || currentUser.email || 'حسابي';
        state.textContent = currentUser.email || 'حساب العميل';
        if (mobileDrawerLogoutBtn) mobileDrawerLogoutBtn.style.display = 'flex';
        if (mobileDrawerAdminLink) mobileDrawerAdminLink.style.display = 'none';
    }
}
function syncMobileCounters() {
    const cartCounter = document.getElementById('mobileBottomCartCount');
    const wishlistCounter = document.getElementById('mobileBottomWishlistCount');
    if (cartCounter) cartCounter.textContent = String(cart.reduce((sum, item) => sum + Number(item.quantity || 0), 0));
    if (wishlistCounter) wishlistCounter.textContent = String(wishlist.length);
    updateMobileAccountUI();
}

if (mobileMenuBtn) mobileMenuBtn.addEventListener('click', openMobileDrawer);
if (mobileDrawerClose) mobileDrawerClose.addEventListener('click', closeMobileDrawer);
if (mobileAppOverlay) mobileAppOverlay.addEventListener('click', closeMobileDrawer);
if (mobileBottomCart) mobileBottomCart.addEventListener('click', () => { closeMobileDrawer(); cartBtn?.click(); });
if (mobileBottomWishlist) mobileBottomWishlist.addEventListener('click', () => { closeMobileDrawer(); wishlistBtnHeader?.click(); });
if (mobileBottomCategories) mobileBottomCategories.addEventListener('click', () => { closeMobileDrawer(); document.getElementById('categories')?.scrollIntoView({behavior:'smooth'}); });
if (mobileBottomAccount) mobileBottomAccount.addEventListener('click', () => { closeMobileDrawer(); accountLink?.click(); });
if (mobileDrawerAccountBtn) mobileDrawerAccountBtn.addEventListener('click', () => { closeMobileDrawer(); accountLink?.click(); });
if (mobileDrawerLogoutBtn) mobileDrawerLogoutBtn.addEventListener('click', () => { closeMobileDrawer(); logoutLink?.click(); });

document.querySelectorAll('.mobile-drawer-nav a[href^="#"]').forEach(link => {
    link.addEventListener('click', () => {
        closeMobileDrawer();
        document.querySelectorAll('.mobile-bottom-item').forEach(item => item.classList.remove('active'));
        const home = document.querySelector('.mobile-bottom-item[href="#home"]');
        if (link.getAttribute('href') === '#home' && home) home.classList.add('active');
    });
});

document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeMobileDrawer(); });

// إبقاء عدادات شريط التطبيق متزامنة مع السلة والمفضلة.
const _originalUpdateCartUI = typeof updateCartUI === 'function' ? updateCartUI : null;
if (_originalUpdateCartUI) {
    const __updateCartUI = updateCartUI;
    updateCartUI = function(...args) {
        const result = __updateCartUI.apply(this, args);
        syncMobileCounters();
        return result;
    };
}
const _originalUpdateWishlistUI = typeof updateWishlistUI === 'function' ? updateWishlistUI : null;
if (_originalUpdateWishlistUI) {
    const __updateWishlistUI = updateWishlistUI;
    updateWishlistUI = function(...args) {
        const result = __updateWishlistUI.apply(this, args);
        syncMobileCounters();
        return result;
    };
}

// ========== الوضع الداكن ==========
const savedTheme = localStorage.getItem('theme') || 'light';
document.documentElement.setAttribute('data-theme', savedTheme);
updateThemeIcon(savedTheme);

themeToggle.addEventListener('click', () => {
    const current = document.documentElement.getAttribute('data-theme');
    const newTheme = current === 'light' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
    updateThemeIcon(newTheme);
});

function updateThemeIcon(theme) {
    const icon = themeToggle.querySelector('i');
    icon.className = theme === 'light' ? 'fas fa-moon' : 'fas fa-sun';
}

// ========== الإشعارات ==========
function showToast(message) {
    toastMessage.textContent = message;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 3000);
}

// ========== التصنيفات ==========
document.querySelectorAll('.category-card').forEach(card => {
    card.addEventListener('click', () => {
        const category = card.dataset.category;
        if (category === 'custom') {
            document.getElementById('custom-order').scrollIntoView({ behavior: 'smooth' });
            return;
        }
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.filter === category);
        });
        currentFilter = category;
        showSubCategories(category);
        renderProducts(category);
        document.getElementById('products').scrollIntoView({ behavior: 'smooth' });
    });
});

// ========== نموذج الطلب المخصص ==========
document.getElementById('customOrderForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData);

    try {
        if (typeof supabaseClient !== 'undefined') {
            const { error } = await supabaseClient
                .from('custom_requests')
                .insert([{
                    customer_name: data.name,
                    customer_email: data.email,
                    customer_phone: data.phone,
                    project_type: data.projectType,
                    budget: data.budget,
                    description: data.description,
                    status: 'pending',
                    created_at: new Date().toISOString()
                }]);

            if (error) throw error;
        }

        alert(`✅ تم استلام طلبك بنجاح!\n\nشكراً ${data.name}،\nسنتواصل معك خلال 24 ساعة على ${data.email}`);
        e.target.reset();
        showToast('تم إرسال طلبك بنجاح! ');

    } catch (error) {
        console.error('Error submitting custom order:', error);
        alert('حدث خطأ أثناء إرسال الطلب.');
    }
});

// ========== ✅ إظهار/إخفاء حقول التاجر ==========
function toggleVendorFields() {
    const userType = document.getElementById('registerUserType').value;
    const vendorFields = document.getElementById('vendorFields');
    
    if (userType === 'vendor') {
        vendorFields.style.display = 'block';
    } else {
        vendorFields.style.display = 'none';
    }
}

// ========== نموذج تسجيل الدخول ==========
const authModal = document.getElementById('authModal');
const supportLink = document.getElementById('supportLink');
const closeAuthModal = document.getElementById('closeAuthModal');
const authTabs = document.querySelectorAll('.auth-tab');
const loginForm = document.getElementById('loginForm');
const registerForm = document.getElementById('registerForm');

if (accountLink) {
    accountLink.addEventListener('click', async (e) => {
        e.preventDefault();
        
        const { data: { user } } = await supabaseClient.auth.getUser();
        
        if (user && !user.is_anonymous) {
            // التحقق من نوع المستخدم
            const { data: userData } = await supabaseClient
                .from('users')
                .select('user_type, vendor_id')
                .eq('id', user.id)
                .single();
            
            if (userData?.role === 'admin' || isAdminUser || user.email === ADMIN_CREDENTIALS.email) {
                // الأدمن - يذهب مباشرة إلى لوحة التحكم
                window.location.href = 'admin.html';
            } else if (userData?.user_type === 'vendor') {
                // تاجر - يذهب للوحة تحكم التاجر
                window.location.href = 'vendor-dashboard.html';
            } else {
                // عميل
                window.location.href = 'profile.html';
            }
        } else {
            if (authModal) {
                authModal.classList.add('active');
                const registerTab = document.querySelector('.auth-tab[data-tab="register"]');
                if (registerTab) registerTab.click();
            }
        }
    });
}

if (closeAuthModal) {
    closeAuthModal.addEventListener('click', () => {
        authModal.classList.remove('active');
    });
}

if (authModal) {
    authModal.addEventListener('click', (e) => {
        if (e.target === authModal) {
            authModal.classList.remove('active');
        }
    });
}

authTabs.forEach(tab => {
    tab.addEventListener('click', () => {
        authTabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        
        const tabName = tab.dataset.tab;
        if (tabName === 'login') {
            loginForm.classList.add('active');
            registerForm.classList.remove('active');
        } else {
            loginForm.classList.remove('active');
            registerForm.classList.add('active');
        }
    });
});

// ========== معالجة تسجيل الدخول ==========
if (loginForm) {
    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('loginEmail').value.trim().toLowerCase();
        const password = document.getElementById('loginPassword').value;
        
        try {
            // تسجيل دخول الأدمن
            if (email === ADMIN_CREDENTIALS.email) {
                if (password !== ADMIN_CREDENTIALS.password) {
                    throw new Error('بيانات الأدمن غير صحيحة.');
                }
                const { data, error } = await supabaseClient.auth.signInWithPassword({
                    email: ADMIN_CREDENTIALS.email,
                    password
                });

                let authenticatedUser = data?.user || null;

                // إذا لم يكن حساب الأدمن موجوداً بعد، يتم إنشاؤه تلقائياً بالبيانات المحددة.
                if (error) {
                    const { data: signUpData, error: signUpError } = await supabaseClient.auth.signUp({
                        email: ADMIN_CREDENTIALS.email,
                        password: ADMIN_CREDENTIALS.password,
                        options: {
                            data: {
                                full_name: 'Admin',
                                role: 'admin',
                                user_type: 'admin'
                            }
                        }
                    });

                    if (signUpError) throw new Error('تعذر تسجيل دخول الأدمن: ' + signUpError.message);
                    authenticatedUser = signUpData?.user || null;

                    if (!signUpData?.session) {
                        const { data: retryLogin, error: retryError } = await supabaseClient.auth.signInWithPassword({
                            email: ADMIN_CREDENTIALS.email,
                            password: ADMIN_CREDENTIALS.password
                        });
                        if (retryError) {
                            throw new Error('تم إنشاء حساب الأدمن، لكن Supabase يطلب تأكيد البريد الإلكتروني. عطّل Confirm email من Authentication > Providers > Email ثم أعد المحاولة.');
                        }
                        authenticatedUser = retryLogin.user;
                    }
                }

                if (!authenticatedUser) throw new Error('لم يتم الحصول على حساب الأدمن.');

                // مزامنة صلاحية الأدمن داخل public.users من خلال دالة آمنة في قاعدة البيانات.
                const { error: ensureAdminError } = await supabaseClient.rpc('ensure_admin_profile');
                if (ensureAdminError) {
                    await supabaseClient.auth.signOut();
                    throw new Error('تعذر اعتماد حساب الأدمن في قاعدة البيانات. نفّذ database_upgrade.sql ثم أعد المحاولة: ' + ensureAdminError.message);
                }

                // التأكد من أن ملف public.users يحمل صلاحية الأدمن.
                const { data: adminProfile, error: adminProfileError } = await supabaseClient
                    .from('users')
                    .select('role,is_banned')
                    .eq('id', authenticatedUser.id)
                    .single();

                if (adminProfileError || adminProfile?.role !== 'admin' || adminProfile?.is_banned) {
                    await supabaseClient.auth.signOut();
                    throw new Error('الحساب موجود، لكن لم يتم اعتماده كأدمن في قاعدة البيانات.');
                }

                localStorage.setItem('isAdmin', 'true');
                isAdminUser = true;
                currentUser = authenticatedUser;
                alert('✅ تم تسجيل دخول الأدمن بنجاح!');

                // طلب المستخدم: بعد تسجيل دخول الأدمن يتم الدخول إلى المتجر تلقائياً.
                authModal.classList.remove('active');
                loginForm.reset();
                window.location.href = 'index.html';
                return;
            }

            // تسجيل دخول المستخدمين العاديين والتجار
            const { data, error } = await supabaseClient.auth.signInWithPassword({
                email: email,
                password: password
            });
            
            if (error) throw error;
            
            // التحقق من تقييد الحساب
            const { data: userData } = await supabaseClient
                .from('users')
                .select('is_banned, ban_reason, user_type, vendor_id')
                .eq('id', data.user.id)
                .single();
            
            if (userData && userData.is_banned) {
                await supabaseClient.auth.signOut();
                alert('❌ لقد تم تقييد حسابك لعدم التزامك بسياسة الخصوصية.\n\nلإلغاء ذلك قم بالتواصل مع فريق الدعم لحل المشكلة.\n\nشكراً لتفهمك.');
                return;
            }
            
            // التحقق من تقييد التاجر
            if (userData?.user_type === 'vendor' && userData.vendor_id) {
                const { data: vendorData } = await supabaseClient
                    .from('vendors')
                    .select('is_restricted, current_invoice, invoice_limit')
                    .eq('id', userData.vendor_id)
                    .single();
                
                if (vendorData?.is_restricted) {
                    alert(`⚠️ حسابك كتاجر مقيد حالياً!\n\nالفاتورة الحالية: $${vendorData.current_invoice}\nالحد المسموح: $${vendorData.invoice_limit}\n\nيرجى تسديد الفاتورة مع الإدارة لاستعادة صلاحياتك.`);
                }
            }
            
            alert('✅ تم تسجيل الدخول بنجاح!\n\nمرحباً ' + (data.user.user_metadata?.full_name || data.user.email));
            authModal.classList.remove('active');
            loginForm.reset();
            setTimeout(() => location.reload(), 1000);
            
        } catch (error) {
            console.error('Login error:', error);
            alert('❌ فشل تسجيل الدخول!\n\n' + error.message);
        }
    });
}

// ========== ✅ معالجة إنشاء حساب جديد (مع دعم التجار) ==========
if (registerForm) {
    registerForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const userType = document.getElementById('registerUserType').value;
        const name = document.getElementById('registerName').value.trim();
        const email = document.getElementById('registerEmail').value.trim().toLowerCase();
        const phone = document.getElementById('registerPhone').value.trim();
        const password = document.getElementById('registerPassword').value;
        
        try {
            if (email === ADMIN_CREDENTIALS.email) {
                throw new Error('هذا البريد محجوز للأدمن. استخدم بريد آخر.');
            }

            const storeName = userType === 'vendor' ? document.getElementById('vendorStoreName').value.trim() : '';
            const vendorAddress = userType === 'vendor' ? document.getElementById('vendorAddress').value.trim() : '';
            if (userType === 'vendor' && !storeName) {
                throw new Error('يرجى إدخال اسم المتجر');
            }
            
            // 1. إنشاء حساب في Supabase Auth
            const { data: authData, error: authError } = await supabaseClient.auth.signUp({
                email: email,
                password: password,
                options: {
                    data: { 
                        full_name: name, 
                        phone: phone,
                        user_type: userType,
                        role: userType === 'vendor' ? 'vendor' : 'customer'
                    }
                }
            });
            
            if (authError) throw authError;
            if (!authData.user) throw new Error('لم يتم إنشاء الحساب');
            
            // 2. تحديث ملف المستخدم الذي ينشئه Trigger قاعدة البيانات تلقائياً
            let activeUser = authData.user;
            let activeSession = authData.session;
            
            if (!activeSession) {
                const { data: loginData, error: loginError } = await supabaseClient.auth.signInWithPassword({
                    email: email,
                    password: password
                });
                
                if (loginError) {
                    throw new Error('تم إنشاء الحساب بنجاح، لكن يلزم تأكيد البريد الإلكتروني من Supabase قبل تسجيل الدخول تلقائياً. بعد التأكيد استخدم نفس البريد وكلمة المرور.');
                }
                
                activeUser = loginData.user;
                activeSession = loginData.session;
            }
            
            const { error: userError } = await supabaseClient
                .from('users')
                .upsert([{
                    id: activeUser.id,
                    email: email,
                    full_name: name,
                    phone: phone,
                    user_type: userType,
                    role: userType === 'vendor' ? 'vendor' : 'customer'
                }], { onConflict: 'id' });
            
            if (userError) throw userError;
            
            // 3. إذا كان تاجر، إنشاء سجل في جدول vendors
            let vendorId = null;
            if (userType === 'vendor') {
                const { data: vendorData, error: vendorError } = await supabaseClient
                    .from('vendors')
                    .insert([{
                        user_id: activeUser.id,
                        store_name: storeName,
                        store_description: '',
                        phone: phone,
                        address: vendorAddress,
                        commission_rate: 3.00,
                        current_invoice: 0,
                        invoice_limit: 100.00,
                        is_restricted: false,
                        total_earned: 0
                    }])
                    .select()
                    .single();
                
                if (vendorError) {
                    console.error('Vendor insert error:', vendorError);
                } else {
                    vendorId = vendorData.id;
                    
                    // تحديث جدول users بـ vendor_id
                    await supabaseClient
                        .from('users')
                        .update({ vendor_id: vendorId })
                        .eq('id', activeUser.id);
                }
            }
            
            currentUser = activeUser;
            accountText.textContent = activeUser.user_metadata?.full_name || name || 'حسابي';
            authModal.classList.remove('active');
            registerForm.reset();
            document.getElementById('vendorFields').style.display = 'none';
            alert(`✅ تم إنشاء الحساب وتسجيل الدخول تلقائياً بنجاح!\n\nمرحباً ${activeUser.user_metadata?.full_name || name}`);
            setTimeout(() => location.reload(), 300);
            
        } catch (error) {
            console.error('Register error:', error);
            alert('❌ فشل إنشاء الحساب!\n\n' + error.message);
        }
    });
}

if (supportLink) {
    supportLink.addEventListener('click', (e) => {
        e.preventDefault();
        const contactSection = document.getElementById('contact');
        if (contactSection) {
            contactSection.scrollIntoView({ behavior: 'smooth' });
        }
    });
}

// ========== زر العودة للأعلى ==========
window.addEventListener('scroll', () => {
    scrollTop.classList.toggle('show', window.scrollY > 500);
});

scrollTop.addEventListener('click', () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
});

// ========== التمرير النشط ==========
window.addEventListener('scroll', () => {
    const sections = document.querySelectorAll('section[id]');
    const scrollPos = window.scrollY + 150;

    sections.forEach(section => {
        const top = section.offsetTop;
        const height = section.offsetHeight;
        const id = section.getAttribute('id');
        const link = document.querySelector(`.nav-menu a[href="#${id}"]`);

        if (link && scrollPos >= top && scrollPos < top + height) {
            document.querySelectorAll('.nav-menu a').forEach(a => a.classList.remove('active'));
            link.classList.add('active');
        }
    });
});

// ========== إنشاء جلسة زائر تلقائياً عند أول زيارة ==========
async function ensureVisitorSession() {
    try {
        const { data: { session } } = await supabaseClient.auth.getSession();
        if (session?.user) return session.user;

        const { data, error } = await supabaseClient.auth.signInAnonymously({
            options: { data: { full_name: 'زائر', user_type: 'customer', role: 'customer' } }
        });

        if (error) {
            console.warn('Anonymous sign-in is disabled or unavailable:', error.message);
            return null;
        }
        return data.user || null;
    } catch (error) {
        console.warn('Visitor session error:', error);
        return null;
    }
}

// ========== تسجيل الخروج من المتجر ==========
if (logoutLink) {
    logoutLink.addEventListener('click', async (e) => {
        e.preventDefault();
        try {
            await supabaseClient.auth.signOut();
        } finally {
            localStorage.removeItem('isAdmin');
            currentUser = null;
            isAdminUser = false;
            window.location.reload();
        }
    });
}

// ========== التهيئة ==========
document.addEventListener('DOMContentLoaded', async () => {
    loadProductsFromDatabase();
    updateCartUI();
    updateWishlistUI();

    let user = null;
    try {
        const { data: { session } } = await supabaseClient.auth.getSession();
        user = session?.user || null;
    } catch (error) {
        console.warn('Session check failed:', error);
    }

    // إذا لم توجد جلسة دائمة، أنشئ جلسة زائر تلقائياً للمتصفح.
    if (!user) {
        user = await ensureVisitorSession();
    }

    if (!user) { syncMobileCounters(); return; }

    currentUser = user;
    syncMobileCounters();

    if (user.is_anonymous) {
        accountText.textContent = 'إنشاء حساب';
        syncMobileCounters();
        if (logoutLink) logoutLink.style.display = 'none';
        if (adminLink) adminLink.style.display = 'none';
        return;
    }

    // أي حساب دائم يظهر له زر تسجيل الخروج.
    if (logoutLink) logoutLink.style.display = 'inline-block';

    if (user.email?.toLowerCase() === ADMIN_CREDENTIALS.email) {
        const { error: ensureAdminError } = await supabaseClient.rpc('ensure_admin_profile');
        if (ensureAdminError) console.warn('Admin profile sync failed:', ensureAdminError.message);
    }

    const { data: userData, error: userDataError } = await supabaseClient
        .from('users')
        .select('role,user_type,vendor_id,is_banned,ban_reason')
        .eq('id', user.id)
        .single();

    if (userDataError) {
        console.warn('User profile lookup failed:', userDataError.message);
    }

    if (userData?.is_banned) {
        await supabaseClient.auth.signOut();
        localStorage.removeItem('isAdmin');
        alert('❌ تم تقييد هذا الحساب.');
        window.location.reload();
        return;
    }

    isAdminUser = userData?.role === 'admin' || user.email === ADMIN_CREDENTIALS.email;

    if (isAdminUser) {
        localStorage.setItem('isAdmin', 'true');
        accountText.textContent = '👑 الأدمن';
        syncMobileCounters();
        if (adminLink) adminLink.style.display = 'inline-block';
    } else if (userData?.user_type === 'vendor') {
        localStorage.removeItem('isAdmin');
        accountText.textContent = '🏪 لوحة التاجر';
        syncMobileCounters();
    } else {
        localStorage.removeItem('isAdmin');
        accountText.textContent = user.user_metadata?.full_name || 'حسابي';
        syncMobileCounters();
    }
});
