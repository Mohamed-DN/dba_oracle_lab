# المرحلة 4: تكوين Data Guard Broker (DGMGRL)

> يعتبر Data Guard Broker بمثابة "لوحة التحكم" المركزية لإدارة تكوين Data Guard. يسهل Broker عمليات التحويل (Switchover) وفشل النظام (Failover) والمراقبة بشكل كبير مقارنة بالإدارة اليدوية.

---

### الفرق بين Switchover و Failover

1. **Switchover (مخطط له)**: تبادل الأدوار بين الأساسي والاحتياطي بدون فقدان بيانات. يستخدم للصيانة.
2. **Failover (طارئ)**: تحويل الاحتياطي إلى أساسي عند تعطل الأساسي الأصلي بشكل كامل. قد يؤدي لفقدان طفيف للبيانات إذا لم تكن في وضع الحماية القصوى.

---

## 4.1 تفعيل Data Guard Broker

نفذ على **جميع** العقد (الأساسي والاحتياطي):
```sql
sqlplus / as sysdba
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```
> سيقوم هذا ببدء عملية `DMON` المسؤولة عن المراقبة.

---

## 4.2 إنشاء إعدادات Broker

من العقدة الأساسية (`rac1`) كـ `oracle`:
```bash
dgmgrl sys/pass@RACDB
```
```sql
-- إنشاء التكوين
CREATE CONFIGURATION dg_config AS
  PRIMARY DATABASE IS RACDB
  CONNECT IDENTIFIER IS RACDB;

-- إضافة قاعدة البيانات الاحتياطية
ADD DATABASE RACDB_STBY AS
  CONNECT IDENTIFIER IS RACDB_STBY
  MAINTAINED AS PHYSICAL;

-- تفعيل التكوين
ENABLE CONFIGURATION;
```

---

## 4.3 التحقق من الحالة

```sql
DGMGRL> SHOW CONFIGURATION;
```
> يجب أن تظهر الحالة **SUCCESS**.

لتفاصيل أكثر عن حالة الاحتياطي ومقدار التأخير (Lag):
```sql
DGMGRL> SHOW DATABASE RACDB_STBY;
```

---

## 4.4 أوضاع الحماية (Protection Modes)

- **Max Performance** (افتراضي): أداء عالٍ، تأخير بسيط جداً في الإرسال.
- **Max Availability**: تأكيد الإرسال قبل إتمام العملية (Sync)، مع الرجوع للوضع الافتراضي عند تعطل الشبكة.
- **Max Protection**: ضمان عدم فقدان أي بيانات إطلاقاً، ولكن سيتوقف الأساسي إذا تعذر التواصل مع الاحتياطي.

---

## 4.5 اختبار التحويل (Switchover)

قبل البدء، تحقق من الجاهزية:
```sql
DGMGRL> VALIDATE DATABASE RACDB_STBY;
-- يجب أن تظهر: Ready for Switchover: Yes
```

تنفيذ التحويل:
```sql
DGMGRL> SWITCHOVER TO RACDB_STBY;
```
> سيقوم Broker بإطفاء وإعادة تشغيل جميع النسخ (Instances) وتبادل الأدوار تلقائياً.

---

## 4.7 تفعيل Active Data Guard

يسمح بفتح قاعدة الاحتياطي للقراءة فقط مع استمرار تطبيق السجلات:
```sql
-- على الاحتياطي
ALTER DATABASE OPEN READ ONLY;
-- الحالة: READ ONLY WITH APPLY
```

---

## 4.8 أوامر DGMGRL مفيدة

- `SHOW CONFIGURATION VERBOSE`: تفاصيل كاملة.
- `SHOW DATABASE <DB_NAME> StatusReport`: تقرير عن الأخطاء.
- `EDIT DATABASE <DB_NAME> SET PROPERTY LogXptMode='SYNC'`: تغيير وضع الإرسال.

---
**التالي: [المرحلة 5: تكوين GoldenGate](./ar/GUIDE_PHASE5_GOLDENGATE.md)**
