-- ============================================================
-- إصلاح حساب الأدمن: ahmed@admin.com
-- شغّل هذا الملف مرة واحدة في Supabase SQL Editor.
-- لا يحذف أي مستخدم أو منتج أو طلب.
-- ============================================================

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
    VALUES (
        v_auth_user.id,
        v_auth_user.email,
        COALESCE(v_auth_user.raw_user_meta_data->>'full_name','Admin'),
        COALESCE(v_auth_user.raw_user_meta_data->>'phone',''),
        'admin','admin',false,NULL
    )
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

-- إصلاح الحساب الحالي إن كان موجوداً في Authentication > Users.
INSERT INTO public.users (id,email,full_name,phone,role,user_type,is_banned,ban_reason)
SELECT
    a.id,
    a.email,
    COALESCE(a.raw_user_meta_data->>'full_name','Admin'),
    COALESCE(a.raw_user_meta_data->>'phone',''),
    'admin','admin',false,NULL
FROM auth.users a
WHERE lower(COALESCE(a.email,''))='ahmed@admin.com'
ON CONFLICT (id) DO UPDATE SET
    email=EXCLUDED.email,
    role='admin',
    user_type='admin',
    is_banned=false,
    ban_reason=NULL,
    updated_at=NOW();

-- اجعل التحقق المركزي يعرف الأدمن الصحيح.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE((SELECT role='admin' FROM public.users WHERE id=auth.uid()), false)
        OR COALESCE((SELECT lower(email) FROM auth.users WHERE id=auth.uid())='ahmed@admin.com', false);
$$;

SELECT id,email,role,user_type,is_banned
FROM public.users
WHERE lower(email)='ahmed@admin.com';
