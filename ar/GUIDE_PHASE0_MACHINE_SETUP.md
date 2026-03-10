# المرحلة 0: إعداد الأجهزة (VirtualBox)

> **يجب إكمال هذه المرحلة قبل أي شيء آخر.** هنا سنقوم بإنشاء الأجهزة الافتراضية (VMs) في VirtualBox لـ DNS، و RAC الأساسي، و RAC الاحتياطي.
> **استناداً إلى**: [دليل Oracle Base RAC 19c](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox) — معدل خصيصاً للتثبيت اليدوي خطوة بخطوة.

### نظرة عامة على مختبر VirtualBox

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                         جهاز الكمبيوتر الخاص بك (HOST VIRTUALBOX)              ║
║                                                                                  ║
║   ┌───────────────────────────────────────────────────────────────────────┐      ║
║   │              Rete Host-Only #1 (192.168.56.0/24)                      │      ║
║   │                    "العامة" للعنقود (Cluster)                         │      ║
║   └──┬─────────┬────────┬──────────┬──────────┬──────────────────────────┘      ║
║      │         │        │          │          │                                  ║
║   ┌──┴───┐  ┌──┴──┐  ┌──┴──┐   ┌──┴──┐   ┌──┴──┐                              ║
║   │dns   │  │rac1 │  │rac2 │   │stby1│   │stby2│                               ║
║   │.56.50│  │.56.1│  │.56.2│   │.56.3│   │.56.4│   dbtarget + GG على السحابة  ║
║   │1GB   │  │8GB  │  │8GB  │   │8GB  │   │8GB  │                               ║
║   │1CPU  │  │4CPU │  │4CPU │   │4CPU │   │4CPU │                               ║
║   └──────┘  └──┬──┘  └──┬──┘   └──┬──┘   └──┬──┘                               ║
║                │        │        │         │                                    ║
║             ┌──┴────────┴──┐  ┌──┴─────────┴──┐                                ║
║             │  Host-Only   │  │  Host-Only    │    (شبكات الربط البيني الخاصة) ║
║             │  #2: 192.168 │  │  #3: 192.168  │    منفصلة لكل عنقود            ║
║             │  .1.x (أسا)  │  │  .2.x (احتيا) │                                ║
║             └──────────────┘  └───────────────┘                                ║
║                                                                                  ║
║   الأقراص المشتركة (Shareable VDI):                                             ║
║   ┌────────────────────────┐    ┌────────────────────────┐                      ║
║   │ rac1 + rac2            │    │ racstby1 + racstby2    │                      ║
║   │ asm-crs-disk1  2GB     │    │ asm-stby-crs-1  2GB   │                      ║
║   │ asm-crs-disk2  2GB     │    │ asm-stby-crs-2  2GB   │                      ║
║   │ asm-crs-disk3  2GB     │    │ asm-stby-crs-3  2GB   │                      ║
║   │ asm-data-disk1 20GB    │    │ asm-stby-data   20GB  │                      ║
║   │ asm-reco-disk1 15GB    │    │ asm-stby-reco   15GB  │                      ║
║   └────────────────────────┘    └────────────────────────┘                      ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```

---

## 0.1 ما تحتاجه (متطلبات الأجهزة)

| الجهاز | النوع | RAM | CPU | قرص النظام | قرص /u01 | أقراص ASM |
|---|---|---|---|---|---|---|
| `dnsnode` | VM VirtualBox | **1 GB** | **1 vCPU** | 15 GB | — | — |
| `rac1` | VM VirtualBox | **8 GB** | **4 vCPU** | 50 GB | 100 GB | 5 مشتركة |
| `rac2` | VM (نسخة من rac1) | **8 GB** | **4 vCPU** | 50 GB | 100 GB | نفس rac1 |
| `racstby1` | VM VirtualBox | **8 GB** | **4 vCPU** | 50 GB | 100 GB | 5 مشتركة (خاصة بها) |
| `racstby2` | VM (نسخة من racstby1) | **8 GB** | **4 vCPU** | 50 GB | 100 GB | نفس racstby1 |

> **لماذا DNS منفصل؟** تنصح Oracle Base باستخدام جهاز افتراضي DNS مخصص مع **Dnsmasq** (بديل خفيف لـ BIND). بهذه الطريقة لا يتوقف DNS عند إعادة تشغيل عقد RAC، ويعمل SCAN دائماً. تكلفته 1 جيجابايت فقط.
>
> **لماذا قرص /u01 منفصل؟** يجب تثبيت برمجيات Oracle (Grid + DB) على قرص منفصل. تستخدم Oracle Base هذا النهج — فصل الملفات التنفيذية عن نظام التشغيل.
>
> **`dbtarget` و GoldenGate** يعملان على **سحابة OCI** أو جهاز آخر، وليس على هذا الكمبيوتر.

### خطة العناوين (IP) الكاملة

| اسم المضيف | النوع | IP العامة | IP الخاصة | ملاحظات |
|---|---|---|---|---|
| `dnsnode` | DNS Server | 192.168.56.50 | — | Dnsmasq |
| `rac1` | RAC الأساسي رقم 1 | 192.168.56.101 | 192.168.1.101 | |
| `rac2` | RAC الأساسي رقم 2 | 192.168.56.102 | 192.168.1.102 | |
| `rac1-vip` | VIP رقم 1 | 192.168.56.103 | — | مدار بواسطة CRS |
| `rac2-vip` | VIP رقم 2 | 192.168.56.104 | — | مدار بواسطة CRS |
| `rac-scan` | SCAN (3 IPs) | 192.168.56.105-107 | — | Round-Robin DNS |
| `racstby1` | الاحتياطي رقم 1 | 192.168.56.111 | 192.168.2.111 | |
| `racstby2` | الاحتياطي رقم 2 | 192.168.56.112 | 192.168.2.112 | |
| `racstby1-vip` | VIP الاحتياطي رقم 1 | 192.168.56.113 | — | مدار بواسطة CRS |
| `racstby2-vip` | VIP الاحتياطي رقم 2 | 192.168.56.114 | — | مدار بواسطة CRS |
| `racstby-scan` | SCAN الاحتياطي | 192.168.56.115-117 | — | Round-Robin DNS |

### البرمجيات المطلوب تحميلها قبل البدء

| البرنامج | الملف | الرابط | الحجم |
|---|---|---|---|
| Oracle Linux 7.9 ISO | `OracleLinux-R7-U9-Server-x86_64-dvd.iso` | [yum.oracle.com](https://yum.oracle.com/oracle-linux-isos.html) | ~4.6 GB |
| Grid Infrastructure 19c | `LINUX.X64_193000_grid_home.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~2.7 GB |
| Database 19c | `LINUX.X64_193000_db_home.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~2.9 GB |
| Oracle GoldenGate 19c/21c | `fbo_ggs_Linux_x64_Oracle_shiphome.zip` | [edelivery.oracle.com](https://edelivery.oracle.com) | ~500 MB |
| VirtualBox | الأخير | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) | ~100 MB |

---

## 0.2 تكوين الشبكات في VirtualBox (مرة واحدة فقط)

قبل إنشاء أي جهاز افتراضي، قم بتكوين الشبكات على المستوى العام.

### شبكة Host-Only رقم 1: الشبكة "العامة" للعنقود (192.168.56.0/24)

1. افتح VirtualBox ← **File > Tools > Network Manager**
2. اختر التبويب **Host-only Networks**
3. انقر على **Create**
4. التكوين:
    - عنوان IPv4: `192.168.56.1`
    - القناع: `255.255.255.0`
    - **DHCP Server**: ❌ **معطل** (نستخدم عناوين ثابتة!)

### شبكة Host-Only رقم 2: الربط البيني لـ RAC الأساسي (192.168.1.0/24)

5. انقر على **Create** مرة أخرى
6. التكوين:
    - عنوان IPv4: `192.168.1.1`
    - القناع: `255.255.255.0`
    - **DHCP**: ❌ معطل

### شبكة Host-Only رقم 3: الربط البيني لـ RAC الاحتياطي (192.168.2.0/24)

7. انقر على **Create** مرة ثالثة
8. التكوين:
    - عنوان IPv4: `192.168.2.1`
    - القناع: `255.255.255.0`
    - **DHCP**: ❌ معطل

---

## 0.3 إنشاء جهاز الـ DNS الافتراضي (أولاً وقبل كل شيء)

### إنشاء VM `dnsnode` في VirtualBox

1. **New** ← الاسم: `dnsnode`, النوع: Linux, Oracle (64-bit)
2. **RAM**: 1024 MB (1 GB)
3. **CPU**: 1
4. **Disk**: 15 GB
5. **Network**:
    - المحول 1: **NAT** (للوصول إلى الإنترنت/yum)
    - المحول 2: **Host-only Adapter** ← اختر الشبكة 192.168.56.0
6. **تثبيت Oracle Linux 7.9** (تثبيت بسيط، بدون واجهة رسومية)

### تكوين الشبكة (من خلال شاشة VirtualBox)

من شاشة VirtualBox:
1. سجل الدخول بـ `root`
2. اكتب الأمر: `nmtui`
3. اختر **Edit a connection**
4. **تفعيل NAT (الإنترنت)**: اختر المحول الأول (غالباً `enp0s3`), اذهب إلى Edit, وحدد خيار **"Automatically connect"**.
5. **تكوين الـ IP الثابت**: اختر المحول الثاني (غالباً `enp0s8`), اذهب إلى Edit.
6. غير IPv4 Configuration إلى **Manual**.
7. أدخل العنوان: `192.168.56.50/24` (اترك البوابة فارغة).
8. احفظ واخرج.
9. اكتب: `systemctl restart network`
10. **تأكد**: من وصول الإنترنت قبل المتابعة!
    `ping -c 2 google.com`

### الاتصال عبر MobaXterm (الآن يمكنك النسخ واللصق!)

افتح **MobaXterm** وأنشئ جلسة SSH إلى العنوان `192.168.56.50`.

### تكوين Dnsmasq

```bash
# نفذ كـ root عبر MobaXterm

