#!/bin/sh

# Pre-flight Checks

## Output Function

function output() {
    if [ "$QUIET" != true ] ; then echo "$@"; fi
}

## Copy template to openssl.cnf
if [ ! -f /opt/openssl.cnf ]; then
    echo
    echo " !! Initializing openssl.cnf..."
    echo
    [ -z "$C" ]       && read -p "Set 'Country Name' (C) [no]: " -r Y && [ ! -z "${Y}" ] && read -p "-- Country Name (2 letter code) [XX]: " -r C
    [ -z "$ST" ]      && read -p "Set 'State or Province Name' (ST) [no]: " -r Y && [ ! -z "${Y}" ] && read -p "-- State or Province Name (full name) [My State]: " -r ST
    [ -z "$L" ]       && read -p "Set 'Locality Name' (L) [no]: " -r Y && [ ! -z "${Y}" ] && read -p "-- Locality Name (city, district) [My City]: " -r L
    [ -z "$O" ]       && read -p "Set 'Organization Name' (O) [no]: " -r Y && [ ! -z "${Y}" ] && read -p "-- Organization Name (company) [My Company]: " -r O
    [ -z "$OU" ]      && read -p "Set 'Organizational Unit Name' (OU) [no]: " -r Y && [ ! -z "${Y}" ] && read -p "-- Organizational Unit Name (department, division) [My Department]: " -r OU
    [ -z "$EMAIL" ]   && read -p "Set 'Email Address' [no]: " -r Y && [ ! -z "${Y}" ] && read -p "-- Email Address [nobody@localhost]: " -r EMAIL
    [ -z "$CN" ]      && read -p "-- Common Name [localhost.localdomain]: " -r CN
    cp /openssl.tmpl /opt/openssl.cnf
    [ ! -z "$EMAIL" ] && sed -i "s/nobody@localhost/${EMAIL}/" /opt/openssl.cnf      && sed -i "s/\#emailAddress/emailAddress/" /opt/openssl.cnf
    [ ! -z "$C" ]     && sed -i "s/XX/${C}/" /opt/openssl.cnf                        && sed -i "s/\#countryName/countryName/" /opt/openssl.cnf
    [ ! -z "$ST" ]    && sed -i "s/My State/${ST}/" /opt/openssl.cnf                 && sed -i "s/\#stateOrProvinceName/stateOrProvinceName/" /opt/openssl.cnf
    [ ! -z "$L" ]     && sed -i "s/My City/${L}/" /opt/openssl.cnf                   && sed -i "s/\#localityName/localityName/" /opt/openssl.cnf
    [ ! -z "$O" ]     && sed -i "s/My Company/${O}/" /opt/openssl.cnf                && sed -i "s/\#0.organizationName/0.organizationName/" /opt/openssl.cnf
    [ ! -z "$OU" ]    && sed -i "s/My Department/${OU}/" /opt/openssl.cnf            && sed -i "s/\#organizationalUnitName/organizationalUnitName/" /opt/openssl.cnf
    [ ! -z "$CN" ]    && sed -i "s/localhost.localdomain/${CN}/" /opt/openssl.cnf
fi

