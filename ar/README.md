# دليل Oracle RAC + Data Guard + GoldenGate + Cloud - الدليل النهائي

> دليل شامل خطوة بخطوة لبناء بنية تحتية لـ Oracle Enterprise في المختبر.
> **تم التحقق منه بنسبة 98%** وفقاً لأفضل ممارسات Oracle MAA Gold الرسمية.

---

> ⚠️ **متطلبات الأجهزة الحرجة**: لتشغيل البيئة الكاملة (4 عقد RAC + عقدة DNS + عقدة Target PostgreSQL + نظام التشغيل المضيف) **يلزم توفر 32 جيجابايت على الأقل من ذاكرة الوصول العشوائي (RAM) الفعلية** على جهاز الكمبيوتر الخاص بك. إذا كان لديك 16 جيجابايت، يمكنك تنفيذ نصف المختبر فقط (مثلاً عقدتا RAC بدون Standby).

> 🤖 **الأتمتة متاحة**: هل تريد تخطي الخطوات المملة؟ ستجد في مجلد `scripts/` نصوص bash جاهزة للاستخدام للتهيئة التلقائية للتخزين (`configure_storage.sh`) وتثبيت Grid (`install_grid.sh`). توضح لك الأدلة المسار اليدوي (للتعلم)، لكن النصوص البرمجية تحت تصرفك!

---

## 🚀 سجل التغييرات: تحسينات مسؤول قاعدة البيانات الذاتية

*يتتبع هذا القسم التحسينات الهيكلية والتعليمية المطبقة بشكل مستقل تماماً للارتقاء بالمستودع إلى معايير مؤسسية مثالية.*

| التاريخ | الملف المعدل | التعديل المطبق (شرح لمسؤول قاعدة البيانات) |
|---|---|---|
| قيد التنفيذ... | `...` | *بدء التدقيق...* |

---

## من أين تبدأ

**مسار الدراسة**

```
الخطوة 0: اقرأ النظرية أولاً (ساعتان)
  |
  |  1. GUIDE_ORACLE_ARCHITECTURE.md   <-- SGA, PGA, Redo, Undo, Temp, ASM
  |  2. GUIDE_DBA_COMMANDS.md           <-- استعلامات SQL الأساسية، نصوص DBA
  |  3. DAILY_STUDY_PLAN.md             <-- خطتك: 40 يوماً × 3 ساعات
  |
  v
الخطوات 1-7: بناء المختبر (الأسابيع 1-4)
  |
  |  4. المرحلة 0 --> إعداد أجهزة VirtualBox (DNS, RAC, Storage)
  |  5. المرحلة 1 --> إعداد نظام التشغيل (الشبكة، DNS، المستخدمون، SSH)
  |  6. المرحلة 2 --> Grid Infrastructure + RAC Database
  |  7. المرحلة 3 --> RAC Standby (RMAN Duplicate)
  |  8. المرحلة 4 --> Data Guard (DGMGRL, ADG)
  |  9. المرحلة 5 --> GoldenGate (Extract, Pump, Replicat)
  | 10. المرحلة 6 --> الاختبار والتحقق الشامل
  | 11. المرحلة 7 --> استراتيجية نسخ RMAN الاحتياطي
  |
  v
الخطوات 8-11: العمليات المتقدمة (الأسبوع 4)
  |
  | 12. Switchover لـ Data Guard
  | 13. Failover + Reinstate
  | 14. الهجرة بدون وقت توقف باستخدام GoldenGate
  | 15. Listener, Services, DBA Toolkit
  |
  v
الخطوات 12-14: السحابة + DBA PRO (الأسبوع 5)
  |
  | 16. Cloud GoldenGate على OCI ARM Free Tier
  | 17. أنشطة DBA (الدفعات، AWR، الترقيع، DataPump، الأمان)
  | 18. أفضل ممارسات MAA + التحقق
  |
  v
الخطوات 15-17: POSTGRES + الاختبارات (الأسابيع 6-8)
  |
  | 19. هجرة Oracle -> PostgreSQL باستخدام GoldenGate
  | 20. مراجعة اختبار 1Z0-082 (Admin I + SQL)
  | 21. مراجعة اختبار 1Z0-083 (DBA Professional 2)
  |
  v
تم الإكمال! --> اقرأ GUIDE_DA_LAB_A_PRODUZIONE.md لمعرفة الحجم الفعلي
```

> **نصيحة**: اتبع [خطة الدراسة اليومية](./DAILY_STUDY_PLAN.md) -- فهي تخبرك بالضبط بما يجب عليك فعله كل يوم في 3 ساعات.

---

## الفهرس الكامل - جميع الأدلة

### النظرية (اقرأ قبل البدء في البناء)

