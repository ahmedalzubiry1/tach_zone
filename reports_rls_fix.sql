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
