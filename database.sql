-- ============================================================
-- تيك زون | قاعدة بيانات متوافقة مع المشروع بالكامل
-- نفّذ الملف كاملاً في Supabase SQL Editor بعد أخذ نسخة احتياطية.
-- ============================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
DROP TRIGGER IF EXISTS update_products_updated_at ON public.products;
DROP TRIGGER IF EXISTS update_orders_updated_at ON public.orders;
DROP TRIGGER IF EXISTS update_custom_requests_updated_at ON public.custom_requests;
DROP TRIGGER IF EXISTS update_vendors_updated_at ON public.vendors;

DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.transactions CASCADE;
DROP TABLE IF EXISTS public.product_reviews CASCADE;
DROP TABLE IF EXISTS public.custom_requests CASCADE;
DROP TABLE IF EXISTS public.product_images CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.vendors CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
DROP TABLE IF EXISTS public.offers CASCADE;
DROP TABLE IF EXISTS public.settings CASCADE;

CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(255) DEFAULT '',
    phone VARCHAR(30) DEFAULT '',
    avatar_url TEXT,
    role VARCHAR(20) NOT NULL DEFAULT 'customer' CHECK (role IN ('customer','vendor','admin')),
    user_type VARCHAR(20) NOT NULL DEFAULT 'customer' CHECK (user_type IN ('customer','vendor','admin')),
    vendor_id UUID,
    is_banned BOOLEAN NOT NULL DEFAULT false,
    ban_reason TEXT,
    banned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_ar VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    slug VARCHAR(100) UNIQUE,
    icon VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
    store_name VARCHAR(255) NOT NULL,
    store_description TEXT DEFAULT '',
    phone VARCHAR(30) DEFAULT '',
    address TEXT DEFAULT '',
    commission_rate NUMERIC(5,2) NOT NULL DEFAULT 3.00,
    current_invoice NUMERIC(12,2) NOT NULL DEFAULT 0,
    invoice_limit NUMERIC(12,2) NOT NULL DEFAULT 100.00,
    is_restricted BOOLEAN NOT NULL DEFAULT false,
    total_earned NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.users
    ADD CONSTRAINT users_vendor_id_fkey FOREIGN KEY (vendor_id) REFERENCES public.vendors(id) ON DELETE SET NULL;

CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    sub_category VARCHAR(100),
    description TEXT DEFAULT '',
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    old_price NUMERIC(12,2),
    main_image TEXT,
    icon VARCHAR(100) DEFAULT 'fa-box',
    features TEXT[] DEFAULT '{}',
    specs JSONB DEFAULT '{}'::jsonb,
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    rating NUMERIC(2,1) NOT NULL DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
    reviews_count INTEGER NOT NULL DEFAULT 0 CHECK (reviews_count >= 0),
    badge VARCHAR(100) DEFAULT '',
    is_active BOOLEAN NOT NULL DEFAULT true,
    shop_note TEXT DEFAULT '',
    offer_type VARCHAR(50) DEFAULT '',
    offer_duration INTEGER NOT NULL DEFAULT 0,
    offer_start_date TIMESTAMPTZ,
    offer_end_date TIMESTAMPTZ,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE SET NULL,
    is_vendor_product BOOLEAN NOT NULL DEFAULT false,
    approval_status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (approval_status IN ('pending','approved','rejected')),
    rejection_reason TEXT,
    published_at TIMESTAMPTZ,
    track_inventory BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX products_category_idx ON public.products(category);
CREATE INDEX products_sub_category_idx ON public.products(category, sub_category);
CREATE INDEX products_vendor_idx ON public.products(vendor_id);
CREATE INDEX products_active_idx ON public.products(is_active);

CREATE TABLE public.product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_main BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.product_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user_name VARCHAR(255),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(product_id, user_id)
);

CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE,
    customer_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE SET NULL,
    customer_name VARCHAR(255) DEFAULT '',
    customer_email VARCHAR(255) DEFAULT '',
    customer_phone VARCHAR(30) DEFAULT '',
    subtotal_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal_amount >= 0),
    shipping_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    vendor_commission NUMERIC(12,2) NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    payment_method VARCHAR(50),
    payment_details JSONB DEFAULT '{}'::jsonb,
    payment_proof_url TEXT,
    shipping_address TEXT,
    location_lat NUMERIC(10,7),
    location_lng NUMERIC(10,7),
    location_address TEXT,
    items_count INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    vendor_id UUID REFERENCES public.vendors(id) ON DELETE SET NULL,
    product_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    subtotal NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','completed','cancelled')),
    commission_posted BOOLEAN NOT NULL DEFAULT false,
    commission_reversed BOOLEAN NOT NULL DEFAULT false,
    inventory_restored BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.custom_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_number VARCHAR(50) UNIQUE,
    customer_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_email VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(30),
    project_type VARCHAR(100) NOT NULL,
    budget VARCHAR(100),
    description TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    admin_notes TEXT,
    price_quoted NUMERIC(12,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    discount_percentage NUMERIC(5,2),
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL,
    type VARCHAR(30) NOT NULL CHECK (type IN ('commission','payment')),
    description TEXT,
    reference_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL,
    payment_method VARCHAR(100),
    receipt_number VARCHAR(100),
    status VARCHAR(30) NOT NULL DEFAULT 'completed',
    admin_notes TEXT,
    paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_custom_requests_updated_at BEFORE UPDATE ON public.custom_requests FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_vendors_updated_at BEFORE UPDATE ON public.vendors FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- إنشاء ملف المستخدم تلقائياً عند إنشاء Auth user.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, email, full_name, phone, role, user_type)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        CASE
             WHEN lower(COALESCE(NEW.email,'')) = 'ahmed@admin.com'
                  OR COALESCE(NEW.raw_user_meta_data->>'role','') = 'admin'
                  OR COALESCE(NEW.raw_user_meta_data->>'user_type','') = 'admin' THEN 'admin'
             WHEN COALESCE(NEW.raw_user_meta_data->>'user_type','') = 'vendor' THEN 'vendor'
             ELSE 'customer'
        END,
        CASE
             WHEN lower(COALESCE(NEW.email,'')) = 'ahmed@admin.com'
                  OR COALESCE(NEW.raw_user_meta_data->>'role','') = 'admin'
                  OR COALESCE(NEW.raw_user_meta_data->>'user_type','') = 'admin' THEN 'admin'
             WHEN COALESCE(NEW.raw_user_meta_data->>'user_type','') = 'vendor' THEN 'vendor'
             ELSE 'customer'
        END
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role,
        user_type = EXCLUDED.user_type,
        updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- تقييم المنتج يحافظ على متوسط التقييم وعدده.
