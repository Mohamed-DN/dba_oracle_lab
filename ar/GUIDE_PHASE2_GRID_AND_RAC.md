# المرحلة 2: تثبيت Grid Infrastructure و Oracle RAC الأساسي

> جميع خطوات هذه المرحلة تتعلق بالعقدتين **rac1** و **rac2** (RAC الأساسي).
> يجب أن تكون وسائط التخزين المشتركة مرئية بالفعل من كلتا العقدتين قبل المتابعة.

> 🛑 **قبل المتابعة: اتصل عبر MOBAXTERM!**
> هذه المرحلة مليئة بالسكربتات والإعدادات الرسومية. من **الإلزامي** استخدام MobaXterm مع تفعيل خاصية X11-Forwarding. افتح لسانين (tabs) في MobaXterm للتحكم في العقدتين معاً.

---

### ماذا نبني في هذه المرحلة

```
╔═══════════════════════════════════════════════════════════════════════╗
║                     عنقود RAC (rac1 + rac2)                         ║
║                                                                       ║
║    ┌──────────────────────────────────────────────────────────┐       ║
║    │              Oracle Database 19c + RU + OJVM             │       ║
║    │         ┌──────────────┐  ┌──────────────┐               │       ║
║    │         │  Instance    │  │  Instance    │               │       ║
║    │         │  RACDB1      │  │  RACDB2      │               │       ║
║    │         │  (rac1)      │  │  (rac2)      │               │       ║
║    │         └──────┬───────┘  └──────┬───────┘               │       ║
║    └────────────────┼─────────────────┼───────────────────────┘       ║
║    ┌────────────────┼─────────────────┼───────────────────────┐       ║
║    │         Grid Infrastructure 19c + Release Update         │       ║
║    │         ┌──────┴───────┐  ┌──────┴───────┐               │       ║
║    │         │    ASM       │  │    ASM       │               │       ║
║    │         │  Instance    │  │  Instance    │               │       ║
║    │         │  (+ASM1)     │  │  (+ASM2)     │               │       ║
║    │         └──────┬───────┘  └──────┬───────┘               │       ║
║    │         Clusterware (CRS) ◄═══════════════►              │       ║
║    │           crsd, cssd, evmd, ohasd                        │       ║
║    └────────────────┼─────────────────┼───────────────────────┘       ║
║                     │                 │                               ║
║    ┌────────────────┴─────────────────┴───────────────────────┐       ║
║    │                  أقراص ASM المشتركة                       │       ║
║    │  ┌─────────┐     ┌──────────┐     ┌──────────┐          │       ║
║    │  │ +CRS    │     │ +DATA    │     │ +FRA     │          │       ║
║    │  │  5 GB   │     │  20 GB   │     │  15 GB   │          │       ║
║    │  │ OCR,    │     │ Datafile,│     │ Archive, │          │       ║
║    │  │ Voting  │     │ Redo,    │     │ Backup,  │          │       ║
║    │  │ Disk    │     │ Control  │     │ Flashback│          │       ║
║    │  └─────────┘     └──────────┘     └──────────┘          │       ║
║    └──────────────────────────────────────────────────────────┘       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### ترتيب التثبيت في هذه المرحلة

1. **أقراص ASM**: التأكد من الأقراص والتقسيمات.
2. **cluvfy**: التحقق من المتطلبات المسبقة.
3. **Grid Infrastructure**: تشغيل `gridSetup.sh` و `root.sh`.
4. **DATA + FRA**: إنشاء مجموعات الأقراص عبر `asmca`.
5. **ترقيع Grid**: استخدام `opatchauto` (كـ root).
6. **برنامج DB**: تشغيل `runInstaller` و `root.sh`.
7. **ترقيع DB Home**: استخدام `opatchauto` و `opatch`.
8. **DBCA**: إنشاء قاعدة بيانات RACDB.
9. **datapatch**: تطبيق الرقع على قاموس البيانات (Dictionary).

---

## 2.1 تحضير التخزين المشترك (ASM)

### التحقق من التقسيمات (على rac1 كـ root)
يجب أن تكون الأقراص قد قُسمت في المرحلة 0. تحقق باستخدام:
```bash
lsblk
# يجب أن ترى sdc1, sdd1, sde1, sdf1, sdg1
```

---

## 2.2 تحميل وتحضير الملفات التنفيذية

قم بفك ضغط ملف Grid في مسار GRID_HOME (كمستخدم `grid`):
```bash
su - grid
unzip -q /tmp/LINUX.X64_193000_grid_home.zip -d /u01/app/19.0.0/grid
```

---

## 2.3 تثبيت حزمة CVU Disk

يجب تثبيت `cvuqdisk` على العقدتين. انقل ملف RPM من `rac1` إلى `rac2` ثم ثبته:
```bash
# على rac1 كـ root
rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm

