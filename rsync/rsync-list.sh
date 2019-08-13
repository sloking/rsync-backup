#!/bin/bash
# created by francois scheurer on 20081109
# this script is used by rsync-snapshot.sh,
# it recursively prints to stdout the filelist of folder $1 and computes md5 signatures
# it deals correctly with special filenames with newlines or '\'
# note1: the script assumes that a file is unchanged if its size and ctime are unchanged;
#   this assumption has a very small risk of being wrong:
#   it could be wrong if two files with different contents but same filename and size are created in the same second in two directories;
#   if the first directory is then removed and the second is renamed as the first, the file is not detected as changed.
# note2: ctime checking can be replaced by mtime checking if CTIME_CHK=0;
#   this is needed by rsync-snapshot.sh (because of hard links creation that do not preserve ctime).




# ------------- the help page ---------------------------------------------
if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
  cat << "EOF"
Version 1.6 2009-06-19

USAGE: rsync-list.sh PATH/DIR CTIME_CHK [REF_LIST]

PURPOSE: recursively prints to stdout the filelist of folder PATH/DIR and computes md5 integrity signatures.
  It deals correctly with special filenames with newlines or '\'.
  If a ref_list is provided, it is used to avoid the re-calculation of md5 on files
  with unchanged filename and ctime.
  A ref_list is a file containing the output of a previously execution of this shell-script.
  The script assumes that a file is unchanged if its size and ctime are unchanged.
  The ref_list_mtime is used to force a md5 re-calculation of all files with newer ctime:
  -if file_ctime > ref_list_mtime then re-calculate md5
  -if file_ctime = ref_file_ctime then use ref_list
  CTIME_CHK can be 1 to base the algorithm on ctime or 0 to base it on mtime.

NOTE: the script assumes that all processes avoid all file modifications in PATH/DIR during the script's execution,
  you should read following remarks if this assumption cannot be guaranted:
  -a recent ref_list_mtime (>= date_of_first_write_to_ref_list) causes the script
   to miss all files with: ref_list_mtime >= file_ctime > ref_file_ctime
   solution: 'touch' ref_file_mtime with date_of_first_write_to_ref_list - 1 second
  -an old ref_list_mtime (< date_of_last_write_to_ref_list) causes the script
   to double all files with: ref_list_mtime < file_ctime = ref_file_ctime
   solution: pipe the output to 'sort -u'

EXAMPLE:
  DATESTR=$( date -d "1970-01-01 UTC $(( $( date +%s ) - 1 )) seconds" "+%Y-%m-%d_%H:%M:%S" ) # 'now - 1s' to avoid missing files
  REF_LIST="/etc.2008-11-23_10:00:00.list.gz"
  REF_LIST2="/tmp/rsync-reflist.tmp"
  gzip -dc "${REF_LIST}" >"${REF_LIST2}"
  touch -r "${REF_LIST}" "${REF_LIST2}"
  ./rsync-list.sh "/etc/" 1 "${REF_LIST2}" | sort -u | gzip -c >"/etc.${DATESTR}.list.gz" # 'sort -u' to avoid doubling files
  rm "${REF_LIST2}"
  touch -d "${DATESTR/_/ }" "/etc.${DATESTR}.list.gz"
EOF
  exit 1
