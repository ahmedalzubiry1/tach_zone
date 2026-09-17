-- ============================================================
-- تيك زون | ترقية آمنة لقاعدة البيانات الحالية
-- IMPORTANT: لا يحذف المستخدمين/المنتجات/الطلبات الحالية.
-- نفّذه مرة واحدة بعد database.sql السابق.
-- ============================================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) NOT NULL DEFAULT 'approved';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS track_inventory BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS subtotal_amount NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS shipping_fee NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS status VARCHAR(30) NOT NULL DEFAULT 'pending';
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS commission_posted BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS commission_reversed BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS inventory_restored BOOLEAN NOT NULL DEFAULT false;

UPDATE public.products SET approval_status='approved' WHERE approval_status IS NULL OR approval_status='';
UPDATE public.products SET published_at=COALESCE(published_at, created_at) WHERE is_active=true AND approval_status='approved';
UPDATE public.orders SET subtotal_amount=GREATEST(total_amount-shipping_fee,0) WHERE subtotal_amount=0 AND total_amount>0;

ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_approval_status_check;
ALTER TABLE public.products ADD CONSTRAINT products_approval_status_check CHECK (approval_status IN ('pending','approved','rejected'));
ALTER TABLE public.order_items DROP CONSTRAINT IF EXISTS order_items_status_check;
ALTER TABLE public.order_items ADD CONSTRAINT order_items_status_check CHECK (status IN ('pending','confirmed','completed','cancelled'));

