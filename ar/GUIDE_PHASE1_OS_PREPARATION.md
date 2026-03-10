# المرحلة 1: تحضير العقد ونظام التشغيل (Oracle Linux 7.9)

> **بنية المرجع**: عقدتا RAC أساسي (`rac1` ، `rac2`) + عقدتا RAC احتياطي (`racstby1` ، `racstby2`).
> يجب تنفيذ جميع الأوامر كمستخدم `root` ما لم يذكر خلاف ذلك.
> يجب تكرار خطوات هذه المرحلة على **جميع العقد** ما لم يحدد خلاف ذلك.

---

### ما هو DNS ولماذا نحتاجه؟

**DNS (Domain Name System)** هو الخدمة التي تترجم الأسماء إلى عناوين IP. عندما تكتب `rac-scan.localdomain` ، يستجيب الـ DNS بـ `192.168.56.105, 192.168.56.106, 192.168.56.107`.

**لماذا يتطلبه Oracle RAC؟**
- يجب أن يحل **SCAN** (Single Client Access Name) إلى 3 عناوين IP في وقت واحد.
- ملف `/etc/hosts` **لا يكفي** لـ SCAN لأنه لا يدعم خاصية Round-Robin (التوزيع الدائري).
- يسمح DNS بـ **round-robin**: يتم توزيع اتصالات العملاء تلقائياً بين عناوين IP الثلاثة.

---

## 1.1 خطة العناوين (IP) وأسماء المضيفين

| الدور | اسم المضيف | IP العامة | IP الخاصة | IP VIP |
|---|---|---|---|---|
| عقدة RAC 1 | rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 |
| عقدة RAC 2 | rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 |
| RAC SCAN | rac-scan | .105, .106, .107 | - | - |
| احتياطي عقدة 1 | racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 |
| احتياطي عقدة 2 | racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 |

---

## 1.2 إعداد الشبكة المؤقت (عبر شاشة VirtualBox)

قبل استخدام MobaXterm، يجب إعطاء IP للجهاز يدوياً:
1. سجل الدخول كـ `root`.
2. نفذ `hostnamectl set-hostname rac1.localdomain`.
3. نفذ `nmtui` لتكوين IP ثابت (مثلاً `192.168.56.101/24`) وتأكد من تفعيل "Automatically connect".
4. نفذ `systemctl restart network`.

---

## 1.3 تكوين ملفات الشبكة الثابتة (عبر MobaXterm)

> **ملاحظة**: الأسماء الشائعة للمحولات هي `enp0s3` (للإنترنت)، `enp0s8` (للعامة)، `enp0s9` (للخاصة).

### 1. محول الإنترنت (NAT) ← `enp0s3`
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s3 <<'EOF'
TYPE=Ethernet
BOOTPROTO=dhcp
NAME=enp0s3
DEVICE=enp0s3
ONBOOT=yes
EOF
```

### 2. المحول العام (192.168.56.x) ← `enp0s8`
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s8 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=enp0s8
DEVICE=enp0s8
ONBOOT=yes
IPADDR=192.168.56.101
NETMASK=255.255.255.0
DOMAIN=localdomain
EOF
```

### 3. المحول الخاص (Interconnect) ← `enp0s9`
```bash
cat > /etc/sysconfig/network-scripts/ifcfg-enp0s9 <<'EOF'
TYPE=Ethernet
BOOTPROTO=static
NAME=enp0s9
DEVICE=enp0s9
ONBOOT=yes
IPADDR=192.168.1.101
NETMASK=255.255.255.0
EOF
```

---

## 1.4 تكوين ملف /etc/hosts

نفذ على جميع العقد:
```bash
cat >> /etc/hosts <<'EOF'
# === RAC PRIMARY ===
192.168.56.101   rac1.localdomain       rac1
192.168.56.102   rac2.localdomain       rac2
192.168.1.101    rac1-priv.localdomain  rac1-priv
192.168.1.102    rac2-priv.localdomain  rac2-priv
192.168.56.103   rac1-vip.localdomain   rac1-vip
192.168.56.104   rac2-vip.localdomain   rac2-vip

# === RAC STANDBY ===
192.168.56.111   racstby1.localdomain      racstby1
192.168.56.112   racstby2.localdomain      racstby2
192.168.2.111    racstby1-priv.localdomain racstby1-priv
192.168.2.112    racstby2-priv.localdomain racstby2-priv
192.168.56.113   racstby1-vip.localdomain  racstby1-vip
192.168.56.114   racstby2-vip.localdomain  racstby2-vip
EOF
```

---

## 1.5 تعطيل الجدار الناري و SELinux

```bash
# تعطيل الجدار الناري
systemctl stop firewalld
systemctl disable firewalld

# تعطيل SELinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
```

---

## 1.5ب تكوين /tmp كـ Filesystem في الذاكرة (tmpfs)

لزيادة السرعة وحماية القرص الأساسي، سنقوم بجعل `/tmp` يعمل من الذاكرة العشوائية (RAM):

