#!/bin/ksh
set -
#   -x turns on debugging, - turns it off
#
#   This script needs to run with the
#    full path name to determine the environment.
#
#   This script is called from a mainframe background job
#          [REDACTED]
#     that reads the IMS mailbox sending ECR adds and
#     updates to downstream systems (Enovia).
#
#   currently the mainframe job only runs a job for the following:
#         [REDACTED]
#
#   to run this from the command line, use the full path name
#          parameter $(0)   full path name (supplied automatically)
#          parameter $(1)   full path name of file from mailbox
#
# [REDACTED]/piosEcrExtract.ksh [REDACTED]/pecrv6.e53854.imstest
#
#  - - - - - - - - -
#  SAL - 20150626 - Separated rerun files between scripts
#  SAL - 20150604 - DB2 version detection added, Java version update, error capture
#                           
#  - - - - - - - - -
#

if [[ `print $0 | grep _dev | wc -l` -ne 0 ]]; then
	APP_CSNA=[REDACTED]
	env=dev
	dataPath=[REDACTED]/${env}
elif [[ `print $0 | grep -E "_tst|_test" | wc -l` -ne 0 ]]; then
	APP_CSNA=[REDACTED]
	env=tst
	dataPath=[REDACTED]/${env}
else
	APP_CSNA=[REDACTED]
	env=prod
	dataPath=[REDACTED]/ecrUpdates
fi

#            usr/java6/bin/java = /usr/java6/jre/bin
javaVersion=/usr/java6/bin/java

onCall=`grep "^PDDOncall=" ${APP_CSNA}/[REDACTED]/emailAddress.properties | cut -f 2 -d "=" `
ecrLink=`grep "^ECRDisplayLink=" ${APP_CSNA}/[REDACTED]/absoluteURL.properties | cut -f 2 -d "=" `
VPM=`grep "^VPMAdmin=" ${APP_CSNA}/[REDACTED]/emailAddress.properties | cut -f2 -d "=" `

mkdir -p ${dataPath}
logDir=${dataPath}/logs
mkdir -p ${logDir}

#  to build individual logs for each update, use this if block
if [ ${env} == "dev" ] 
then
   FILE_TIMESTAMP=`date +%Y-%m-%d-%H-%M-%S`
elif [ ${env} == "tst" ]
then
   FILE_TIMESTAMP=`date +%Y-%m-%d-%H-%M`
else
   FILE_TIMESTAMP=`date +%Y-%m-%d-%H`
fi

errFile=${logDir}/ecrErrFile.txt
errFileSave=${logDir}/${FILE_TIMESTAMP}_ecrErrFile.txt
logFile=${logDir}/${FILE_TIMESTAMP}_ecrUpdate.log
touch ${logFile}
touch ${errFile}

echo host: `hostname` >> ${logFile}
echo ${USER} >> ${logFile}

if [  ${env} == "dev" ] || [ ${env} == "tst"  ]
then 
   chmod 777 ${dataPath}
   chmod 777 ${logDir}
   chmod 777 ${logFile}
   chmod 777 ${errFile}
fi

fileNme=`basename ${1}`

if [ -w ${logDir}/debug.${env} ]
then
  echo " " >> ${logDir}/debug.${env}
  echo ${USER} >> ${logDir}/debug.${env}
  echo `date +"%D"` `date +"%r"` >> ${logDir}/debug.${env}
  echo this script: ${0} >> ${logDir}/debug.${env}
  echo dataPath: ${dataPath} >> ${logDir}/debug.${env}
  echo logDir: ${logDir} >> ${logDir}/debug.${env}
  echo input filename and path: ${1} >> ${logDir}/debug.${env}
  echo input filename: ${fileNme} >> ${logDir}/debug.${env}
  echo output filename: ${logFile} >> ${logDir}/debug.${env}
  echo error log: ${errFile} >> ${logDir}/debug.${env}
  #echo PDDOncall ${onCall} >> ${logDir}/debug.${env}
  echo starting ECR notification at `date +%Y%m%d%H%M%S` >> ${logDir}/debug.${env}
fi

#echo `date +%Y%m%d%H%M%S` "   " `cat ${1}` "   " 

if [ `grep C510C ${1} | wc -l` -lt 1 ]
then
   mv ${1} ${logDir}/${fileNme}.noC510C.txt
   echo "  " >> ${logFile}
   echo "no C510C activity recorded in " ${logDir}/${fileNme}.noC510C.txt >> ${logFile}
   echo "  " >> ${logFile}
   # /apps/open/bin/fastmail -s "${env} PIOS ECR activity - no C510 Create " -F ${onCall} -r ${onCall} ${1} ${onCall} 
   exit
fi 

#
#  sort and eliminate duplicates (one row per ECR/userid  
#
grep C510C ${1} | sort | uniq > ${logDir}/${fileNme}.noDups.txt

