#!/bin/bash

#USE AT YOUR OWN RISK!!
#
# this script is set up for dual fan nvidia gpus only at the moment
# i can't find a command that will give me a fan count per gpu
# one option is to change fan speeds for all gpus at the same time

# in order to change clock offsets, coolbits must be enabled for all gpus
# run this command in terminal
#
#sudo nvidia-xconfig --cool-bits=31 --allow-empty-initial-configuration --enable-all-gpus
#reboot

# optional
# i use the following on my system to add an export statement to my .bashrc file.
# if you would like to use this instead of local $nv variable then uncomment the if statement below
# and comment out the 2 lines of code for declaring xAuthPath and nv below.
# the benefit to this is, if you want to do other nvidia-settings commands
# you can use $nv instead of writing the whole display auth path
# example: sudo $nv nvidia-settings -q all
#
# if ! [[ $nv ]];
#     then
#         xAuthPath=$(ps a |grep X | awk '{print $10}')
#         echo -e "\n#nv xrdp / ssh display auth path " | cat >> ~/.bashrc
#         echo -e "export nv=\"DISPLAY=:0 XAUTHORITY=$xAuthPath\"" | cat >> ~/.bashrc
# fi

#variable for display authority
xAuthPath=$(ps a |grep X | awk '{print $10}') #comment out this line if using the above if statement
nv="DISPLAY=:0 XAUTHORITY=$xAuthPath" #comment out this line if using the above if statement

#enable persistant mode
enable_pm () {
    echo 'enable persistant mode'
    sudo nvidia-smi -pm 1
}

#set pomermizer mode
setPowerMizerMode1() {
    sudo $nv nvidia-settings -a [gpu:$deviceID]/GpuPowerMizerMode=1 #set powermizer mode to prefer max performance
}

#display help menu
help () {
    echo "nv-overclock.sh help"
    echo -e "-h\t\t\tdisplay help menu"
    echo -e "-q\t\t\tquery current fan speed, core clock, memory clock"
    echo -e "-d\t\t\trestore default fan speed and clock frequencies"
    echo -e "-i <device_id>\t\tset interface device ID"
    echo -e "-p <max_watts>\t\tset power level in max watts"
    echo -e "-f <fan_speed>\t\tchange gpu fan speed between 0 - 100"
    echo -e "-c <core_offset>\tchange core clock offset between $coreMin - $coreMax"
    echo -e "-m <memory_offset>\tchange memory clock offset between $memMin - $memMax"
    echo
    selectDeviceMessage
}


selectDeviceMessage () {
    echo '-i option must be present to select a device ID'
    echo 'select from available gpus:'
    nvidia-smi --list-gpus
}