elif [ $# -ne 2 ] && [ $# -ne 3 ]
then
  echo "Sorry, you must provide 2 or 3 arguments. Exiting..."
  exit 2
fi




# ------------- file locations and constants ---------------------------
SRC="$1" #name of source of backup, remote or local hostname
CTIME_CHK=$2 #1 for ctime checking, 0 for mtime checking
if [ "$CTIME_CHK" -eq 1 ]
then
  CTIME_STAT="%z"
  CTIME_FIND="-cnewer"
else
  CTIME_STAT="%y"
  CTIME_FIND="-newer"
fi
REF="$3" #filename of optional reference list
SCRIPT_PATH="/backup/snapshot/rsync"
FINDSCRIPT="$SCRIPT_PATH/rsync-find.sh.tmp" # temporary shell-script to calculate filelist




# ------------- using reference list to to reduce md5 calculation time -
if [ -n "$REF" ] #we have a previous md5 list
then

  if ! [ -s "$REF" ] #invalid reference list
  then
     echo "Error: $REF is not a valid reference list. Exiting..."
     exit 2
  fi

  touch /tmp/testsystime.tmp
  if ! [ /tmp/testsystime.tmp -nt "$REF" ] #if system time is incorrect then exit
  then
    echo "Error: system time is older than mtime of $REF. Exiting..."
    rm /tmp/testsystime.tmp
    exit 2
  fi
  rm /tmp/testsystime.tmp

  cat "$REF" | while read -r LINE #consider all previous files that still exist now with same ctime and size and print their already calculated md5
  do
    SIZE_AND_CTIME="${LINE#* md5sum=* * * * }" #extract size and ctime from reference list
    SIZE_AND_CTIME="${SIZE_AND_CTIME% \`*}"
    LINE2="${LINE%% md5sum=*}"    #1) keep only the filename part of the line
    LINE2="${LINE2//\\\\n/
}"                                #2) replace '\n' with newline, the problem now is that '\\n' is replaced, too (following is not a solution because it removes previous char LINE2="${LINE2//[^\\\\]\\\\n/newline}")
    LINE2="${LINE2//\\\\
/\\\\n}"                          #3) replace '\'+newline with '\\n', fixing the problem of 2)
    LINE2="${LINE2//\\\\\\\\/\\}" #4) replace '\\' with '\'
    if [ -a "$LINE2" ] || [ -h "$LINE2" ] #check if file still exists
    then
      SIZE_AND_CTIME2=$( stat -c"%s $CTIME_STAT" "$LINE2" )
      SIZE_AND_CTIME2="${SIZE_AND_CTIME2#* md5sum=* * * * }" #get size and ctime from current file
      SIZE_AND_CTIME2="${SIZE_AND_CTIME2% \`*}"
      if [ "$SIZE_AND_CTIME" == "$SIZE_AND_CTIME2" ] #current file unchanged (see above note), so print the already calculated md5
      then
        echo "$LINE"
      elif [ "${SIZE_AND_CTIME#* }" == "${SIZE_AND_CTIME2#* }" ] #size is different but ctime is same: update current file's ctime to force md5's recalculation (see below)
      then
        if [ "$CTIME_CHK" -eq 1 ]
        then
          chmod --reference="$LINE2" "$LINE2" #update ctime (note: system time is assumed to be correct)
        else
          touch -m "$LINE2" #update mtime (note: system time is assumed to be correct)
        fi
      fi
    fi #else the file has been either deleted or modified (different ctime) and reference list is here useless
  done
  CNEWER_REF="$CTIME_FIND $REF" #prepare 'find' -cnewer option
else
  CNEWER_REF=""
fi




# ------------- calculation of md5 sums --------------------------------
#this 1st method is not slow but fails on filenames with newlines or '\'
find "${SRC}" $CNEWER_REF \! \( -path "*
*" -o -path "*\\\*" -o -path " *" -o -path "* " \) | while read LINE
do
  LINE2="$LINE"
  if ! [ -h "$LINE" ] && [ -f "$LINE" ]
  then
    RES=$( md5sum "$LINE" )
    LINE2="$LINE2 md5sum=${RES%% *}"
  else
    LINE2="$LINE2 md5sum=-"
  fi
  RES=$( echo $( stat -c"%A %U %G %s $CTIME_STAT \`%F'" "$LINE" ) )
  echo -E "$LINE2 $RES"
done
#this 2nd method is slow but works on filenames with newlines or '\'
( cat << "EOF"
#!/bin/bash
  LINE="$1"
#  LINE2="${LINE//\\\\/\\\\}" # replace \ with \\
  LINE2="${LINE//\\/\\\\}" # replace \ with \\
  LINE2="${LINE2//
/\n}" # replace newline with \n
  if ! [ -h "$LINE" ] && [ -f "$LINE" ]
  then
    RES=$( md5sum "$LINE" )
    LINE2="$LINE2 md5sum=${RES%% *}"
  else
    LINE2="$LINE2 md5sum=-"
  fi
  RES=$( echo $( stat -c"%A %U %G %s $CTIME_STAT \`%F'" "$LINE" ) )
  echo -E "$LINE2 $RES"
EOF
) >"$FINDSCRIPT"
chmod +x "$FINDSCRIPT"
find "${SRC}" $CNEWER_REF \( -path "*
*" -o -path "*\\\*" -o -path " *" -o -path "* " \) -print0 | xargs --replace --null "$FINDSCRIPT" "{}"
rm "$FINDSCRIPT"
#eof


