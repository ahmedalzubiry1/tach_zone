// ========== المتغيرات ==========
let product = null;
let allProducts = [];
let cart = JSON.parse(localStorage.getItem('cart')) || [];
let wishlist = JSON.parse(localStorage.getItem('wishlist')) || [];
let detailQty = 1;
let currentImageIndex = 0;
let productImages = [];
let selectedRating = 0;
let currentUser = null;

// ========== الحصول على المنتج من URL ==========
const urlParams = new URLSearchParams(window.location.search);
const productIdParam = urlParams.get('id');

// ========== تحميل المنتج ==========
async function loadProduct() {
    try {
        if (typeof supabaseClient === 'undefined') {
            showError('قاعدة البيانات غير متصلة');
            return;
        }
        
        // ✅ التحقق من صحة ID
        if (!productIdParam || isNaN(parseInt(productIdParam)) && !isValidUUID(productIdParam)) {
            showError('معرف المنتج غير صالح');
            return;
        }
        
        // ✅ تحميل المنتج المحدد فقط
        const { data: productData, error } = await supabaseClient
            .from('products')
            .select('*, product_images(*), product_reviews(*)')
            .eq('id', productIdParam)
            .single();
        
        if (error || !productData) {
            console.error('Product error:', error);
            showError('المنتج غير موجود');
            return;
        }
        
        // ✅ تعبئة بيانات المنتج بشكل صحيح
        product = {
            id: productData.id,
            name: productData.name || '',
            category: productData.category || '',
            price: parseFloat(productData.price) || 0,
            oldPrice: productData.old_price ? parseFloat(productData.old_price) : null,
            icon: productData.icon || 'fa-box',
            rating: parseFloat(productData.rating) || 0,
            reviews: productData.reviews_count || 0,
            badge: productData.badge || '',
            description: productData.description || '',
            features: productData.features || [],
            specs: productData.specs || {},
            mainImage: productData.main_image || '',
            images: productData.product_images || [],
            reviewsList: productData.product_reviews || [],
            shopNote: productData.shop_note || ''
        };
        
        // ✅ تحميل جميع المنتجات للمنتجات المشابهة
        const { data: allData } = await supabaseClient
            .from('products')
            .select('*')
            .eq('is_active', true);
        
        if (allData) {
            allProducts = allData.map(p => ({
                id: p.id,
                name: p.name,
                category: p.category,
                price: parseFloat(p.price),
                oldPrice: p.old_price ? parseFloat(p.old_price) : null,
                icon: p.icon || 'fa-box',
                rating: parseFloat(p.rating) || 0,
                reviews: p.reviews_count || 0,
                badge: p.badge || '',
                description: p.description || '',
                features: p.features || [],
                specs: p.specs || {},
                mainImage: p.main_image || ''
            }));
        }
        
        // ✅ التحقق من المستخدم الحالي
        const { data: { user } } = await supabaseClient.auth.getUser();
        currentUser = user;
        
        // إخفاء شاشة التحميل وإظهار المحتوى
        document.getElementById('loadingSpinner').style.display = 'none';
        document.getElementById('productDetailsContainer').style.display = 'block';
        
        // تعبئة البيانات
        fillProductDetails();
        updateCartCount();
        
    } catch (error) {
        console.error('Error loading product:', error);
        showError('حدث خطأ في تحميل المنتج: ' + error.message);
    }
}

function isValidUUID(str) {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
}

function showError(message) {
    document.getElementById('loadingSpinner').innerHTML = `
        <i class="fas fa-exclamation-triangle" style="color: var(--danger);"></i>
        <h3 style="color: var(--danger);">${message}</h3>
        <a href="index.html" class="btn btn-primary" style="margin-top: 20px; display: inline-block;">
            العودة للمتجر
        </a>
    `;
}

