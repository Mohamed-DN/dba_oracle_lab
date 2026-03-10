# المرحلة 6: اختبارات التحقق (Data Guard + GoldenGate)

> هذه المرحلة حاسمة. النظام الذي لم يتم اختباره هو نظام لا يعمل. سنقوم هنا بإجراء اختبارات شاملة (End-to-End) للتأكد من أن السلسلة بأكملها (RAC الأساسي ← DG الاحتياطي ← GG المستهدف) تعمل بكفاءة.

---

## 6.1 اختبار Data Guard — التحقق من نقل السجلات (Redo Transport)

### على الأساسي: توليد بيانات تجريبية
```sql
sqlplus / as sysdba
CREATE USER testdg IDENTIFIED BY testdg123 QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE TO testdg;

CONNECT testdg/testdg123
CREATE TABLE test_replica (id NUMBER PRIMARY KEY, nome VARCHAR2(50), ts_insert TIMESTAMP DEFAULT SYSTIMESTAMP);
INSERT INTO test_replica VALUES (1, 'Test Data Guard', SYSTIMESTAMP);
COMMIT;

ALTER SYSTEM SWITCH LOGFILE; -- لتسريع عملية الإرسال
```

### على الاحتياطي: التحقق من وصول البيانات
```sql
-- يجب أن تكون القاعدة في وضع READ ONLY (Active Data Guard)
SELECT * FROM testdg.test_replica;
```
> **النتيجة المتوقعة**: رؤية السجلات التي تم إدخالها في الأساسي. والتحقق من أن `transport lag` و `apply lag` يقتربان من الصفر في `v$dataguard_stats`.

---

## 6.2 اختبار Data Guard — عملية التحويل الكاملة (Switchover)

```bash
dgmgrl sys/pass@RACDB
VALIDATE DATABASE RACDB_STBY;
-- يجب أن تظهر: Ready for Switchover: Yes
SWITCHOVER TO RACDB_STBY;
```
بعد التحويل، تأكد من أن الأدوار قد تبادلت وأن التجربة تعمل في الاتجاه المعاكس (إدخال بيانات في الاحتياطي السابق الذي أصبح أساسياً ورؤيتها في الأساسي السابق).

---

## 6.3 اختبار GoldenGate — التحقق من التكرار الشامل

### على الاحتياطي والمستهدف:
تأكد من أن جميع العمليات (MANAGER, EXTRACT, PUMP, REPLICAT) في حالة **RUNNING** باستخدام أمر `INFO ALL` في `ggsci` أو عبر واجهة الويب.

### توليد بيانات والتحقق:
أدخل بيانات في RAC الأساسي وتحقق من وصولها إلى قاعدة البيانات في السحابة (OCI) بعد ثوانٍ قليلة.
```sql
-- على المستهدف (dbtarget)
SELECT * FROM testdg.test_replica WHERE id >= 100;
```

---

## 6.7 اختبار تعطل العقدة (Node Failure)

> هذا الاختبار هو الأهم: يجب أن ينجو الـ RAC من فقدان إحدى العقد.

1. **إغلاق قسري**: قم بإطفاء العقدة `rac2` بشكل مفاجئ من VirtualBox.
2. **التحقق**: تأكد من أن العقدة `rac1` لا تزال تعمل وتستقبل البيانات وتجري عمليات الـ DML بنجاح.
3. **VIP Failover**: تأكد من انتقال عنوان الـ VIP الخاص بالعقدة المتعطلة إلى العقدة العاملة.
4. **إعادة التشغيل**: أعد تشغيل `rac2` وتأكد من انضمامها للتجمع (Cluster) تلقائياً وعودتها للعمل.

---

## 6.8 اختبار GoldenGate بعد التحويل (Switchover)

بعد إجراء `Switchover` لـ Data Guard ، يجب أن يستمر GoldenGate في العمل بشكل طبيعي لأن الـ Extract ينتقل للعمل على العقدة التي أصبحت أساسية.

---

## 6.9 استكشاف الأخطاء وإصلاحها (Troubleshooting)

- **Data Guard**: تحقق من الـ Alert Log واتصال الشبكة ومنافذ الـ Listener.
- **GoldenGate**: استخدم `VIEW REPORT <process_name>` لمعرفة سبب توقف أي عملية.
- **Cluster**: استخدم `crsctl stat res -t` لمراقبة حالة الموارد.

---
**التالي: [المرحلة 7: استراتيجية النسخ الاحتياطي RMAN](./ar/GUIDE_PHASE7_RMAN_BACKUP.md)**
