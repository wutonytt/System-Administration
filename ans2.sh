#!/usr/local/bin/bash
OK=0
CANCEL=1
ESC=255

Main_Menu()
{
    trap "Trap_ctrlc" 2
    Selection=$(dialog --cancel-label "Exit" \
        --menu "System Info Panel" 50 50 5 \
        1 "LOGIN RANK" \
        2 "PORT INFO" \
        3 "MOUNTPOINT INFO" \
        4 "SAVE SYSTEM INFO" \
        5 "LOAD SYSTEM INFO"\
        2>&1 > /dev/tty)

    result=$?
    if [ $result -eq $OK ]; then
        Select $Selection
    elif [ $result -eq $CANCEL ]; then
	echo "Exit." >&1
        exit 0
    elif [ $result -eq $ESC ]; then
	echo "Esc pressed." >&2
	exit 1
    fi
}

Trap_ctrlc()
{
    echo "Ctrl + C pressed." >&1
    exit 2
}

Select()
{
    Choice=$1

    case $Choice in
        1)  # Option 1
            Login_Rank
            ;;
        2)  # Option 2
            Port_Info
            ;;
        3)  # Option 1
            MOUNTPOINT_INFO
            ;;
        4)  # Option 2
            Save_to_file
            ;;
        5)  # Option 1
            Load_from_file
            ;;
    esac
}

Login_Rank()
{
    showinfo=$(last -s | awk '{print $1}' | sort | uniq -c | sort -rn | head -5 | awk ' BEGIN {print "Rank Name                Times"} { printf "%-5i%-20s%-6s\n",NR,$2,$1} ')

    dialog --title "LOGIN RANK"\
    --no-collapse \
    --msgbox "$showinfo" 20 50

    result=$?
    if [ $result -eq $OK ]; then
        Main_Menu
    fi
}

Port_Info()
{
    showinfo=$(sockstat | tail +2 | awk ' {if ($5 == "tcp4" || $5 == "udp4") printf "%-7s%-4s_%-20s\n",$3,$5,$6} ' )

    Selection=$(dialog --menu "PORT INFO(PID and Port)" 50 50 23\
	    $showinfo\
    	    2>&1 > /dev/tty)

    result=$?
    if [ $result -eq $OK ]; then
	Process_Status $Selection
    elif [ $result -eq $CANCEL ]; then
        Main_Menu
    fi
}

Process_Status()
{
    pid=$1
    processinfo=$(ps -Af -o "user pid ppid stat %cpu %mem command" | awk -v awkpid="$pid" ' {if ($2 == awkpid && $7 == "sshd:") print "USER: "$1"\nPID: "$2"\nPPID: "$3"\nSTAT: "$4"\n%CPU: "$5"\n%MEM: "$6"\nCOMMAND: sshd"; else if ($2 == awkpid && $7 != "sshd:") print "USER: "$1"\nPID: "$2"\nPPID: "$3"\nSTAT: "$4"\n%CPU: "$5"\n%MEM: "$6"\nCOMMAND: "$7} ')

    dialog --title "Process Status: "$pid\
    --msgbox "$processinfo" 20 50

    result=$?
    if [ $result -eq $OK ]; then
	Port_Info
    fi
}

MOUNTPOINT_INFO()
{
    showinfo=$(df -hT | awk ' { if($2 == "zfs" || $2 == "nfs") printf "%-32s %-s\n",$1,$7} ')

    Selection=$(dialog --menu "MOUNTPOINT INFO" 50 50 23\
	    $showinfo\
    	    2>&1 > /dev/tty)

    result=$?
    if [ $result -eq $OK ]; then
	MOUNTPOINT_INFO_filesystem $Selection
    elif [ $result -eq $CANCEL ]; then
        Main_Menu
    fi
}

