// Reports module - kept external to prevent HTML parser issues and guarantee clean execution.
        async function fetchAdminReportBundle() {
            showLoading('جاري تجهيز التقرير...');
            try {
                const { data, error } = await supabaseClient.rpc('get_admin_report_bundle');
                if (error) throw error;
                if (!data) throw new Error('لم تُرجع قاعدة البيانات بيانات التقرير.');
                return data;
            } finally {
                hideLoading();
            }
        }

        function escapeReport(value) {
            return String(value ?? '-').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
        }

        function moneyReport(value) {
            const n = Number(value || 0);
            return `${STORE_INFO.currencySymbol}${n.toFixed(2)}`;
        }

        function reportDate(value) {
            if (!value) return '-';
            return new Date(value).toLocaleString('ar-YE', {year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'});
        }

        function reportStatus(value) {
            const map={pending:'قيد الانتظار',confirmed:'مؤكد',processing:'قيد التجهيز',shipped:'تم الشحن',delivered:'تم التسليم',cancelled:'ملغي',completed:'مكتمل'};
            return map[value] || value || '-';
        }

        function openPrintReport(titleAr, titleEn, bodyHtml, summaryHtml='') {
            const w=window.open('', '_blank', 'width=1200,height=900');
            if(!w){ alert('يرجى السماح بالنوافذ المنبثقة لفتح التقرير.'); return; }
            const logo='assets/emage/log.jpeg';
            w.document.write(`<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>${escapeReport(titleAr)}</title><link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800;900&display=swap" rel="stylesheet"><style>
            @page{size:A4;margin:12mm}*{box-sizing:border-box}body{font-family:Tajawal,Arial,sans-serif;color:#172033;background:#fff;margin:0;direction:rtl}.toolbar{display:flex;justify-content:center;gap:10px;margin:0 0 16px}.toolbar button{border:0;border-radius:9px;padding:10px 18px;background:#0f766e;color:#fff;font-family:inherit;cursor:pointer}.sheet{max-width:1000px;margin:auto}.header{border-bottom:3px solid #0f766e;padding-bottom:18px;display:flex;justify-content:space-between;align-items:center;gap:20px}.brand{display:flex;align-items:center;gap:14px}.brand img{width:70px;height:70px;object-fit:contain;border-radius:12px}.brand h1{margin:0;font-size:25px}.brand p{margin:3px 0 0;color:#64748b}.en{text-align:left;direction:ltr}.title{text-align:center;margin:24px 0 16px}.title h2{margin:0;font-size:24px}.title p{margin:5px 0;color:#64748b;direction:ltr}.meta{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:12px 0 18px}.meta div{background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:10px}.meta b{display:block;font-size:12px;color:#64748b}.summary{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin-bottom:20px}.metric{border:1px solid #e2e8f0;border-radius:12px;padding:13px;text-align:center}.metric strong{display:block;font-size:20px;color:#0f766e}.metric span{font-size:12px;color:#64748b}.section{margin-top:18px}.section h3{font-size:16px;border-right:4px solid #0f766e;padding-right:9px}.table-wrap{overflow:visible}table{width:100%;border-collapse:collapse;font-size:11px;margin-top:8px}thead{display:table-header-group}th{background:#17324d;color:#fff;padding:9px;border:1px solid #17324d}td{padding:8px;border:1px solid #dbe2ea;vertical-align:top}tbody tr:nth-child(even){background:#f8fafc}.footer{margin-top:32px;border-top:1px solid #cbd5e1;padding-top:18px;display:flex;justify-content:space-between;gap:30px}.signature{text-align:center;min-width:180px}.line{border-bottom:1px solid #334155;margin-top:35px}.small{font-size:10px;color:#64748b}.ltr{direction:ltr;text-align:left}.status{font-weight:700}.no-data{text-align:center;padding:25px;color:#64748b}@media print{.toolbar{display:none!important}.sheet{max-width:none}.header{break-inside:avoid}.section{break-inside:auto}table{page-break-inside:auto}tr{page-break-inside:avoid;page-break-after:auto}}@media(max-width:700px){.meta{grid-template-columns:1fr}.header,.footer{flex-direction:column}.en{text-align:right;direction:ltr}}
            </style></head><body><div class="toolbar"><button onclick="window.print()">🖨 طباعة / حفظ PDF</button><button onclick="window.close()">إغلاق</button></div><main class="sheet"><header class="header"><div class="brand"><img src="${logo}" onerror="this.style.display='none'"><div><h1>${escapeReport(STORE_INFO.name)}</h1><p>${escapeReport(STORE_INFO.location)} · ${escapeReport(STORE_INFO.email)}</p><p>${escapeReport(STORE_INFO.whatsapp)}</p></div></div><div class="en"><strong>TECH ZONE</strong><div>Official Store Report</div></div></header><section class="title"><h2>${escapeReport(titleAr)}</h2><p>${escapeReport(titleEn)}</p></section><div class="meta"><div><b>تاريخ الطباعة / Print Date</b>${escapeReport(reportDate(new Date().toISOString()))}</div><div><b>المتجر / Store</b>${escapeReport(STORE_INFO.name)}</div><div><b>العملة / Currency</b>${escapeReport(STORE_INFO.currency)}</div></div>${summaryHtml ? `<div class="summary">${summaryHtml}</div>` : ''}${bodyHtml}<footer class="footer"><div><strong>إدارة ${escapeReport(STORE_INFO.name)}</strong><div class="small">هذا التقرير صادر من النظام الإداري للمتجر.</div></div><div class="signature"><strong>توقيع الإدارة / Management Signature</strong><div class="line"></div><div class="small">الختم الرسمي / Official Stamp</div></div></footer></main></body></html>`);
            w.document.close();
        }

        function rowsTable(headers, rows) {
            if(!rows.length) return '<div class="no-data">لا توجد بيانات متاحة لهذا التقرير.</div>';
            return `<div class="table-wrap"><table><thead><tr>${headers.map(h=>`<th>${escapeReport(h)}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${r.map(c=>`<td>${c}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
        }

        async function generateSalesReport(){
            try{const d=await fetchAdminReportBundle(); const orders=d.orders||[]; const total=orders.reduce((s,o)=>s+Number(o.total_amount||0),0); const completed=orders.filter(o=>['delivered','completed'].includes(o.status)).length;
            const rows=orders.map(o=>[`#${escapeReport(String(o.id).slice(0,8))}`,escapeReport(o.customer_name||'عميل'),escapeReport(o.customer_email||'-'),escapeReport(reportDate(o.created_at)),moneyReport(o.total_amount),escapeReport(reportStatus(o.status))]);
            openPrintReport('تقرير المبيعات','Sales Report',`<section class="section"><h3>تفاصيل المبيعات</h3>${rowsTable(['رقم الطلب','العميل','البريد','التاريخ','الإجمالي','الحالة'],rows)}</section>`,`<div class="metric"><strong>${moneyReport(total)}</strong><span>إجمالي المبيعات</span></div><div class="metric"><strong>${orders.length}</strong><span>إجمالي الطلبات</span></div><div class="metric"><strong>${completed}</strong><span>طلبات مكتملة</span></div>`);}catch(e){alert('تعذر إنشاء تقرير المبيعات: '+e.message);}}

        async function generateProductsReport(){
            try{const d=await fetchAdminReportBundle(); const products=d.products||[]; const stock=products.reduce((s,p)=>s+Number(p.stock||0),0); const rows=products.map(p=>[escapeReport(p.name),escapeReport(p.category_name||p.category),escapeReport(p.sub_category_name||p.sub_category||'-'),moneyReport(p.price),escapeReport(p.stock===null?'غير محدود':p.stock),escapeReport(p.approval_status||'-')]); openPrintReport('تقرير المنتجات والمخزون','Products & Inventory Report',`<section class="section"><h3>قائمة المنتجات والمخزون</h3>${rowsTable(['المنتج','التصنيف','التصنيف الفرعي','السعر','المخزون','الحالة'],rows)}</section>`,`<div class="metric"><strong>${products.length}</strong><span>عدد المنتجات</span></div><div class="metric"><strong>${stock}</strong><span>وحدات المخزون</span></div>`);}catch(e){alert('تعذر إنشاء تقرير المنتجات: '+e.message);}}

        async function generateOrdersReport(){
            try{const d=await fetchAdminReportBundle(); const orders=d.orders||[]; const rows=orders.map(o=>[`#${escapeReport(String(o.id).slice(0,8))}`,escapeReport(o.customer_name||'عميل'),escapeReport(o.customer_phone||'-'),moneyReport(o.total_amount),escapeReport(reportStatus(o.status)),escapeReport(reportDate(o.created_at))]); openPrintReport('تقرير الطلبات','Orders Report',`<section class="section"><h3>سجل الطلبات</h3>${rowsTable(['رقم الطلب','العميل','الهاتف','المبلغ','الحالة','التاريخ'],rows)}</section>`,`<div class="metric"><strong>${orders.length}</strong><span>إجمالي الطلبات</span></div><div class="metric"><strong>${moneyReport(orders.reduce((s,o)=>s+Number(o.total_amount||0),0))}</strong><span>قيمة الطلبات</span></div>`);}catch(e){alert('تعذر إنشاء تقرير الطلبات: '+e.message);}}

        async function generateVendorsReport(){
            try{const d=await fetchAdminReportBundle(); const vendors=d.vendors||[]; const rows=vendors.map(v=>[escapeReport(v.store_name||'-'),escapeReport(v.phone||'-'),escapeReport(v.commission_rate??0)+'%',moneyReport(v.current_invoice),moneyReport(v.total_commissions),escapeReport(v.is_restricted?'مقيّد':'نشط')]); openPrintReport('تقرير التجار والعمولات','Vendors & Commissions Report',`<section class="section"><h3>التجار والفواتير</h3>${rowsTable(['المتجر','الهاتف','العمولة','الفاتورة الحالية','إجمالي العمولات','الحالة'],rows)}</section>`);}catch(e){alert('تعذر إنشاء تقرير التجار: '+e.message);}}

        async function generateCustomersReport(){
            try{const d=await fetchAdminReportBundle(); const users=d.customers||[]; const rows=users.map(u=>[escapeReport(u.full_name||'-'),escapeReport(u.email||'-'),escapeReport(u.phone||'-'),escapeReport(u.user_type||'customer'),escapeReport(reportDate(u.created_at))]); openPrintReport('تقرير العملاء','Customers Report',`<section class="section"><h3>سجل العملاء</h3>${rowsTable(['الاسم','البريد الإلكتروني','الهاتف','النوع','تاريخ التسجيل'],rows)}</section>`,`<div class="metric"><strong>${users.length}</strong><span>إجمالي الحسابات</span></div>`);}catch(e){alert('تعذر إنشاء تقرير العملاء: '+e.message);}}

        async function generateComprehensiveReport(){
            try{const d=await fetchAdminReportBundle(); const orders=d.orders||[], products=d.products||[], vendors=d.vendors||[], customers=d.customers||[]; const sales=orders.reduce((s,o)=>s+Number(o.total_amount||0),0); const comm=vendors.reduce((s,v)=>s+Number(v.total_commissions||0),0); const rows=orders.slice(0,100).map(o=>[`#${escapeReport(String(o.id).slice(0,8))}`,escapeReport(o.customer_name||'عميل'),moneyReport(o.total_amount),escapeReport(reportStatus(o.status)),escapeReport(reportDate(o.created_at))]); openPrintReport('التقرير التنفيذي الشامل','Executive Store Report',`<section class="section"><h3>ملخص الطلبات</h3>${rowsTable(['رقم الطلب','العميل','المبلغ','الحالة','التاريخ'],rows)}</section><section class="section"><h3>مؤشرات المتجر</h3><p>عدد المنتجات: <strong>${products.length}</strong> — عدد التجار: <strong>${vendors.length}</strong> — عدد الحسابات: <strong>${customers.length}</strong> — إجمالي العمولات المسجلة: <strong>${moneyReport(comm)}</strong>.</p></section>`,`<div class="metric"><strong>${moneyReport(sales)}</strong><span>إجمالي المبيعات</span></div><div class="metric"><strong>${orders.length}</strong><span>الطلبات</span></div><div class="metric"><strong>${products.length}</strong><span>المنتجات</span></div><div class="metric"><strong>${vendors.length}</strong><span>التجار</span></div><div class="metric"><strong>${customers.length}</strong><span>الحسابات</span></div>`);}catch(e){alert('تعذر إنشاء التقرير الشامل: '+e.message);}}
