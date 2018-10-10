#!/bin/bash 
clear
SCRIPT_CURRENT_DIRECTORY="`dirname \"$0\"`"
if [ ! -e "$SCRIPT_CURRENT_DIRECTORY/tmp" ]
then
    mkdir $SCRIPT_CURRENT_DIRECTORY/tmp
fi
function ReadServerData {
    read -p "Please, Enter IP Of $2 Server : " $1"IP"
    read -p "Please, Enter User Name Of $2 Server : " $1"USER"
    read -sp "Please, Enter User Password Of $2 Server : " $1"PASS"
    echo
    read -sp "Please, Enter User Password Of $2 Server Again .. : " $1"PASSAgain"
    echo
    read -p "Please, Enter Absolute Path To Be Compared Of $2 Server : " $1"PATH"
} 
function printing_servers_data {
    for (( i=0;i<=3;i++ ))
    do
        echo
        echo "$1 Server" 
        echo "=============="
        eval "echo IP = \$"_"$1"ServerIP"" 
        eval "echo User = \$"_"$1"ServerUSER""
        ServerPASS=$( eval "echo \$"_"$1"ServerPASS"" )
        ServerPASSAgain=$( eval "echo \$"_"$1"ServerPASSAgain"" )
        for (( i=0;i<=3;i++ ))
        do
            if [[ $ServerPASS = $ServerPASSAgain ]]
            then
                echo "Password : Both Passwords Entered Matches each Other"
                break
            else
                if [[ "$i" -eq "2" ]]
                then
                    exit
                else
                    echo "Password : Both Passwords Entered Does Not Match each Other"
                    read -sp "Please, Enter User Password Of "$1" Server : " ServerPASS
                    echo
                    read -sp "Please, Enter User Password Of "$1" Server Again .. : " ServerPASSAgain
                    echo
                fi
            fi
        done
        eval "echo Absolute Path = \$"_"$1"ServerPATH""
        echo "--------------------------"
        read -p "Is The Data Right ? [Y/N] : " _YN1
        if [[ $_YN1 == "y" ]] || [[ "$_YN1" == "Y" ]] || [[ "$_YN1" = "" ]]
        then
            break
        elif [[ $_YN1 == "n" ]] || [[ "$_YN1" == "N" ]]
        then
            if [[ "$i" -eq "2" ]]
            then
                exit
            else
                ReadServerData "_"$1"Server" "$1"
            fi    
        fi
    done

   
} 

function ssh_auth {
    if [[ -e /root/.ssh/id_rsa* ]]
    then
        echo "SSH-Key Already Exists"
    else
        echo -e  'y\n'|ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
    fi
    sshpass -p $ServerPASS ssh-copy-id -f -o StrictHostKeyChecking=no  "$_1stServerUSER"@"$_1stServerIP"
    sshpass -p $ServerPASS ssh-copy-id -f -o StrictHostKeyChecking=no  "$_2ndServerUSER"@"$_2ndServerIP"
} 

function simple_diff {

   
    diff -y --suppress-common-lines <(ssh -o 'StrictHostKeyChecking=no' "$_1stServerUSER"@"$_1stServerIP" 'ls -R '$_1stServerPATH'') <(ssh -o 'StrictHostKeyChecking=no' "$_2ndServerUSER"@"$_2ndServerIP" 'ls -R '$_2ndServerPATH'' ) > $SCRIPT_CURRENT_DIRECTORY/tmp/diff.tmp


    
} 