## Set Environment and Build Subject
##  (there's got to be a better way, not sure why ( expr1 || expr2) && (expr3 && expr4 ) does not work. )
[ ! -z "$EMAIL" ] || EMAIL=`grep "^emailAddress_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
[ ! -z "$C" ]     || C=`grep "^countryName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
[ ! -z "$ST" ]    || ST=`grep "^stateOrProvinceName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
[ ! -z "$L" ]     || L=`grep "^localityName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
[ ! -z "$O" ]     || O=`grep "^0.organizationName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
[ ! -z "$OU" ]    || OU=`grep "^organizationalUnitName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
[ ! -z "$CN" ]    || CN=`grep "^commonName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
SUBJECT="/"
[ ! -z "$EMAIL" ] && SUBJECT="${SUBJECT}emailAddress=${EMAIL}/"
[ ! -z "$C" ]     && SUBJECT="${SUBJECT}C=${C}/"
[ ! -z "$ST" ]    && SUBJECT="${SUBJECT}ST=${ST}/"
[ ! -z "$L" ]     && SUBJECT="${SUBJECT}L=${L}/"
[ ! -z "$O" ]     && SUBJECT="${SUBJECT}O=${O}/"
[ ! -z "$OU" ]    && SUBJECT="${SUBJECT}OU=${OU}/"
SUBJECT="${SUBJECT}CN=${CN}/"

output ${SUBJECT}

while getopts ":g:r:i:k:p:qncl" opt; do
    case $opt in
        c)
            # Print out Certiciate Authority Cert
            cat /opt/ca/ca.crt
            exit 0
            ;;
        i)
            # Print client certificate information
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -i"; exit 1; fi
            openssl x509 -in /opt/private/${OPTARG}.crt -noout -subject -startdate -enddate -fingerprint -sha256 -serial | sed "s/^/        /g"
            exit 0
            ;;
        l)
            cat /opt/ca/ca.crl
            exit 0
            ;;
        p)
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -p"; exit 1; fi
            FILE=$(echo ${OPTARG} | sed -e 's/[^A-Za-z0-9._-]/_/g') # Basic sanitation.
            cat /opt/private/${FILE}.crt
            exit 0
            ;;
        k)
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -k"; exit 1; fi
            FILE=$(echo ${OPTARG} | sed -e 's/[^A-Za-z0-9._-]/_/g') # Basic sanitation.
            cat /opt/private/${FILE}.key
            exit 0
            ;;
        q)
            QUIET=true
            SILENT="> /dev/null 2>&1"
            ;;
        n)
            NONINTERACTIVE=true
            ;;
        g)
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -n"; exit 1; fi
            COMMONNAME=$(echo ${OPTARG} | sed -e 's/[^A-Za-z0-9._-]/_/g') # Basic sanitation.
            ;;
        r)
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -r"; exit 1; fi
            REVOKE=$(echo ${OPTARG} | sed -e 's/[^A-Za-z0-9._-]/_/g') # Basic sanitation.
            ;;
    esac
done

## CA files are missing, regenerate entire structure destructively since it's borked anyway.
if ([ ! -f /opt/ca/private/ca.key ] || [ ! -f /opt/ca/ca.crt ]); then
    # Clean up old certs and files...
    output
    output " !! Creating Certificate Authority... please wait..."

    rm -rf /opt/database.* && touch /opt/database.txt
    rm -rf /opt/certs/     && mkdir /opt/certs/
    rm -rf /opt/private    && mkdir /opt/private
    rm -rf /opt/public     && mkdir -p /opt/public/certs
    rm -rf /opt/ca         && mkdir -p /opt/ca/private

    # Generate Certificate Authority in one sexy command-line
    openssl req -new -x509 -sha256 -days ${CADAYS:=3650} -nodes -newkey rsa:4096 \
        -subj "${SUBJECT}" \
        -extensions v3_root -config /opt/openssl.cnf \
        -keyout /opt/ca/private/ca.key -out /opt/ca/ca.crt > /dev/null 2>&1

    ## Create Random CA Serial
    openssl rand -base64 16 | sha256sum | head -c 16 | tr '[:lower:]' '[:upper:]' > /opt/ca/ca.serial

    cp /opt/ca/ca.crt /opt/public
fi


## CRL files are missing, regenerate entire structure destructively since it's borked anyway.
if ([ ! -f /opt/ca/ca.crl ] || [ ! -f /opt/ca/crl.serial ]); then
    test -f /opt/ca/private/ca.key  || ( echo "/opt/ca/private/ca.key not found..." && exit 1 )
    test -f /opt/ca/ca.crt          || ( echo "/opt/ca/ca.crt not found..." && exit 1 )

    ## Create CRL Number
    echo 01 > /opt/ca/crl.serial
    rm /opt/ca/ca.crl || true

    ## Create a blank CRL
    openssl ca -name CA_root -gencrl \
        -keyfile /opt/ca/private/ca.key \
        -cert /opt/ca/ca.crt \
        -out /opt/ca/ca.crl \
        -crldays ${CRLDAYS:=3650} \
        -config /opt/openssl.cnf > /dev/null 2>&1

    cp /opt/ca/ca.crl /opt/public
fi

## List Current CA for debugging and verification
if [ "$QUIET" != true ]; then
    echo
    echo " !! Using the following Certificate Authority:"
    echo
    openssl x509 -in /opt/ca/ca.crt -noout -subject -startdate -enddate -fingerprint -sha256 -serial | sed "s/^/        /g"
fi

# Functions

function generateCertificate() {

    [ -f /opt/private/${COMMONNAME}.crt ] && echo " !! Certificate ${COMMONNAME}.crt already exists..." && exit 1;

    ## Replace defaults with environment variables for runtime
    cp /opt/openssl.cnf /opt/openssl.runtime.cnf
    DEFAULT_C=`grep "countryName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
    DEFAULT_ST=`grep "stateOrProvinceName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
    DEFAULT_L=`grep "localityName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
    DEFAULT_O=`grep "0.organizationName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
    DEFAULT_OU=`grep "organizationalUnitName_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
    DEFAULT_EMAIL=`grep "emailAddress_default" /opt/openssl.cnf | awk -F "= " -e '{ print $2; }'`
    DEFAULT_CN=`grep "commonName_default" /opt/openssl.runtime.cnf | awk -F "= " -e '{ print $2; }'`
    sed -i "s/${DEFAULT_C}/${C}/" /opt/openssl.runtime.cnf
    sed -i "s/${DEFAULT_ST}/${ST}/" /opt/openssl.runtime.cnf
    sed -i "s/${DEFAULT_L}/${L}/" /opt/openssl.runtime.cnf
    sed -i "s/${DEFAULT_O}/${O}/" /opt/openssl.runtime.cnf
    sed -i "s/${DEFAULT_OU}/${OU}/" /opt/openssl.runtime.cnf
    sed -i "s/${DEFAULT_EMAIL}/${EMAIL}/" /opt/openssl.runtime.cnf
    sed -i "s/${DEFAULT_CN}/${COMMONNAME}/" /opt/openssl.runtime.cnf

    output
    output " !! Generating a client certificate for $COMMONNAME"

    if [ "$NONINTERACTIVE" = true ] ; then
        SUBJECT=$(echo $SUBJECT | sed "s/CN=[^/]+/CN=${COMMONNAME}/")
        NOPASS=" -passout pass:"
        openssl req -new -newkey rsa:4096 -keyout /opt/private/${COMMONNAME}.key -out /opt/private/${COMMONNAME}.csr -nodes \
            -subj "${SUBJECT}" \
            -config /opt/openssl.runtime.cnf > /dev/null 2>&1
    else
        output
        openssl req -new -newkey rsa:4096 -keyout /opt/private/${COMMONNAME}.key -out /opt/private/${COMMONNAME}.csr -nodes \
            -config /opt/openssl.runtime.cnf 2>/dev/null
    fi

    openssl ca -name CA_root \
            -extensions v3_client \
            -in /opt/private/${COMMONNAME}.csr \
            -out /opt/private/${COMMONNAME}.crt \
            -updatedb -config /opt/openssl.cnf -batch > /dev/null 2>&1

    md5cert="$(openssl x509 -in /opt/private/${COMMONNAME}.crt -noout -modulus | openssl md5)"
    md5key="$(openssl rsa -in /opt/private/${COMMONNAME}.key -noout -modulus | openssl md5)"
    md5req="$(openssl req -in /opt/private/${COMMONNAME}.csr -noout -modulus | openssl md5)"

    output

    if [ "${md5key}" == "${md5req}" ] && [ "${md5key}" == "${md5cert}" ]; then
        openssl pkcs12 -export -nodes -clcerts \
            -in /opt/private/${COMMONNAME}.crt \
            -inkey /opt/private/${COMMONNAME}.key \
            -certfile /opt/ca/ca.crt \
            ${NOPASS} \
            -out /opt/private/${COMMONNAME}.p12 > /dev/null 2>&1

        cat /opt/private/${COMMONNAME}.key > /opt/private/${COMMONNAME}.pem
        cat /opt/private/${COMMONNAME}.crt >> /opt/private/${COMMONNAME}.pem
        rm /opt/private/${COMMONNAME}.csr

        if [ "$QUIET" != true ]; then
            echo
            openssl x509 -in /opt/private/${COMMONNAME}.crt -noout -subject -startdate -enddate -fingerprint -sha256 -serial | sed "s/^/        /g"
            echo
        fi
    else
        output "ERROR: Keys did not generate properly.  Start crying now."
        exit 1
    fi
}

