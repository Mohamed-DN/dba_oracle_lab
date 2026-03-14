# GUIDA SSH Keys RAC (grid, oracle, root)

Questa guida serve per configurare o riparare la user equivalence SSH nel lab Oracle RAC/Data Guard.
Obiettivo: evitare errori `PRVG-2019`, `Host key verification failed`, `Permission denied`.

---

## 1) Quando usarla

Usala quando:

- `runcluvfy.sh` fallisce su `Verifying User Equivalence`
- `ssh-copy-id` non completa per `grid`/`oracle`
- dopo clone/snapshot cambiano host key e compare `Host key verification failed`
- vuoi ripartire da zero con chiavi pulite

---

## 2) Nodi e utenti target

Nodi standby:

- `racstby1`
- `racstby2`

Utenti:

- `grid`
- `oracle`
- `root`

---

## 3) Procedura standard (rapida)

Esegui questo blocco su **entrambi** i nodi come `root`.

```bash
# ESEGUI SU racstby1 E racstby2 (ripeti per grid, oracle, root)
for U in grid oracle root; do
  echo "=== setup SSH per utente: $U ==="
  su - $U -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
  su - $U -c "ssh-keygen -R racstby1 >/dev/null 2>&1 || true"
  su - $U -c "ssh-keygen -R racstby2 >/dev/null 2>&1 || true"
  su - $U -c "[ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
  su - $U -c "ssh-keyscan -H racstby1 racstby2 >> ~/.ssh/known_hosts"
  su - $U -c "chmod 600 ~/.ssh/known_hosts"
done
```

Poi completa la trust bidirezionale:

```bash
# Da racstby1
su - grid   -c "ssh-copy-id grid@racstby2"
su - oracle -c "ssh-copy-id oracle@racstby2"
su - root   -c "ssh-copy-id root@racstby2"

# Da racstby2
su - grid   -c "ssh-copy-id grid@racstby1"
su - oracle -c "ssh-copy-id oracle@racstby1"
su - root   -c "ssh-copy-id root@racstby1"
```

Verifica finale:

```bash
su - grid   -c "ssh racstby2 hostname"
su - oracle -c "ssh racstby2 hostname"
su - root   -c "ssh racstby2 hostname"
```

---

## 4) Reset completo (se hai fatto tentativi confusi)

Esegui su `racstby1` e `racstby2` come `root`:

```bash
rm -rf /home/grid/.ssh
rm -rf /home/oracle/.ssh
rm -rf /root/.ssh
```

Poi riparti da sezione 3.

---

## 5) Fix rapido errori comuni

### 5.1 `Host key verification failed`

La host key salvata non coincide piu (tipico dopo clone/snapshot).

```bash
for U in grid oracle root; do
  su - $U -c "ssh-keygen -R racstby1 >/dev/null 2>&1 || true"
  su - $U -c "ssh-keygen -R racstby2 >/dev/null 2>&1 || true"
  su - $U -c "ssh-keyscan -H racstby1 racstby2 >> ~/.ssh/known_hosts"
  su - $U -c "chmod 600 ~/.ssh/known_hosts"
done
```

### 5.2 `Permission denied (publickey,...)` su `grid`/`oracle`

Controlla prima che password e shell utente siano sane:

```bash
passwd grid
passwd oracle
getent passwd grid
getent passwd oracle
```

Poi verifica permessi lato destinazione:

```bash
ls -ld /home/grid /home/grid/.ssh
ls -l /home/grid/.ssh
ls -ld /home/oracle /home/oracle/.ssh
ls -l /home/oracle/.ssh
```

Permessi corretti:

- home utente non scrivibile da altri (`755` o `750`)
- `.ssh` = `700`
- `authorized_keys` = `600`
- owner coerente (`grid:oinstall` o `oracle:oinstall`)

### 5.3 `PRVG-2019` in cluvfy

Rifai tutta la sezione 3 e rilancia:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
$ORACLE_HOME/runcluvfy.sh stage -pre crsinst -n racstby1,racstby2 -verbose
```

---

## 6) Piano B (se ssh-copy-id fallisce per grid/oracle)

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

- `ssh racstby1 hostname` e `ssh racstby2 hostname` senza password per `grid`, `oracle`, `root`
- nessun errore `PRVG-2019` in `cluvfy`
- file `known_hosts` e `authorized_keys` con owner/permessi corretti

