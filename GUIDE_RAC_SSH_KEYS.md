# GUIDE SSH Keys RAC (grid, oracle, root)

This guide is for configuring or repairing SSH user equivalence in the Oracle RAC/Data Guard lab.
Objective: avoid errors`PRVG-2019`, `Host key verification failed`, `Permission denied`.

---

## 1) Quando usarla

Usala quando:

- `runcluvfy.sh` fallisce su `Verifying User Equivalence`
- `ssh-copy-id` not complete for `grid`/`oracle`
- after clone/snapshot the host key changes and `Host key verification failed` appears
- you want to start from scratch with clean keys

---

## 2) Target nodes and users

Standby nodes:

- `racstby1`
- `racstby2`

Users:

- `grid`
- `oracle`
- `root`

---

## 3) Standard procedure (manual)

### Step 0 - Reset (optional, recommended if you have already tried)

Run on `racstby1` and `racstby2` as `root`:

```bash
rm -rf /home/grid/.ssh
rm -rf /home/oracle/.ssh
rm -rf /root/.ssh
```

### Step 1 - Generate keys on both nodes

```bash
su - grid   -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
su - oracle -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
su - root   -c "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
```

### Step 2 - Aggiorna known_hosts su entrambi i nodi

```bash
su - grid   -c "ssh-keygen -R racstby1 >/dev/null 2>&1 || true"
su - grid   -c "ssh-keygen -R racstby2 >/dev/null 2>&1 || true"
su - grid   -c "ssh-keyscan -H racstby1 racstby2 >> ~/.ssh/known_hosts"
su - grid   -c "chmod 600 ~/.ssh/known_hosts"

su - oracle -c "ssh-keygen -R racstby1 >/dev/null 2>&1 || true"
su - oracle -c "ssh-keygen -R racstby2 >/dev/null 2>&1 || true"
su - oracle -c "ssh-keyscan -H racstby1 racstby2 >> ~/.ssh/known_hosts"
su - oracle -c "chmod 600 ~/.ssh/known_hosts"

su - root   -c "ssh-keygen -R racstby1 >/dev/null 2>&1 || true"
su - root   -c "ssh-keygen -R racstby2 >/dev/null 2>&1 || true"
su - root   -c "ssh-keyscan -H racstby1 racstby2 >> ~/.ssh/known_hosts"
su - root   -c "chmod 600 ~/.ssh/known_hosts"
```

### Step 3 - Trust bidirezionale

```bash
# grid
# da racstby1
su - grid -c "ssh-copy-id grid@racstby1"
su - grid -c "ssh-copy-id grid@racstby2"
# da racstby2
su - grid -c "ssh-copy-id grid@racstby1"
su - grid -c "ssh-copy-id grid@racstby2"

# oracle
# da racstby1
su - oracle -c "ssh-copy-id oracle@racstby1"
su - oracle -c "ssh-copy-id oracle@racstby2"
# da racstby2
su - oracle -c "ssh-copy-id oracle@racstby1"
su - oracle -c "ssh-copy-id oracle@racstby2"

# root
# da racstby1
su - root -c "ssh-copy-id root@racstby1"
su - root -c "ssh-copy-id root@racstby2"
# da racstby2
su - root -c "ssh-copy-id root@racstby1"
su - root -c "ssh-copy-id root@racstby2"
```

### Step 4 - Final check

```bash
su - grid   -c "ssh racstby1 hostname"
su - grid   -c "ssh racstby2 hostname"
su - oracle -c "ssh racstby1 hostname"
su - oracle -c "ssh racstby2 hostname"
su - root   -c "ssh racstby1 hostname"
su - root   -c "ssh racstby2 hostname"
```

---

## 4) Complete reset (if you made confusing attempts)

Run on `racstby1` and `racstby2` as `root`:

```bash
rm -rf /home/grid/.ssh
rm -rf /home/oracle/.ssh
rm -rf /root/.ssh
```

Then start again from section 3.

---