# 2. ملء /etc/hosts بجميع أسماء المضيفين
cat >> /etc/hosts <<EOF

# === RAC PRIMARY ===
192.168.56.101   rac1.localdomain       rac1
192.168.56.102   rac2.localdomain       rac2
192.168.1.101    rac1-priv.localdomain  rac1-priv
192.168.1.102    rac2-priv.localdomain  rac2-priv
192.168.56.103   rac1-vip.localdomain   rac1-vip
192.168.56.104   rac2-vip.localdomain   rac2-vip
192.168.56.105   rac-scan.localdomain   rac-scan
192.168.56.106   rac-scan.localdomain   rac-scan
192.168.56.107   rac-scan.localdomain   rac-scan

# === RAC STANDBY ===
192.168.56.111   racstby1.localdomain      racstby1
192.168.56.112   racstby2.localdomain      racstby2
192.168.2.111    racstby1-priv.localdomain racstby1-priv
192.168.2.112    racstby2-priv.localdomain racstby2-priv
192.168.56.113   racstby1-vip.localdomain  racstby1-vip
192.168.56.114   racstby2-vip.localdomain  racstby2-vip
192.168.56.115   racstby-scan.localdomain  racstby-scan
192.168.56.116   racstby-scan.localdomain  racstby-scan
192.168.56.117   racstby-scan.localdomain  racstby-scan
EOF

