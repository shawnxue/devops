#!/bin/sh

#  deploy_rmp_remotely.sh
#
#  Created by Shawn Xue on 2014-11-11.
#  This script deploy RPMs to remote RHEL servers
#
# Usage:
#
# ./deploy.sh dir_of_rpms server_1 [server_2] [server_3] … [server_N]
#
# format of server_i should be [user@]name[.domain.com]
# If it does not end with “abc.com”, append “abc.com”
# if it does not have username, use the default user name “admin”.
#
# Assumptions:
# 1: dir_of_rpms is local dir on the client machine
# 2: the users have the permissions to install rpm packages and have ssh key installed so it doesn't prompt for password
# 3: There is no dependencies among the rpms
# 4: Server doesn't need to reboot after installing rpm
# 5: server name that users input is existing and accessable
########################################################################################################################

# =================================================================================================
# GLOBAL VARIABLES
# =================================================================================================
DEFAULT_DOMAIN="abc.com"
DEFAULT_USER="admin"
DIR_OF_RPMS=""
SERVERS=""
REMOTE_DIR="/tmp/$(date +'%Y%m%d%H%M%S')"
declare -a FAILED_SERVERS

# help functions

# function to show how to use this bash script
function showUsage(){
echo
echo "Usage: "
echo
echo "/deploy.sh dir_of_rpms server_1 [server_2] [server_3] … [server_N]"
echo
echo "format of server_i should be [user@]name[.domain.com]"
echo
echo 'If it does not end with “abc.com”, append “abc.com”'
echo
echo 'If it does not have username, use the current username plus “admin”'
echo
}

# function to show initial log
function initLog(){
echo "==================================================================="
echo "==================================================================="
echo "STARTING DEPLOYING RPM PACKAGES ON ALL REMOTE SERVERS $(date +"%Y-%m-%d:%T")"
echo "==================================================================="
echo "==================================================================="
}

# function to show finalized log
function finalizeLog(){
echo "================================================================="
echo "================================================================="
echo "FINISH DEPLOYING RPM PACKAGES ON ALL REMOTE SERVERS $(date +"%Y-%m-%d:%T")"
echo "================================================================="
echo "================================================================="
for item in ${FAILED_SERVERS[*]}
do
echo "$item failed to be installed/upgraded"
done
}

# function to validate arguments
function validateArgument(){
[[ $# -lt 2 ]] && showUsage && exit 1

[[ ! -d $1 ]] && echo "$1 is either not a directory or does not exist" && showUsage && exit 1
}

# function to get full name of server, including user name and domain name
function getServerAccessFullName(){
local server=$1
# append abc.com if server is not ended with abc.com
[[ ! $server == *abc.com ]] && server="$server.$DEFAULT_DOMAIN"
# use default user admin if there is no username in server
[[ ! $server == *@* ]] && server="$DEFAULT_USER@$server"
echo "$server"
}

# function to return all rpms in local rpm directory
function listAllRPMs(){
local dir=$DIR_OF_RPMS

i=$((${#dir}-1))
lastChar="${dir:$i:1}"
if [[ $lastChar == '/' ]]; then
dir="$dir*"
elif [[ $lastChar == '*' ]]; then
dir="$dir"
else
dir="$dir/*"
fi

echo "$dir"
}

# function to upload RPMs to all remote servers
function deployRPMsToAllServers(){
local rpms=$(listAllRPMs)
local server=$1
# make a working dir in remote server
ssh -oStrictHostKeyChecking=no $server "mkdir $REMOTE_DIR"
# deploy all rpms in current server
for rpm in $rpms
do
echo "Uploading package $rpm to server $server"
scp -Cv $rpm $server:$REMOTE_DIR
filename=`basename $rpm`
echo "Installing/Upgrading package $REMOTE_DIR/$filename in server $server"
ssh -oStrictHostKeyChecking=no $server "rpm -Uvh $REMOTE_DIR/$filename"
done
}

# function to clean up the remote working directory
function cleanupWorkingDirInAllServers(){
local server=$1
echo "Removing working directory in server $server"
ssh -oStrictHostKeyChecking=no $server "rm -rf $REMOTE_DIR"
}


# =================================================================================================
# PROGRAM EXECUTION
# =================================================================================================
validateArgument "$@"
DIR_OF_RPMS="$1"
shift
SERVERS="$@"
initLog
for srv in $SERVERS
do
remote_server=$(getServerAccessFullName $srv)
ssh -oStrictHostKeyChecking=no $remote_server "echo"
if [[ $? -ne 0 ]]; then
count=${#FAILED_SERVERS[@]}
FAILED_SERVERS[$count]=$remote_server
echo ${FAILED_SERVERS[$count]}
continue
fi
deployRPMsToAllServers $remote_server
cleanupWorkingDirInAllServers $remote_server
done
finalizeLog