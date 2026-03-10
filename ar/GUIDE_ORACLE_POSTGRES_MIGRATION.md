# الهجرة من أوراكل إلى PostgreSQL باستخدام GoldenGate

> **الهدف**: هجرة قاعدة بيانات أوراكل (من مختبر الـ RAC الخاص بنا) إلى PostgreSQL 16 باستخدام Oracle GoldenGate للمزامنة اللحظية وضمان أقل وقت توقف ممكن (Zero-downtime).

---

## بنية الهجرة (Migration Architecture)

تتضمن هذه الهجرة نقل البيانات من بيئة أوراكل المعقدة (RAC/CDB) إلى بيئة PostgreSQL حديثة. يقوم GoldenGate بدور "المترجم" والموزع للبيانات بين النظامين المختلفين.

---

## المتطلبات المسبقة

- **أوراكل المصدر**: الإصدار 19c (مختبرنا الحالي).
- **PostgreSQL الهدف**: الإصدار 16.x.
- **الأدوات**:
  - GoldenGate المخصص لأوراكل (Extract).
  - GoldenGate المخصص لـ PostgreSQL (Replicat).
  - أداة `ora2pg` لتحويل هيكل البيانات (Schema Conversion).

---

## المرحلة 1: تجهيز أوراكل (المصدر)

يجب تفعيل **Supplemental Logging** للسماح لـ GoldenGate بالتقاط جميع تفاصيل العمليات:
```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER TABLE hr.employees ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```
*لماذا؟* أوراكل عادة لا تسجل كل الأعمدة في سجلات الإعادة، لكن GoldenGate يحتاج إليها لبناء أوامر SQL صحيحة في الجانب الآخر (PostgreSQL).

---

## المرحلة 2: تجهيز PostgreSQL (الهدف)

1. **تغيير إعدادات الـ WAL**: يجب ضبط `wal_level = logical` للسماح بـ Logical Replication.
2. **تحويل الهيكل (Schema)**: أوراكل تستخدم أنواع بيانات مختلفة (مثل NUMBER و VARCHAR2)، نستخدم أداة `ora2pg` لتحويل هذه الأنواع تلقائياً إلى ما يقابلها في PostgreSQL (مثل BIGINT و VARCHAR).
3. **تحديد الهوية (Replica Identity)**: يجب ضبط الجداول لضمان تعريف السجلات بشكل صحيح أثناء التحديث:
```sql
ALTER TABLE hr.employees REPLICA IDENTITY FULL;
```

---

## المرحلة 3: إعداد GoldenGate

- يتم تثبيت نسخة GoldenGate الخاصة بـ PostgreSQL على خادم الهدف.
- نحتاج لتعريف تعريفات الـ **ODBC** لتمكين GoldenGate من الاتصال بـ PostgreSQL.

---

## المرحلة 4: تكوين العمليات (Processes)

1. **Extract**: لقراءة التغييرات من أوراكل.
2. **Replicat**: لتطبيق هذه التغييرات على PostgreSQL.
3. **Initial Load**: استخدام Data Pump للتصدير من أوراكل، ثم استخدام `ora2pg -t INSERT` لتحميل البيانات في PostgreSQL لأول مرة.

---

## المرحلة 5: التحويل النهائي (Cutover)

عندما يصبح التأخير (Lag) بين النظامين صفراً:
1. اقلب التطبيق إلى وضع "القراءة فقط".
2. انتظر حتى ينهي GoldenGate نقل آخر العمليات.
3. قم بتغيير رابط الاتصال في التطبيق (Connection String) من Oracle إلى PostgreSQL.
4. أعد تشغيل التطبيقات.

---

## خريطة أنواع البيانات (Oracle → PostgreSQL)

| أوراكل | PostgreSQL | ملاحظات |
|---|---|---|
| `NUMBER` | `NUMERIC` / `BIGINT` | حسب الدقة المطلوبة |
| `VARCHAR2` | `VARCHAR` | متطابق |
| `DATE` | `TIMESTAMP` | التاريخ في أوراكل يشمل الوقت |
| `CLOB` | `TEXT` | PostgreSQL لا يضع حدوداً للـ Text |
| `SYSDATE` | `NOW()` | دالة الوقت الحالي |

---
**التالي: [دليل التبديل الكامل (Full Switchover)](./ar/GUIDE_FULL_SWITCHOVER.md)**
