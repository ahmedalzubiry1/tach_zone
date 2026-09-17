// ========== التحقق من تسجيل الدخول ==========
let currentUser = null;

document.getElementById('loginForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('adminEmail').value;
    const password = document.getElementById('adminPassword').value;
    
    if (email !== ADMIN_CREDENTIALS.email || password !== ADMIN_CREDENTIALS.password) {
        alert('البريد الإلكتروني أو كلمة المرور غير صحيحة!');
        return;
    }
    try {
        const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });
        if (error) throw error;
        const { error: ensureAdminError } = await supabaseClient.rpc('ensure_admin_profile');
        if (ensureAdminError) throw ensureAdminError;
        currentUser = data.user;
        localStorage.setItem('adminUser', JSON.stringify({ email, role: 'admin' }));
        showDashboard();
    } catch (error) {
        alert('تعذر تسجيل دخول الأدمن: ' + error.message);
    }
});

// التحقق من وجود جلسة مسجلة
window.addEventListener('load', () => {
    const savedUser = localStorage.getItem('adminUser');
    if (savedUser) {
        currentUser = JSON.parse(savedUser);
        showDashboard();
    }
});

function showDashboard() {
    document.getElementById('loginContainer').style.display = 'none';
    document.getElementById('adminDashboard').style.display = 'block';
    loadDashboardData();
}

function logout() {
    localStorage.removeItem('adminUser');
    location.reload();
}

// ========== التنقل بين الأقسام ==========
function showSection(sectionName) {
    // إخفاء جميع الأقسام
    document.querySelectorAll('.main-content > section').forEach(section => {
        section.style.display = 'none';
    });
    
    // إزالة النشاط من جميع العناصر
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    
    // إظهار القسم المطلوب
    const sectionMap = {
        'dashboard': 'dashboardSection',
        'products': 'productsSection',
        'categories': 'categoriesSection',
        'orders': 'ordersSection',
        'customers': 'customersSection',
        'offers': 'offersSection',
        'reports': 'reportsSection'
    };
    
    document.getElementById(sectionMap[sectionName]).style.display = 'block';
    event.target.closest('.nav-item').classList.add('active');
    
    // تحميل بيانات القسم
    if (sectionName === 'products') loadProducts();
    if (sectionName === 'orders') loadOrders();
}

// ========== لوحة المعلومات ==========
async function loadDashboardData() {
    try {
        // تحميل إحصائيات المبيعات
        const { data: orders } = await supabase.from('orders').select('*');
        const { data: products } = await supabase.from('products').select('*');
        const { data: customers } = await supabase.from('users').select('*');
        
        const totalSales = orders?.reduce((sum, order) => sum + parseFloat(order.total_amount || 0), 0) || 0;
        
        document.getElementById('totalSales').textContent = formatPrice(totalSales);
        document.getElementById('totalOrders').textContent = orders?.length || 0;
        document.getElementById('totalProducts').textContent = products?.length || 0;
        document.getElementById('totalCustomers').textContent = customers?.length || 0;
        
        // تحميل آخر الطلبات
        const recentOrders = orders?.slice(-5).reverse() || [];
        const tbody = document.querySelector('#recentOrdersTable tbody');
        tbody.innerHTML = recentOrders.map(order => `
            <tr>
                <td>#${order.id}</td>
                <td>${order.customer_name || 'عميل'}</td>
                <td>${new Date(order.created_at).toLocaleDateString('ar-YE')}</td>
                <td>${formatPrice(order.total_amount)}</td>
                <td><span class="badge ${order.status}">${order.status}</span></td>
            </tr>
        `).join('');
        
    } catch (error) {
        console.error('Error loading dashboard:', error);
    }
}