CREATE OR REPLACE FUNCTION public.refresh_product_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE pid UUID;
BEGIN
    pid := COALESCE(NEW.product_id, OLD.product_id);
    UPDATE public.products
    SET rating = COALESCE((SELECT ROUND(AVG(rating)::numeric, 1) FROM public.product_reviews WHERE product_id = pid), 0),
        reviews_count = (SELECT COUNT(*) FROM public.product_reviews WHERE product_id = pid),
        updated_at = NOW()
    WHERE id = pid;
    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS refresh_product_rating_trigger ON public.product_reviews;
CREATE TRIGGER refresh_product_rating_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.product_reviews
FOR EACH ROW EXECUTE FUNCTION public.refresh_product_rating();

-- دالة تسديد فاتورة التاجر المستخدمة من لوحة الأدمن.
CREATE OR REPLACE FUNCTION public.settle_vendor_invoice(
    p_vendor_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_receipt_number TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE current_amount NUMERIC;
BEGIN
    IF NOT public.is_admin() THEN RAISE EXCEPTION 'غير مصرح: هذه العملية للأدمن فقط'; END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'المبلغ غير صالح'; END IF;
    SELECT current_invoice INTO current_amount FROM public.vendors WHERE id = p_vendor_id FOR UPDATE;
    IF current_amount IS NULL THEN RAISE EXCEPTION 'التاجر غير موجود'; END IF;
    IF p_amount > current_amount + 0.01 THEN RAISE EXCEPTION 'المبلغ أكبر من الفاتورة الحالية'; END IF;
    UPDATE public.vendors
    SET current_invoice = GREATEST(current_invoice - p_amount, 0),
        is_restricted = GREATEST(current_invoice - p_amount, 0) >= invoice_limit,
        total_earned = total_earned + p_amount,
        updated_at = NOW()
    WHERE id = p_vendor_id;
    INSERT INTO public.transactions(vendor_id, amount, type, description, reference_id)
    VALUES(p_vendor_id, p_amount, 'payment', 'سداد فاتورة عبر ' || COALESCE(p_payment_method,''), NULL);
END;
$$;


-- ============================================================
-- Marketplace security/business logic
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_order_secure(
    p_items JSONB,
    p_customer_name TEXT,
    p_customer_email TEXT,
    p_customer_phone TEXT,
    p_payment_method TEXT,
    p_payment_details JSONB DEFAULT '{}'::jsonb,
    p_payment_proof_path TEXT DEFAULT NULL,
    p_shipping_address TEXT DEFAULT NULL,
    p_location_lat NUMERIC DEFAULT NULL,
    p_location_lng NUMERIC DEFAULT NULL,
    p_location_address TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_order UUID;
    v_item JSONB;
    v_product public.products%ROWTYPE;
    v_qty INTEGER;
    v_subtotal NUMERIC(12,2) := 0;
    v_shipping NUMERIC(12,2);
    v_vendor UUID;
    v_vendor_count INTEGER;
BEGIN
    IF v_user IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول بحساب دائم'; END IF;
    IF COALESCE((auth.jwt()->>'is_anonymous')::boolean, false) THEN RAISE EXCEPTION 'الحساب الزائر لا يمكنه إتمام الشراء'; END IF;
    IF COALESCE((SELECT is_banned FROM public.users WHERE id=v_user), false) THEN RAISE EXCEPTION 'الحساب مقيد ولا يمكنه الشراء'; END IF;
    IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN RAISE EXCEPTION 'السلة فارغة'; END IF;
    IF p_payment_method IS NULL OR p_payment_method NOT IN ('bank','wallet','cash') THEN RAISE EXCEPTION 'طريقة الدفع غير متاحة'; END IF;
    IF COALESCE(length(trim(p_shipping_address)),0) < 5 THEN RAISE EXCEPTION 'عنوان الشحن غير صالح'; END IF;

    -- Validate all products and calculate the server-side total.
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
        v_qty := COALESCE((v_item->>'quantity')::INTEGER, 0);
        IF v_qty <= 0 OR v_qty > 100 THEN RAISE EXCEPTION 'كمية المنتج غير صالحة'; END IF;
        SELECT * INTO v_product FROM public.products WHERE id=(v_item->>'id')::UUID FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'أحد المنتجات غير موجود'; END IF;
        IF NOT v_product.is_active OR v_product.approval_status <> 'approved' THEN RAISE EXCEPTION 'المنتج % غير متاح حالياً', v_product.name; END IF;
        IF v_product.track_inventory AND v_product.stock < v_qty THEN RAISE EXCEPTION 'المخزون غير كافٍ للمنتج %', v_product.name; END IF;
        v_subtotal := v_subtotal + (v_product.price * v_qty);
    END LOOP;

    v_shipping := CASE WHEN v_subtotal > 200 THEN 0 ELSE 15 END;

    SELECT count(DISTINCT p.vendor_id), min(p.vendor_id) INTO v_vendor_count, v_vendor
    FROM public.products p
    WHERE p.id IN (SELECT (value->>'id')::UUID FROM jsonb_array_elements(p_items));

    INSERT INTO public.orders(
        order_number, customer_id, vendor_id, customer_name, customer_email, customer_phone,
        subtotal_amount, shipping_fee, total_amount, status, payment_method, payment_details,
        payment_proof_url, shipping_address, location_lat, location_lng, location_address,
        items_count, notes
    ) VALUES (
        'TZ-' || to_char(clock_timestamp(),'YYYYMMDDHH24MISS') || '-' || substr(replace(gen_random_uuid()::text,'-',''),1,6),
        v_user, CASE WHEN v_vendor_count=1 THEN v_vendor ELSE NULL END,
        COALESCE(p_customer_name,''), COALESCE(p_customer_email,''), COALESCE(p_customer_phone,''),
        v_subtotal, v_shipping, v_subtotal + v_shipping, 'pending', p_payment_method,
        COALESCE(p_payment_details,'{}'::jsonb), p_payment_proof_path, p_shipping_address,
        p_location_lat, p_location_lng, p_location_address, jsonb_array_length(p_items), p_notes
    ) RETURNING id INTO v_order;

    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
        v_qty := (v_item->>'quantity')::INTEGER;
        SELECT * INTO v_product FROM public.products WHERE id=(v_item->>'id')::UUID FOR UPDATE;
        INSERT INTO public.order_items(order_id, product_id, vendor_id, product_name, quantity, price, subtotal, status)
        VALUES(v_order, v_product.id, v_product.vendor_id, v_product.name, v_qty, v_product.price, v_product.price*v_qty, 'pending');
        IF v_product.track_inventory THEN
            UPDATE public.products SET stock = stock - v_qty, updated_at=NOW() WHERE id=v_product.id;
        END IF;
    END LOOP;

    RETURN v_order;
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_vendor_order(p_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_vendor UUID := public.current_vendor_id();
    v_commission NUMERIC(12,2) := 0;
    v_items INTEGER := 0;
    v_remaining INTEGER := 0;
    v_new_invoice NUMERIC(12,2);
    v_limit NUMERIC(12,2);
BEGIN
    IF v_vendor IS NULL THEN RAISE EXCEPTION 'الحساب ليس حساب تاجر'; END IF;
    IF (SELECT is_restricted FROM public.vendors WHERE id=v_vendor) THEN RAISE EXCEPTION 'التاجر مقيد حالياً'; END IF;

    SELECT count(*), COALESCE(sum(oi.subtotal),0) * (v.commission_rate/100.0)
    INTO v_items, v_commission
    FROM public.order_items oi JOIN public.vendors v ON v.id=oi.vendor_id
    WHERE oi.order_id=p_order_id AND oi.vendor_id=v_vendor AND oi.status='pending' AND NOT oi.commission_posted;

    IF v_items = 0 THEN RAISE EXCEPTION 'لا توجد عناصر معلقة لهذا التاجر في الطلب'; END IF;

    UPDATE public.order_items
    SET status='confirmed', commission_posted=true
    WHERE order_id=p_order_id AND vendor_id=v_vendor AND status='pending' AND NOT commission_posted;

    UPDATE public.vendors
    SET current_invoice=current_invoice+v_commission,
        is_restricted=(current_invoice+v_commission)>=invoice_limit,
        updated_at=NOW()
    WHERE id=v_vendor
    RETURNING current_invoice, invoice_limit INTO v_new_invoice, v_limit;

    INSERT INTO public.transactions(vendor_id, amount, type, description, reference_id)
    VALUES(v_vendor, v_commission, 'commission', 'عمولة طلب #'||substr(p_order_id::text,1,8), p_order_id);

    SELECT count(*) INTO v_remaining FROM public.order_items WHERE order_id=p_order_id AND status='pending';
    IF v_remaining = 0 THEN
        UPDATE public.orders SET status='confirmed', updated_at=NOW() WHERE id=p_order_id AND status='pending';
    END IF;

    RETURN jsonb_build_object('commission',v_commission,'invoice',v_new_invoice,'invoice_limit',v_limit,'order_completed',v_remaining=0);
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE r RECORD; v_comm NUMERIC(12,2); v_new_invoice NUMERIC(12,2);
BEGIN
    IF NEW.status IN ('confirmed','completed') AND OLD.status NOT IN ('confirmed','completed') THEN
        FOR r IN SELECT oi.id, oi.vendor_id, oi.subtotal, v.commission_rate
                 FROM public.order_items oi JOIN public.vendors v ON v.id=oi.vendor_id
                 WHERE oi.order_id=NEW.id AND oi.status='pending' AND NOT oi.commission_posted LOOP
            v_comm := round(r.subtotal * r.commission_rate / 100.0, 2);
            UPDATE public.order_items SET status='confirmed', commission_posted=true WHERE id=r.id;
            UPDATE public.vendors SET current_invoice=current_invoice+v_comm,
                is_restricted=(current_invoice+v_comm)>=invoice_limit, updated_at=NOW()
                WHERE id=r.vendor_id RETURNING current_invoice INTO v_new_invoice;
            INSERT INTO public.transactions(vendor_id,amount,type,description,reference_id)
            VALUES(r.vendor_id,v_comm,'commission','عمولة طلب #'||substr(NEW.id::text,1,8),NEW.id);
        END LOOP;
    ELSIF NEW.status='cancelled' AND OLD.status <> 'cancelled' THEN
        FOR r IN SELECT oi.id, oi.vendor_id, oi.subtotal, v.commission_rate, oi.commission_posted, oi.inventory_restored, p.track_inventory
                 FROM public.order_items oi JOIN public.vendors v ON v.id=oi.vendor_id LEFT JOIN public.products p ON p.id=oi.product_id
                 WHERE oi.order_id=NEW.id LOOP
            IF r.commission_posted AND NOT r.commission_reversed THEN
                v_comm := round(r.subtotal * r.commission_rate / 100.0, 2);
                UPDATE public.vendors SET current_invoice=GREATEST(current_invoice-v_comm,0),
                    is_restricted=GREATEST(current_invoice-v_comm,0)>=invoice_limit, updated_at=NOW()
                    WHERE id=r.vendor_id;
                INSERT INTO public.transactions(vendor_id,amount,type,description,reference_id)
                VALUES(r.vendor_id,-v_comm,'commission','عكس عمولة طلب ملغي #'||substr(NEW.id::text,1,8),NEW.id);
                UPDATE public.order_items SET commission_reversed=true WHERE id=r.id;
            END IF;
            IF r.track_inventory AND NOT r.inventory_restored THEN
                UPDATE public.products SET stock=stock+(SELECT quantity FROM public.order_items WHERE id=r.id), updated_at=NOW() WHERE id=(SELECT product_id FROM public.order_items WHERE id=r.id);
                UPDATE public.order_items SET inventory_restored=true WHERE id=r.id;
            END IF;
            UPDATE public.order_items SET status='cancelled' WHERE id=r.id;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS order_status_business_trigger ON public.orders;
CREATE TRIGGER order_status_business_trigger AFTER UPDATE OF status ON public.orders FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION public.handle_order_status_change();

-- بيانات التصنيفات الأساسية المستخدمة في الواجهة.
INSERT INTO public.categories(name_ar,name_en,slug,icon) VALUES
('مواقع إلكترونية','Websites','websites','fa-globe'),
('تطبيقات موبايل','Mobile Apps','mobile-apps','fa-mobile-screen-button'),
('ذكاء اصطناعي','AI Tools','ai-tools','fa-robot'),
('خدمات برمجية','Tech Services','tech-services','fa-code'),
('إلكترونيات','Electronics','electronics','fa-laptop'),
('رياضة ولياقة','Sports','sports','fa-dumbbell'),
('إكسسوارات','Accessories','accessories','fa-gem'),
('أثاث ومكتبي','Furniture & Office','furniture-office','fa-chair'),
('مفروشات','Furnishings','furnishings','fa-couch'),
('أدوات منزلية','Home Appliances','home-appliances','fa-blender')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.settings(key,value) VALUES
('store_name','تيك زون'),
('store_location','صنعاء، الجمهورية اليمنية'),
('store_email','ahmedalzubiry8@gmail.com'),
('store_whatsapp','+967776730573'),
('currency','USD'),
('currency_symbol','$')
ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=NOW();

-- ============================================================
-- RLS
-- ============================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- Helper checks.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
    SELECT COALESCE((SELECT role='admin' FROM public.users WHERE id=auth.uid()), false)
        OR COALESCE((SELECT lower(email) FROM auth.users WHERE id=auth.uid()) = 'ahmed@admin.com', false);
$$;

CREATE OR REPLACE FUNCTION public.current_vendor_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
    SELECT vendor_id FROM public.users WHERE id=auth.uid();
$$;


CREATE OR REPLACE FUNCTION public.ensure_admin_profile()
RETURNS public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth_user auth.users%ROWTYPE;
    v_profile public.users%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
    END IF;

    SELECT * INTO v_auth_user FROM auth.users WHERE id = auth.uid();
    IF lower(COALESCE(v_auth_user.email, '')) <> 'ahmed@admin.com' THEN
        RAISE EXCEPTION 'هذا الحساب ليس حساب الأدمن المسموح';
    END IF;

    INSERT INTO public.users (id,email,full_name,phone,role,user_type,is_banned,ban_reason)
    VALUES (v_auth_user.id,v_auth_user.email,
            COALESCE(v_auth_user.raw_user_meta_data->>'full_name','Admin'),
            COALESCE(v_auth_user.raw_user_meta_data->>'phone',''),
            'admin','admin',false,NULL)
    ON CONFLICT (id) DO UPDATE SET
        email=EXCLUDED.email,
        role='admin',
        user_type='admin',
        is_banned=false,
        ban_reason=NULL,
        updated_at=NOW()
    RETURNING * INTO v_profile;

    RETURN v_profile;
END;
$$;
REVOKE ALL ON FUNCTION public.ensure_admin_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_admin_profile() TO authenticated;

CREATE OR REPLACE FUNCTION public.protect_user_privileges()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
   NEW.role := OLD.role;
   NEW.user_type := OLD.user_type;
   IF NEW.vendor_id IS DISTINCT FROM OLD.vendor_id THEN
     IF NEW.vendor_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.vendors v WHERE v.id=NEW.vendor_id AND v.user_id=auth.uid()) THEN
       NEW.vendor_id := OLD.vendor_id;
     END IF;
   END IF;
   NEW.is_banned := OLD.is_banned;
   NEW.ban_reason := OLD.ban_reason;
   NEW.banned_at := OLD.banned_at;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS protect_user_privileges_trigger ON public.users;
CREATE TRIGGER protect_user_privileges_trigger BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.protect_user_privileges();

-- users: keep compatibility with existing store statistics/profile screens.
DROP POLICY IF EXISTS users_select ON public.users;
CREATE POLICY users_select ON public.users FOR SELECT USING (auth.uid() = id OR public.is_admin());
DROP POLICY IF EXISTS users_insert_self ON public.users;
CREATE POLICY users_insert_self ON public.users FOR INSERT WITH CHECK (auth.uid() = id);
DROP POLICY IF EXISTS users_update_self_or_admin ON public.users;
CREATE POLICY users_update_self_or_admin ON public.users FOR UPDATE USING (auth.uid() = id OR public.is_admin()) WITH CHECK (auth.uid() = id OR public.is_admin());
DROP POLICY IF EXISTS users_delete_admin ON public.users;
CREATE POLICY users_delete_admin ON public.users FOR DELETE USING (public.is_admin());

CREATE OR REPLACE FUNCTION public.moderate_vendor_product()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NOT NULL AND NOT public.is_admin() AND NEW.vendor_id = public.current_vendor_id() THEN
   NEW.approval_status='pending'; NEW.published_at=NULL;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS product_vendor_moderation_trigger ON public.products;
CREATE TRIGGER product_vendor_moderation_trigger BEFORE INSERT OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.moderate_vendor_product();

-- products: public active read; admin full access; vendor owns vendor products.
DROP POLICY IF EXISTS products_public_read ON public.products;
CREATE POLICY products_public_read ON public.products FOR SELECT USING ((is_active = true AND approval_status='approved') OR public.is_admin() OR vendor_id = public.current_vendor_id());
DROP POLICY IF EXISTS products_admin_insert ON public.products;
CREATE POLICY products_admin_insert ON public.products FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS products_admin_update ON public.products;
CREATE POLICY products_admin_update ON public.products FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS products_admin_delete ON public.products;
CREATE POLICY products_admin_delete ON public.products FOR DELETE USING (public.is_admin());
DROP POLICY IF EXISTS products_vendor_insert ON public.products;
CREATE POLICY products_vendor_insert ON public.products FOR INSERT WITH CHECK (vendor_id = public.current_vendor_id() AND is_vendor_product = true);
DROP POLICY IF EXISTS products_vendor_update ON public.products;
CREATE POLICY products_vendor_update ON public.products FOR UPDATE USING (vendor_id = public.current_vendor_id()) WITH CHECK (vendor_id = public.current_vendor_id());
DROP POLICY IF EXISTS products_vendor_delete ON public.products;
CREATE POLICY products_vendor_delete ON public.products FOR DELETE USING (vendor_id = public.current_vendor_id());

-- images
DROP POLICY IF EXISTS product_images_read ON public.product_images;
CREATE POLICY product_images_read ON public.product_images FOR SELECT USING (true);
DROP POLICY IF EXISTS product_images_write ON public.product_images;
CREATE POLICY product_images_write ON public.product_images FOR INSERT WITH CHECK (public.is_admin() OR EXISTS (SELECT 1 FROM public.products p WHERE p.id=product_id AND p.vendor_id=public.current_vendor_id()));
DROP POLICY IF EXISTS product_images_update ON public.product_images;
CREATE POLICY product_images_update ON public.product_images FOR UPDATE USING (public.is_admin() OR EXISTS (SELECT 1 FROM public.products p WHERE p.id=product_id AND p.vendor_id=public.current_vendor_id()));
DROP POLICY IF EXISTS product_images_delete ON public.product_images;
CREATE POLICY product_images_delete ON public.product_images FOR DELETE USING (public.is_admin() OR EXISTS (SELECT 1 FROM public.products p WHERE p.id=product_id AND p.vendor_id=public.current_vendor_id()));

-- reviews
DROP POLICY IF EXISTS product_reviews_read ON public.product_reviews;
CREATE POLICY product_reviews_read ON public.product_reviews FOR SELECT USING (true);
DROP POLICY IF EXISTS product_reviews_insert ON public.product_reviews;
CREATE POLICY product_reviews_insert ON public.product_reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS product_reviews_update ON public.product_reviews;
CREATE POLICY product_reviews_update ON public.product_reviews FOR UPDATE USING (auth.uid() = user_id OR public.is_admin()) WITH CHECK (auth.uid() = user_id OR public.is_admin());
DROP POLICY IF EXISTS product_reviews_delete ON public.product_reviews;
CREATE POLICY product_reviews_delete ON public.product_reviews FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

-- vendors
DROP POLICY IF EXISTS vendors_public_read ON public.vendors;
CREATE POLICY vendors_public_read ON public.vendors FOR SELECT USING (true);
DROP POLICY IF EXISTS vendors_admin_insert ON public.vendors;
CREATE POLICY vendors_admin_insert ON public.vendors FOR INSERT WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS vendors_self_insert ON public.vendors;
CREATE POLICY vendors_self_insert ON public.vendors FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS vendors_self_update ON public.vendors;
CREATE POLICY vendors_self_update ON public.vendors FOR UPDATE USING (user_id = auth.uid() OR public.is_admin()) WITH CHECK (user_id = auth.uid() OR public.is_admin());
DROP POLICY IF EXISTS vendors_admin_delete ON public.vendors;
CREATE POLICY vendors_admin_delete ON public.vendors FOR DELETE USING (public.is_admin());

-- orders
DROP POLICY IF EXISTS orders_read_owner_admin_vendor ON public.orders;
CREATE POLICY orders_read_owner_admin_vendor ON public.orders FOR SELECT USING (public.is_admin() OR customer_id=auth.uid() OR customer_email=(SELECT email FROM auth.users WHERE id=auth.uid()) OR vendor_id=public.current_vendor_id());
DROP POLICY IF EXISTS orders_insert_authenticated ON public.orders;
CREATE POLICY orders_insert_authenticated ON public.orders FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND (customer_id=auth.uid() OR customer_id IS NULL));
DROP POLICY IF EXISTS orders_update_admin_vendor ON public.orders;
DROP POLICY IF EXISTS orders_update_admin_only ON public.orders;
CREATE POLICY orders_update_admin_only ON public.orders FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS orders_delete_admin ON public.orders;
CREATE POLICY orders_delete_admin ON public.orders FOR DELETE USING (public.is_admin());

-- order items
DROP POLICY IF EXISTS order_items_read_related ON public.order_items;
CREATE POLICY order_items_read_related ON public.order_items FOR SELECT USING (public.is_admin() OR vendor_id=public.current_vendor_id() OR EXISTS (SELECT 1 FROM public.orders o WHERE o.id=order_id AND (o.customer_id=auth.uid() OR o.customer_email=(SELECT email FROM auth.users WHERE id=auth.uid()))));
DROP POLICY IF EXISTS order_items_insert_customer ON public.order_items;
CREATE POLICY order_items_insert_customer ON public.order_items FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.orders o WHERE o.id=order_id AND (o.customer_id=auth.uid() OR o.customer_id IS NULL) AND NOT public.is_admin())
    OR public.is_admin()
);
DROP POLICY IF EXISTS order_items_update_admin ON public.order_items;
CREATE POLICY order_items_update_admin ON public.order_items FOR UPDATE USING (public.is_admin());
DROP POLICY IF EXISTS order_items_delete_admin ON public.order_items;
CREATE POLICY order_items_delete_admin ON public.order_items FOR DELETE USING (public.is_admin());

