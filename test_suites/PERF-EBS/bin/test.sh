#!/bin/bash

# Discription:
# $1: disk type
# $2:At present,only Azure use $2.
#    When $1=datadisk,$2 can only be "ssd" or "std".
#    When $1=instance,$2 can only be "cached" or "uncached".
#    When $1=tempdisk,$2 can only be "bw" or "iops"
# $3:At present,only Azure use $3.
#    When $1=datadisk or $1=instance ,$3 can be "bw" or "iops".
#    When $1=tempdisk,$3 not in use.

PATH=~/workspace/bin:/usr/sbin:/usr/local/bin:$PATH

# setup
setup.sh

if [ "$1" != "" ]; then
	disktype=$1
else
	disktype=unknown
fi

cloud_type=`bash cloud_type.sh`
if [ ${cloud_type} == "azure" ];then
    inst_type=$(metadata.sh -s)
    inst_id=$(metadata.sh --local-hostname)
else
    inst_type=$(metadata.sh -t | awk '{print $2}')
    inst_id=$(metadata.sh -i | awk '{print $2}')
fi

if [ "$(cloud_type.sh)" = "aws" ]; then
	inst_type=$(metadata.sh -t | awk '{print $2}')
	inst_id=$(metadata.sh -i | awk '{print $2}')
fi

time_stamp=$(timestamp.sh)

logfile=~/workspace/log/storage_performance_${inst_type}_${disktype}_${time_stamp}.log

# log the informaiton
show_info.sh >> $logfile 2>&1

# perform this test
function run_cmd(){
	# $1: Command

	echo -e "\n$ $1" >> $logfile
	eval $1 >> $logfile 2>&1
}

echo -e "\n\nTest Results:\n===============\n" >> $logfile

run_cmd 'setup_fio.sh'

run_cmd 'lsblk -d'
run_cmd 'lsblk -t'
run_cmd 'sudo blockdev --report'

mode=fio_script_test

# blind test for all parameters
if [ "$mode" = "blind_test" ]; then
	## fio.sh $log $disktype $rw $bs $iodepth
	fio.sh $logfile $disktype read 4k 1
	fio.sh $logfile $disktype read 16k 1
	fio.sh $logfile $disktype read 256k 1
	fio.sh $logfile $disktype read 1024k 1
	fio.sh $logfile $disktype read 2048k 1
	fio.sh $logfile $disktype write 4k 1
	fio.sh $logfile $disktype write 16k 1
	fio.sh $logfile $disktype write 256k 1
	fio.sh $logfile $disktype write 1024k 1
	fio.sh $logfile $disktype write 2048k 1
	fio.sh $logfile $disktype randread 4k 1
	fio.sh $logfile $disktype randread 16k 1
	fio.sh $logfile $disktype randread 256k 1
	fio.sh $logfile $disktype randread 1024k 1
	fio.sh $logfile $disktype randread 2048k 1
	fio.sh $logfile $disktype randwrite 4k 1
	fio.sh $logfile $disktype randwrite 16k 1
	fio.sh $logfile $disktype randwrite 256k 1
	fio.sh $logfile $disktype randwrite 1024k 1
	fio.sh $logfile $disktype randwrite 2048k 1

# choose parameters by disktype
elif [ "$mode" = "capacity_test" ]; then

	if [ "$disktype" = "gp2" ] || [ "$disktype" = "io1" ]; then
		# IOPS performance hit
		fio.sh $logfile $disktype randread 16k 1
		fio.sh $logfile $disktype randwrite 16k 1
		# BW performance hit
		fio.sh $logfile $disktype randread 256k 1
		fio.sh $logfile $disktype randwrite 256k 1
	fi

	if [ "$disktype" = "st1" ] || [ "$disktype" = "sc1" ]; then
		# IOPS and BW performance hit
		fio.sh $logfile $disktype read 1024k 1
		fio.sh $logfile $disktype write 1024k 1
	fi