// ========== تعبئة تفاصيل المنتج ==========
function fillProductDetails() {
    if (!product) return;
    
    document.title = `${product.name} | تيك زون`;
    
    // الأيقونة الرئيسية
    const mainIcon = document.getElementById('mainIcon');
    if (mainIcon) mainIcon.className = `fas ${product.icon}`;
    
    // الشارة
    const badge = document.getElementById('productBadge');
    if (product.badge) {
        badge.textContent = product.badge;
        badge.style.display = 'block';
    }
    
    // التصنيف
    document.getElementById('productCategory').textContent = getCategoryName(product.category);
    
    // الاسم
    document.getElementById('productName').textContent = product.name;
    
    // التقييم
    const rating = product.rating || 0;
    const reviews = product.reviews || 0;
    const stars = '★'.repeat(Math.floor(rating)) + '☆'.repeat(5 - Math.floor(rating));
    document.getElementById('productStars').textContent = reviews > 0 ? stars : '☆☆☆☆☆';
    document.getElementById('productRating').textContent = rating.toFixed(1);
    document.getElementById('productReviews').textContent = reviews;
    
    // الوصف
    document.getElementById('productDescription').textContent = product.description || 'لا يوجد وصف';
    
    // السعر
    document.getElementById('productPrice').textContent = formatPrice(product.price);
    
    const oldPriceEl = document.getElementById('productOldPrice');
    const discountBadge = document.getElementById('discountBadge');
    
    if (product.oldPrice) {
        oldPriceEl.textContent = formatPrice(product.oldPrice);
        oldPriceEl.style.display = 'block';
        
        const discount = Math.round(((product.oldPrice - product.price) / product.oldPrice) * 100);
        discountBadge.textContent = `-${discount}%`;
        discountBadge.style.display = 'block';
    }
    
    // Breadcrumb
    document.getElementById('breadcrumbCategory').textContent = getCategoryName(product.category);
    document.getElementById('breadcrumbProduct').textContent = product.name;
    
    // المميزات
    const featuresList = document.getElementById('productFeaturesList');
    if (product.features && product.features.length > 0) {
        featuresList.innerHTML = product.features.map(f => `<li>${f}</li>`).join('');
    } else {
        featuresList.innerHTML = '<li>لا توجد مميزات متاحة</li>';
    }
    
    // الوصف الكامل
    document.getElementById('fullDescription').innerHTML = `
        <p style="line-height: 1.8; color: var(--text-light);">${product.description || 'لا يوجد وصف'}</p>
        ${product.features && product.features.length > 0 ? `
            <h4 style="margin-top: 20px; color: var(--primary);">لماذا تختار هذا المنتج؟</h4>
            <ul style="padding-right: 20px; color: var(--text-light); line-height: 2;">
                ${product.features.map(f => `<li>${f}</li>`).join('')}
            </ul>
        ` : ''}
    `;
    
    // المواصفات
    const specsTable = document.getElementById('specsTable');
    if (product.specs && Object.keys(product.specs).length > 0) {
        specsTable.innerHTML = Object.entries(product.specs).map(([key, value]) => `
            <tr><td>${key}</td><td>${value}</td></tr>
        `).join('');
    } else {
        specsTable.innerHTML = '<tr><td colspan="2" style="text-align: center; color: var(--text-light);">لا توجد مواصفات</td></tr>';
    }
    
    // ✅ تحميل الصور
    loadProductImages();
    
    // ✅ تحميل التقييمات
    loadReviews();
    
    // التحقق من المفضلة
    updateWishlistButton();
    
    // المنتجات المشابهة
    renderRelatedProducts();
    
    // ✅ إخفاء نموذج التقييم إذا لم يكن المستخدم مسجل
    if (!currentUser) {
        document.getElementById('reviewFormContainer').innerHTML = `
            <div style="text-align: center; padding: 20px;">
                <i class="fas fa-lock" style="font-size: 3rem; color: var(--text-light); margin-bottom: 15px;"></i>
                <h3>سجل دخولك لإضافة تقييم</h3>
                <p style="color: var(--text-light); margin-bottom: 15px;">يجب تسجيل الدخول أولاً لتتمكن من تقييم المنتجات</p>
                <a href="index.html" class="btn btn-primary" style="display: inline-block;">
                    <i class="fas fa-sign-in-alt"></i> تسجيل الدخول
                </a>
            </div>
        `;
    }
}

