#!/bin/bash

# Predefined variables for host certificate

fqdn=$1
countryName=AM
state=Yerevan
organization=Mkoyan-DevOps
organizationUnitNmae=IT
emailClient=mkoyan44@gmail.com
caCrt=rootCrt
caKey=rootKey
caDir=ca
confDir=/etc/ssl

# Vars for intermadiate CA
intermediateCA=`hostname --fqdn` # point to I-CA fqdn
# To rewrite Inter-CA attributes reassign vars located on top


createCSR () {
cat << EOF > $confDir/csr.conf
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C=$countryName
ST=$state
L=$state
O=$organization
OU=$organizationUnitNmae
emailAddress=$emailClient
CN = $fqdn
EOF
}
createAltConf () {

cat << EOF > $confDir/subjectAltName.conf
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $fqdn
DNS.2 = www."$fqdn"
DNS.3 = *."$fqdn"
EOF
}

echo "Befor execute it make sure all variables set properly\n"
echo "Are you ready?:yes/no"
read isReady
if [[ $isReady == 'no' ]]; then
	exit 1 
else
	echo "You are able to Gen-CA ('CA'|'ca'|'Ca')"
    echo "You are able to GenHost-CRT-and-sign (gen-sign'|'gs')"
	echo "You are make to Intermediate ('inter-ca'|'ica')"
	echo "What do you want to perform"
	read toDo
	case "$toDo" in
	'CA'|'ca'|'Ca')
		echo "Root CA Cert"
		if [ ! -d $PWD/$caDir ];then
			mkdir -p $PWD/$caDir
		fi 
		createCSR
		createAltConf
		openssl genrsa -out $PWD/$caDir/$caKey.key 2048
		openssl req -x509 -new -nodes -key $PWD/$caDir/$caKey.key -sha256 -days 1024 -out $PWD/$caDir/$caCrt.pem 
	;;
	'gen-sign'|'gs')
		echo "Generat and Sign the Cert."
		createCSR
		createAltConf
		if [ ! -d $PWD/$fqdn ];then
			mkdir -p $PWD/$fqdn
		fi 
		openssl req -new -sha256 -nodes -out $PWD/$fqdn/$fqdn.csr -newkey rsa:2048 -keyout $PWD/$fqdn/$fqdn.key -config $confDir/csr.conf
		openssl x509 -req -in $PWD/$fqdn/$fqdn.csr -CA $PWD/$caDir/$caCrt.pem -CAkey $PWD/$caDir/$caKey.key -CAcreateserial -out $PWD/$fqdn/$fqdn.crt -days 500 -sha256 -extfile $confDir/subjectAltName.conf
		openssl dhparam -out $PWD/$fqdn/"$fqdn"_dh.pem 1024

	;;
	'inter-ca'|'ica')
		echo "Generat and Sign the Intermediate-Certificate authority."
		echo "Intermediate CA"
		fqdn=$intermediateCA
		createCSR
		createAltConf
		if [ ! -d $PWD/$fqdn ];then
			mkdir -p $PWD/$fqdn
		fi 
		openssl req -new -sha256 -nodes -out $PWD/$fqdn/$fqdn.csr -newkey rsa:2048 -keyout $PWD/$fqdn/$fqdn.key -config $confDir/csr.conf
		openssl x509 -req -in $PWD/$fqdn/$fqdn.csr -CA $PWD/$caDir/$caCrt.pem -CAkey $PWD/$caDir/$caKey.key -CAcreateserial -out $PWD/$fqdn/$fqdn.crt -days 365 -sha256 -extensions v3_intermediate_ca -extfile $confDir/subjectAltName.conf
	;;
	*)
		echo "'CA'|'ca'|'Ca'"\n
		echo "'gen-sign'|'gs'"\n
		echo "'inter-ca'|'ica')"\n
	;;
	esac
fi

