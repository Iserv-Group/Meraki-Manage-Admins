#!/bin/bash

api_key=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx #Meraki Dashboard API Key
comp="Example Company" #Company name used in a few of the menu items
#Pulls list of orginizations and sorts
IFS=$'\n' org_list1=(`curl 2>/dev/null --location --request GET 'https://api.meraki.com/api/v0/organizations' --header "X-Cisco-Meraki-API-Key: $api_key" | python -m json.tool | grep \"name\" | awk -F '"' '{print $4}'`)
IFS=$'\n' org_list=($(sort <<<"${org_list1[*]}"))

#Choose a script option using a dialog box


DIALOG=${DIALOG=dialog}
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

$DIALOG --clear --backtitle "Manage Meraki Users" --title "Meraki Admin Manager" \
        --menu "Choose from the following options" 20 60 4 \
        "1"  "Add single admin to all organizations" \
        "2" "Remove single admin from all organizations" \
        "3"  "Add all $comp admins to a single organization" 2> $tempfile

retval=$?

select=`cat $tempfile`

#Create command variable for options 1 and 2
if [ "$select" == "1" ]; then
	command=add
	elif [ "$select" == "2" ]; then
	command=delete
fi
#Runs options 1 and 2
if [ "$select" == "1" ] || [ "$select" == "2" ]; then
	if [ "$command" = "delete" ]; then
        	txt1=from
        	txt2=deleting
	        txt3=Delete
        	elif [ "$command" = "add" ]; then
	        txt1=to
        	txt2=adding
	        txt3=Add
	fi
	#Dialog box for getting name and email
	dialog --backtitle "Manage Meraki Users" --title "$txt3 User" \
	--form "\nWaring, This script will $command the given user $txt1 all $comp controlled Orginizations in Meraki. Use with caution\n
	\n
	Enter both Admin Name and Email before pressing Enter to continue\n
	Ctrl+C to end script" 30 60 16 \
	"Admin Name:" 1 1 "" 1 13 30 1  \
	"Admin Email:" 2 1 "" 2 13 30 1 > /tmp/out.tmp \
	2>&1 >/dev/tty
	# Start retrieving each line from temp file 1 by one with sed and declare variables as inputs
	name=`sed -n 1p /tmp/out.tmp`
	email=`sed -n 2p /tmp/out.tmp`
	# remove temporary file created
	rm -f /tmp/out.tmp
	#end dialog box for name and email


	#begin Dialog box for confirming input and running script
	$DIALOG --backtitle "Manage Meraki Users" --title "Confirm Entry" --clear \
	        --yesno "Please confirm the the following are correct\n
	Name: $name\n
	Email: $email" 10 50

	case $? in
	  0)
		dialog --backtitle "Manage Meraki Users" --title "$txt3 to Admin list?" --clear --yesno "Do you want to $command user $txt1 Admin List" 10 50 
		case $? in
		0)
		#Checks for adding the user to the list of admins
		if [ "$command" == "add" ]; then
			echo "$name||$email" >> ./admins.txt
		else
			grep -v $email ./admins.txt > ./admins.tmp
			cat ./admins.tmp > ./admins.txt
			rm ./admins.tmp
		fi
		;;
		1)
		;;
		255)
		;;
		esac
		#runs script when yes is chosen
		for i in "${org_list[@]}"; do
		python3 ./manageadmins.py -k $api_key -o "$i" -c $command -a $email -n "$name"
		done | dialog --backtitle "Manage Meraki Users" --title "Running Python Script" --programbox 60 160
		;;
	  1)
		#Exits script when no is chosen
		echo "Add Admin script closed"
		;;
	  255)
		echo "ESC pressed."
		;;
	esac
#end Dialog box

fi

#Runs option 3
if [ "$select" == "3" ]; then
        $DIALOG --backtitle "Manage Meraki Users" --colors --nocancel --no-items --menu "Choose Orginization" 20 51 30  "${org_list[@]}" 2> $tempfile
	retval=$?
	org=`cat $tempfile`
	#Load Variables into seperate arrays
	IFS=$'\n' name=(`cat ./admins.txt | awk -F\| '{print $1}'`)
	IFS=$'\n' email=(`cat ./admins.txt | awk -F\| '{print $3}'`)
		for ((i=0;i<${#name[@]};++i)); do
				python3 ./manageadmins.py -k $api_key -o "$org" -c add -a "${email[i]}" -n "${name[i]}"

		done | dialog --backtitle "Manage Meraki Users" --title "Running Python Script" --programbox 60 160
	clear
fi
clear
