# دليل إضافي: إعداد OCI ARM (Always Free) كهدف لـ GoldenGate

> 🚀 **الهدف:** بدلاً من إنشاء جهاز افتراضي ثقيل آخر على جهازك المحلي ليكون هدفاً لـ GoldenGate (مما قد يستهلك الذاكرة)، سنستفيد من **المستوى المجاني الدائم لـ Oracle Cloud (OCI)**.
> سنقوم بإنشاء نسخة ARM قوية جداً (4 OCPUs و 24 جيجابايت RAM - مجانية للأبد!) وسنقوم بتثبيت **Oracle Database 23ai Free** عليها بأمر واحد. ستكون قاعدة البيانات هذه في السحابة هي الهدف البعيد (Replicat) للبيانات المستخرجة من RAC 19c المحلي الخاص بك!

---

## 1. إنشاء نسخة ARM على Oracle Cloud

1. سجل الدخول إلى وحدة تحكم **Oracle Cloud Infrastructure (OCI)**.
2. انتقل إلى **Compute** -> **Instances** -> **Create Instance**.
3. املأ الحقول الأساسية:
   - **Name:** `dbtarget-arm`
   - **Image and shape:**
     - **Image:** `Oracle Linux 8` (تأكد من أنها النسخة 8 وليس 9).
     - **Shape:** انقر فوق `Change Shape` -> `Virtual Machine` -> `Ampere` -> اختر **`VM.Standard.A1.Flex`**. اضبط **4 OCPUs** و **24 GB Memory**. (هذا العرض "Always Free").
   - **Networking:** اترك الإعدادات الافتراضية. تأكد من ضبط **Assign a public IPv4 address** على `Yes`.
   - **SSH Keys:** اختر `Generate a key pair for me` وقم بتحميل **Private Key** (ستحتاجها للاتصال عبر MobaXterm!).
   - **Boot volume:** يمكنك تركه 50 جيجابايت.
4. انقر فوق **Create** وانتظر حتى تصبح النسخة باللون الأخضر (**RUNNING**).
5. **انسخ عنوان IP العام** (مثال: `130.x.x.x`).

---

## 2. بنية الشبكة: محلي ↔ سحابي

في بيئة العمل الحقيقية (**Enterprise**)، ستقوم بربط مركز البيانات المحلي بـ Oracle Cloud عبر:
1. **IPsec Site-to-Site VPN**: نفق مشفر بين جدار حماية الشركة و OCI.
2. **Oracle FastConnect**: خط ألياف ضوئية خاص ومخصص (عالي التكلفة والأداء).

في مختبرنا، سنستخدم **Tailscale (WireGuard)**: وهي شبكة VPN مشفرة وخفيفة جداً تسمح للأجهزة المحلية والنسخة السحابية برؤية بعضها البعض كأنها في شبكة خاصة واحدة.

---

## 3. الاتصال الأولي عبر MobaXterm وإعداد نظام التشغيل

1. افتح **MobaXterm** وأنشئ جلسة SSH باستخدام IP العام والمفتاح الخاص للمستخدم `opc`.
2. تحول للمستخدم `root`: `sudo su -`.
3. **إعداد مساحة التبديل (Swap)** (مطلوبة لقاعدة بيانات أوراكل):
```bash
dd if=/dev/zero of=/swapfile count=4096 bs=1MiB
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile   swap    swap    sw  0 0" >> /etc/fstab
```
4. **تثبيت Tailscale**:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```
*اتبع رابط المصادقة لتسجيل الجهاز في شبكتك الخاصة.*

---

## 4. التثبيت "السحري" لـ Oracle Database 23ai Free

بفضل مستودعات `yum` الرسمية، التثبيت سهل جداً:
```bash
# 1. تثبيت المتطلبات المسبقة
dnf install -y oracle-database-preinstall-23ai

# 2. تثبيت البرنامج
dnf install -y oracle-database-free-23ai

# 3. تكوين قاعدة البيانات (سيطلب منك كلمة مرور لـ sys/system)
/etc/init.d/oracle-free-23ai configure
```

### إعداد متغيرات البيئة للمستخدم `oracle`:
```bash
su - oracle
cat >> ~/.bash_profile <<EOF
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/23ai/dbhomeFree
export ORACLE_SID=FREE
export PATH=\$PATH:\$ORACLE_HOME/bin
EOF
source ~/.bash_profile
```

---

## 6. تثبيت Oracle GoldenGate 23ai Free (Microservices)

في نسخة ARM، يتوفر GoldenGate 23ai Free مباشرة عبر مستودعات `dnf`:
```bash
# كـ root
dnf install -y oracle-goldengate-free-23ai

# إعداد المجلدات
mkdir -p /opt/oracle/gg_home
mkdir -p /opt/oracle/gg_deploy
chown -R oracle:oinstall /opt/oracle/gg_*

# تشغيل سكربت التكوين التلقائي
/opt/oracle/goldengate/bin/oggca.sh \
  -silent \
  -responseFile /opt/oracle/goldengate/response/oggca.rsp \
  -showProgress \
  oggDeploy.deploymentName=Target \
  oggDeploy.deploymentDirectory=/opt/oracle/gg_deploy \
  oggDeploy.administratorUser=admin \
  oggDeploy.administratorPassword=oracle \
  oggDeploy.dbVersion=Oracle \
  oggSoftwareHome=/opt/oracle/goldengate
```

### فتح المنافذ (Firewall):
افتح المنافذ من 9011 إلى 9014 (TCP) للسماح لخدمات GoldenGate بالعمل، ولكن فقط عبر واجهة `tailscale0` للأمان التام.

---

## 7. الجسر السحري: ربط المحلي بالسحابي

على عقد RAC المحلية (في VirtualBox)، قم بتثبيت Tailscale أيضاً (`tailscale up`) وتأكد من تسجيل الدخول بنفس الحساب.
بعد ذلك، أضف عنوان IP الخاص (Tailscale) للنسخة السحابية في ملف `/etc/hosts` المحلي:
```bash
echo "100.x.x.C   dbtarget.localdomain   dbtarget" >> /etc/hosts
```

بهذه الطريقة، عندما تخبر GoldenGate في المختبر المحلي بإرسال البيانات إلى `dbtarget` ، ستنتقل البيانات عبر النفق المشفر مباشرة إلى السحابة!

---
**التالي: [المرحلة 5: تكوين GoldenGate](./ar/GUIDE_PHASE5_GOLDENGATE.md)** (العودة لإكمال إعداد الـ Extract).