elif [ "$mode" = "fio_script_test" ]; then

	cd ~/workspace/bin
        cloud_type=`bash cloud_type.sh`
        if [ "$cloud_type" == "azure" ]; then
            #if [ "$1" == "datadisk" ]
            if [ "$1" ==  "datadisk" ]; then
                if [ "$2" == "std" ]; then
                    if [ "$3" == "iops" ]; then
                        echo "azure_datadisk_std_iops.fio"
                        fio2.sh $logfile $1 azure_datadisk_std_iops.fio
                    elif [ "$3" == "bw" ]; then
                        echo "azure_datadisk_std_bw.fio"
                        fio2.sh $logfile $1 azure_datadisk_std_bw.fio
                    else
                        echo "Parameter Error: Parameter can only be 'bw' or 'iops'"
                    fi
                elif [ "$2" == "ssd" ]; then
                    if [ "$3" == "iops" ]; then
                        echo "azure_datadisk_ssd_iops.fio"
                        fio2.sh $logfile $1 azure_datadisk_ssd_iops.fio
                    elif [ "$3" == "bw" ]; then
                        echo "azure_datadisk_ssd_bw.fio"
                        fio2.sh $logfile $1 azure_datadisk_ssd_bw.fio
                    else
                        echo "Parameter Error: Parameter can only be 'bw' or 'iops'"
                    fi
                else
                        echo "Parameter Error: Parameter can only be 'std' or 'ssd'"
                fi
            elif [ "$1" == "instance" ]; then
                if [ "$2" == "uncached" ]; then
                    if [ "$3" == "iops" ]; then
                        echo "azure_instance_uncached_iops.fio"
                        fio2.sh $logfile $1 azure_instance_uncached_iops.fio
                    elif [ "$3" == "bw" ]; then
                        echo "azure_instance_uncached_bw.fio"
                        fio2.sh $logfile $1 azure_instance_uncached_bw.fio                 
                    else
                        echo "Parameter Error: Parameter can only be 'bw' or 'iops'"
                    fi
                elif [ "$2" == "cached" ]; then
                    if [ "$3" == "iops" ]; then
                        echo "azure_instance_cached_iops.fio"
                        fio2.sh $logfile $1 azure_instance_cached_iops.fio
                    elif [ "$3" == "bw" ]; then
                        echo "azure_instance_cached_bw.fio"
                        fio2.sh $logfile $1 azure_instance_cached_bw.fio
                    else
                        echo "Parameter Error: Parameter can only be 'bw' or 'iops'"
                    fi
                else
                    echo "Parameter Error: Parameter can only be 'cached' or 'uncached'"
                fi
            elif [ "$1" == "tempdisk" ]; then
                if [ "$2" == "iops" ]; then
                    echo "azure_tempdisk_iops.fio"
                    fio2.sh $logfile $1 azure_tempdisk_iops.fio
                elif [ "$2" == "bw" ]; then
                    echo "azure_tempdisk_bw.fio"
                    fio2.sh $logfile $1 azure_tempdisk_bw.fio
                else
                    echo "Parameter Error: Parameter can only be 'bw' or 'iops'"
                fi 
            else
                echo "Parameter Error: Parameter can only be 'datadisk' or 'instance' or 'tempdisk'"
            fi
        fi	# End if Azure.

        if [ "$cloud_type" == "aws" ]; then

		# Support KVM-based instance
		last_blk_dev=$(lsblk -d -p | grep -v NAME | cut -f 1 -d ' ' | tail -n 1)
		if [[ $last_blk_dev =~ nvme ]]; then
			echo -e "\nReplacing the filename with \"$last_blk_dev\" in ebs_*.fio files...\n" >> $logfile
			sed -i "s#^filename=.*#filename=${last_blk_dev}#" ./ebs_*.fio
		fi

		if [ "$disktype" = "gp2" ] || [ "$disktype" = "io1" ]; then
			# IOPS and BW performance hit
			fio2.sh $logfile $disktype ebs_ssd_randread.fio
			fio2.sh $logfile $disktype ebs_ssd_randwrite.fio
		fi

		if [ "$disktype" = "st1" ] || [ "$disktype" = "sc1" ]; then
			# IOPS and BW performance hit
			fio2.sh $logfile $disktype ebs_hdd_read.fio
			fio2.sh $logfile $disktype ebs_hdd_write.fio
		fi
        fi	# End if AWS.

elif [ "$mode" = "ebs_bandwidth_test" ]; then

	cd ~/workspace/bin

	# EBS Bandwidth Test
	fio2.sh $logfile multi-io1 ebs_bandwidth_test.fio

fi

# teardown
teardown.sh

exit 0

