# المرحلة 5: تكوين GoldenGate على الاحتياطي (Extract) نحو قاعدة بيانات ثالثة (Replicat)

> في هذه المرحلة، نقوم بتكوين Oracle GoldenGate لالتقاط التغييرات من قاعدة البيانات الاحتياطية (Active Data Guard) وتكرارها في قاعدة بيانات مستهدفة ثالثة مستقلة (`dbtarget`).

---

## 5.0 تحضير الجهاز المستهدف (`dbtarget`)

بدلاً من استخدام جهاز افتراضي محلي يستهلك الذاكرة، سنستخدم خدمة **Oracle Cloud Infrastructure (OCI)** (المستوى المجاني) لإنشاء قاعدة بيانات **Oracle Database 23ai Free** و **GoldenGate 23ai Free**.

👉 **اتبع الدليل أولاً**: [إعداد OCI ARM كهدف لـ GoldenGate](./ar/GUIDE_GOLDENGATE_OCI_ARM.md).

---

## 5.1 بنية GoldenGate مع ADG Standby

البنية التي ننفذها تسمى **Downstream Integrated Extract**:
1. يرسل الأساسي السجلات (Redo) للاحتياطي.
2. يقوم GoldenGate Extract على الاحتياطي بقراءة هذه السجلات.
3. يرسل الـ Extract البيانات للجهاز المستهدف (Target).

> **لماذا الاستخراج من الاحتياطي؟** لتقليل الحمل على الأساسي ولضمان استمرارية العمل عند تحول الاحتياطي إلى أساسي.

---

## 5.2 متطلبات قاعدة البيانات المسبقة

### على الأساسي (RACDB)
يجب تفعيل خاصية التكرار و Supplemental Logging:
```sql
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

---

## 5.3 إنشاء مستخدم GoldenGate

أنشئ مستخدم `ggadmin` بصلاحيات `DBA` وصلاحيات إدارة GoldenGate الخاصة:
```sql
CREATE USER ggadmin IDENTIFIED BY <password> ...;
GRANT DBA TO ggadmin;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
```

---

## 5.4 تثبيت GoldenGate

1. قم بتحميل نسخة GoldenGate المناسبة لنظام التشغيل (x86 للاحتياطي و ARM للسحابة).
2. فك الضغط وشغل `./runInstaller`.
3. حدد مسار البرمجيات وقاعدة البيانات.

---

## 5.6 تكوين المدير (Manager)

يجب تشغيل عملية المدير على كل من الاحتياطي والمستهدف:
```text
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTORESTART EXTRACT *, RETRIES 3, WAITMINUTES 5
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 24
```
شغل المدير باستخدام أمر `START MGR` داخل `ggsci`.

---

## 5.7 تكوين الاستخراج (Extract)

على جهاز الاحتياطي، قم بتسجيل الـ Extract وإضافته:
```sql
GGSCI> DBLOGIN USERID ggadmin@RACDB_STBY
GGSCI> REGISTER EXTRACT ext_racdb DATABASE
GGSCI> ADD EXTRACT ext_racdb, INTEGRATED TRANLOG, BEGIN NOW
GGSCI> ADD EXTTRAIL ./dirdat/ea, EXTRACT ext_racdb
```
في ملف البارامترات، حدد الجداول المراد تكرارها: `TABLE HR.*;`

---

## 5.8 تكوين الدافع (Data Pump)

يقوم الـ Pump بنقل البيانات من الاحتياطي إلى المستهدف عبر الشبكة:
```sql
GGSCI> ADD EXTRACT pump_racdb, EXTTRAILSOURCE ./dirdat/ea
GGSCI> ADD RMTTRAIL ./dirdat/ra, EXTRACT pump_racdb
```

---

## 5.9 تكوين المُكرر (Replicat)

على المستهدف في السحابة (OCI)، استخدم واجهة الويب لـ **GoldenGate 23ai Microservices**:
1. أضف بيانات الاعتماد (Credentials).
2. أنشئ **Integrated Replicat** باسم `REPTAR`.
3. حدد خريطة الجداول: `MAP HR.*, TARGET HR.*;`

---

## 5.10 التحميل الأولي (Initial Load)

يتم نقل البيانات الموجودة مسبقاً باستخدام `expdp` و `impdp` مع تحديد رقم التسلسل **SCN** لضمان المزامنة:
1. ابحث عن SCN الحالي على الاحتياطي.
2. قم بتصدير البيانات (Export) باستخدام هذا الـ SCN.
3. انقل الملف للمستهدف وقم باستيراده (Import).

---

## 5.11 بدء العمليات

ابدأ بالترتيب التالي:
1. المدير (Manager) على الطرفين.
2. الاستخراج (Extract) على الاحتياطي.
3. الدافع (Pump) على الاحتياطي.
4. المُكرر (Replicat) على المستهدف (ابدأه بخيار "After CSN" مع وضع رقم الـ SCN).

---
**التالي: [المرحلة 6: اختبارات التحقق](./ar/GUIDE_PHASE6_TEST_VERIFY.md)**