// ========== تحميل الصور ==========
function loadProductImages() {
    const mainImageContainer = document.getElementById('mainImage');
    const thumbnailList = document.getElementById('thumbnailList');
    
    productImages = [];
    
    if (product.mainImage) {
        productImages.push({ url: product.mainImage, isMain: true });
    }
    
    if (product.images && product.images.length > 0) {
        product.images.forEach(img => {
            if (img.image_url && !productImages.some(p => p.url === img.image_url)) {
                productImages.push({ url: img.image_url, isMain: img.is_main || false });
            }
        });
    }
    
    if (productImages.length > 0) {
        const icon = document.getElementById('mainIcon');
        if (icon) icon.style.display = 'none';
        
        mainImageContainer.innerHTML = `
            ${product.badge ? `<span class="product-badge" style="display: block;">${product.badge}</span>` : ''}
            <img src="${productImages[0].url}" alt="${product.name}" id="mainProductImage">
        `;
        currentImageIndex = 0;
        
        thumbnailList.innerHTML = productImages.map((img, index) => `
            <div class="thumbnail ${index === 0 ? 'active' : ''}" onclick="changeMainImage(${index})">
                <img src="${img.url}" alt="صورة ${index + 1}">
            </div>
        `).join('');
    } else {
        mainImageContainer.innerHTML = `
            ${product.badge ? `<span class="product-badge" style="display: block;">${product.badge}</span>` : ''}
            <i class="fas ${product.icon || 'fa-box'}"></i>
        `;
        thumbnailList.innerHTML = '';
    }
}

function changeMainImage(index) {
    if (index < 0 || index >= productImages.length) return;
    
    currentImageIndex = index;
    const img = document.getElementById('mainProductImage');
    
    if (img) {
        img.src = productImages[index].url;
    }
    
    document.querySelectorAll('.thumbnail').forEach((thumb, i) => {
        thumb.classList.toggle('active', i === index);
    });
}

// ========== ✅ تحميل التقييمات ==========
async function loadReviews() {
    try {
        const { data: reviews, error } = await supabaseClient
            .from('product_reviews')
            .select('*')
            .eq('product_id', product.id)
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        const reviewsList = document.getElementById('reviewsList');
        
        if (!reviews || reviews.length === 0) {
            reviewsList.innerHTML = `
                <div style="text-align: center; padding: 40px; color: var(--text-light);">
                    <i class="fas fa-comment-slash" style="font-size: 3rem; opacity: 0.3; margin-bottom: 15px;"></i>
                    <h3>لا توجد تقييمات بعد</h3>
                    <p>كن أول من يقيّم هذا المنتج!</p>
                </div>
            `;
            return;
        }
        
        reviewsList.innerHTML = reviews.map(review => `
            <div class="review-item">
                <div class="review-header">
                    <div class="review-author">
                        <div class="author-avatar">${(review.user_name || 'م').charAt(0)}</div>
                        <div>
                            <h5>${review.user_name || 'مستخدم'}</h5>
                            <span>${new Date(review.created_at).toLocaleDateString('ar-YE')}</span>
                        </div>
                    </div>
                    <div class="stars">${'★'.repeat(review.rating)}${'☆'.repeat(5 - review.rating)}</div>
                </div>
                <p style="color: var(--text-light); line-height: 1.7;">${review.comment || 'لا يوجد تعليق'}</p>
            </div>
        `).join('');
        
    } catch (error) {
        console.error('Error loading reviews:', error);
    }
}