CREATE OR REPLACE FUNCTION public.settle_vendor_invoice(p_vendor_id UUID,p_amount NUMERIC,p_payment_method TEXT,p_receipt_number TEXT DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE current_amount NUMERIC;
BEGIN
 IF NOT public.is_admin() THEN RAISE EXCEPTION 'غير مصرح: هذه العملية للأدمن فقط'; END IF;
 IF p_amount IS NULL OR p_amount<=0 THEN RAISE EXCEPTION 'المبلغ غير صالح'; END IF;
 SELECT current_invoice INTO current_amount FROM public.vendors WHERE id=p_vendor_id FOR UPDATE;
 IF current_amount IS NULL THEN RAISE EXCEPTION 'التاجر غير موجود'; END IF;
 IF p_amount>current_amount+0.01 THEN RAISE EXCEPTION 'المبلغ أكبر من الفاتورة الحالية'; END IF;
 UPDATE public.vendors SET current_invoice=GREATEST(current_invoice-p_amount,0), is_restricted=GREATEST(current_invoice-p_amount,0)>=invoice_limit, total_earned=total_earned+p_amount, updated_at=NOW() WHERE id=p_vendor_id;
 INSERT INTO public.transactions(vendor_id,amount,type,description,reference_id) VALUES(p_vendor_id,p_amount,'payment','سداد فاتورة عبر '||COALESCE(p_payment_method,''),NULL);
END; $$;

CREATE OR REPLACE FUNCTION public.create_order_secure(
 p_items JSONB,p_customer_name TEXT,p_customer_email TEXT,p_customer_phone TEXT,p_payment_method TEXT,
 p_payment_details JSONB DEFAULT '{}'::jsonb,p_payment_proof_path TEXT DEFAULT NULL,p_shipping_address TEXT DEFAULT NULL,
 p_location_lat NUMERIC DEFAULT NULL,p_location_lng NUMERIC DEFAULT NULL,p_location_address TEXT DEFAULT NULL,p_notes TEXT DEFAULT NULL)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_user UUID:=auth.uid(); v_order UUID; v_item JSONB; v_product public.products%ROWTYPE; v_qty INTEGER; v_subtotal NUMERIC(12,2):=0; v_shipping NUMERIC(12,2); v_vendor UUID; v_vendor_count INTEGER;
BEGIN
 IF v_user IS NULL OR COALESCE((auth.jwt()->>'is_anonymous')::boolean,false) THEN RAISE EXCEPTION 'يجب تسجيل الدخول بحساب دائم'; END IF;
 IF COALESCE((SELECT is_banned FROM public.users WHERE id=v_user),false) THEN RAISE EXCEPTION 'الحساب مقيد ولا يمكنه الشراء'; END IF;
 IF jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items)=0 THEN RAISE EXCEPTION 'السلة فارغة'; END IF;
 IF p_payment_method NOT IN ('bank','wallet','cash') THEN RAISE EXCEPTION 'طريقة الدفع غير متاحة'; END IF;
 IF COALESCE(length(trim(p_shipping_address)),0)<5 THEN RAISE EXCEPTION 'عنوان الشحن غير صالح'; END IF;
 FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
   v_qty:=COALESCE((v_item->>'quantity')::INTEGER,0); IF v_qty<=0 OR v_qty>100 THEN RAISE EXCEPTION 'كمية المنتج غير صالحة'; END IF;
   SELECT * INTO v_product FROM public.products WHERE id=(v_item->>'id')::UUID FOR UPDATE;
   IF NOT FOUND OR NOT v_product.is_active OR v_product.approval_status<>'approved' THEN RAISE EXCEPTION 'أحد المنتجات غير متاح حالياً'; END IF;
   IF v_product.track_inventory AND v_product.stock<v_qty THEN RAISE EXCEPTION 'المخزون غير كافٍ للمنتج %',v_product.name; END IF;
   v_subtotal:=v_subtotal+(v_product.price*v_qty);
 END LOOP;
 v_shipping:=CASE WHEN v_subtotal>200 THEN 0 ELSE 15 END;
 SELECT count(DISTINCT p.vendor_id),min(p.vendor_id) INTO v_vendor_count,v_vendor FROM public.products p WHERE p.id IN (SELECT (value->>'id')::UUID FROM jsonb_array_elements(p_items));
 INSERT INTO public.orders(order_number,customer_id,vendor_id,customer_name,customer_email,customer_phone,subtotal_amount,shipping_fee,total_amount,status,payment_method,payment_details,payment_proof_url,shipping_address,location_lat,location_lng,location_address,items_count,notes)
 VALUES('TZ-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISS')||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6),v_user,CASE WHEN v_vendor_count=1 THEN v_vendor ELSE NULL END,COALESCE(p_customer_name,''),COALESCE(p_customer_email,''),COALESCE(p_customer_phone,''),v_subtotal,v_shipping,v_subtotal+v_shipping,'pending',p_payment_method,COALESCE(p_payment_details,'{}'::jsonb),p_payment_proof_path,p_shipping_address,p_location_lat,p_location_lng,p_location_address,jsonb_array_length(p_items),p_notes) RETURNING id INTO v_order;
 FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
   v_qty:=(v_item->>'quantity')::INTEGER; SELECT * INTO v_product FROM public.products WHERE id=(v_item->>'id')::UUID FOR UPDATE;
   INSERT INTO public.order_items(order_id,product_id,vendor_id,product_name,quantity,price,subtotal,status) VALUES(v_order,v_product.id,v_product.vendor_id,v_product.name,v_qty,v_product.price,v_product.price*v_qty,'pending');
   IF v_product.track_inventory THEN UPDATE public.products SET stock=stock-v_qty,updated_at=NOW() WHERE id=v_product.id; END IF;
 END LOOP;
 RETURN v_order;
END; $$;