-- custom requests
DROP POLICY IF EXISTS custom_requests_read_owner_admin ON public.custom_requests;
CREATE POLICY custom_requests_read_owner_admin ON public.custom_requests FOR SELECT USING (public.is_admin() OR customer_id=auth.uid() OR customer_email=(SELECT email FROM auth.users WHERE id=auth.uid()));
DROP POLICY IF EXISTS custom_requests_insert_authenticated ON public.custom_requests;
CREATE POLICY custom_requests_insert_authenticated ON public.custom_requests FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS custom_requests_update_admin ON public.custom_requests;
CREATE POLICY custom_requests_update_admin ON public.custom_requests FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
DROP POLICY IF EXISTS custom_requests_delete_admin ON public.custom_requests;
CREATE POLICY custom_requests_delete_admin ON public.custom_requests FOR DELETE USING (public.is_admin());

-- transactions/payments: admin or owning vendor.
DROP POLICY IF EXISTS transactions_read ON public.transactions;
CREATE POLICY transactions_read ON public.transactions FOR SELECT USING (public.is_admin() OR vendor_id=public.current_vendor_id());
DROP POLICY IF EXISTS transactions_insert ON public.transactions;
CREATE POLICY transactions_insert ON public.transactions FOR INSERT WITH CHECK (public.is_admin() OR vendor_id=public.current_vendor_id());
DROP POLICY IF EXISTS payments_read ON public.payments;
CREATE POLICY payments_read ON public.payments FOR SELECT USING (public.is_admin() OR vendor_id=public.current_vendor_id());
DROP POLICY IF EXISTS payments_insert ON public.payments;
CREATE POLICY payments_insert ON public.payments FOR INSERT WITH CHECK (public.is_admin());