echo "  " >> ${logFile}
echo `date +%Y-%m-%d_%H-%M-%S` >> ${logFile}
echo "   ECRs from PIOS ${1} " >> ${logFile}
echo "  " >> ${logFile}
 
for line in `grep C510C ${logDir}/${fileNme}.noDups.txt `
do
   echo ${line} | cut -c1-6 >> ${logDir}/${fileNme}.ecr.txt
   echo ${line} | cut -c12- >> ${logDir}/${fileNme}.coordinators.txt
done

#
# echo  sort and eliminate duplicates 
#
cat ${logDir}/${fileNme}.ecr.txt | sort | uniq > ${logDir}/${fileNme}.ecrList.txt
cat ${logDir}/${fileNme}.coordinators.txt | sort | uniq > ${logDir}/${fileNme}.ccList.txt

cd $APP_CSNA/[REDACTED]

. [REDACTED]/db2profile

echo "  " >> ${logFile}
echo "   Using Java path (" $javaVersion ")   " >> ${logFile}
echo "   Return from db2level: " >> ${logFile}
echo ` db2level ` >> ${logFile}
echo "  " >> ${logFile}

# Set Java files for DB2 version:
if [[ `db2level|grep v9|wc -l` -gt 0 ]]; then
	# Version 9 detected
	${javaVersion} -classpath .:./../javaLib/activation.jar:./../javaLib/axis.jar:./../javaLib/axis-ant.jar:./../javaLib/commons-discovery-0.2.jar:./../javaLib/commons-lang-current.jar:./../javaLib/commons-logging-1.0.4.jar:./../javaLib/log4j-1.2.8.jar:./../javaLib/log4j.properties:./../javaLib/dab.jar:./../javaLib/db2jcc.jar:./../javaLib/db2jcc_license_cu.jar:./../javaLib/saaj.jar:./../javaLib/wsdl4j-1.5.1.jar:./../javaLib/mail.jar:./../javaLib/jaxrpc.jar:./../javaLib/spring.jar:./applicationContext-EcrWSQuery.xml [REDACTED]/PiosEcrQueryImpl `cat ${logDir}/${fileNme}.ecrList.txt ` 1>${logDir}/${fileNme}.resUmLead.txt  2>${errFile}
elif [[ `db2level|grep v8|wc -l` -gt 0 ]]; then
	# Version 8 detected
	${javaVersion} -classpath .:./../javaLib/activation.jar:./../javaLib/axis.jar:./../javaLib/axis-ant.jar:./../javaLib/commons-discovery-0.2.jar:./../javaLib/commons-lang-current.jar:./../javaLib/commons-logging-1.0.4.jar:./../javaLib/log4j-1.2.8.jar:./../javaLib/log4j.properties:./../javaLib/dab.jar:./../javaLib/db2java.jar:./../javaLib/saaj.jar:./../javaLib/wsdl4j-1.5.1.jar:./../javaLib/mail.jar:./../javaLib/jaxrpc.jar:./../javaLib/spring.jar:./applicationContext-EcrWSQuery.xml [REDACTED]/PiosEcrQueryImpl `cat ${logDir}/${fileNme}.ecrList.txt ` 1>${logDir}/${fileNme}.resUmLead.txt  2>${errFile}
else
	# Version not supported
	echo " DB2 version not configured. " >> ${errFile}
	echo " Return from db2level:       " >> ${errFile}
	echo ` db2level ` >> ${errFile}
	echo "          " >> ${errFile}
	cat ${logDir}/${fileNme}.noDups.txt >> [REDACTED]/${env}/`date +%Y-%m-%d`.rerun.piosEcrExtract.txt
    echo " Rerun file created: [REDACTED]/${env}/`date +%Y-%m-%d`.rerun.piosEcrExtract.txt " >> ${errFile}
    rm -f ${1}*.txt 
	echo " This is a system generated email from " ${0} >> ${errFile}
	[REDACTED]/fastmail -s "${env} PIOS ECR extraction failed" -c ${VPM} -F ${onCall} -r ${onCall} ${errFile} ${onCall}
	exit
fi



if [ -w ${logDir}/debug.${env} ]
then
  echo ending ECR notification at `date +%H%M%S` >> ${logDir}/debug.${env}
  echo input file `cat ${logDir}/${fileNme}.ecrList.txt ` >> ${logDir}/debug.${env}
  echo output file `cat ${logDir}/${fileNme}.resUmLead.txt ` >> ${logDir}/debug.${env}
fi

saveErrFile=0

