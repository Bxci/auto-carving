#!/bin/bash
HOME=$(pwd)
start_time=$(date '+%d-%m-%Y %H:%M:%S')

#if to check if the script running with root, or with sudo, if not get exiting.
if [[ "$USER" != "root" ]]; then
    echo "Error: script not running as root or with sudo! Exiting..."
    exit 1
fi

if [[ $(whoami) != "root" ]]; then
    echo "Warning: script must be run as root or with elevated privileges!"
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


#1.2 - here just the read file to person you wanna to see if he can to read files and explore them.
function CHECK_FILE() {
    echo "Enter the full path to the file you wish to analyze:"
    read file

    if [[ -r "$file" ]]; then
        echo "File '$file' is valid, readable, and has the correct extension. Proceeding..."
        return 0
    else
        echo "file '$file' Please try again."
        return 1 
    fi
}
while true; do
    if CHECK_FILE; then
        break
    fi
done

#2.1 here we can see the memdump.mem can run with
#taking help from that theard - https://stackoverflow.com/questions/407184/how-to-check-the-extension-of-a-filename-in-a-bash-script
function CHECK(){
if [[ "$file" =~ \.(raw|dmp|mem|vmem|core|vhd|vhdx)$ ]]; then
echo "the $file can running with vol"
else
echo "the $file can't running with vol"
fi
}
CHECK

#here the functions to install requirements.
function FOREMOST(){
    if command -v "foremost" > /dev/null 2>&1 ;then
    echo "Foremost is Already Installed!"
    else
    sudo apt-get install foremost -y >/dev/null 2>&1
    echo "foremost Downloaded!"
    fi
}
FOREMOST

function BINWLAK(){
    if command -v "binwalk" > /dev/null 2>&1 ;then
    echo "binwalk is already installed!"
    else
    sudo apt-get install binwalk -y </dev/null 2>&1
    echo "binwlak Downloaded!"
    fi
}
BINWLAK

function BULK_EXTRACTOR(){
    if command -v "bulk_extractor" > /dev/null 2>&1 ;then
    echo "bulk_extractor is already installed!"
    else
    sudo apt-get install bulk_extractor -y </dev/null 2>&1
    echo "bulk_extractor Downloaded!"
    fi
}
BULK_EXTRACTOR

function BINUTILS(){
    if command -v "strings" > /dev/null 2>&1 ;then
    echo "Strings is already installed!"
    else
    sudo apt-get install binutils -y >/dev/null 2>&1
    echo "Strings Downloaded!"
    fi
}
BINUTILS

#1.5 mkdirs for the carving txt.

mkdir Data
cd ./Data

#1.4 here the carvers starting to working and sending the readable to each file to a directory.
bulk_extractor -o bulk_data "$file"
foremost -i "$file" -o foremost_data
binwalk "$file" > bikwalk_data

#1.7 here its gonna to search for passwords usernames and exe's files
strings $file | grep -i passwords >> passwords_carved.txt
strings $file | grep -i username >> username_carved.txt
strings $file | grep -i .exe >> exe_carved.txt

#in 1.6 we need memdump.mem to search and its will give us pcap file.

#installation of vol
function VOL() {
	cd ..
	git clone https://github.com/Bxci/vol.git
	chmod +x volatility_2.5_linux_x64
	PROFILE=$(./volatility_2.5_linux_x64 -f "$file" imageinfo | grep -i suggested | awk '{print $4}' | sed 's/\,//g')
}
VOL
#2.3 here its to find proccess whos running on the mem.
echo "looking for running proccess with vol!"
./volatility_2.5_linux_x64 -f "$file" --profile="$PROFILE" pslist

#2.4 same like 2.3 but with connections.
echo "looking for active connections."
./volatility_2.5_linux_x64 -f "$file" --profile="$PROFILE" connections

HIVE=$(./volatility_2.5_linux_x64 -f $file --profile=$PROFILE hivelist | grep -i system32 | awk '{print $1}')

DUMP=$(./volatility_2.5_linux_x64 -f "$file" --profile="$PROFILE" dumpregistry "$HIVE" -D "./Data")

function PCAP(){
    echo "Searching for PCAP file."
    pcap_files=$(find ./Data -type f -name "*.pcap" -exec du -h {} +)

    if [ -z "$pcap_files" ]; then
    echo "No pcap files located"
    else
    echo "Found PCAP File"
    echo "$pcap_files"
    fi
}
PCAP

end_time=$(date '+%d-%m-%Y %H:%M:%S')
echo "Script started at: $start_time"
echo "Script ended at: $end_time"

cd ./Data
O=$(ls -lR | awk '{print $9}' | grep -v "^$" | find -type f | wc -l)
echo "Total of files got extracted: $O"

ls -lR | awk '{print $9}' | grep -v "^$" | find -type f > report.txt
echo "$REPORT Report.txt extracted! to Data folder"
cd ..
HOME=$(pwd)
zip -r Data.zip Data
