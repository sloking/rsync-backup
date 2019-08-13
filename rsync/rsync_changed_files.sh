#!/bin/bash


CHANGEDFILES_PATH="/backup/snapshot/changedfiles"
CHANGEDLOGFNAME="${2}.log"
IFS=$'+'


if [ -z "${1}" ] || [ -z "${2}" ];then
  echo "kein Parameter"
fi

if [ -d "${1}/${2}/snapshot.001" ];then

  cd "${1}/${2}/snapshot.001"

  echo " " >> "${CHANGEDFILES_PATH}/${CHANGEDLOGFNAME}"
  echo "-----------------------------------------------------" >> "${CHANGEDFILES_PATH}/${CHANGEDLOGFNAME}"
  echo $(date +%Y-%m-%d_%H:%M:%S) >> "${CHANGEDFILES_PATH}/${CHANGEDLOGFNAME}"
  echo $(zcat rsync.log.gz | grep -v 'uptodate' | grep -v '[sender] ' | grep -v 'total: matches' | grep -v '(receiver) heap statistics:' | grep -v '(generator) heap statistics:' | grep -v 'smblks:' | grep -v 'Literal data:' | grep -v '/$'| sed -e 's/\\#303\\#274/ü/g' | sed -e 's/\\#303\\#244/ä/g' | sed -e 's/\\#303\\#266/ö/g' | sed -e 's/\\#303\\#234/Ü/g' | sed -e 's/\\#303\\#204/Ä/g' | sed -e 's/\\#303\\#226/Ö/g' | sed -e 's/\\#303\\#237/ß/g') >> "${CHANGEDFILES_PATH}/${CHANGEDLOGFNAME}"
  echo " " >> "${CHANGEDFILES_PATH}/${CHANGEDLOGFNAME}"
  echo $(zcat rsync.log.gz | grep 'Number of created files:') >> "${CHANGEDFILES_PATH}/${CHANGEDLOGFNAME}"
  echo $(zcat rsync.log.gz | grep 'Number of regular files transferred:') >> "${CHANGEDFILES_PATH}/${CHANGEDLOGFNAME}"
else
  echo " "
  echo " Directory \"${1}/${2}/snapshot.001\" not found"
fi