function complex_diff {
    ssh 192.168.180.161 find /root/server-1 -type f > $SCRIPT_CURRENT_DIRECTORY/tmp/diff_1.tmp
    ssh 192.168.180.162 find /root/server-1 -type f > $SCRIPT_CURRENT_DIRECTORY/tmp/diff_2.tmp

    diff -u diff_1.tmp diff_2.tmp | grep -wv -e "+" -e "-" -e "@@" > $SCRIPT_CURRENT_DIRECTORY/tmp/diff_1_2.tmp

    counter=0
    while IFS='' read -r line || [[ -n "$line" ]]
    do
    _Array[$counter]=$line;
    let counter=counter+1;
   
    done < diff_1_2.tmp

    if [[ -e $SCRIPT_CURRENT_DIRECTORY/tmp/diff_1_2_output.tmp ]]
    then
        rm -rf $SCRIPT_CURRENT_DIRECTORY/tmp/diff_1_2_output.tmp
    fi
    for ((i=0;i<${#_Array[@]};i++))
    do
        diff -y --suppress-common-lines <(ssh -o 'StrictHostKeyChecking=no' "$_1stServerUSER"@"$_1stServerIP" 'cat '${_Array[$i]}'') <(ssh -o 'StrictHostKeyChecking=no' "$_2ndServerUSER"@"$_2ndServerIP" 'cat '${_Array[$i]}'' ) > $SCRIPT_CURRENT_DIRECTORY/tmp/diff_1_2_output.tmp 
    done
}

function Manual_Sync {    
    ssh "$_1stServerUSER"@"$_1stServerIP"  << EOF
    yum install -y sshpass
    echo -e  'y\n'|ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
    sshpass -p $_2ndServerPASS ssh-copy-id -o StrictHostKeyChecking=no  "$_2ndServerUSER"@"$_2ndServerIP"
    osync.sh --initiator="$_1stServerPATH" --target="ssh://"$_2ndServerUSER"@"$_2ndServerIP":22/$_2ndServerPATH" --rsakey=/root/.ssh/id_rsa
EOF
}

function Resolving_Output {
    flag=0

    _WCDiffOutPutDiff=`wc -l < $SCRIPT_CURRENT_DIRECTORY/tmp/$1`

    if [[ "$_WCDiffOutPutDiff" -gt "0" ]]
    then
        flag=0
        echo "Not Identical"
        read -p "Do You Want To Sync Between Directories and Files ? [Y/N] : " _YN3
        if [[ $_YN3 == "y" ]] || [[ "$_YN3" == "Y" ]] || [[ "$_YN3" = "" ]]
        then
            cat $SCRIPT_CURRENT_DIRECTORY/tmp/$1
            read -p "Do You Want To Sync Between Two Servers ? [Y/n] : " _Sync_Choose
            if [[ $_Sync_Choose == "y" ]] || [[ "$_Sync_Choose" == "Y" ]] || [[ "$_Sync_Choose" = "" ]]
            then
                flag=1
                Manual_Sync
            elif [[ $_Sync_Choose == "n" ]] || [[ "$_Sync_Choose" == "N" ]]
            then
                flag=0
                
            fi
        elif [[ $_YN3 == "n" ]] || [[ "$_YN3" == "N" ]]
        then
            flag=0    
            
        fi
    else
        flag=1
        echo "Identical"
    fi
} 

function _Exit {

    variable_names=( flag _YN1 _YN2 _YN3 _YN4 _YNQ _1stServer
     _1stServerIP _1stServerPATH _1stServerUSER _2ndServer _2ndServerIP _2ndServerPASS _2ndServerPASSAgain _2ndServerPATH _2ndServerUSER _Array _Sync_Choose _WCDiffOutPutDiff SCRIPT_CURRENT_DIRECTORY line counter ServerPASS ServerPASSAgain  )
	for((i=0;i<${#variable_names[@]};i++))
	do
        unset ${variable_names[$i]}
    done
    exit

}

if [[ "$1" = "--simple" ]] || [[ "$1" = "-s" ]] || [[ "$1" = "--complex" ]] || [[ "$1" = "-c" ]] || [[ "$1" = "--simple--complex" ]]  || [[ "$1" = "-s-c" ]]
then
    ReadServerData "_1stServer" "1st"
    ReadServerData "_2ndServer" "2nd"
    printing_servers_data "1st"
    printing_servers_data "2nd"
    ssh_auth
	if [[ "$1" = "--simple" ]] || [[ "$1" = "-s" ]]
	then
		simple_diff
        Resolving_Output "diff.tmp"
        _Exit
	elif [[ "$1" = "--complex" ]]  || [[ "$1" = "-c" ]]
	then
		complex_diff
        Resolving_Output "diff_1_2_output.tmp"
        _Exit
	elif [[ "$1" = "--simple--complex" ]]  || [[ "$1" = "-s-c" ]]
	then
        simple_diff
        Resolving_Output "diff.tmp"
        if [[ $flag -eq "1" ]]
        then
            complex_diff
            Resolving_Output "diff_1_2_output.tmp"
            _Exit
        else
            echo "Directores And Files Are Not Identical On Both Servers."
            read -p "Do You Want To Sync Now ? [Y/n/c/q]
            Y : [Default] Yes Sync Now
            n : Don't Sync Now
            q : Quit
            > Your Answer : " _YNQ
            if [[ $_YNQ == "y" ]] || [[ "$_YNQ" == "Y" ]] || [[ "$_YNQ" = "" ]]
            then
                Manual_Sync
                read -p "Do You Want TO Compare Between Files Content Using Complex Mode. [Y/n]" _YN4
                if [[ $_YN4 == "y" ]] || [[ "$_YN4" == "Y" ]] || [[ "$_YN4" = "" ]]
                then
                    complex_diff
                    Resolving_Output "diff_1_2_output.tmp"
                    _Exit
                elif [[ $_YN4 == "n" ]] || [[ "$_YN4" == "N" ]]
                then
                    _Exit
                fi
            elif [[ $_YNQ == "n" ]] || [[ "$_YNQ" == "N" ]]
            then
                complex_diff
                Resolving_Output "diff_1_2_output.tmp"
                _Exit
            elif [[ $_YNQ == "q" ]] || [[ "$_YNQ" == "Q" ]]
            then
                _Exit
            fi
        fi
	fi
else
	
	echo "Usage: ./.../diff.sh [OPTION]... "
	echo "Options:
	RMARK: Options Order Is Mandatory 
	-s, --simple          	[ Recommended To Run First ]
                                TO Compare Only Between Directories And File Names.
	
    -c, --complex           	TO Compare Between Files Content. Files Should Be 
                                Existed In The Both Servers.
	
    -s-c, --simple--complex 	TO Compare First The Existance Of Directories 
                                And Files Then Check The Content Of The Files."	
fi 