// ========== إدارة المنتجات ==========
async function loadProducts() {
    try {
        const { data: products, error } = await supabase.from('products').select('*');
        
        if (error) throw error;
        
        const tbody = document.querySelector('#productsTable tbody');
        tbody.innerHTML = products.map(product => `
            <tr>
                <td><i class="fas ${product.icon || 'fa-box'}" style="font-size: 2rem; color: var(--primary);"></i></td>
                <td>${product.name}</td>
                <td>${product.category}</td>
                <td>${formatPrice(product.price)}</td>
                <td>${product.stock || 'غير محدود'}</td>
                <td>
                    <button class="btn-edit" onclick="editProduct(${product.id})">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="btn-delete" onclick="deleteProduct(${product.id})">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            </tr>
        `).join('');
        
    } catch (error) {
        console.error('Error loading products:', error);
    }
}

function openProductModal(productId = null) {
    document.getElementById('productModal').classList.add('active');
    document.getElementById('modalTitle').textContent = productId ? 'تعديل منتج' : 'إضافة منتج جديد';
    
    if (productId) {
        loadProductData(productId);
    } else {
        document.getElementById('productForm').reset();
        document.getElementById('productId').value = '';
    }
}

function closeProductModal() {
    document.getElementById('productModal').classList.remove('active');
}

async function loadProductData(productId) {
    const { data: product } = await supabase.from('products').select('*').eq('id', productId).single();
    
    if (product) {
        document.getElementById('productId').value = product.id;
        document.getElementById('productName').value = product.name;
        document.getElementById('productCategory').value = product.category;
        document.getElementById('productPrice').value = product.price;
        document.getElementById('productOldPrice').value = product.old_price || '';
        document.getElementById('productDescription').value = product.description || '';
        document.getElementById('productFeatures').value = product.features?.join(', ') || '';
        document.getElementById('productIcon').value = product.icon || '';
        document.getElementById('productImage').value = product.image_url || '';
    }
}

document.getElementById('productForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const productData = {
        name: document.getElementById('productName').value,
        category: document.getElementById('productCategory').value,
        price: parseFloat(document.getElementById('productPrice').value),
        old_price: parseFloat(document.getElementById('productOldPrice').value) || null,
        description: document.getElementById('productDescription').value,
        features: document.getElementById('productFeatures').value.split(',').map(f => f.trim()),
        icon: document.getElementById('productIcon').value,
        image_url: document.getElementById('productImage').value,
        updated_at: new Date().toISOString()
    };
    
    const productId = document.getElementById('productId').value;
    
    try {
        if (productId) {
            await supabase.from('products').update(productData).eq('id', productId);
        } else {
            productData.created_at = new Date().toISOString();
            await supabase.from('products').insert([productData]);
        }
        
        alert('تم حفظ المنتج بنجاح!');
        closeProductModal();
        loadProducts();
        
    } catch (error) {
        console.error('Error saving product:', error);
        alert('حدث خطأ أثناء حفظ المنتج');
    }
});

async function editProduct(productId) {
    openProductModal(productId);
}

async function deleteProduct(productId) {
    if (confirm('هل أنت متأكد من حذف هذا المنتج؟')) {
        try {
            await supabase.from('products').delete().eq('id', productId);
            alert('تم حذف المنتج بنجاح!');
            loadProducts();
        } catch (error) {
            console.error('Error deleting product:', error);
            alert('حدث خطأ أثناء حذف المنتج');
        }
    }
}

// ========== إدارة الطلبات ==========
async function loadOrders() {
    try {
        const { data: orders, error } = await supabase.from('orders').select('*');
        
        if (error) throw error;
        
        const tbody = document.querySelector('#ordersTable tbody');
        tbody.innerHTML = orders.map(order => `
            <tr>
                <td>#${order.id}</td>
                <td>${order.customer_name || 'عميل'}</td>
                <td>${order.items_count || 1} منتجات</td>
                <td>${formatPrice(order.total_amount)}</td>
                <td>
                    <select onchange="updateOrderStatus(${order.id}, this.value)" style="padding: 5px; border-radius: 5px;">
                        <option value="pending" ${order.status === 'pending' ? 'selected' : ''}>قيد المعالجة</option>
                        <option value="completed" ${order.status === 'completed' ? 'selected' : ''}>مكتمل</option>
                        <option value="cancelled" ${order.status === 'cancelled' ? 'selected' : ''}>ملغي</option>
                    </select>
                </td>
                <td>
                    <button class="btn-edit" onclick="viewOrder(${order.id})">
                        <i class="fas fa-eye"></i>
                    </button>
                </td>
            </tr>
        `).join('');
        
    } catch (error) {
        console.error('Error loading orders:', error);
    }
}