```bash
echo "tmpfs  /tmp  tmpfs  defaults,size=4g,mode=1777  0 0" >> /etc/fstab
mount -o remount /tmp 2>/dev/null || mount /tmp
```

---

## 1.6 تثبيت حزم المتطلبات المسبقة

```bash
# تثبيت حزمة الإعداد المسبق لـ Oracle 19c
yum install -y oracle-database-preinstall-19c

# حزم إضافية مطلوبة
yum install -y ksh libaio-devel net-tools nfs-utils \
    smartmontools sysstat unzip wget xorg-x11-xauth \
    xorg-x11-utils xterm bind-utils
```

---

## 1.7 حل مشكلة RemoveIPC (مهم جداً!)

لمنع نظام التشغيل من حذف ذاكرة Oracle المشتركة عند تسجيل الخروج:
```bash
echo "RemoveIPC=no" >> /etc/systemd/logind.conf
systemctl restart systemd-logind
```

---

## 1.8 إنشاء المستخدمين والمجموعات

```bash
# مجموعات ASM
groupadd -g 54327 asmdba
groupadd -g 54328 asmoper
groupadd -g 54329 asmadmin

# إضافة مستخدم oracle لمجموعة asmdba
usermod -a -G asmdba oracle

# إنشاء مستخدم grid
useradd -u 54331 -g oinstall -G dba,asmdba,asmadmin,asmoper,racdba grid

# تعيين كلمات المرور
echo "oracle" | passwd --stdin oracle
echo "grid" | passwd --stdin grid
```

---

## 1.9 إنشاء مجلدات التثبيت (OFA)

```bash
mkdir -p /u01/app/19.0.0/grid
mkdir -p /u01/app/grid
mkdir -p /u01/app/oraInventory
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1

chown -R grid:oinstall   /u01/app/19.0.0/grid
chown -R grid:oinstall   /u01/app/grid
chown -R grid:oinstall   /u01/app/oraInventory
chown -R oracle:oinstall /u01/app/oracle
chmod -R 775 /u01
```

---

## 1.10 تحسينات النواة (Kernel Parameters)

### تعطيل Transparent HugePages (THP)
يسبب THP مشاكل في الأداء لـ Oracle.
1. عدل `/etc/default/grub` وأضف `transparent_hugepage=never` إلى `GRUB_CMDLINE_LINUX`.
2. نفذ `grub2-mkconfig -o /boot/grub2/grub.cfg`.

### ضبط Standard HugePages
سنخصص 2 جيجابايت للصفحات الضخمة:
```bash
echo "vm.nr_hugepages = 1024" >> /etc/sysctl.conf
sysctl -p
```

---

## 1.11 مزامنة الوقت (Chrony)

```bash
systemctl enable chronyd
systemctl restart chronyd
```

---

## 1.14 إجراء عملية النسخ (Cloning)

بمجرد الانتهاء من الإعدادات السابقة على `rac1` (الصورة الذهبية أو Golden Image):
1. أطفئ `rac1`.
2. خذ لقطة (Snapshot) باسم `SNAP-02: Golden_Image_Pronta`.
3. استنسخ `rac1` لإنشاء `rac2` و `racstby1` و `racstby2` مع اختيار "Generate new MAC addresses".
4. **مهم**: بعد الاستنساخ، أعد ربط الأقراص المشتركة الأصلية لـ `rac2` (تأكد من عدم استخدام نسخ الأقراص التي أنشأها VirtualBox تلقائياً).

---

## 1.15 إعداد الثقة المتبادلة (SSH Trust)

يجب تنفيذ هذا بعد تشغيل العقد وتغيير أسمائها وعناوين الـ IP الخاصة بها:
1. توليد المفاتيح لكل من `grid` و `oracle` على جميع العقد (`ssh-keygen`).
2. تبادل المفاتيح باستخدام `ssh-copy-id` بحيث تستطيع كل عقدة الدخول للأخرى بدون كلمة مرور.

---

## 1.16 إنشاء أقراص ASM (بعد النسخ)

على العقدة الأولى (`rac1`) فقط:
```bash
oracleasm createdisk CRS1 /dev/sdc1
oracleasm createdisk CRS2 /dev/sdd1
oracleasm createdisk CRS3 /dev/sde1
oracleasm createdisk DATA /dev/sdf1
oracleasm createdisk RECO /dev/sdg1
```

على العقدة الثانية (`rac2`):
```bash
oracleasm scandisks
oracleasm listdisks
```

---

## ✅ قائمة التحقق النهائية للمرحلة 1

قبل الانتقال للمرحلة 2، تأكد من:
1. أسماء المضيفين صحيحة.
2. القدرة على عمل `ping` لجميع المحطات (العامة والخاصة).
3. عمل الـ DNS SCAN بنجاح (يعيد 3 عناوين).
4. عمل SSH بدون كلمة مرور لمستخدمي `grid` و `oracle`.

---
**التالي: [المرحلة 2: تثبيت Grid Infrastructure و Oracle RAC](./ar/GUIDE_PHASE2_GRID_AND_RAC.md)**
