# أوامر مدير قاعدة البيانات الأساسية + سكربتات Oracle-Base.com (مع الشرح)

> مجموعة منظمة من أكثر أوامر مدير قاعدة البيانات (DBA) فائدة لمختبرك، مع استعلامات مختارة من [oracle-base.com/dba/scripts](https://oracle-base.com/dba/scripts)، مشروحة ومقيمة.

---

## 1. 🔍 فحص الحالة السريع — "كيف حال قاعدة البيانات؟"

قم بتشغيل هذه الاستعلامات بعد كل مرحلة من المختبر للتحقق من حالة قاعدة البيانات.

### 1.1 معلومات قاعدة البيانات
```sql
SELECT dbid, name, db_unique_name, open_mode, log_mode,
       force_logging, flashback_on, database_role,
       protection_mode, switchover_status
FROM v$database;
```
> **لماذا؟** يظهر كل شيء في لمح البصر: هل قاعدة البيانات مفتوحة؟ هل هي في وضع archivelog؟ هل هي الأساسية أم الاحتياطية؟ هذا الاستعلام وحده يخبرك بـ 50% من حالة قاعدة البيانات.

### 1.2 حالة النسخ (Instance Status) في RAC
```sql
SELECT inst_id, instance_name, host_name, status, startup_time,
       ROUND(sysdate - startup_time) AS uptime_days
FROM gv$instance
ORDER BY inst_id;
```
> **أساسي في RAC**: تأكد من أن جميع النسخ في حالة `OPEN`.

---

## 2. 📊 مراقبة الأداء (Performance Monitoring)

### 2.1 الجلسات النشطة (Active Sessions)
```sql
SELECT s.inst_id, s.sid, s.username, s.program, s.event, s.sql_id,
       s.last_call_et AS "Seconds Active", sq.sql_text
FROM gv$session s
LEFT JOIN gv$sql sq ON s.sql_id = sq.sql_id AND s.inst_id = sq.inst_id
WHERE s.status = 'ACTIVE' AND s.type = 'USER'
ORDER BY s.last_call_et DESC;
```
> **لماذا؟** إذا اشتكى شخص ما من بطء قاعدة البيانات، فهذا الاستعلام يظهر لك **من** يفعل **ماذا** ومنذ **متى**.

---

## 3. 💾 التخزين ومساحات الجداول (Storage & Tablespaces)

### 3.1 استهلاك مساحات الجداول
```sql
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024) AS total_mb,
       ROUND(SUM(bytes - NVL(free_bytes,0))/1024/1024) AS used_mb,
       ROUND((SUM(bytes - NVL(free_bytes,0)) / SUM(bytes)) * 100, 1) AS pct_used
FROM (
    SELECT df.tablespace_name, df.bytes,
           (SELECT SUM(fs.bytes) FROM dba_free_space fs 
            WHERE fs.tablespace_name = df.tablespace_name AND fs.file_id = df.file_id) AS free_bytes
    FROM dba_data_files df
)
GROUP BY tablespace_name ORDER BY pct_used DESC;
```
> **متى تقلق؟** إذا تجاوزت نسبة الاستهلاك `pct_used` الـ 85%، يجب إضافة مساحة. إذا تجاوزت 95%، فالأمر عاجل جداً!

---

## 4. 🔒 الأقفال والنزاعات (Locks & Contention)

### 4.1 من يحجب من؟ (Blocking Locks)
```sql
SELECT s1.inst_id AS blocker_inst, s1.sid AS blocker_sid, s1.username AS blocker_user,
       s2.inst_id AS waiter_inst, s2.sid AS waiter_sid, s2.username AS waiter_user
FROM gv$lock l1
JOIN gv$session s1 ON l1.sid = s1.sid AND l1.inst_id = s1.inst_id
JOIN gv$lock l2 ON l1.id1 = l2.id1 AND l1.id2 = l2.id2 AND l1.block = 1 AND l2.request > 0
JOIN gv$session s2 ON l2.sid = s2.sid AND l2.inst_id = s2.inst_id;
```
> يحدد هذا الاستعلام "الجاني" الذي يحجب الآخرين.

---

## 5. 👥 المستخدمون والأمان

### 5.1 قائمة المستخدمين وحالتهم
```sql
SELECT username, account_status, profile, expiry_date, last_login
FROM dba_users
WHERE oracle_maintained = 'N'
ORDER BY username;
```

---

## 8. 🔧 أوامر مدير قاعدة البيانات اليومية

- **البدء والإيقاف**:
  - `STARTUP;` (فتح قاعدة البيانات).
  - `SHUTDOWN IMMEDIATE;` (إغلاق آمن وسريع).
- **أوامر RAC (srvctl)**:
  - `srvctl status database -d RACDB` (حالة قاعدة البيانات في الكلاستر).
  - `srvctl stop instance -d RACDB -i RACDB1` (إيقاف نسخة محددة).
- **مراجعة سجل الأخطاء (Alert Log)**:
  - `adrci` ثم `SHOW ALERT` (الطريقة الرسمية لمراجعة سجل أوراكل).

> **نصيحة**: اقرأ سجل الـ Alert Log يومياً. إنه "المذكرات" الخاصة بقاعدة البيانات وأول مكان تبحث فيه عند حدوث مشكلة.

---
**التالي: [من المختبر إلى الإنتاج الحقيقي](./ar/GUIDE_FROM_LAB_TO_PRODUCTION.md)**