# 3. تثبيت Dnsmasq وأدوات الشبكة
yum install -y dnsmasq bind-utils

# تكوين Dnsmasq
cat > /etc/dnsmasq.d/rac.conf <<EOF
interface=enp0s8
domain=localdomain
expand-hosts
local=/localdomain/
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
server=8.8.4.4
log-queries
EOF

# 4. التمكين والتشغيل
systemctl enable dnsmasq
systemctl start dnsmasq

# 5. فتح منفذ DNS في الجدار الناري
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload

# 6. اختبار DNSMASق
nslookup rac1.localdomain 192.168.56.50
nslookup rac-scan.localdomain 192.168.56.50      # يجب أن يعيد 3 عناوين IP!
```

---

## 0.4 إنشاء الـ VM `rac1` (RAC الأساسي — العقدة 1)

1. انقر على **New** (جديد)
2. الاسم: `rac1`, النوع: **Linux** → **Oracle (64-bit)**
3. الذاكرة: **8192 MB** (8 GB)
4. المعالج: **4** معالجات
5. القرص: **50 GB**

### تكوين العتاد (Settings)

#### Network (3 محولات شبكة)
- **المحول 1**: **NAT**
- **المحول 2**: **Host-only Adapter** ← شبكة 192.168.56.0 (العامة)
- **المحول 3**: **Host-only Adapter** ← شبكة 192.168.1.0 (الربط البيني الأساسي)

#### Storage (التخزين)
1. في **Controller: IDE**, اربط ملف الـ ISO الخاص بـ Oracle Linux 7.9
2. أضف قرصاً ثانياً بحجم **100 GB** (لـ `/u01`)

---

## 0.5 إنشاء الأقراص المشتركة لـ ASM

من VirtualBox ← **File > Virtual Media Manager** ← **Create**:

| القرص | الحجم | النوع | الاستخدام |
|---|---|---|---|
| `asm-crs-disk1.vdi` | **2 GB** | **Fixed Size** | OCR (نشاط العنقود) |
| `asm-crs-disk2.vdi` | **2 GB** | **Fixed Size** | Voting (التصويت) |
| `asm-crs-disk3.vdi` | **2 GB** | **Fixed Size** | Voting (التصويت) |
| `asm-data-disk1.vdi` | **20 GB** | **Fixed Size** | ملفات البيانات |
| `asm-reco-disk1.vdi` | **15 GB** | **Fixed Size** | النسخ الاحتياطي |

### جعل الأقراص قابلة للمشاركة (مهم جداً!)
1. اختر كل قرص ASM.
2. التبويب **Attributes** ← النوع: **Shareable**.
3. انقر **Apply**.

### ربط الأقراص بـ `rac1`
في إعدادات `rac1` ← **Storage** ← **Controller: SATA** ← أضف جميع الأقراص الخمسة.

---

## 0.6 تثبيت Oracle Linux 7.9 على `rac1`

1. شغل `rac1` ← اختر **Install Oracle Linux 7.9**.
2. **Software Selection**: اختر **Server with GUI** (مهم لتشغيل مثبت Oracle).
3. **Installation Destination**: اختر القرص 50GB.
4. **Network & Host Name**: فعل جميع الواجهات، واسم المضيف `rac1`.
5. **Root Password**: `oracle`.
6. بعد الانتهاء ← **Reboot**.

---

## 0.7 تحضير قرص /u01

قم بتنفيذ الأوامر التالية كـ `root`:

```bash
# 1. تقسيم القرص 100GB
fdisk /dev/sdb
# التسلسل: n, p, 1, Enter, Enter, w

