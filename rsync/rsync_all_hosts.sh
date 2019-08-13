#!/bin/bash


HOSTSFILE="rsync_hosts_daily"
WEEKDAYNB=`date +%w`
HOSTFILEWEEKDAY="`ls -la rsync_hosts_${WEEKDAYNB}* | awk '{ print $NF }'`"
SCRIPT_PATH="/backup/snapshot/rsync"
SNAPSHOT_DST="/backup/snapshot/DATA"
LOGFNAME="backup_all_hosts.log"

cd ${SCRIPT_PATH}

###################################################################################
pingtest()
{

HOSTN="$1"
if [ -z "${HOSTN}" ];then
        echo "No parameter given! (rsync_all_hosts.sh) Aborted..."
        echo "$(date +%Y-%m-%d_%H:%M:%S) ${HOSTN}: === Snapshot failed. ==="
        exit 1
fi

PINGRES=`ping -c 1 ${HOSTN} | grep '1 received'`
if [ -z "${PINGRES}" ];then
        echo "Host is not reachable via ping. Exiting..."
	echo "$(date +%Y-%m-%d_%H:%M:%S) ${HOSTN}: === Snapshot failed. ==="
	exit 1
fi
}


##########################
####### Main #############
##########################
{

if ! [ -f "${HOSTSFILE}" ];then
	echo "File ${HOSTSFILE} not exist! Aborted..."
        echo "$(date +%Y-%m-%d_%H:%M:%S) : === Snapshot failed. ==="
        exit 1
fi

if ! [ -f "${HOSTFILEWEEKDAY}" ];then
        echo "File ${HOSTFILEWEEKDAY} not exist! Aborted..."
        echo "$(date +%Y-%m-%d_%H:%M:%S) : === Snapshot failed. ==="
        exit 1
fi





echo ""
echo ""

echo "-----------------------------------------------------"

echo $(date +%Y-%m-%d_%H:%M:%S)
echo ""

# ----------------- Backup every Day of Week ----------------
while read line
do

  Hname="`echo $line | grep -v ^#`"
  if [ ! -e ${Hname} ];then

    echo "----> Backup ${Hname}"
    echo ""

    pingtest ${Hname}

    /backup/snapshot/rsync/rsync-snapshot.sh ${Hname} --noquest
    if [ "${Hname}" == "localhost" ];then
	Hname="$(hostname)"
    fi
    /backup/snapshot/rsync/rsync_changed_files.sh ${SNAPSHOT_DST} ${Hname}

    echo ""

 fi


done < ${SCRIPT_PATH}/${HOSTSFILE}


# ----------------- Backup only one Day of Week ----------------

while read line
do

  Hname="`echo $line | grep -v ^#`"
  if [ ! -e ${Hname} ];then

    echo "----> Backup ${Hname}"
    echo ""

    pingtest ${Hname}

    /backup/snapshot/rsync/rsync-snapshot.sh ${Hname} --noquest
    if [ "${Hname}" == "localhost" ];then
        Hname="$(hostname)"
    fi
    /backup/snapshot/rsync/rsync_changed_files.sh ${SNAPSHOT_DST} ${Hname}

    echo ""

 fi


done < ${SCRIPT_PATH}/${HOSTFILEWEEKDAY}

} >> ${SCRIPT_PATH}/${LOGFNAME} 2>&1