## 5) Quick fix common errors

### 5.1 `Host key verification failed`

The saved host key no longer matches (typical after clone/snapshot).

```bash
su - grid   -c "ssh-keygen -R racstby1 >/dev/null 2>&1 || true"
su - grid   -c "ssh-keygen -R racstby2 >/dev/null 2>&1 || true"
su - grid   -c "ssh-keyscan -H racstby1 racstby2 >> ~/.ssh/known_hosts"
su - grid   -c "chmod 600 ~/.ssh/known_hosts"

su - oracle -c "ssh-keygen -R racstby1 >/dev/null 2>&1 || true"
su - oracle -c "ssh-keygen -R racstby2 >/dev/null 2>&1 || true"
su - oracle -c "ssh-keyscan -H racstby1 racstby2 >> ~/.ssh/known_hosts"
su - oracle -c "chmod 600 ~/.ssh/known_hosts"

su - root   -c "ssh-keygen -R racstby1 >/dev/null 2>&1 || true"
su - root   -c "ssh-keygen -R racstby2 >/dev/null 2>&1 || true"
su - root   -c "ssh-keyscan -H racstby1 racstby2 >> ~/.ssh/known_hosts"
su - root   -c "chmod 600 ~/.ssh/known_hosts"
```

### 5.2 `Permission denied (publickey,...)` su `grid`/`oracle`

Check that your password and user shell are healthy first:

```bash
passwd grid
passwd oracle
getent passwd grid
getent passwd oracle
```

Then check permissions on the destination side:

```bash
ls -ld /home/grid /home/grid/.ssh
ls -l /home/grid/.ssh
ls -ld /home/oracle /home/oracle/.ssh
ls -l /home/oracle/.ssh
```

Correct permissions:

- user home not writable by others (`755` or `750`)
- `.ssh` = `700`
- `authorized_keys` = `600`
- owner coerente (`grid:oinstall` o `oracle:oinstall`)

### 5.3 `PRVG-2019` in cluvfy

Redo all of section 3 and relaunch:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/runcluvfy.sh stage -pre crsinst -n racstby1,racstby2 -verbose
```

---

## 6) Plan B (if ssh-copy-id fails for grid/oracle)

Da `racstby1`:

```bash
cat /home/grid/.ssh/id_rsa.pub | ssh root@racstby2 \
"install -d -m 700 -o grid -g oinstall /home/grid/.ssh; cat >> /home/grid/.ssh/authorized_keys; chown grid:oinstall /home/grid/.ssh/authorized_keys; chmod 600 /home/grid/.ssh/authorized_keys"

cat /home/oracle/.ssh/id_rsa.pub | ssh root@racstby2 \
"install -d -m 700 -o oracle -g oinstall /home/oracle/.ssh; cat >> /home/oracle/.ssh/authorized_keys; chown oracle:oinstall /home/oracle/.ssh/authorized_keys; chmod 600 /home/oracle/.ssh/authorized_keys"
```

Da `racstby2`:

```bash
cat /home/grid/.ssh/id_rsa.pub | ssh root@racstby1 \
"install -d -m 700 -o grid -g oinstall /home/grid/.ssh; cat >> /home/grid/.ssh/authorized_keys; chown grid:oinstall /home/grid/.ssh/authorized_keys; chmod 600 /home/grid/.ssh/authorized_keys"

cat /home/oracle/.ssh/id_rsa.pub | ssh root@racstby1 \
"install -d -m 700 -o oracle -g oinstall /home/oracle/.ssh; cat >> /home/oracle/.ssh/authorized_keys; chown oracle:oinstall /home/oracle/.ssh/authorized_keys; chmod 600 /home/oracle/.ssh/authorized_keys"
```

---

## 7) Checklist finale

- `ssh racstby1 hostname` and `ssh racstby2 hostname` without password for `grid`, `oracle`, `root`
- no errors`PRVG-2019` in `cluvfy`
- `known_hosts` and `authorized_keys` files with correct owner/permissions