function revokeCertificate() {
    if [ -f /opt/private/${REVOKE}.crt ]; then

        if [ "$QUIET" != true ]; then
            echo
            echo " !! Revoking ${REVOKE}.crt"
            openssl x509 -in /opt/private/${REVOKE}.crt -noout -subject -startdate -enddate -fingerprint -sha256 -serial | sed "s/^/        /g"
            echo
        fi;

        openssl ca -name CA_root -revoke /opt/private/${REVOKE}.crt -config /opt/openssl.cnf > /dev/null 2>&1
        openssl ca -name CA_root -gencrl -out /opt/ca/ca.crl -config /opt/openssl.cnf > /dev/null 2>&1

        SERIAL=`openssl x509 -in /opt/private/${REVOKE}.crt -noout -serial | awk -F "=" -e '{ print $2; }'`
        mkdir -p /opt/private/.revoked/${SERIAL}/
        mv /opt/private/${REVOKE}.* /opt/private/.revoked/${SERIAL}/
        rm /opt/public/certs/${SERIAL}.pem

        if [ "$QUIET" != true ]; then
            openssl crl -in /opt/ca/ca.crl -noout -crlnumber -lastupdate -nextupdate
        fi;
        cp /opt/ca/ca.crl /opt/public
        cat /opt/ca/ca.crl
    else
        output
        output " !! /opt/private/${REVOKE}.crt does not exist..."
        exit 1
    fi
    exit 0;
}

# Runtime Setup

## Revoke Certificates
if [ ! -z "$REVOKE" ]; then
    revokeCertificate $REVOKE
fi

## Iterate creating users
if [ "$NONINTERACTIVE" = true ] ; then
    generateCertificate ${COMMONNAME}
else
    output
    output "    Instructions:"
    output "      Enter the client certificate Common Name (e.g. jnovack, api.${DEFAULT_CN})"
    output "      Pressing 'Enter' on a blank line exits."
    output
    while read -p "Common Name: " -r COMMONNAME && [ -n "${COMMONNAME}" ]; do
        generateCertificate ${COMMONNAME}
    done
fi

