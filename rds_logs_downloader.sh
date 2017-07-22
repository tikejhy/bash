#!/bin/bash
#This script usages RDSCLI to download full logs;
#This is to overcome bug with aws-cli; since RDSCLI is not maintained anymore but full log download (feature) is 
#only available with RDSCLI. 
#aws-cli usages portion download of logs and need to use token as counter; behind the sence in this case aws-cli is doing 
#view logic rather than download; i.e if there is binary character it terminates the download, and downloaded file is incomplete.

echo "`date +%Y-%M-%d:%H:%M:%S` ::EntryPoint::: ***********************************************************"

LOGSTART=$(date +%Y-%M-%d:%H:%M:%S)
export AWS_RDS_HOME=/opt/aws/RDSCli
export AWS_CREDENTIAL_FILE=/opt/aws/RDSCli/credential-file
export JAVA_HOME=/usr/lib/jvm/jre

#No Arguments
init_variables(){

	FILENAME_CONTAINS="audit"
	BASE_DIR="/data/logs"
	BASE_APP="rds"
	CONNECTION_TIMEOUT="300"
	LOG_DOWNLOADER="/opt/aws/RDSCli/bin/rds-download-db-logfile"
	FILENAME_CONTAINS="audit"
	MASTER_LOG="audit/server_audit.log"
	SLEEP_SECONDS="1"
	ARCHIVE_STAMP=$(date +%s)

	var_mapping
}

var_mapping(){
	if [[ ${PROJECT} == "tikejhya" ]]; then
		CUR_LOG_STRUCTURE="tikejhya_log_structure"
		DB_INSTANCE_IDENTIFIER="mysql-tikejhya-prod"
		LOG_DIR="/data/logs/rds/tikejhya/logs/"
	elif [[ ${PROJECT} == "anepal" ]]; then
	        CUR_LOG_STRUCTURE="ashishnepal_log_structure"
	        DB_INSTANCE_IDENTIFIER="mysql-anepal-prod"
		LOG_DIR="/data/logs/rds/anepal/logs/"
	else
		echo "`date +%Y-%M-%d:%H:%M:%S` :: I am not inteligent enough to understand your input SIR!"
		rm -f "${LOCKFILE}"
		exit 1
	fi

	if [ ! -d ${BASE_DIR}/${BASE_APP}/${PROJECT}/audit ]; then
		mkdir -p ${BASE_DIR}/${BASE_APP}/${PROJECT}/audit;
	fi
	if [ ! -d ${LOG_DIR} ]; then
		mkdir -p ${LOG_DIR};
	fi
}

# No arguments
usage()
{
	echo "Usage: $0 --project tikejhya|anepal

	Example:
	    $0 --project tikejhya

	Required parameters:
	--project                   The Project for logdownload (tikejhya or anepal)
	--dryrun                    Default: Yes (To disable --dryrun No)

	Optional parameters:
	--help                   Print this help message and exit
	--version                Print version information and exit
	"
	rm -f "${LOCKFILE}"
	exit 0
}

# no arguments
function version()
{
    echo "$0 version 1.0.0"
    echo "Written by Tikejhya (Ashish Nepal)"
    rm -f "${LOCKFILE}"
    exit 0
}


describe_db_log_files(){
	if [[ ${DRYRUN} == "No" || ${DRYRUN} == "no" ]]; then
		/usr/bin/aws rds describe-db-log-files --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} --filename-contains ${FILENAME_CONTAINS} | jq -c '.DescribeDBLogFiles[]' > ${CUR_LOG_STRUCTURE}
	else
		/usr/bin/aws rds describe-db-log-files --db-instance-identifier ${DB_INSTANCE_IDENTIFIER} --filename-contains ${FILENAME_CONTAINS} | jq -c '.DescribeDBLogFiles[]' > ${CUR_LOG_STRUCTURE}
	fi
}


download_logs(){
	if [[ "$FILE_NAME" == "${MASTER_LOG}" ]]; then
		echo "`date +%Y-%M-%d:%H:%M:%S` :: Master Log is exempted from download"
	else
		echo "`date +%Y-%M-%d:%H:%M:%S` :: Starting log download loop"
		if [[ ${DRYRUN} == "No" || ${DRYRUN} == "no" ]]; then
                	${LOG_DOWNLOADER} ${DB_INSTANCE_IDENTIFIER} --connection-timeout ${CONNECTION_TIMEOUT} --region eu-west-1 --log-file-name ${FILE_NAME} > ${LOCAL_FULL_FILE_NAME}
			sleep 10;
			sanity_logs
                	sleep ${SLEEP_SECONDS};
                else
                        echo "${LOG_DOWNLOADER} ${DB_INSTANCE_IDENTIFIER} --connection-timeout ${CONNECTION_TIMEOUT} --region eu-west-1 --log-file-name ${FILE_NAME} > ${LOCAL_FULL_FILE_NAME}"
                fi
	fi
}