-- categories/settings public read.
DROP POLICY IF EXISTS categories_read ON public.categories;
CREATE POLICY categories_read ON public.categories FOR SELECT USING (true);
DROP POLICY IF EXISTS settings_read ON public.settings;
CREATE POLICY settings_read ON public.settings FOR SELECT USING (true);
DROP POLICY IF EXISTS settings_admin_write ON public.settings;
CREATE POLICY settings_admin_write ON public.settings FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Storage buckets used by the existing project.
INSERT INTO storage.buckets (id, name, public) VALUES
('product-images','product-images',true),
('payment-proofs','payment-proofs',true)
ON CONFLICT (id) DO UPDATE SET public=EXCLUDED.public;

DROP POLICY IF EXISTS product_images_storage_read ON storage.objects;
CREATE POLICY product_images_storage_read ON storage.objects FOR SELECT USING (bucket_id='product-images');
DROP POLICY IF EXISTS product_images_storage_insert ON storage.objects;
CREATE POLICY product_images_storage_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='product-images');
DROP POLICY IF EXISTS product_images_storage_update ON storage.objects;
CREATE POLICY product_images_storage_update ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='product-images');
DROP POLICY IF EXISTS product_images_storage_delete ON storage.objects;
CREATE POLICY product_images_storage_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id='product-images');

