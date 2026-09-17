-- تيك زون | إصلاح تقرير المنتجات والمخزون
-- إصلاح نهائي: جدول categories يستخدم name_ar/name_en وليس name.
-- هذا الملف لا يحذف أي بيانات.

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

    IF COALESCE(v_email, '') <> 'ahmed@admin.com' AND lower(COALESCE(v_role,'')) <> 'admin' THEN
        RAISE EXCEPTION 'غير مصرح: هذا التقرير متاح للأدمن فقط';
    END IF;

    SELECT jsonb_build_object(
        'generated_at', now(),
        'store', jsonb_build_object(
            'name', COALESCE((SELECT value FROM public.settings WHERE key='store_name' LIMIT 1), 'تيك زون'),
            'location', COALESCE((SELECT value FROM public.settings WHERE key='store_location' LIMIT 1), 'اليمن'),
            'email', COALESCE((SELECT value FROM public.settings WHERE key='store_email' LIMIT 1), ''),
            'whatsapp', COALESCE((SELECT value FROM public.settings WHERE key='store_whatsapp' LIMIT 1), ''),
            'currency', COALESCE((SELECT value FROM public.settings WHERE key='currency' LIMIT 1), 'USD')
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