MOUNTPOINT_INFO_filesystem()
{
    filesystem=$1

    file_info=$(df -hT | awk -v awkfilesys="$filesystem" ' {if($1 == awkfilesys) print "Filesystem: "$1"\nType: "$2"\nSize: "$3"\nUsed: "$4"\nAvail: "$5"\nCapacity: "$6"\nMounted_on: "$7} ')

    dialog --title $filesystem\
    --msgbox "$file_info" 20 50

    result=$?
    if [ $result -eq $OK ]; then
	MOUNTPOINT_INFO
    fi
}

Save_to_file()
{

    Path=$(dialog --title "Save to file"\
	    --inputbox "Enter the path:" 9 50\
    	    2>&1 > /dev/tty)

    result=$?

    firstchar=$(echo "$Path" | cut -c1)

    # curpath=$(pwd)
    homedir=$(echo ~)

    if [ $firstchar != "/" ]; then
	Path="$homedir/$Path"
    fi

    if [ $result -eq $OK ]; then
	Save_System_Info $Path
    elif [ $result -eq $CANCEL ]; then
        Main_Menu
    fi
}

Save_System_Info()
{
    path=$1

    date=$(date)

    freemem=$(top -n | grep Mem | awk ' {print $10} ')

    ttllogin=$(who | cut -d' ' -f1 | sort | uniq | wc -l | awk ' {print $1} ')

    systeminfo=$(sysctl -a | grep -E "kern.hostname|kern.ostype|kern.osrelease|hw.machine:|hw.model|hw.ncpu|hw.physmem" | cut -d' ' -f2- | awk '{printf $0" "}' | awk '{if($13>=1024*1024*1024) print $0" "$13/1024/1024/1024" GB"; if($13<1024*1024*1024) print $0" "$13/1024/1024" MB" } ' | awk -v date="$date" -v freemem="$freemem" -v ttllogin="$ttllogin" '{print "This system report is generated on "date"\n==================================================================\nHostname: "$3"\nOS Name: "$1"\nOS Release Version: "$2"\nOS Architecture: "$4"\nProcess Model: "$5" "$6" "$7" "$8" "$9" "$10" "$11"\nNumber of Processor Cores: "$12"\nTotal Physical Memory: "$14" "$15"\nFree Memory (%): "freemem/1024/$14*100"\nTotal logged in users: "ttllogin}')

    echo "$systeminfo" > "$path"

    outputmsg="${systeminfo}\n\n\nThe output file is saved to ${path}"

    dialog --title "System Info"\
    --no-collapse\
    --cr-wrap\
    --msgbox "$outputmsg" 40 80

    result=$?
    if [ $result -eq $OK ]; then
        Main_Menu
    fi

}

Load_from_file()
{
    Path=$(dialog --title "Load from file"\
	--inputbox "Enter the path:" 9 50\
        2>&1 > /dev/tty)

    result=$?

    firstchar=$(echo "$Path" | cut -c1)

    # curpath=$(pwd)
    homedir=$(echo ~)

    if [ $firstchar != "/" ]; then
	Path="$homedir/$Path"
    fi


    if [ $result -eq $OK ]; then
	Load_System_Info $Path
    elif [ $result -eq $CANCEL ]; then
        Main_Menu
    fi
}

Load_System_Info()
{
    path=$1
    outputmsg=$(cat "$path")

    filename=$(echo "$path" | rev | cut -d'/' -f1 | rev)

    dialog --title "$filename"\
    --no-collapse\
    --cr-wrap\
    --msgbox "$outputmsg" 40 80

    result=$?
    if [ $result -eq $OK ]; then
        Main_Menu
    fi
}

Directory_not_found()
{
    dialog --title "Directory not found"\
    --msgbox "not found!" 8 50
}

File_not_found()
{
    dialog --title "File not found"\
    --msgbox "not found!" 8 50
}

No_write_permission()
{
    dialog --title "Permission Denied"\
    --msgbox "No write permission to!" 8 50
}

No_read_permission()
{
    dialog --title "Permission Denied"\
    --msgbox "No read permission to!" 8 50
}

File_not_valid()
{
    dialog --title "File not valid"\
    --msgbox "The file is not generated by this program." 8 50
}

Main_Menu
