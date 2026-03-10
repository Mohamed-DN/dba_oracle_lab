# المرحلة 3: تحضير وإنشاء Oracle RAC الاحتياطي (عبر RMAN Duplicate)

> تغطي هذه المرحلة تحضير عقد الاحتياطي (`racstby1`, `racstby2`) وإنشاء قاعدة بيانات احتياطية فيزيائية (Physical Standby) باستخدام خاصية RMAN Duplicate من قاعدة البيانات النشطة.

---

## 3.0 إنشاء أجهزة الاحتياطي والإعداد الأساسي (طريقة الصورة الذهبية)

بدلاً من تثبيت كل شيء من الصفر، سنستخدم `rac1` كـ **صورة ذهبية (Golden Image)** (في الحالة التي كان عليها بعد المرحلة 1، قبل تثبيت الـ Grid).

### الخطوة 1: استنساخ الأجهزة
1. تأكد من إطفاء `rac1`.
2. في VirtualBox، استنسخ `rac1` مرتين لإنشاء `racstby1` و `racstby2`.
3. **مهم**: اختر "Generate new MAC addresses".
4. اربط أقراص ASM الخمسة الخاصة بالاحتياطي التي أنشأتها في المرحلة 0 (`asm-stby-crs1`, إلخ).

### الخطوة 2: تغيير العناوين وأسماء المضيفين
قم بتشغيل كل جهاز على حدة واستخدم `nmtui` لتغيير العناوين:
- **racstby1**: العامة `192.168.56.111` ، الخاصة `192.168.2.111`.
- **racstby2**: العامة `192.168.56.112` ، الخاصة `192.168.2.112`.

### الخطوة 3: تهيئة أقراص ASM للاحتياطي (فقط على `racstby1`)
```bash
# كـ root على racstby1
oracleasm createdisk CRS1 /dev/sdc1
oracleasm createdisk CRS2 /dev/sdd1
oracleasm createdisk CRS3 /dev/sde1
oracleasm createdisk DATA /dev/sdf1
oracleasm createdisk RECO /dev/sdg1

# على racstby2
oracleasm scandisks
```

### الخطوة 4: تكرار تثبيت Grid والبرنامج (المرحلة 2)
كرر خطوات المرحلة 2 على عقد الاحتياطي مع مراعاة:
- اسم التجمع: `racstby-cluster`.
- اسم الـ SCAN: `racstby-scan.localdomain`.
- الشبكة الخاصة: `192.168.2.0`.
- **تثبيت برنامج DB فقط** (Software Only) بدون إنشاء قاعدة بيانات.

---

## 3.2 تكوين Listener الساكن (Static Listener)

يجب إضافة مدخلات ساكنة في ملف `listener.ora` لضمان الاتصال حتى والقاعدة في وضع `MOUNT`.

### على الأساسي والاحتياطي (SID_LIST)
أضف لعقد الأساسي: `GLOBAL_DBNAME = RACDB` و `SID_NAME = RACDB1/2`.
أضف لعقد الاحتياطي: `GLOBAL_DBNAME = RACDB_STBY` و `SID_NAME = RACDB1/2`.

---

## 3.4 تكوين TNS Names
يجب أن يكون ملف `tnsnames.ora` متطابقاً على **جميع** العقد ويحتوي على تعريفات لـ `RACDB` و `RACDB_STBY` مع إضافة `(UR=A)` للاحتياطي.

---

## 3.5 إعداد الأساسي لـ Data Guard

```sql
-- إضافة Standby Redo Logs (SRL)
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 11 ('+DATA') SIZE 200M, ...;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 21 ('+DATA') SIZE 200M, ...;

-- ضبط بارامترات الإرسال
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(RACDB,RACDB_STBY)' SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_2='SERVICE=RACDB_STBY LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB_STBY' SCOPE=BOTH SID='*';
ALTER SYSTEM SET standby_file_management=AUTO SCOPE=BOTH SID='*';
```

---

## 3.6 ملف كلمة المرور (Password File)
انسخ ملف كلمة المرور من الأساسي إلى الاحتياطي في مسار `$ORACLE_HOME/dbs/` وقم بتغيير اسمه ليناسب الـ SID المحلي (مثلاً `orapwRACDB1`).

---

## 3.9 بدء تشغيل الاحتياطي في وضع NOMOUNT
أنشئ ملف `init.ora` بسيط للاحتياطي يحتوي على `db_unique_name='RACDB_STBY'` وقم بتشغيل القاعدة:
```sql
STARTUP NOMOUNT PFILE='...';
```

---

## 3.10 تنفيذ RMAN Duplicate
من عقدة الاحتياطي `racstby1`:
```bash
rman TARGET sys/pass@RACDB AUXILIARY sys/pass@RACDB1_STBY
```
```rman
DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER
  SPFILE SET db_unique_name='RACDB_STBY' ... NOFILENAMECHECK;
```

---

## 3.12 التسجيل في العنقود (OCR)
بعد اكتمال النسخ، سجل القاعدة في العنقود ليديرها الـ Clusterware:
```bash
srvctl add database -d RACDB_STBY -role PHYSICAL_STANDBY -startoption MOUNT
srvctl add instance -d RACDB_STBY -instance RACDB1 -node racstby1
srvctl add instance -d RACDB_STBY -instance RACDB2 -node racstby2
```

---

## 3.13 بدء تطبيق السجلات (MRP)
```sql
-- على الاحتياطي
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;
```

---

## 3.15 التحقق من المزامنة
تأكد من أن رقم الـ Sequence الأخير في `v$archived_log` متطابق بين الأساسي (حيث `archived='YES'`) والاحتياطي (حيث `applied='YES'`).

---
**التالي: [المرحلة 4: تكوين Data Guard و DGMGRL](./ar/GUIDE_PHASE4_DATAGUARD_DGMGRL.md)**