DROP POLICY IF EXISTS payment_proofs_storage_read ON storage.objects;
CREATE POLICY payment_proofs_storage_read ON storage.objects FOR SELECT USING (bucket_id='payment-proofs');
DROP POLICY IF EXISTS payment_proofs_storage_insert ON storage.objects;
CREATE POLICY payment_proofs_storage_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='payment-proofs');
DROP POLICY IF EXISTS payment_proofs_storage_update ON storage.objects;
CREATE POLICY payment_proofs_storage_update ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='payment-proofs');
DROP POLICY IF EXISTS payment_proofs_storage_delete ON storage.objects;
CREATE POLICY payment_proofs_storage_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id='payment-proofs');

-- ملاحظة: تأكد من تعطيل Confirm email من Authentication > Providers > Email إذا أردت
-- إنشاء الحساب ثم تسجيل الدخول فوراً من الواجهة بدون انتظار رسالة البريد.

-- Security hardening: order creation and commission changes are server-side RPCs.
REVOKE INSERT ON public.orders FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.order_items FROM anon, authenticated;
REVOKE INSERT ON public.transactions FROM anon, authenticated;
REVOKE UPDATE, DELETE ON public.transactions FROM anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.orders TO authenticated;
GRANT SELECT ON public.order_items TO authenticated;
GRANT SELECT ON public.transactions TO authenticated;
-- ============================================================
-- تيك زون | إصلاح جذري لـ RLS + نظام التقارير الإداري
-- هذا الملف ترقية غير مدمرة: لا يحذف المستخدمين/المنتجات/الطلبات.
-- ============================================================