async function updateOrderStatus(orderId, status) {
    try {
        await supabase.from('orders').update({ status }).eq('id', orderId);
        alert('تم تحديث حالة الطلب بنجاح!');
    } catch (error) {
        console.error('Error updating order:', error);
    }
}

// ========== التقارير و PDF ==========
async function generateSalesReport() {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ align: 'right' });
    
    // إضافة الخط العربي
    doc.addFileToVFS('Tajawal.ttf', '');
    doc.addFont('Tajawal.ttf', 'Tajawal', 'normal');
    doc.setFont('Tajawal');
    
    // عنوان التقرير
    doc.setFontSize(20);
    doc.text('تقرير المبيعات', 105, 20, { align: 'center' });
    
    doc.setFontSize(12);
    doc.text(`المتجر: ${STORE_INFO.name}`, 20, 40);
    doc.text(`التاريخ: ${new Date().toLocaleDateString('ar-YE')}`, 20, 50);
    
    // تحميل بيانات المبيعات
    const { data: orders } = await supabase.from('orders').select('*');
    
    const tableData = orders.map(order => [
        `#${order.id}`,
        order.customer_name || 'عميل',
        new Date(order.created_at).toLocaleDateString('ar-YE'),
        formatPrice(order.total_amount),
        order.status
    ]);
    
    doc.autoTable({
        head: [['رقم الطلب', 'العميل', 'التاريخ', 'المبلغ', 'الحالة']],
        body: tableData,
        startY: 60,
        theme: 'grid',
        styles: { font: 'Tajawal', fontSize: 10 }
    });
    
    doc.save(`sales-report-${Date.now()}.pdf`);
}

async function generateProductsReport() {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ align: 'right' });
    
    doc.setFontSize(20);
    doc.text('تقرير المنتجات', 105, 20, { align: 'center' });
    
    doc.setFontSize(12);
    doc.text(`المتجر: ${STORE_INFO.name}`, 20, 40);
    doc.text(`التاريخ: ${new Date().toLocaleDateString('ar-YE')}`, 20, 50);
    
    const { data: products } = await supabase.from('products').select('*');
    
    const tableData = products.map(product => [
        product.name,
        product.category,
        formatPrice(product.price),
        formatPrice(product.old_price || 0),
        product.stock || 'غير محدود'
    ]);
    
    doc.autoTable({
        head: [['المنتج', 'التصنيف', 'السعر', 'السعر القديم', 'المخزون']],
        body: tableData,
        startY: 60,
        theme: 'grid'
    });
    
    doc.save(`products-report-${Date.now()}.pdf`);
}

async function generateOrdersReport() {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ align: 'right' });
    
    doc.setFontSize(20);
    doc.text('تقرير الطلبات', 105, 20, { align: 'center' });
    
    const { data: orders } = await supabase.from('orders').select('*');
    
    const tableData = orders.map(order => [
        `#${order.id}`,
        order.customer_name,
        order.customer_email,
        formatPrice(order.total_amount),
        order.status
    ]);
    
    doc.autoTable({
        head: [['رقم الطلب', 'العميل', 'البريد', 'المبلغ', 'الحالة']],
        body: tableData,
        startY: 60,
        theme: 'grid'
    });
    
    doc.save(`orders-report-${Date.now()}.pdf`);
}

function printOrdersReport() {
    window.print();
}