// ========== ✅ إضافة تقييم ==========
async function submitReview() {
    if (!currentUser || currentUser.is_anonymous) {
        alert('يجب إنشاء حساب دائم أولاً');
        return;
    }
    
    if (selectedRating === 0) {
        alert('يرجى اختيار عدد النجوم');
        return;
    }
    
    const comment = document.getElementById('reviewComment').value.trim();
    
    try {
        const { error } = await supabaseClient
            .from('product_reviews')
            .insert([{
                product_id: product.id,
                user_id: currentUser.id,
                user_name: currentUser.user_metadata?.full_name || currentUser.email,
                rating: selectedRating,
                comment: comment
            }]);
        
        if (error) throw error;
        
        alert('✅ شكراً! تم إضافة تقييمك بنجاح');
        
        // إعادة تحميل التقييمات
        loadReviews();
        
        // إعادة تعيين النموذج
        selectedRating = 0;
        document.querySelectorAll('#starRating i').forEach(star => {
            star.classList.remove('active');
            star.className = 'far fa-star';
        });
        document.getElementById('reviewComment').value = '';
        
        // تحديث تقييم المنتج
        const { data: updatedProduct } = await supabaseClient
            .from('products')
            .select('rating, reviews_count')
            .eq('id', product.id)
            .single();
        
        if (updatedProduct) {
            product.rating = updatedProduct.rating;
            product.reviews = updatedProduct.reviews_count;
            fillProductDetails();
        }
        
    } catch (error) {
        console.error('Error submitting review:', error);
        alert('❌ حدث خطأ: ' + error.message);
    }
}

// ========== ✅ تفاعل النجوم ==========
function initStarRating() {
    const stars = document.querySelectorAll('#starRating i');
    
    stars.forEach(star => {
        star.addEventListener('click', () => {
            selectedRating = parseInt(star.dataset.rating);
            
            stars.forEach(s => {
                const rating = parseInt(s.dataset.rating);
                if (rating <= selectedRating) {
                    s.className = 'fas fa-star active';
                } else {
                    s.className = 'far fa-star';
                }
            });
        });
        
        star.addEventListener('mouseover', () => {
            const hoverRating = parseInt(star.dataset.rating);
            stars.forEach(s => {
                const rating = parseInt(s.dataset.rating);
                if (rating <= hoverRating) {
                    s.style.color = '#fbbf24';
                } else {
                    s.style.color = '';
                }
            });
        });
        
        star.addEventListener('mouseout', () => {
            stars.forEach(s => {
                s.style.color = '';
            });
        });
    });
}

// ========== تبديل التبويبات ==========
function initTabs() {
    document.querySelectorAll('.tab-button').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.tab-button').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            
            btn.classList.add('active');
            document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
        });
    });
}

function changeDetailQty(change) {
    detailQty = Math.max(1, detailQty + change);
    document.getElementById('detailQty').textContent = detailQty;
}

function addToCart(productId) {
    const p = allProducts.find(x => x.id === productId) || product;
    if (!p) return;
    
    const existing = cart.find(item => item.id === productId);
    const qty = productId === product.id ? detailQty : 1;
    
    if (existing) {
        existing.quantity += qty;
    } else {
        cart.push({ ...p, quantity: qty });
    }
    
    localStorage.setItem('cart', JSON.stringify(cart));
    updateCartCount();
    showToast(`✓ تمت إضافة "${p.name}" إلى السلة`);
}

function updateCartCount() {
    const total = cart.reduce((sum, item) => sum + item.quantity, 0);
    const cartCountEl = document.getElementById('cartCount');
    if (cartCountEl) cartCountEl.textContent = total;
}

function toggleWishlist() {
    const index = wishlist.findIndex(item => item.id === product.id);
    
    if (index > -1) {
        wishlist.splice(index, 1);
        showToast('تمت الإزالة من المفضلة');
    } else {
        wishlist.push(product);
        showToast('تمت الإضافة إلى المفضلة ❤️');
    }
    
    localStorage.setItem('wishlist', JSON.stringify(wishlist));
    updateWishlistButton();
}

