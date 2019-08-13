# First Initial




# rsync-backup







Howto – local and remote snapshot backup using rsync with hard links
Introduction

Your Linux servers are running smoothly? Fine.
Now if something incidentally gets wrong you need also to prepare an emergency plan.
And even when everything is going fine, a backup that is directly stored on the same server can still be useful:

    for example when you need to see what was changed on a specific file,
    or if you want to find the list of files that were installed or modified after the installation of an application

This article is then intended to show you how you can set up an open-source solution, using the magic of the famous ‘rsync’ tool and some shell-scripting, to deploy a backup system without the need of investing into expensive proprietary software.
Another advantage of a shell-script is that you can easily adapt it according to your specific needs, for example for you DRP architecture.

The proposed shell-script is derivate from the great work of Mikes Handy’s rotating-filesystem-snapshot utility (cf. http://www.mikerubel.org/computers/rsync_snapshots).
It creates backups of your full filesystem (snapshots) with the combined advantages of full and incremental backups:

    It uses as little disk space as an incremental backup because all unchanged files are hard linked with existing files from previous backups; only the modified files require new inodes.
    Because of the transparency of hard links, all backups are directly available and always online for read access with your usual programs; there is no need to extract the files from a full archive and also no complicate replay of incremental archives is necessary.

It is capable of doing local (self) backups and it can also be run from a remote backup server to centralize all backups to a safe place and therefore avoid correlated physical risks.
‘rsync’ features tremendous optimizations of bandwidth usage and transfers only the portions of a file that were changed thanks to its brilliant algorithms, created by Andrew Tridgell. (cf. http://bryanpendleton.blogspot.ch/2010/05/rsync-algorithm.html)
‘rsync’ is also using network encryption via ‘ssh’.

The script let you achieve:

    local or remote backups with extremely low bandwidth requirement
    file level deduplication between backups using hard links (also across servers on the remote backup server)
    specify a bandwidth limit to moderate the network and I/O load on production servers
    backup retention policy:
        per server disk quota restrictions: for example never exceed 50GB and always keep 100GB of free disk
        rotation of backups with non-linear distribution, with the idea that recent backups are more useful than older, but that sometimes you still need a very old backup
    filter rules to include or exclude specific patterns of folders and files
    integrity protection, the backups have a ‘chattr’ read-only protection and a MD5 integrity signature can also be calculated incrementally

 

Installation

The snapshot backups are saved into the ‘/backup’ folder.
You can also create a symbolic link to point to another partition with more disk space, for example:

ln -sv mnt/bigdisk /backup

Then create the folders:

mkdir -pv /backup/snapshot/{$(hostname -s),rsync,md5-log}
[ -h /backup/snapshot/localhost ] || ln -vs $(hostname -s) /backup/snapshot/localhost

Now create the shell-script ‘/backup/snapshot/rsync/rsync-snapshot.sh’ (download rsync-snapshot.sh):

Then create the file ‘/backup/snapshot/rsync/rsync-include.txt’ (download rsync-include) that contains the include and exclude patterns:
And finally create the optional shell-script ‘/backup/snapshot/rsync/rsync-list.sh’ (download rsync-list.sh) that calculates the MD5 integrity signatures:
 

Set the ownerships and permissions:

chown -cR root:root /backup/snapshot/rsync/
chmod 700 /backup/snapshot/rsync/rsync-*.sh
chmod 600 /backup/snapshot/rsync/rsync-include.txt

 

Usage

When you call the script ‘rsync-snapshot.sh’ without parameters or with the hostname of the server itself (or localhost), the script performs a self-snapshot of the complete filesystem ‘/’.
You can and should use filter rules to exclude things like ‘/proc/*’ and ‘/sys/*’. For this you need to edit the configuration file ‘/backup/snapshot/rsync/rsync-include.txt’.
A description of the filter rules syntax is written as comments in the file itself.

The snapshot backup is created into ‘/backup/snapshot/HOST/snapshot.001′, where ‘HOST’ is your server’s hostname. If the folder ‘snapshot.001′ exists already it is rotated to ‘snapshot.002′ and so on, up to ‘snapshot.512′, thereafter it is removed. So if you create one backup per night, for example with a cronjob, then this retention policy gives you 512 days of retention. This is useful but this can require to much disk space, that is why we have included a non-linear distribution policy. In short, we keep only the oldest backup in the range 257-512, and also in the range 129-256, and so on. This exponential distribution in time of the backups retains more backups in the short term and less in the long term; it keeps only 10 or 11 backups but spans a retention of 257-512 days.
In the following table you can see on each column the different steps of the rotation, where each column shows the current set of snapshots (limited from snapshot.1 to snapshot.16 in this example):
To save more disk space, ‘rsync’ will make hard links for each file of ‘snapshot.001′ that already existed in ‘snapshot.002′ with identical content, timestamps and ownerships.
For example, the following example creates a backup and then use commands to let you see the used disk space of the 4 existing backups:

root@server05:~# /backup/snapshot/rsync/rsync-snapshot.sh
2012-09-11_19:07:43 server05: === Snapshot backup is created into /backup/snapshot/server05/snapshot.001 ===
2012-09-11_19:07:43 Testing needed free disk space ... 0 MiB needed.
2012-09-11_19:07:45 Checking free disk space... 485997 MiB free. Ok, bigger than 5000 MiB.
2012-09-11_19:07:45 Checking disk space used by /backup/snapshot/server05 ... 11011 MiB used. Ok, smaller than 20000 MiB.
2012-09-11_19:07:46 Creating folder /backup/snapshot/server05/snapshot.000 ...
2012-09-11_19:07:46 Creating backup of server05 into /backup/snapshot/server05/snapshot.000 hardlinked with  /backup/snapshot/server05/snapshot.001 ...
2012-09-11_19:07:52 Setting recursively immutable flag of /backup/snapshot/server05/snapshot.000 ...
Renaming /backup/snapshot/server05/snapshot.003 into /backup/snapshot/server05/snapshot.004 ...
Renaming /backup/snapshot/server05/snapshot.002 into /backup/snapshot/server05/snapshot.003 ...
Renaming /backup/snapshot/server05/snapshot.001 into /backup/snapshot/server05/snapshot.002 ...
Renaming /backup/snapshot/server05/snapshot.000 into /backup/snapshot/server05/snapshot.001 ...
2012-09-11_19:07:55 Checking free disk space... 485958 MiB free. Ok, bigger than 5000 MiB.
2012-09-11_19:07:55 Checking disk space used by /backup/snapshot/server05 ... 11050 MiB used. Ok, smaller than 20000 MiB.
2012-09-11_19:07:56 server05: === Snapshot backup successfully done in 13 sec. ===
-----------------------------
root@server05:~# du -chslB1M /backup/snapshot/localhost/snapshot.* | column -t
10901  /backup/snapshot/localhost/snapshot.001
10901  /backup/snapshot/localhost/snapshot.002
10901  /backup/snapshot/localhost/snapshot.003
10901  /backup/snapshot/localhost/snapshot.004
0      /backup/snapshot/localhost/snapshot.last
43602  total
-----------------------------
root@server05:~# du -chsB1M /backup/snapshot/localhost/snapshot.* | column -t
10898  /backup/snapshot/localhost/snapshot.001
40     /backup/snapshot/localhost/snapshot.002
45     /backup/snapshot/localhost/snapshot.003
45     /backup/snapshot/localhost/snapshot.004
0      /backup/snapshot/localhost/snapshot.last
11026  total
-----------------------------
We can see that the 4 snapshot backups use 10.9 GB each, so without hard links they would sum to 43 GB; the last command shows on the contrary that the real used size is only 11 GB, thanks to the hard links.
BTW, the following command can be very useful to replace all duplicate files with hard links to the first file in each set of duplicates, even if they have different name or path:

chattr -fR -i /backup/snapshot/localhost/snapshot.*
fdupes -r1L /backup/snapshot/localhost/snapshot.*

A good tutorial on how to use the ‘rsync’ command is available here:
http://www.thegeekstuff.com/2010/09/rsync-command-examples/
 

When called with a remote hostname as parameter, the script performs a snapshot backup via the network. This can be very useful for a DRP (Disaster Recovery Plan), in order to have a servers’ farm replicated every night to a secondary site. In addition to that you could implement a continuous replication of the databases for example. The ‘BWLIMIT’ can then be changed inside the shell-script to limit here the network bandwidth usage and the disk I/O overhead; it can help so to moderate the performance impact and avoid any slow down on critical production servers.
Other variables can also be modified at the beginning of the script, either as a global setting or specific tuning for some servers; a ‘BACKUPSERVER’ section is already provided for this purpose and let you tune specific settings for the remote central backup server:
To make the backup server able to connect via ‘ssh’ to the target servers without interactive entering of a password, you should create a ‘ssh’ host-key with empty passphrase ‘/root/.ssh/rsync_rsa’ and copy the public key to the target servers:

#on each targetserver:
mkdir -p ~root/.ssh/
chown root:root ~root/.ssh/
chmod 700 ~root/.ssh/
touch ~root/.ssh/authorized_keys
chown root:root ~root/.ssh/authorized_keys
chmod 600 ~root/.ssh/authorized_keys
#update manually /etc/ssh/sshd_config to have 'AllowUsers root'
service ssh reload

#on the backupserver, create the key with an empty passphrase:
ssh-keygen -f ~/.ssh/rsync_rsa
#and upload the public key to the targetserver:
MYIP=$(hostname -i) #assign here the backupserver's external IP if necessary
echo "from="${MYIP%% *}",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty,command="rsync ${SSH_ORIGINAL_COMMAND#* }" $(ssh-keygen -yf ~/.ssh/rsync_rsa)" | ssh targetserver "cat - >>~/.ssh/authorized_keys"

Note that the ‘command=’ restriction (http://larstobi.blogspot.ch/2011/01/restrict-ssh-access-to-one-command-but.html) will not apply if ‘/etc/sshd_config’ has already a ‘ForceCommand’ directive.
This central backup server could also be used to centralize the administration of all other servers via pdsh/ssh (LINK).
 

Because the script does not freeze the filesystem during its operation, there is no guaranty that the snapshot backup will be a strict snapshot, in other words the files will not be copied at the exact same moment. This is usually not an issue, except for databases. In order to keep the consistency of a database, you should follow the instructions of http://www.postgresql.org/docs/9.1/static/continuous-archiving.html and http://www.anchor.com.au/blog/documentation/better-postgresql-backups-with-wal-archiving/.