# نسخ الملف إلى rac2
scp /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm root@rac2:/tmp/

# على rac2 كـ root
rpm -ivh /tmp/cvuqdisk-1.0.10-1.rpm
```

---

## 2.4 التحقق المسبق باستخدام cluvfy

```bash
# كمستخدم grid على rac1
su - grid
cd /u01/app/19.0.0/grid

./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
```
> **ملاحظة**: تحذيرات الذاكرة وعنوان IP الـ NAT يمكن تجاهلها.

---

## 2.5 تثبيت Grid Infrastructure

### الطريقة الرسومية GUI
```bash
# كمستخدم grid على rac1 عبر MobaXterm
cd /u01/app/19.0.0/grid
./gridSetup.sh
```

### خطوات المثبت الرسومي:
1. **Option**: Configure Oracle Grid Infrastructure for a New Cluster.
2. **Type**: Configure an Oracle Standalone Cluster.
3. **SCAN**: الاسم `rac-scan.localdomain` والمنفذ `1521`.
4. **Nodes**: أضف `rac2` وقم بإعداد ومراجعة SSH.
5. **Network**: 
   - `enp0s8` ← **Public**
   - `enp0s9` ← **ASM & Private**
   - `enp0s3` ← **Do Not Use**
6. **Storage**: Use Oracle Flex ASM.
7. **GIMR**: No.
8. **Disk Group**: أنشئ مجموعة باسم `CRS` بنوع **Normal** واختر الـ 3 أقراص (CRS1, CRS2, CRS3).
   - مسار الاكتشاف: `/dev/oracleasm/disks/*`
9. **Password**: استخدم كلمة مرور موحدة.
10. **OS Groups**: استخدم المجموعات التي أنشأتها (asmadmin, asmdba, asmoper).
11. **Root Scripts**: لا تختر التشغيل التلقائي.

### تنفيذ سكربتات root
عندما يطلب البرنامج، نفذ السكربتات **بالتتابع** (أنهِ تماماً في العقدة 1 قبل البدء في 2):
```bash
# على rac1 كـ root
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh

# ثم على rac2 كـ root
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh
```

---

## 2.6 التحقق من العنقود (Cluster)

```bash
# كمستخدم grid
crsctl check crs
crsctl stat res -t
```
> يجب أن تكون جميع الموارد (Services) في حالة **ONLINE**.

---

## 2.7 إنشاء مجموعات الأقراص DATA و RECO

استخدم `asmca` أو SQL لإنشاء المجموعات المتبقية:
```sql
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY DISK '/dev/oracleasm/disks/DATA';
CREATE DISKGROUP RECO EXTERNAL REDUNDANCY DISK '/dev/oracleasm/disks/RECO';
```

---

## 2.8 ترقيع Grid Infrastructure (RU)

1. حدث **OPatch** في الـ Grid Home على العقدتين.
2. فك ضغط الـ **Release Update** في مجلد مؤقت.
3. طبق الرقعة باستخدام `opatchauto`:
```bash
# كـ root على كل عقدة
$ORACLE_HOME/OPatch/opatchauto apply /tmp/patch/37957391 -oh $ORACLE_HOME
```

---

## 2.9 تثبيت برنامج قاعدة البيانات

1. فك ضغط ملف DB في `ORACLE_HOME` (كمستخدم `oracle`).
2. شغل `./runInstaller` واختر **Set Up Software Only** لنوع **Real Application Clusters**.
3. نفذ سكربت `root.sh` على العقدتين عند الطلب.
4. طبق رقعة الـ RU و OJVM على الـ DB Home (باستخدام `opatchauto` و `opatch`).

---

## 2.12 إنشاء قاعدة البيانات RACDB

شغل `dbca` كمستخدم `oracle` على `rac1`:
- اختر **Oracle RAC database**.
- اسم القاعدة: `RACDB`.
- التخزين: **ASM** (Data: `+DATA`, Recovery: `+RECO`).
- **مهم**: فعل خاصية **Archiving** في المرحلة 7.
- الذاكرة: SGA 1500MB ، PGA 500MB.

---

## 2.13 ما بعد الإنشاء

1. طبق `datapatch` لتحديث قاموس البيانات.
2. فعل خاصية **Force Logging**:
```sql
ALTER DATABASE FORCE LOGGING;
```

---
**التالي: [المرحلة 3: تحضير وإنشاء Oracle RAC الاحتياطي](./ar/GUIDE_PHASE3_RAC_STANDBY.md)**