| # | المستند | الملف | ماذا تتعلم |
|---|---|---|---|
| 1 | **هندسة أوراكل** | [GUIDE_ORACLE_ARCHITECTURE](./ar/GUIDE_ORACLE_ARCHITECTURE.md) | SGA, PGA, Redo Log, Undo, Temp, ASM, Cache Fusion |
| 2 | **أوامر DBA** | [GUIDE_DBA_COMMANDS](./ar/GUIDE_DBA_COMMANDS.md) | أكثر من 100 استعلام SQL، نصوص Oracle Base، فحص الصحة |
| 3 | **CDB/PDB، المستخدمون، EM Express** | [GUIDE_CDB_PDB_USERS](./ar/GUIDE_CDB_PDB_USERS.md) | Multitenant، إنشاء/نسخ/توصيل PDB، المستخدمون، الأدوار، ضبط SQL |
| 4 | **خطة الدراسة** | [DAILY_STUDY_PLAN](./ar/DAILY_STUDY_PLAN.md) | 25 يوماً × 3 ساعات/يوم (5 أسابيع)، نصائح للسيرة الذاتية |

---

### بناء المختبر (اتبع بالترتيب!)

| # | المرحلة | الملف | ماذا تفعل |
|---|---|---|---|
| 4 | **المرحلة 0** | [إعداد الأجهزة](./ar/GUIDE_PHASE0_MACHINE_SETUP.md) | إنشاء أجهزة VirtualBox، DNS Dnsmasq، أقراص ASM oracleasm، تثبيت OL 7.9 |
| 5 | **المرحلة 1** | [إعداد نظام التشغيل](./ar/GUIDE_PHASE1_OS_PREPARATION.md) | تكوين الشبكة، DNS، المستخدمون، SSH، النواة |
| 6 | **المرحلة 2** | [GRID + RAC](./ar/GUIDE_PHASE2_GRID_AND_RAC.md) | تثبيت Grid, ASM, DB Software، إنشاء RACDB |
| 7 | **المرحلة 3** | [RAC STANDBY](./ar/GUIDE_PHASE3_RAC_STANDBY.md) | RMAN Duplicate، Listener ثابت، MRP |
| 8 | **المرحلة 4** | [DATA GUARD](./ar/GUIDE_PHASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker، Active Data Guard |
| 9 | **المرحلة 5** | [GOLDENGATE](./ar/GUIDE_PHASE5_GOLDENGATE.md) | Extract على Standby، Pump، Replicat Target |
| 10 | **المرحلة 6** | [الاختبار والتحقق](./ar/GUIDE_PHASE6_TEST_VERIFY.md) | اختبار DG + GG + الإجهاد + تعطل العقد |
| 11 | **المرحلة 7** | [RMAN BACKUP](./ar/GUIDE_PHASE7_RMAN_BACKUP.md) | استراتيجية النسخ الاحتياطي، النصوص، cron، BCT، الاستعادة |

---

### العمليات المتقدمة (بعد المختبر الأساسي)

| # | المستند | الملف | ماذا تتعلم |
|---|---|---|---|
| 12 | **Switchover** | [GUIDE_FULL_SWITCHOVER](./ar/GUIDE_FULL_SWITCHOVER.md) | Switchover + Switchback خطوة بخطوة |
| 13 | **Failover + Reinstate** | [GUIDE_FAILOVER_AND_REINSTATE](./ar/GUIDE_FAILOVER_AND_REINSTATE.md) | Failover الطارئ، إعادة التعيين، FSFO |
| 14 | **هجرة GoldenGate** | [GUIDE_GOLDENGATE_MIGRATION](./ar/GUIDE_GOLDENGATE_MIGRATION.md) | الهجرة بدون توقف باستخدام GoldenGate |
| 15 | **Listener + Services** | [GUIDE_LISTENER_SERVICES_DBA](./ar/GUIDE_LISTENER_SERVICES_DBA.md) | Listener RAC، SCAN، الخدمات، أدوات DBA |

---

### السحابة و مسؤول قاعدة البيانات المحترف (الأسبوع 5)

| # | المستند | الملف | ماذا تتعلم |
|---|---|---|---|
| 16 | **Cloud GoldenGate** | [GUIDE_GOLDENGATE_OCI_ARM](./ar/GUIDE_GOLDENGATE_OCI_ARM.md) | OCI Free Tier ARM، إعداد هجين 23ai Free، نفق SSH |
| 17 | **أنشطة DBA** | [GUIDE_DBA_ACTIVITIES](./ar/GUIDE_DBA_ACTIVITIES.md) | وظائف الدفعات، AWR/ADDM/ASH، الترقيع، DataPump، الأمان |
| 18 | **أفضل ممارسات MAA** | [GUIDE_MAA_BEST_PRACTICES](./ar/GUIDE_MAA_BEST_PRACTICES.md) | التحقق من المختبر مقابل Oracle MAA Gold |

---

### الاختبارات + هجرة PostgreSQL (الأسبوع 6)

| # | المستند | الملف | ماذا تتعلم |
|---|---|---|---|
| 19 | **مراجعة الاختبار** | [GUIDE_EXAM_REVIEW](./ar/GUIDE_EXAM_REVIEW.md) | جميع موضوعات 1Z0-082 + 1Z0-083 (Admin + SQL + DBA Pro 2) |
| 20 | **Oracle → PostgreSQL** | [GUIDE_ORACLE_POSTGRES_MIGRATION](./ar/GUIDE_ORACLE_POSTGRES_MIGRATION.md) | الهجرة من Oracle إلى PostgreSQL باستخدام GoldenGate, ora2pg, ODBC |

---

### المراجع والتعمق

| المستند | الملف | الوصف |
|---|---|---|
| **من المختبر إلى الإنتاج** | [GUIDE_FROM_LAB_TO_PRODUCTION](./ar/GUIDE_FROM_LAB_TO_PRODUCTION.md) | الحجم، HugePages، الأمان، المراقبة |
| **التحقق من أفضل الممارسات** | [BEST_PRACTICES_VALIDATION](./ar/BEST_PRACTICES_VALIDATION.md) | تدقيق 54 نقطة، بطاقة أداء 98%، واجهة المستخدم مقابل سطر الأوامر |
| **تحليل Oracle Base** | [ORACLEBASE_VAGRANT_ANALYSIS](./ar/ORACLEBASE_VAGRANT_ANALYSIS.md) | مقارنة مع Oracle Base Vagrant |

---

## الهندسة الإجمالية

```
+===========================================================================+
|                      VIRTUALBOX HOST (جهاز الكمبيوتر الخاص بك)               |
|                                                                           |
|  Host-Only #1: 192.168.56.0/24 (عامة)                                     |
|  Host-Only #2: 192.168.1.0/24  (الربط البيني الأساسي)                         |
|  Host-Only #3: 192.168.2.0/24  (الربط البيني للاحتياطي)                       |
|                                                                           |
|  +----------+   +----------+----------+   +----------+----------+        |
|  | dnsnode  |   | rac1     | rac2     |   | racstby1 | racstby2 |        |
|  | .56.50   |   | .56.101  | .56.102  |   | .56.111  | .56.112  |        |
|  | Dnsmasq  |   | VIP .103 | VIP .104 |   | VIP .113 | VIP .114 |        |
|  | 1GB/1CPU |   | 8GB/4CPU | 8GB/4CPU |   | 8GB/4CPU | 8GB/4CPU |        |
|  +----------+   +-----+----+----+-----+   +-----+----+----+-----+        |
|                       |         |               |         |               |
|                  +----+---------+----+     +----+---------+----+          |
|                  | الربط البيني      |     | الربط البيني      |           |
|                  | 192.168.1.101-102|     | 192.168.2.111-112|           |
|                  | (Cache Fusion)   |     | (Cache Fusion)   |           |
|                  +------------------+     +------------------+           |
|                                                                           |
|  SCAN Primary: rac-scan       --> 192.168.56.105, .106, .107             |
|  SCAN Standby: racstby-scan   --> 192.168.56.115, .116, .117             |
|                                                                           |
|  +-------------------------------+   +-------------------------------+   |
|  | RAC PRIMARY (RACDB)           |   | RAC STANDBY (RACDB_STBY)     |   |
|  | Grid 19c + RU                 |   | Active Data Guard            |   |
|  | ASM: +CRS(2GBx3) +DATA(20GB) |   | القراءة فقط مع التطبيق        |   |
|  |      +RECO(15GB)              |   | GG Extract + Data Pump       |   |
|  +---------------+---------------+   +-------------------------------+   |
|                  |                                                        |
|                  | Data Guard: Redo Shipping (LGWR ASYNC)                 |
|                  v                                                        |
|  +---------------------------------------------------------------+        |
|  | بيئة الهدف (dbtarget / Cloud OCI / جهاز افتراضي آخر)               |        |
|  | - Oracle Database Target (نسخة Oracle-Oracle)                 |        |
|  | - PostgreSQL 16 Target   (هجرة Oracle-PostgreSQL)              |        |
|  |   --> يستلم البيانات عبر GoldenGate Replicat                    |        |
|  +---------------------------------------------------------------+        |
+===========================================================================+
```

---

## متطلبات البرمجيات

| البرنامج | الإصدار | التحميل |
|---|---|---|
| Oracle Linux | 7.9 (VM) | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Oracle Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c o 21c | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | الأخير | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> قم بتحميل كل شيء قبل البدء! انظر القائمة الكاملة في [المرحلة 0](./ar/GUIDE_PHASE0_MACHINE_SETUP.md).

---

## خطة الـ IP

| اسم المضيف | IP العامة | IP الخاصة | IP لـ VIP | ملاحظات |
|---|---|---|---|---|
| dnsnode | 192.168.56.50 | -- | -- | Dnsmasq DNS |
| rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 | الأساسي رقم 1 |
| rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 | الأساسي رقم 2 |
| rac-scan | 192.168.56.105-107 | -- | -- | SCAN (3 IPs) |
| racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 | الاحتياطي رقم 1 |
| racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 | الاحتياطي رقم 2 |
| racstby-scan | 192.168.56.115-117 | -- | -- | SCAN الاحتياطي (3 IPs) |
| dbtarget | Cloud OCI | -- | -- | GoldenGate Replicat |

---

## الاعتمادات والمراجع

- [Oracle Base - RAC 19c on VirtualBox](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox)
- [Oracle MAA Best Practices](https://www.oracle.com/database/technologies/high-availability/maa.html)
- [My Oracle Support](https://support.oracle.com) - Doc ID 2118136.2 لتحديثات الإصدار