-- 1) دالة الأدمن: لا تقرأ public.users عبر RLS أثناء تقييم الـ policies.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
SET row_security = off
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_email text;
    v_role text;
BEGIN
    IF v_uid IS NULL THEN
        RETURN false;
    END IF;

    SELECT lower(email) INTO v_email FROM auth.users WHERE id = v_uid;
    IF v_email = 'ahmed@admin.com' THEN
        RETURN true;
    END IF;

    SELECT role INTO v_role FROM public.users WHERE id = v_uid;
    RETURN lower(COALESCE(v_role,'')) = 'admin';
END;
$$;

CREATE OR REPLACE FUNCTION public.current_vendor_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
    SELECT vendor_id FROM public.users WHERE id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;
REVOKE ALL ON FUNCTION public.current_vendor_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_vendor_id() TO authenticated;

-- 2) إعادة بناء سياسات orders بدون أي self-reference مباشر.
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS orders_read_owner_admin_vendor ON public.orders;
DROP POLICY IF EXISTS orders_insert_authenticated ON public.orders;
DROP POLICY IF EXISTS orders_update_admin_only ON public.orders;
DROP POLICY IF EXISTS orders_update_admin_vendor ON public.orders;
DROP POLICY IF EXISTS orders_delete_admin ON public.orders;

