#!/bin/bash


#in order to change clock offsets, coolbits must be enabled
#run this command in terminal
#sudo nvidia-xconfig --cool-bits=31 --allow-empty-initial-configuration
#reboot

coreMin=$(sudo $nv nvidia-settings -q [gpu:0]/GPUGraphicsClockOffset[3] | grep -i range | awk '{print $10}')
coreMax=$(sudo $nv nvidia-settings -q [gpu:0]/GPUGraphicsClockOffset[3] | grep -i range | awk '{print $12}')
memMin=$(sudo $nv nvidia-settings -q [gpu:0]/GPUMemoryTransferRateOffset[3] | grep -i range | awk '{print $10}')
memMax=$(sudo $nv nvidia-settings -q [gpu:0]/GPUMemoryTransferRateOffset[3] | grep -i range | awk '{print $12}')

#enable persistant mode
enable_pm () {
    echo 'enable persistant mode'
    sudo nvidia-smi -pm 1  
}

#display help menu
help () {
    echo "overclock.sh help"
    echo -e "-h\t\t\tdisplay help menu"
    echo -e "-q\t\t\tquery current fan speed, core clock, memory clock"
    echo -e "-d\t\t\trestore default fan speed and clock frequencies"
    echo -e "-f <fan_speed>\t\tchange gpu fan speed between 0 - 100"
    echo -e "-c <core_offset>\tchange core clock offset between $coreMin - $coreMax"
    echo -e "-m <memory_offset>\tchange memory clock offset between $memMin - $memMax"
}



#if nv does not exist - append export nv to .bashrc
if ! [[ $nv ]];
    then
        xAuthPath=$(ps a |grep X | awk '{print $10}')
        echo -e "\n#nv xrdp / ssh display auth path " | cat >> ~/.bashrc
        echo -e "export nv=\"DISPLAY=:0 XAUTHORITY=$xAuthPath\"" | cat >> ~/.bashrc
fi


while getopts :dqhf:c:m: option; do
    case $option in
        #Restore Defaults
        d)
            echo 'option d present'
            sudo $nv nvidia-settings -a [gpu:0]/GPUFanControlState=0;
            sudo $nv nvidia-settings -a [gpu:0]/GPUGraphicsClockOffset[3]=0
            sudo $nv nvidia-settings -a [gpu:0]/GPUMemoryTransferRateOffset[3]=0
            sudo nvidia-smi -pm 0
            echo 'restored defaults'
            exit 0
        ;;
        #Query Speeds
        q)
            echo 'option q present'
            sudo $nv nvidia-settings -q [fan:0]/GPUTargetFanSpeed
            sudo $nv nvidia-settings -q [gpu:0]/GPUGraphicsClockOffset[3]
            sudo $nv nvidia-settings -q [gpu:0]/GPUMemoryTransferRateOffset[3]
            exit 0
        ;;
        #Fan Speed
        f) fan=$OPTARG
            echo 'option f present'
            if [ $fan -ge 0 ] && [ $fan -le 100 ];
                then
                    echo "set gpu fan $fan%";
                    sudo $nv nvidia-settings -a [gpu:0]/GPUFanControlState=1;
                    sudo $nv nvidia-settings -a [fan:0]/GPUTargetFanSpeed=$fan;

                else
                    echo 'value must be between 0 - 100'
                    exit 0
            fi
        ;;
        #Core Clock Offset
        c) core=$OPTARG
            echo 'option c present'
            if [ $core -ge $coreMin ] && [ $core -le $coreMax ];
            then
                enable_pm
                echo "set gpu core frequency offset $core"
                sudo $nv nvidia-settings -a [gpu:0]/GPUGraphicsClockOffset[3]=$core
            else
                echo "core frequency offset must be between $coreMin - $coreMax"
                exit 0
            fi
        ;;
        #Memory Clock Offset
        m) memory=$OPTARG
            echo 'option m present'
            if [ $memory -ge $memMin ] && [ $memory -le $memMax ];
            then
                enable_pm
                echo "set gpu memory frequency offset $memory"
                sudo $nv nvidia-settings -a [gpu:0]/GPUMemoryTransferRateOffset[3]=$memory
            else
                echo "memory frequency offest must be between $memMin - $memMax"
            fi
            echo $memory
        ;;
        #Display Help
        h | *)
            help
            exit 0
        ;;  
    esac
done

#if no options are present display usage options
if [ $# == 0 ];
  then
    help
fi

exit 0
