# 04 - Backups: vzdump, retention and restore
 
## Goal
 
The VMs of the lab are safe from my own mistakes (snapshots), but not from a broken disk. So now I want real backups.
 
- A backup job runs every day.
- Backups are saved on a different storage from the VM disks.
- Only the last 3 backups are kept.
- I prove it works: I delete a VM, restore it from the backup, and measure how long it takes.
The final result is in [5. Results](#5-results).
 
## 1. Snapshot or backup?
 
I already use snapshots before risky changes. A snapshot is not a copy of the data. It only keeps the old version of a block when that block changes (copy-on-write). This is why it is instant, and why it grows over time as the VM keeps writing.
 
The problem: **a snapshot lives on the same disk as the VM.** If the disk breaks, the VM and its snapshots are gone together. It is one copy of the data with a bookmark, and that is why backups are different.
 
A snapshot protects me from my own mistakes (a bad package, a wrong config). A backup protects me from disasters.
 
### What about a mirror?
 
A mirror (like ZFS mirror or RAID 1) keeps two disks identical. It protects from the failure of one disk, but it is **not a backup**: if I delete a file, or ransomware encrypts it, the change is copied to both disks right away. There is no history to go back to.
 
## 2. A separate storage for the backups
 
The VM disks are on `local-lvm`. For the backups I use the ZFS pool `tank`, which is on a different virtual disk. First I create a dataset:
 
```bash
zfs create tank/backups
```
 
Then I tell Proxmox to use it as a storage:
 
`Datacenter` > `Storage` > `Add` > `Directory`
 
- **ID:** `backups` (I will use this name in the backup job)
- **Directory:** `/tank/backups`
- **Content:** only `backups`
Proxmox now accepts only backups on this storage.
 
## 3. The backup job
 
`Datacenter` > `Backup` > `Add`
 
- **Storage:** `backups`
- **Schedule:** every day
- **Selection:** the VM I want to protect (deb01)
- **Mode:** `Snapshot`, so the VM stays on while it is saved
- **Compression:** `ZSTD`
In the **Retention** tab I set `Keep Last` to `3`. After each backup, Proxmox deletes the older ones and keeps only the 3 latest. Without a retention, the backups would grow until the storage is full.
 
### Testing the retention
 
A job that never ran is only an idea, so I use `Run now` 4 times. Then I check the files:
 
```bash
root@pve1:~# ls -lh /tank/backups/dump/*.zst
-rw-r--r-- 1 root root 507M Oct 30 15:27 /tank/backups/dump/vzdump-qemu-100-2026_10_30-15_27_46.vma.zst
-rw-r--r-- 1 root root 507M Oct 30 15:28 /tank/backups/dump/vzdump-qemu-100-2026_10_30-15_27_57.vma.zst
-rw-r--r-- 1 root root 505M Oct 30 15:28 /tank/backups/dump/vzdump-qemu-100-2026_10_30-15_28_34.vma.zst
```
 
There are only 3 files, so the oldest one was deleted. The retention works.
 
## 4. RPO
 
The **RPO** (Recovery Point Objective) is how much data I can afford to lose. With one backup per day, in the worst case I lose **24 hours** of work.
 
## 5. Results
 
### The restore test
 
A backup is only a backup after the first restore. So I simulate a disaster.
 
1. I delete deb01: `More` > `Remove`, and I select `Destroy unreferenced disks owned by guest`.
2. I check that it is gone:
```bash
root@pve1:~# qm list
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID       
       102 deb02                stopped    2048              20.00 0         
       103 deb03                stopped    2048              20.00 0         
       104 OPNsense             running    4096              20.00 9358    
```
 
deb01 is not in the list anymore.
 
3. I start a stopwatch and restore the latest backup: `backups` storage > `Backups` > `Restore`.
4. I stop the stopwatch when the VM answers to `ping`.
| Measure | Value |
|---|---|
| Data inside the VM | about 1 GB |
| Backup file size | about 500 MB |
| Restore | about 7 seconds |
| Until the VM answers to ping (**RTO**) | about 20 seconds |
 
The other 13 seconds or so are the boot of the machine.
 
The **RTO** (Recovery Time Objective) is how long it takes to be back online. Mine is 20 seconds, but this number is optimistic: the VM is very small. The restore time grows with the real amount of data, not with the size of the disk.
 
## 6. Known limits
 
- **The separation is only logical.** `local-lvm` and `tank` are two virtual disks, but both are files on the same physical disk of my PC. If that disk dies, everything is lost. A real setup would use a NAS or another server, and a third copy off-site (the 3-2-1 rule: 3 copies, 2 different media, 1 off-site).

## 7. A problem: space
 
Every backup is a full copy. Three backups of the same VM use three times the space, even if almost all the data is the same. With many similar VMs it gets worse.
 
**Proxmox Backup Server (PBS)** is a better solution. It cuts the data in chunks and calculates a hash for each one. A chunk that already exists is saved only once. So three similar machines share most of their chunks, and only the different ones are stored. PBS also makes incremental backups (only the changed blocks are sent) and can verify that the saved data is not corrupted.