CREATE POLICY orders_read_owner_admin_vendor ON public.orders
FOR SELECT TO authenticated
USING (
    public.is_admin()
    OR customer_id = auth.uid()
    OR customer_email = (SELECT email FROM auth.users WHERE id = auth.uid())
    OR vendor_id = public.current_vendor_id()
);

-- إنشاء الطلبات الفعلية يتم الآن عبر RPC الآمن أدناه، وليس INSERT مباشر.
CREATE POLICY orders_update_admin_only ON public.orders
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY orders_delete_admin ON public.orders
FOR DELETE TO authenticated
USING (public.is_admin());

REVOKE INSERT ON public.orders FROM anon, authenticated;

-- 3) إزالة السياسات القديمة المتداخلة لـ order_items وإعادة بنائها.
DROP POLICY IF EXISTS order_items_read_related ON public.order_items;
DROP POLICY IF EXISTS order_items_insert_customer ON public.order_items;
DROP POLICY IF EXISTS order_items_update_admin ON public.order_items;
DROP POLICY IF EXISTS order_items_delete_admin ON public.order_items;

CREATE POLICY order_items_read_related ON public.order_items
FOR SELECT TO authenticated
USING (
    public.is_admin()
    OR vendor_id = public.current_vendor_id()
    OR EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = order_items.order_id
          AND (o.customer_id = auth.uid() OR o.customer_email = (SELECT email FROM auth.users WHERE id = auth.uid()))
    )
);