function updateWishlistButton() {
    const isInWishlist = wishlist.some(item => item.id === product.id);
    const btn = document.getElementById('wishlistToggle');
    
    if (btn) {
        btn.innerHTML = `<i class="${isInWishlist ? 'fas' : 'far'} fa-heart"></i> ${isInWishlist ? 'في المفضلة' : 'المفضلة'}`;
        btn.classList.toggle('active', isInWishlist);
    }
}

function shareProduct() {
    const url = window.location.href;
    
    if (navigator.share) {
        navigator.share({
            title: product.name,
            text: `شاهد هذا المنتج: ${product.name} - ${formatPrice(product.price)}`,
            url: url
        });
    } else {
        navigator.clipboard.writeText(url).then(() => {
            showToast('✓ تم نسخ رابط المنتج');
        });
    }
}

function renderRelatedProducts() {
    const related = allProducts.filter(p => p.category === product.category && p.id !== product.id).slice(0, 4);
    const grid = document.getElementById('relatedGrid');
    
    if (related.length === 0) {
        grid.innerHTML = '<p style="text-align: center; color: var(--text-light); grid-column: 1/-1;">لا توجد منتجات مشابهة</p>';
        return;
    }
    
    grid.innerHTML = related.map(p => {
        const imageHtml = p.mainImage ? 
            `<img src="${p.mainImage}" style="width:100%;height:100%;object-fit:cover;" alt="${p.name}">` :
            `<i class="fas ${p.icon || 'fa-box'}"></i>`;
        
        return `
        <div class="product-card" onclick="window.location.href='product-details.html?id=${p.id}'">
            <div class="product-image">
                ${p.badge ? `<span class="product-badge">${p.badge}</span>` : ''}
                ${imageHtml}
            </div>
            <div class="product-info">
                <div class="product-category">${getCategoryName(p.category)}</div>
                <h3>${p.name}</h3>
                <div class="product-rating">
                    ${p.reviews > 0 ? '★'.repeat(Math.floor(p.rating)) + '☆'.repeat(5 - Math.floor(p.rating)) : '☆☆☆☆☆'}
                    <span>(${p.reviews})</span>
                </div>
                <div class="product-footer">
                    <div class="product-price">
                        <span class="price-current">${formatPrice(p.price)}</span>
                        ${p.oldPrice ? `<span class="price-old">${formatPrice(p.oldPrice)}</span>` : ''}
                    </div>
                    <button class="add-to-cart" onclick="event.stopPropagation(); addToCart('${p.id}')">
                        <i class="fas fa-plus"></i>
                    </button>
                </div>
            </div>
        </div>
    `}).join('');
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

function showToast(message) {
    const toast = document.createElement('div');
    toast.className = 'toast show';
    toast.innerHTML = `<i class="fas fa-check-circle"></i><span>${message}</span>`;
    toast.style.cssText = 'position: fixed; bottom: 30px; right: 30px; background: #10b981; color: white; padding: 15px 25px; border-radius: 12px; z-index: 9999; display: flex; align-items: center; gap: 10px; box-shadow: 0 4px 20px rgba(0,0,0,0.2);';
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 3000);
}

// ========== الأحداث ==========
document.addEventListener('DOMContentLoaded', () => {
    loadProduct();
    initTabs();
    initStarRating();
    
    const addToCartBtn = document.getElementById('addToCartBtn');
    if (addToCartBtn) {
        addToCartBtn.addEventListener('click', () => {
            if (product) addToCart(product.id);
        });
    }
    
    const buyNowBtn = document.getElementById('buyNowBtn');
    if (buyNowBtn) {
        buyNowBtn.addEventListener('click', async () => {
            if (product) {
                addToCart(product.id);
                const { data: { user } } = await supabaseClient.auth.getUser();
                if (!user || user.is_anonymous) {
                    alert('يرجى إنشاء حساب دائم أولاً');
                    return;
                }
                setTimeout(() => {
                    window.location.href = 'checkout.html';
                }, 500);
            }
        });
    }
    
    const wishlistToggle = document.getElementById('wishlistToggle');
    if (wishlistToggle) {
        wishlistToggle.addEventListener('click', toggleWishlist);
    }
});