if [ `grep -i "error" ${errFile} | wc -l` -gt 0 ] || [ `grep -i "fatal" ${errFile} | wc -l` -gt 0 ] || [ `grep -i "faultCode" ${errFile} | wc -l` -gt 0 ] || [ `grep -i "Exception" ${errFile} | wc -l` -gt 0 ]
then
   # An error of some type occurred
   [REDACTED]/fastmail -s "${env} PIOS ECR notification failed" -c ${VPM} -F ${onCall} -r ${onCall} ${errFile} ${onCall}
   saveErrFile=1
fi

if [ $saveErrFile -gt 0 ]
then
   touch ${errFileSave}
   cat ${errFile} >> ${errFileSave}
   mkdir -p [REDACTED]/${env}
   if [  ${env} == "dev" ] || [ ${env} == "tst"  ]
   then
      chmod 777 ${errFileSave}
	  chmod 777 [REDACTED]/${env}
   fi
   cat ${logDir}/${fileNme}.noDups.txt >> [REDACTED]/${env}/`date +%Y-%m-%d`.rerun.piosEcrExtract.txt
   echo " Rerun file created: [REDACTED]/${env}/`date +%Y-%m-%d`.rerun.piosEcrExtract.txt " >> ${logFile}
   rm -f ${1}*.txt 
   exit
fi

cat ${logDir}/${fileNme}.resUmLead.txt >> ${logFile}
cat ${logDir}/${fileNme}.ecrList.txt >> ${logFile}
cat ${logDir}/${fileNme}.ccList.txt >> ${logFile}

emailBody=${logDir}/${fileNme}.emailBody.txt
echo " The following ECRs have been created in PIOS: " >>  ${logDir}/${fileNme}.emailBody.txt
for ecrNum in ` cat ${logDir}/${fileNme}.ecrList.txt `
do
   echo " " >>  ${logDir}/${fileNme}.emailBody.txt
   echo ${ecrLink}?ECRNUM=${ecrNum} >> ${logDir}/${fileNme}.emailBody.txt
done
 
# cat ${logDir}/${fileNme}.ecrList.txt >> ${logDir}/${fileNme}.emailBody.txt

if [ ` grep -i edcr ${logDir}/${fileNme}.resUmLead.txt | wc -l ` -gt 0 ] 
then
   echo " " >>  ${logDir}/${fileNme}.emailBody.txt
   echo " The following UM Leads have been copied on this email: " >>  ${logDir}/${fileNme}.emailBody.txt
   echo " " >>  ${logDir}/${fileNme}.emailBody.txt
   cat ${logDir}/${fileNme}.resUmLead.txt | cut -f1 -d "|" >> ${logDir}/${fileNme}.emailBody.txt
fi

if [ ${env} == "dev" ] || [ ${env} == "tst" ]
then 
   #echo " " >>  ${logDir}/${fileNme}.ecrList.txt
   #echo "Added by the following: " >>  ${logDir}/${fileNme}.ecrList.txt
   #cat ${logDir}/${fileNme}.ccList.txt >> ${logDir}/${fileNme}.ecrList.txt
   crsSupport=[REDACTED]@cessna.com
   crsSupport2=[REDACTED]@txtav.com
   echo "TestPubsICA@txtav.com" >> ${logDir}/${fileNme}.ccEmail.txt
else
   crsSupport=[REDACTED]@cessna.textron.com
   crsSupport2=[REDACTED]@txtav.com
   echo "TestPubsICA@txtav.com" >> ${logDir}/${fileNme}.ccEmail.txt
   echo ${onCall} >> ${logDir}/${fileNme}.ccEmail.txt
fi


echo " " >>  ${logDir}/${fileNme}.emailBody.txt
echo " " >>  ${logDir}/${fileNme}.emailBody.txt 
echo " this is a system generated email from " ${0} >>  ${logDir}/${fileNme}.emailBody.txt

for id in `cat ${logDir}/${fileNme}.ccList.txt `
do
   [REDACTED]/ldapsearch -LLL -h [REDACTED].textron.com -p 389 -b "o=textron.com" -D "[REDACTED]" -w "Plane234" "uid=${id}" mail | grep -v "^dn" | cut -d' ' -f2 >> ${logDir}/${fileNme}.ccEmail.txt
done

#  now extract email address from resUmLead.txt

for id in `cat ${logDir}/${fileNme}.resUmLead.txt | cut -f 2 -d "|" `
do
    echo ${id} >> ${logDir}/${fileNme}.ccEmail.txt
done

[REDACTED]/fastmail -s "${env} PIOS ECRs added " -F ${onCall} -r ${onCall} ${logDir}/${fileNme}.emailBody.txt  ${crsSupport} ${crsSupport2} ${onCall} `cat ${logDir}/${fileNme}.ccEmail.txt` #  ` cat ${logDir}/${fileNme}.resUmLead.txt `

   # move the input file - it is available on the mainframe as a GDG 
 if [ ${env} == "tst"  ] || [ ${env} == "prod" ]
 then 
   mv ${1}* ${logDir}
fi