CREATE POLICY order_items_update_admin ON public.order_items
FOR UPDATE TO authenticated
USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE POLICY order_items_delete_admin ON public.order_items
FOR DELETE TO authenticated
USING (public.is_admin());

REVOKE INSERT ON public.order_items FROM anon, authenticated;

-- 4) تقرير إداري واحد آمن. القراءة تتم داخل SECURITY DEFINER مع row_security=off.
-- لا توجد فلاتر تاريخ أو حالة طلب في النظام الجديد.
CREATE OR REPLACE FUNCTION public.get_admin_report_bundle()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
SET row_security = off
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_email text;
    v_role text;
    result jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
    END IF;

    SELECT lower(email) INTO v_email FROM auth.users WHERE id = v_uid;
    SELECT role INTO v_role FROM public.users WHERE id = v_uid;

    IF v_email <> 'ahmed@admin.com' AND lower(COALESCE(v_role,'')) <> 'admin' THEN
        RAISE EXCEPTION 'غير مصرح: هذا التقرير متاح للأدمن فقط';
    END IF;

    SELECT jsonb_build_object(
        'generated_at', now(),
        'store', jsonb_build_object(
            'name', COALESCE((SELECT value FROM public.settings WHERE key='store_name' LIMIT 1), 'تيك زون'),
            'location', 'صنعاء، الجمهورية اليمنية',
            'email', 'ahmedalzubiry8@gmail.com',
            'whatsapp', '+967776730573',
            'currency', 'USD'
        ),
        'orders', COALESCE((
            SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
            FROM (
                SELECT id, customer_name, customer_email, customer_phone, total_amount, status, created_at, payment_method
                FROM public.orders
                ORDER BY created_at DESC
            ) x
        ), '[]'::jsonb),
        'products', COALESCE((
            SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
            FROM (
                SELECT p.id, p.name, p.category, p.sub_category, p.price, p.old_price, p.stock,
                       p.approval_status, p.is_active, p.created_at,
                       COALESCE(c.name_ar, p.category) AS category_name,
                       COALESCE(sc.name_ar, p.sub_category) AS sub_category_name
                FROM public.products p
                LEFT JOIN public.categories c ON c.slug = p.category
                LEFT JOIN public.categories sc ON sc.slug = p.sub_category
                ORDER BY p.created_at DESC
            ) x
        ), '[]'::jsonb),
        'vendors', COALESCE((
            SELECT jsonb_agg(to_jsonb(x) ORDER BY x.store_name)
            FROM (
                SELECT v.id, v.store_name, v.phone, v.commission_rate, v.current_invoice,
                       v.invoice_limit, v.is_restricted,
                       COALESCE((SELECT SUM(t.amount) FROM public.transactions t WHERE t.vendor_id=v.id AND t.type='commission'),0) AS total_commissions,
                       COALESCE((SELECT SUM(t.amount) FROM public.transactions t WHERE t.vendor_id=v.id AND t.type='payment'),0) AS total_paid
                FROM public.vendors v
                ORDER BY v.store_name
            ) x
        ), '[]'::jsonb),
        'customers', COALESCE((
            SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
            FROM (
                SELECT id, email, full_name, phone, user_type, created_at
                FROM public.users
                ORDER BY created_at DESC
            ) x
        ), '[]'::jsonb)
    ) INTO result;

    RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_report_bundle() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_report_bundle() TO authenticated;

-- 5) إصلاح اعتماد الأدمن الحالي بدون الاعتماد على policy متكررة.
CREATE OR REPLACE FUNCTION public.ensure_admin_profile()
RETURNS public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
SET row_security = off
AS $$
DECLARE
    v_auth_user auth.users%ROWTYPE;
    v_profile public.users%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'يجب تسجيل الدخول أولاً';
    END IF;

    SELECT * INTO v_auth_user FROM auth.users WHERE id = auth.uid();
    IF lower(COALESCE(v_auth_user.email,'')) <> 'ahmed@admin.com' THEN
        RAISE EXCEPTION 'هذا الحساب ليس حساب الأدمن المسموح';
    END IF;

    INSERT INTO public.users (id,email,full_name,phone,role,user_type,is_banned,ban_reason)
    VALUES (v_auth_user.id,v_auth_user.email,
            COALESCE(v_auth_user.raw_user_meta_data->>'full_name','Admin'),
            COALESCE(v_auth_user.raw_user_meta_data->>'phone',''),
            'admin','admin',false,NULL)
    ON CONFLICT (id) DO UPDATE SET
        email=EXCLUDED.email,
        role='admin',
        user_type='admin',
        is_banned=false,
        ban_reason=NULL,
        updated_at=NOW()
    RETURNING * INTO v_profile;

    RETURN v_profile;
END;
$$;
REVOKE ALL ON FUNCTION public.ensure_admin_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_admin_profile() TO authenticated;

-- انتهى الإصلاح.