CREATE OR REPLACE FUNCTION public.confirm_vendor_order(p_order_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_vendor UUID:=public.current_vendor_id(); v_commission NUMERIC(12,2):=0; v_items INTEGER:=0; v_remaining INTEGER:=0; v_new_invoice NUMERIC(12,2); v_limit NUMERIC(12,2);
BEGIN
 IF v_vendor IS NULL THEN RAISE EXCEPTION 'الحساب ليس حساب تاجر'; END IF;
 IF (SELECT is_restricted FROM public.vendors WHERE id=v_vendor) THEN RAISE EXCEPTION 'التاجر مقيد حالياً'; END IF;
 SELECT count(*),COALESCE(sum(oi.subtotal),0)*(v.commission_rate/100.0) INTO v_items,v_commission FROM public.order_items oi JOIN public.vendors v ON v.id=oi.vendor_id WHERE oi.order_id=p_order_id AND oi.vendor_id=v_vendor AND oi.status='pending' AND NOT oi.commission_posted;
 IF v_items=0 THEN RAISE EXCEPTION 'لا توجد عناصر معلقة لهذا التاجر في الطلب'; END IF;
 UPDATE public.order_items SET status='confirmed',commission_posted=true WHERE order_id=p_order_id AND vendor_id=v_vendor AND status='pending' AND NOT commission_posted;
 UPDATE public.vendors SET current_invoice=current_invoice+v_commission,is_restricted=(current_invoice+v_commission)>=invoice_limit,updated_at=NOW() WHERE id=v_vendor RETURNING current_invoice,invoice_limit INTO v_new_invoice,v_limit;
 INSERT INTO public.transactions(vendor_id,amount,type,description,reference_id) VALUES(v_vendor,v_commission,'commission','عمولة طلب #'||substr(p_order_id::text,1,8),p_order_id);
 SELECT count(*) INTO v_remaining FROM public.order_items WHERE order_id=p_order_id AND status='pending';
 IF v_remaining=0 THEN UPDATE public.orders SET status='confirmed',updated_at=NOW() WHERE id=p_order_id AND status='pending'; END IF;
 RETURN jsonb_build_object('commission',v_commission,'invoice',v_new_invoice,'invoice_limit',v_limit,'order_completed',v_remaining=0);
END; $$;

CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE r RECORD; v_comm NUMERIC(12,2);
BEGIN
 IF NEW.status IN ('confirmed','completed') AND OLD.status NOT IN ('confirmed','completed') THEN
  FOR r IN SELECT oi.id,oi.vendor_id,oi.subtotal,v.commission_rate FROM public.order_items oi JOIN public.vendors v ON v.id=oi.vendor_id WHERE oi.order_id=NEW.id AND oi.status='pending' AND NOT oi.commission_posted LOOP
   v_comm:=round(r.subtotal*r.commission_rate/100.0,2);
   UPDATE public.order_items SET status='confirmed',commission_posted=true WHERE id=r.id;
   UPDATE public.vendors SET current_invoice=current_invoice+v_comm,is_restricted=(current_invoice+v_comm)>=invoice_limit,updated_at=NOW() WHERE id=r.vendor_id;
   INSERT INTO public.transactions(vendor_id,amount,type,description,reference_id) VALUES(r.vendor_id,v_comm,'commission','عمولة طلب #'||substr(NEW.id::text,1,8),NEW.id);
  END LOOP;
 ELSIF NEW.status='cancelled' AND OLD.status<>'cancelled' THEN
  FOR r IN SELECT oi.id,oi.vendor_id,oi.subtotal,v.commission_rate,oi.commission_posted,oi.commission_reversed,oi.inventory_restored,oi.product_id,oi.quantity,p.track_inventory FROM public.order_items oi JOIN public.vendors v ON v.id=oi.vendor_id LEFT JOIN public.products p ON p.id=oi.product_id WHERE oi.order_id=NEW.id LOOP
   IF r.commission_posted AND NOT r.commission_reversed THEN
    v_comm:=round(r.subtotal*r.commission_rate/100.0,2); UPDATE public.vendors SET current_invoice=GREATEST(current_invoice-v_comm,0),is_restricted=GREATEST(current_invoice-v_comm,0)>=invoice_limit,updated_at=NOW() WHERE id=r.vendor_id; INSERT INTO public.transactions(vendor_id,amount,type,description,reference_id) VALUES(r.vendor_id,-v_comm,'commission','عكس عمولة طلب ملغي #'||substr(NEW.id::text,1,8),NEW.id); UPDATE public.order_items SET commission_reversed=true WHERE id=r.id;
   END IF;
   IF r.track_inventory AND NOT r.inventory_restored THEN UPDATE public.products SET stock=stock+r.quantity,updated_at=NOW() WHERE id=r.product_id; UPDATE public.order_items SET inventory_restored=true WHERE id=r.id; END IF;
   UPDATE public.order_items SET status='cancelled' WHERE id=r.id;
  END LOOP;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS order_status_business_trigger ON public.orders;
CREATE TRIGGER order_status_business_trigger AFTER UPDATE OF status ON public.orders FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION public.handle_order_status_change();


-- Prevent privilege escalation through editable Auth metadata.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 INSERT INTO public.users(id,email,full_name,phone,role,user_type)
 VALUES(NEW.id,NEW.email,COALESCE(NEW.raw_user_meta_data->>'full_name',''),COALESCE(NEW.raw_user_meta_data->>'phone',''),
   CASE WHEN lower(COALESCE(NEW.email,''))='ahmed@admin.com' THEN 'admin' WHEN COALESCE(NEW.raw_user_meta_data->>'user_type','')='vendor' THEN 'vendor' ELSE 'customer' END,
   CASE WHEN lower(COALESCE(NEW.email,''))='ahmed@admin.com' OR COALESCE(NEW.raw_user_meta_data->>'role','')='admin' OR COALESCE(NEW.raw_user_meta_data->>'user_type','')='admin' THEN 'admin' WHEN COALESCE(NEW.raw_user_meta_data->>'user_type','')='vendor' THEN 'vendor' ELSE 'customer' END)
 ON CONFLICT(id) DO UPDATE SET email=EXCLUDED.email,full_name=EXCLUDED.full_name,phone=EXCLUDED.phone,role=EXCLUDED.role,user_type=EXCLUDED.user_type,updated_at=NOW();
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


CREATE OR REPLACE FUNCTION public.moderate_vendor_product()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF auth.uid() IS NOT NULL AND NOT public.is_admin() AND NEW.vendor_id = public.current_vendor_id() THEN
   IF TG_OP='INSERT' THEN NEW.approval_status='pending'; NEW.published_at=NULL;
   ELSE NEW.approval_status='pending'; NEW.published_at=NULL; END IF;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS product_vendor_moderation_trigger ON public.products;
CREATE TRIGGER product_vendor_moderation_trigger BEFORE INSERT OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.moderate_vendor_product();

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

-- Marketplace visibility and vendor access.
DROP POLICY IF EXISTS products_public_read ON public.products;
CREATE POLICY products_public_read ON public.products FOR SELECT USING ((is_active=true AND approval_status='approved') OR public.is_admin() OR vendor_id=public.current_vendor_id());
DROP POLICY IF EXISTS order_items_read_related ON public.order_items;
CREATE POLICY order_items_read_related ON public.order_items FOR SELECT USING (public.is_admin() OR vendor_id=public.current_vendor_id() OR EXISTS (SELECT 1 FROM public.orders o WHERE o.id=order_id AND (o.customer_id=auth.uid() OR o.customer_email=(SELECT email FROM auth.users WHERE id=auth.uid()))));
DROP POLICY IF EXISTS orders_read_owner_admin_vendor ON public.orders;
CREATE POLICY orders_read_owner_admin_vendor ON public.orders FOR SELECT USING (public.is_admin() OR customer_id=auth.uid() OR customer_email=(SELECT email FROM auth.users WHERE id=auth.uid()) OR vendor_id=public.current_vendor_id() OR EXISTS (SELECT 1 FROM public.order_items oi WHERE oi.order_id=id AND oi.vendor_id=public.current_vendor_id()));

-- Direct customer writes to orders/items/transactions are disabled. Checkout and commissions use RPCs.
REVOKE INSERT ON public.orders FROM anon,authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.order_items FROM anon,authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.transactions FROM anon,authenticated;
GRANT SELECT,UPDATE,DELETE ON public.orders TO authenticated;
GRANT SELECT ON public.order_items TO authenticated;
GRANT SELECT ON public.transactions TO authenticated;

-- Payment proofs are private; product images remain public because they are storefront media.
UPDATE storage.buckets SET public=false WHERE id='payment-proofs';
DROP POLICY IF EXISTS payment_proofs_storage_read ON storage.objects;
DROP POLICY IF EXISTS payment_proofs_storage_insert ON storage.objects;
DROP POLICY IF EXISTS payment_proofs_storage_update ON storage.objects;
DROP POLICY IF EXISTS payment_proofs_storage_delete ON storage.objects;
CREATE POLICY payment_proofs_storage_read ON storage.objects FOR SELECT TO authenticated USING (bucket_id='payment-proofs' AND (owner_id=auth.uid()::text OR public.is_admin()));
CREATE POLICY payment_proofs_storage_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='payment-proofs' AND (name LIKE auth.uid()::text || '/%'));
CREATE POLICY payment_proofs_storage_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id='payment-proofs' AND (owner_id=auth.uid()::text OR public.is_admin()));

