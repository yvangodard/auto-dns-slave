#!/bin/bash
# automatic DNS slave config

# Variables initialisation
version="autDnsSlaveConfig v0.1 - 2017, Yvan Godard [godardyvan@gmail.com]"
scriptDir=$(dirname "${0}")
scriptName=$(basename "${0}")
scriptNameWithoutExt=$(echo "${scriptName}" | cut -f1 -d '.')
githubRemoteScript="https://raw.githubusercontent.com/yvangodard/auto-dns-slave/master/auto-dns-slave-config.sh"
tempFile=$(mktemp /tmp/${scriptNameWithoutExt}.XXXXX)
tempFile2=$(mktemp /tmp/${scriptNameWithoutExt}2.XXXXX)
confFileDest="/etc/bind/named.pastefromprimaty.conf"
serveurDestination=$1
portDestination=$2
ip=$(dig +short myip.opendns.com @resolver1.opendns.com)

# Exécutable seulement par root
if [ `whoami` != 'root' ]; then
    echo "This tool have to be launched by root. Please use 'sudo'."
    exit 1
fi

# Check URL
function checkUrl() {
  command -p curl -Lsf "$1" >/dev/null
  echo "$?"
}

# exit on error
# set -e

echo ""  >> /var/log/incron.log
echo "****************************** `date` ******************************"  >> /var/log/incron.log
echo "$0 launched..." >> /var/log/incron.log
echo "" >> /var/log/incron.log

echo "Le fichier /etc/bind/named.view.external.conf a été modifié." >> /var/log/incron.log
echo "Nous l'analysons puis générons un fichier pour le serveur secondaire." >> /var/log/incron.log
echo "" >> /var/log/incron.log

# wait a bit until the file has its permanent name
sleep 15

# listons les domaines et générons le fichier
for domain in $(cat /etc/bind/named.view.external.conf | grep zone | sed 's/\t//g' | sed -e 's/[ ]*zone/zone/g' | grep ^zone | grep -v '"."' | grep -vi in-addr | grep -vi localhost | awk '{print $2}' | awk 'length > 1' | awk -F\" '{print $2}'); 
do 
    printf "zone \"${domain}\" {\n\ttype slave;\n\tfile \"/etc/bind/slaves/${domain}.hosts\";\n\tmasters { ${ip}; };\n};\n" >> ${tempFile}
done

# On récupère le fichier original
scp -P ${portDestination} root@${serveurDestination}:${confFileDest} ${tempFile2} >> /var/log/incron.log 2>&1

# On print les modifications
echo "" >> /var/log/incron.log
echo "Modifications qui vont être envoyées en scp :" >> /var/log/incron.log
diff ${tempFile2} ${tempFile} >> /var/log/incron.log

# On envoie les modifications sur le serveur de destination
echo "scp -P ${portDestination} ${tempFile} root@${serveurDestination}:${confFileDest}.new"
scp -P ${portDestination} ${tempFile} root@${serveurDestination}:${confFileDest}.new # >> /var/log/incron.log 2>&1

echo ""
echo "${tempFile}"
echo "${tempFile2}"
#[[ -e ${tempFile} ]] && rm ${tempFile}
#[[ -e ${tempFile2} ]] && rm ${tempFile2}

exit 0