#!/bin/bash
# automatic DNS slave config

# Variables initialisation
version="autDnsSlaveConfig v0.1 - 2017, Yvan Godard [godardyvan@gmail.com]"
scriptDir=$(dirname "${0}")
scriptName=$(basename "${0}")
scriptNameWithoutExt=$(echo "${scriptName}" | cut -f1 -d '.')
githubRemoteScript="https://raw.githubusercontent.com/yvangodard/auto-dns-slave/master/auto-dns-slave.sh"
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

# Changement du séparateur par défaut et mise à jour auto
OLDIFS=$IFS
IFS=$'\n'
# Auto-update script
if [[ $(checkUrl ${githubRemoteScript}) -eq 0 ]] && [[ $(md5sum "$0" | awk '{print $1}') != $(curl -Lsf ${githubRemoteScript} | md5sum | awk '{print $1}') ]]; then
    [[ -e "$0".old ]] && rm "$0".old
    mv "$0" "$0".old
    curl -Lsf ${githubRemoteScript} >> "$0"
    echo "An update for ${0} is available." >> /var/log/incron.log
    echo "We download it from GitHub." >> /var/log/incron.log
    if [ $? -eq 0 ]; then
        echo "Update ok, relaunching the script." >> /var/log/incron.log
        chmod +x "$0"
        exec ${0} "$@"
        exit $0
    else
        echo "Something went wrong when trying to upgrade ${0}." >> /var/log/incron.log
        echo "We continue with the old version of the script." >> /var/log/incron.log
    fi
    echo ""
fi
IFS=$OLDIFS

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
scp -P ${portDestination} ${tempFile} root@${serveurDestination}:${confFileDest}.new >> /var/log/incron.log 2>&1

rm /tmp/${scriptNameWithoutExt}*

exit 0