while getopts :dqhi:p:f:c:m: option; do
    case $option in
        #Set Interface Device
        i) deviceID=$OPTARG
            echo 'option i present'
            echo "device ID = $deviceID"
            coreMin=$(sudo $nv nvidia-settings -q [gpu:$deviceID]/GPUGraphicsClockOffsetAllPerformanceLevels | grep -i range | awk '{print $10}')
            coreMax=$(sudo $nv nvidia-settings -q [gpu:$deviceID]/GPUGraphicsClockOffsetAllPerformanceLevels | grep -i range | awk '{print $12}')
            memMin=$(sudo $nv nvidia-settings -q [gpu:$deviceID]/GPUMemoryTransferRateOffsetAllPerformanceLevels | grep -i range | awk '{print $10}')
            memMax=$(sudo $nv nvidia-settings -q [gpu:$deviceID]/GPUMemoryTransferRateOffsetAllPerformanceLevels | grep -i range | awk '{print $12}')
            fan1ID=$(($deviceID * 2))
            fan2ID=$(($fan1 + 1))
        ;;
        #Restore Defaults
        d)
            if [ $deviceID ];
            then
                echo 'option d present'
                sudo $nv nvidia-settings -a [gpu:$deviceID]/GPUFanControlState=0; #restore fan control state to default
                sudo $nv nvidia-settings -a [gpu:$deviceID]/GPUGraphicsClockOffsetAllPerformanceLevels=0 #restore core clock offset to default
                sudo $nv nvidia-settings -a [gpu:$deviceID]/GPUMemoryTransferRateOffsetAllPerformanceLevels=0 #restore memory clock offset to default
                sudo nvidia-smi -pm 0
                echo 'restored defaults'
                exit 0
            else
                selectDeviceMessage
                exit 0
            fi
        ;;
        #Query Speeds
        q)
            if [ $deviceID ];
            then
                echo 'option q present'
                sudo $nv nvidia-settings -q [gpu:$deviceID]/NvidiaDriverVersion #query nvidia driver version
                sudo $nv nvidia-settings -q [fan:$fan1ID]/GPUTargetFanSpeed #query fan1 speed
                sudo $nv nvidia-settings -q [fan:$fan2ID]/GPUTargetFanSpeed #query fan2 speed
                sudo $nv nvidia-settings -q [gpu:$deviceID]/GPUGraphicsClockOffsetAllPerformanceLevels #query core speed
                sudo $nv nvidia-settings -q [gpu:$deviceID]/GPUMemoryTransferRateOffsetAllPerformanceLevels #query memory speed
                sudo $nv nvidia-settings -q [gpu:$deviceID]/GPUCurrentClockFreqs #query all clock speeds
                exit 0
            else
                selectDeviceMessage
                exit 0
            fi
        ;;
        #Power Level
        p) power=$OPTARG
            if [ $deviceID ];
            then
                if [ $power ];
                then
                    sudo nvidia-smi -i $deviceID -pl $power
                else
                    echo "must enter power in watts"
                    exit 0
                fi
            else
                selectDeviceMessage
                exit 0
            fi
        ;;
        #Fan Speed
        f) fan=$OPTARG
            if [ $deviceID ];
            then
                echo 'option f present'
                if [ $fan -ge 0 ] && [ $fan -le 100 ];
                    then
                        echo "set gpu fan $fan%";
                        sudo $nv nvidia-settings -a [gpu:$deviceID]/GPUFanControlState=1; #enable fan control
                        sudo $nv nvidia-settings -a [fan:$fan1ID]/GPUTargetFanSpeed=$fan; #set fan1 speed
                        sudo $nv nvidia-settings -a [fan:$fan2ID]/GPUTargetFanSpeed=$fan; #set fan2 speed

                    else
                        echo 'value must be between 0 - 100'
                        exit 0
                fi
            else
                selectDeviceMessage
                exit 0
            fi
        ;;
        #Core Clock Offset
        c) core=$OPTARG
            if [ $deviceID ];
            then
                echo 'option c present'
                if [ $core -ge $coreMin ] && [ $core -le $coreMax ];
                then
                    enable_pm
                    setPowerMizerMode1
                    echo "set gpu core frequency offset $core"
                    sudo $nv nvidia-settings -a [gpu:$deviceID]/GPUGraphicsClockOffsetAllPerformanceLevels=$core #set core frequency
                else
                    echo "core frequency offset must be between $coreMin - $coreMax"
                    exit 0
                fi
            else
                selectDeviceMessage
                exit 0
            fi
        ;;
        #Memory Clock Offset
        m) memory=$OPTARG
            if [ $deviceID ];
            then
                echo 'option m present'
                if [ $memory -ge $memMin ] && [ $memory -le $memMax ];
                then
                    enable_pm
                    setPowerMizerMode1
                    echo "set gpu memory frequency offset $memory"
                    sudo $nv nvidia-settings -a [gpu:$deviceID]/GPUMemoryTransferRateOffsetAllPerformanceLevels=$memory #set memory frequency
                else
                    echo "memory frequency offest must be between $memMin - $memMax"
                fi
                echo $memory
            else
                selectDeviceMessage
                exit 0
            fi
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
