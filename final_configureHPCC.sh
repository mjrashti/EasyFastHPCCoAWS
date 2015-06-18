#!/bin/bash -e

. /home/ec2-user/cfg_BestHPCC.sh

echo "slavesPerNode=\"$slavesPerNode\""

set2falseRoxieMulticastEnabled=''
if [ $roxienodes -gt 0 ]
then
  set2falseRoxieMulticastEnabled=' -override roxie,@roxieMulticastEnabled,false'

  echo "roxienodes is greater than 0. So:  execute perl /home/ec2-user/updateEnvGenConfigurationForHPCC.pl"
  perl /home/ec2-user/updateEnvGenConfigurationForHPCC.pl
fi

masterMemTotal=`bash /home/ec2-user/getPhysicalMemory.sh`
echo " masterMemTotal=\"$masterMemTotal\""

SlavePublicIP=$(tail -2 /home/ec2-user/public_ips.txt|head -1)
slaveMemTotal0=$(ssh -o StrictHostKeyChecking=no -t -t -i $pem ec2-user@$SlavePublicIP bash /home/ec2-user/getPhysicalMemory.sh)
slaveMemTotal=`echo $slaveMemTotal0|sed "s/.$//"`
echo " slaveMemTotal=\"$slaveMemTotal\""

# So we change globalMemorySize and masterMemorySize when the master and slave's memory aren't the same and
#  when slave's memory is at least 10 gb and master's memory size is at least 2 gb.
MinLargeSlaveMemory=10000000000
HalfGB=500000000
OneGB=1000000000
TwoGB=2000000000
memory_override=''
if [ $masterMemTotal -ne $slaveMemTotal ] && [ $slaveMemTotal -gt $MinLargeSlaveMemory ] && [ $masterMemTotal -ge $TwoGB ]
then
   masterMemorySize=$(echo $masterMemTotal $OneGB| awk '{printf "%.0f\n",($1-$2)/1000000}')
   globalMemorySize=$(echo $slaveMemTotal $OneGB $slavesPerNode $HalfGB| awk '{printf "%.0f\n",((($1 - $2)/$3)-$4)/1000000}')
   echo "masterMemorySize=\"$masterMemorySize\", globalMemorySize=\"$globalMemorySize\""
   master_override="-override thor,@masterMemorySize,$masterMemorySize"
   slave_override="-override thor,@globalMemorySize,$globalMemorySize"
   memory_override=" $master_override $slave_override"
fi

envgen=/opt/HPCCSystems/sbin/envgen;

# Make new environment.xml file for newly configured HPCC System.
echo "$envgen -env $created_environment_file $memory_override $set2falseRoxieMulticastEnabled -override thor,@watchdogProgressEnabled,false -override esp,@method,htpasswd -override thor,@replicateAsync,true -override thor,@replicateOutputs,true -ipfile $private_ips -supportnodes $supportnodes -thornodes $non_support_instances -roxienodes $roxienodes -slavesPerNode $slavesPerNode -roxieondemand 1"
$envgen  -env $created_environment_file $memory_override $set2falseRoxieMulticastEnabled -override thor,@watchdogProgressEnabled,false -override esp,@method,htpasswd -override thor,@replicateAsync,true -override thor,@replicateOutputs,true -ipfile $private_ips -supportnodes $supportnodes -thornodes $non_support_instances -roxienodes $roxienodes  -slavesPerNode $slavesPerNode -roxieondemand 1

# Copy the newly created environment file  to /etc/HPCCSystems on all nodes of the THOR
out_environment_file=/etc/HPCCSystems/environment.xml
master_ip=`head -1 /home/ec2-user/public_ips.txt`
echo "ssh -o StrictHostKeyChecking=no -t -t -i $pem ec2-user@$master_ip \"sudo /opt/HPCCSystems/sbin/hpcc-push.sh -s $created_environment_file -t $out_environment_file\""
ssh -o StrictHostKeyChecking=no -t -t -i $pem ec2-user@$master_ip "sudo /opt/HPCCSystems/sbin/hpcc-push.sh -s $created_environment_file -t $out_environment_file"

if [ $slavesPerNode -ne 1 ]
then
   echo "slavesPerNode is greater than 1. So:  execute perl /home/ec2-user/updateSystemFilesOnAllInstances.pl"
   perl /home/ec2-user/updateSystemFilesOnAllInstances.pl
else
   echo "slavesPerNode($slavesPerNode) is equal to 1. So did not execute updateSystemFilesOnAllInstances.pl."
fi