# 2. تنسيق القسم بتنسيق XFS
mkfs.xfs -f /dev/sdb1

# 3. إنشاء المجلد
mkdir -p /u01

# 4. الإضافة إلى fstab لضمان التشغيل الدائم
UUID=$(blkid -s UUID -o value /dev/sdb1)
echo "UUID=${UUID}  /u01  xfs  defaults 0 0" >> /etc/fstab

# 5. التوصيل
mount -a
```

---

## 0.8 تكوين ASMLib لـ ASM

```bash
# تثبيت الحزم المطلوبة
yum install -y oracleasm-support kmod-oracleasm

# تحميل المكتبة يدوياً
cd /tmp
wget https://download.oracle.com/otn_software/asmlib/oracleasmlib-2.0.15-1.el7.x86_64.rpm
rpm -ivh oracleasmlib-2.0.15-1.el7.x86_64.rpm

# التكوين
oracleasm configure -i
# المستخدم: grid | المجموعة: asmadmin | بدء التشغيل: y

# البدء
oracleasm init
```

---

## 0.9 تحضير أقراص الاحتياطي (الأقراص فقط!)

في Virtual Media Manager، أنشئ 5 أقراص جديدة بحجم ثابت واجعلها **Shareable** للاحتياطي: `asm-stby-crs1, 2, 3` و `asm-stby-data` و `asm-stby-reco`.

---

## 0.10 الخطوات التالية: إعداد نظام التشغيل

بعد بناء الأجهزة، سننتقل إلى **[المرحلة 1](./ar/GUIDE_PHASE1_OS_PREPARATION.md)** لإعداد نظام التشغيل بشكل كامل (المستخدمين، النواة، وغيرها).

---

> 📸 **ملخص لقطات النظام (Snapshots)**:
> - **SNAP-DNS**: جهاز الـ DNS جاهز.
> - **SNAP-01_OS_Installato**: نظام التشغيل مثبت على rac1.
> - **SNAP-02_Base_VM_Ready**: الأقراص و ASMLib جاهزة على rac1.