sanity_logs(){
	DOWNLOADED_SIZE=$(ls -al ${FULL_FILE_NAME} | awk "{ print \$5 }")
        DIFF=`expr "$FILE_SIZE - $DOWNLOADED_SIZE"`
        if [[ "$DIFF" -gt "1000" ]]; then
           echo "-----------------------------------------"
           echo "`date +%Y-%M-%d:%H:%M:%S` ::DIFF IS GREATER LETS DOWNLOAD ${LOCAL_FULL_FILE_NAME}"
	   echo "`date +%Y-%M-%d:%H:%M:%S` ::Deleting file that is not in full rm -f ${LOCAL_FULL_FILE_NAME}" >> ${LOG_DIR}/download_sanity_deleted.log
	   rm -f ${LOCAL_FULL_FILE_NAME}
           echo "`date +%Y-%M-%d:%H:%M:%S` ::sanity_log::Failed:: Downloaded size: $DOWNLOADED_SIZE File Actual size: $FILE_SIZE And Diff: $DIFF"
           echo "-----------------------------------------"
           echo "`date +%Y-%M-%d:%H:%M:%S` :: download_sanity on ${LOCAL_FULL_FILE_NAME} Failed with Value: ${DIFF}" >> ${LOG_DIR}/download_sanity_error.log
	   if [[ ${DRYRUN} == "No" || ${DRYRUN} == "no" ]]; then
	   	download_logs
	   else
		echo "`date +%Y-%M-%d:%H:%M:%S` ::Dry"
	   fi
        else
           echo "`date +%Y-%M-%d:%H:%M:%S` ::Resonable size ${LOCAL_FULL_FILE_NAME}"
           echo "`date +%Y-%M-%d:%H:%M:%S` ::download_sanity on ${LOCAL_FULL_FILE_NAME} Success with Value: ${DIFF}" >> ${LOG_DIR}/download_sanity_success.log
           echo "`date +%Y-%M-%d:%H:%M:%S` ::sanity_log::Success:: Downloaded size: $DOWNLOADED_SIZE File Actual size: $FILE_SIZE And Diff: $DIFF"
        fi
}




process_download(){
for output in $(cat $CUR_LOG_STRUCTURE); do
	FULL_SPEC=$output
	FILE_NAME=$(echo $FULL_SPEC | jq -r .LogFileName)
	FILE_SIZE=$(echo $FULL_SPEC | jq -r .Size)
	FILE_TIMESTAMP=$(echo $FULL_SPEC | jq -r .LastWritten)
	ARCHIVE_STAMP=$(date +%s)
	FIND_FILE_NAME="${BASE_DIR}/${BASE_APP}/${PROJECT}/audit/"
	FULL_FILE_NAME="${BASE_DIR}/${BASE_APP}/${PROJECT}/audit/server_audit.log.*_${FILE_TIMESTAMP}_${FILE_SIZE}"
	LOCAL_FULL_FILE_NAME="${BASE_DIR}/${BASE_APP}/${PROJECT}/${FILE_NAME}_${FILE_TIMESTAMP}_${FILE_SIZE}"

	if [ -f ${BASE_DIR}/${BASE_APP}/${PROJECT}/audit/server_audit.log.*_${FILE_TIMESTAMP}_${FILE_SIZE} ]; then
    		echo "${LOGSTART} ::files do exist ${LOCAL_FULL_FILE_NAME}"
		sanity_logs
	else
    		echo "`date +%Y-%M-%d:%H:%M:%S` ::files do not exist ${LOCAL_FULL_FILE_NAME}"
		download_logs
	fi

done
}
#------------------------------PARSE PARAMETER-------------------------#
if [ $# -lt 1 ] ; then
        usage
        rm -f "${LOCKFILE}"
 exit
fi

ARGS=$(getopt -u --longoptions="project:,dryrun:,help,version" -o "" -- ${@})

if [ ${?} -ne 0 ]
then
	usage
	rm -f "${LOCKFILE}"
        exit 1
fi

set -- ${ARGS}

while [ ${1} != -- ]
do
        case ${1} in
                '--help')
                        usage
                        ;;

                '--project')
                        PROJECT=$2
                        shift
                        ;;

                '--dryrun')
                        DRYRUN=$2
                        shift
                        ;;
        esac

        shift
done
#--------------------------init variables------------------------#
init_variables
#--------------------------Lock app -----------------------------#
# Bash Lockfile
LOCKFILE="/tmp/.${PROJECT}.lock"

if [ -e "${LOCKFILE}" ]; then
echo "Already running."
exit 99

else

echo $! > "${LOCKFILE}"
chmod 644 "${LOCKFILE}"
#---------------------Lets rock here----------------#
describe_db_log_files
process_download
#---------------------REMOVE LOCK-------------------#


echo "`date +%Y-%M-%d:%H:%M:%S` ::EndPoint::: ***********************************************************"

rm -f "${LOCKFILE}"

fi
