echo "Starting to exclude packages!!"

while read inPkg; do
  echo "======== Start ======== " $inPkg
  echo "========="
  ballerina test $inPkg > out
  echo "========= END  ==========="
  echo "========="
  echo "========="

done < list