// ========== إعدادات Supabase ==========
const SUPABASE_URL = 'https://qixiubjrsfkrpcylpzaj.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_tzwsoHr9pjgXSO3o4sRoLg_Udkq5-H8';

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
    }
});

// ========== بيانات المتجر ==========
const STORE_INFO = {
    name: 'تيك زون',
    location: 'صنعاء، الجمهورية اليمنية',
    email: 'ahmedalzubiry8@gmail.com',
    whatsapp: '+967776730573',
    instagram: 'https://www.instagram.com/a.__az0/',
    facebook: 'https://www.facebook.com/share/1ECwV4Erux/',
    currency: 'USD',
    currencySymbol: '$',
    storageBucket: 'product-images'
};

// ========== بيانات الأدمن ==========
// بيانات الدخول التي يستخدمها نموذج تسجيل الدخول لإنشاء/تسجيل حساب الأدمن في Supabase Auth.
// الصلاحية الفعلية لا تعتمد على هذه القيم وحدها، بل يتم التحقق أيضاً من role=admin داخل قاعدة البيانات.
const ADMIN_CREDENTIALS = {
    email: 'ahmed@admin.com',
    password: '125493'
};

// ========== دوال مساعدة ==========
function formatPrice(price) {
    return `${STORE_INFO.currencySymbol}${parseFloat(price).toFixed(2)}`;
}

// ========== التحقق من الاتصال ==========
async function testDatabaseConnection() {
    try {
        const { data, error } = await supabaseClient
            .from('settings')
            .select('*')
            .limit(1);
        
        if (error) {
            console.error('❌ خطأ في الاتصال:', error.message);
        } else {
            console.log('✅ الاتصال ناجح!');
        }
    } catch (error) {
        console.error('❌ خطأ:', error);
    }
}

document.addEventListener('DOMContentLoaded', testDatabaseConnection);