-- Product image uploads: admin anywhere, vendor inside its own folder.
DROP POLICY IF EXISTS product_images_storage_insert ON storage.objects;
DROP POLICY IF EXISTS product_images_storage_update ON storage.objects;
DROP POLICY IF EXISTS product_images_storage_delete ON storage.objects;
CREATE POLICY product_images_storage_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='product-images' AND (public.is_admin() OR name LIKE public.current_vendor_id()::text || '/%'));
CREATE POLICY product_images_storage_update ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='product-images' AND (public.is_admin() OR name LIKE public.current_vendor_id()::text || '/%')) WITH CHECK (bucket_id='product-images' AND (public.is_admin() OR name LIKE public.current_vendor_id()::text || '/%'));
CREATE POLICY product_images_storage_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id='product-images' AND (public.is_admin() OR name LIKE public.current_vendor_id()::text || '/%'));

-- Default store settings for marketplace behavior.
INSERT INTO public.settings(key,value) VALUES
('default_commission_rate','3'),('invoice_limit','100'),('free_shipping_threshold','200'),('standard_shipping_fee','15'),('require_product_approval','true')
ON CONFLICT(key) DO NOTHING;

-- Refresh PostgREST schema cache after the migration.
NOTIFY pgrst, 'reload schema';


-- ============================================================
-- إصلاح صلاحية الأدمن ahmed@admin.com بشكل موثوق.
-- يمكن تشغيل هذا الجزء بعد تسجيل/إنشاء الحساب في Supabase Auth.
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

    INSERT INTO public.users (id, email, full_name, phone, role, user_type, is_banned, ban_reason)
    VALUES (
        v_auth_user.id,
        v_auth_user.email,
        COALESCE(v_auth_user.raw_user_meta_data->>'full_name', 'Admin'),
        COALESCE(v_auth_user.raw_user_meta_data->>'phone', ''),
        'admin',
        'admin',
        false,
        NULL
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        role = 'admin',
        user_type = 'admin',
        is_banned = false,
        ban_reason = NULL,
        updated_at = NOW()
    RETURNING * INTO v_profile;

    RETURN v_profile;
END;
$$;

REVOKE ALL ON FUNCTION public.ensure_admin_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_admin_profile() TO authenticated;

-- إصلاح الحساب إذا كان موجوداً بالفعل في Auth.
INSERT INTO public.users (id, email, full_name, phone, role, user_type, is_banned, ban_reason)
SELECT
    a.id,
    a.email,
    COALESCE(a.raw_user_meta_data->>'full_name', 'Admin'),
    COALESCE(a.raw_user_meta_data->>'phone', ''),
    'admin',
    'admin',
    false,
    NULL
FROM auth.users a
WHERE lower(COALESCE(a.email, '')) = 'ahmed@admin.com'
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    role = 'admin',
    user_type = 'admin',
    is_banned = false,
    ban_reason = NULL,
    updated_at = NOW();

-- تحديث دالة التحقق بحيث تعتمد على البريد الصحيح أو role داخل public.users.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE((SELECT role='admin' FROM public.users WHERE id=auth.uid()), false)
        OR COALESCE((SELECT lower(email) FROM auth.users WHERE id=auth.uid()) = 'ahmed@admin.com', false);
$$;

SELECT id, email, role, user_type, is_banned
FROM public.users
WHERE lower(email) = 'ahmed@admin.com';
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
