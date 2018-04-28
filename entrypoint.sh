#!/bin/sh

# Pre-flight Checks

if [ $1 == "-h" ]; then
    cat << EOF
jnovack/my-cert-authority ${VERSION} built ${DATE} (branch ${BRANCH}, commit ${COMMIT})
Generates certificates for multi-purpose use.

  Certificate Authority Options:
    -c              print CA.crt
    -l              print certificate revocation list

  Client Request Options:
    -e              generate certificate type
                       ('server', 'client', 'service', 'user')
    -q              print less crap on screen
    -n              non-interactive (use defaults)
    -g <cn>         generate certificate for <cn>
    -r <cn>         revoke certificate for <cn>

  Client Certificate Options:
    -p <cn>         print client public certificate
    -k <cn>         print client private key
    -i <cn>         print client certificate information
    -u <cn>         print client PKCS12 file (uuencoded)

EOF
    exit 0;
fi

## Output Function

function output() {
    if [ "$QUIET" != true ] ; then echo "$@"; fi
}

## Copy template to openssl.cnf
if [ ! -f /opt/openssl.cnf ]; then
    echo
    echo " !! Initializing openssl.cnf..."
    echo
    [ -z "$C" ]       && read -p "-- Country Name (2 letter code) []: " -r C
    [ -z "$ST" ]      && read -p "-- State or Province Name (full name) []: " -r ST
    [ -z "$L" ]       && read -p "-- Locality Name (city, district) []: " -r L
    [ -z "$O" ]       && read -p "-- Organization Name (company) []: " -r O
    [ -z "$OU" ]      && read -p "-- Organizational Unit Name (department, division) []: " -r OU
    [ -z "$EMAIL" ]   && read -p "-- Email Address []: " -r EMAIL
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

while getopts ":g:r:i:k:p:u:e:qncl" opt; do
    case $opt in
        c)
            # Print out Certiciate Authority Cert
            cat /opt/root/ca.crt
            EXIT=true
            ;;
        i)
            # Print client certificate information
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -i"; exit 1; fi
            openssl x509 -in /opt/root/private/${OPTARG}.crt -noout -subject -startdate -enddate -fingerprint -sha256 -serial | sed "s/^/        /g"
            EXIT=true
            ;;
        l)
            cat /opt/root/ca.crl
            EXIT=true
            ;;
        p)
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -p"; exit 1; fi
            FILE=$(echo ${OPTARG} | sed -e 's/[^A-Za-z0-9._-]/_/g') # Basic sanitation.
            cat /opt/root/public/certs/${FILE}.crt
            EXIT=true
            ;;
        k)
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -k"; exit 1; fi
            FILE=$(echo ${OPTARG} | sed -e 's/[^A-Za-z0-9._-]/_/g') # Basic sanitation.
            cat /opt/root/private/${FILE}.key
            EXIT=true
            ;;
        u)
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -u"; exit 1; fi
            FILE=$(echo ${OPTARG} | sed -e 's/[^A-Za-z0-9._-]/_/g') # Basic sanitation.
            cat /opt/root/private/${FILE}.p12 | uuencode -m ${FILE}.p12
            EXIT=true
            ;;
        e)
            if [ -z "$OPTARG" ]; then echo " !! Missing argument for -e"; exit 1; fi
            [ ! -z "$OPTARG" ] \
                || [ $OPTARG == "s"] || [ $OPTARG == "server"] \
                || [ $OPTARG == "c"] || [ $OPTARG == "client"] \
                || [ $OPTARG == "v"] || [ $OPTARG == "service"] \
                || [ $OPTARG == "u"] || [ $OPTARG == "user"] \
                || (echo " !! -e [server|client|user]"; exit 1)
            EXTENSION=$OPTARG
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

if [ ! -z $EXIT ]; then exit 0; fi

## CA files are missing, regenerate entire structure destructively since it's borked anyway.
if ([ ! -f /opt/root/ca/private/ca.key ] || [ ! -f /opt/root/ca.crt ]); then
    # Clean up old certs and files...
    output
    output " !! Creating Certificate Authority... please wait..."

    rm -rf /opt/root/
    mkdir -p /opt/root/ca/private \
        && mkdir -p /opt/root/private \
        && mkdir -p /opt/root/public/certs \
        && mkdir /opt/root/certs/ \
        && touch /opt/root/ca/database.txt \

    # Generate Certificate Authority in one sexy command-line
    openssl req -new -x509 -sha256 -days ${CADAYS:=3650} -nodes -newkey rsa:4096 \
        -subj "${SUBJECT}" \
        -extensions v3_root -config /opt/openssl.cnf \
        -keyout /opt/root/ca/private/ca.key -out /opt/root/ca.crt > /dev/null 2>&1

    ## Create Random CA Serial
    openssl rand -base64 16 | sha256sum | head -c 16 | tr '[:lower:]' '[:upper:]' > /opt/root/ca/ca.serial

    cp /opt/root/ca.crt /opt/root/public
fi


## CRL files are missing, regenerate entire structure destructively since it's borked anyway.
if ([ ! -f /opt/root/ca.crl ] || [ ! -f /opt/root/ca/crl.serial ]); then
    test -f /opt/root/ca/private/ca.key  || ( echo "/opt/root/ca/private/ca.key not found..." && exit 1 )
    test -f /opt/root/ca.crt          || ( echo "/opt/root/ca.crt not found..." && exit 1 )

    ## Create CRL Number
    echo 01 > /opt/root/ca/crl.serial

    ## Create a blank CRL
    openssl ca -name CA_root -gencrl \
        -keyfile /opt/root/ca/private/ca.key \
        -cert /opt/root/ca.crt \
        -out /opt/root/ca.crl \
        -crldays ${CRLDAYS:=3650} \
        -config /opt/openssl.cnf > /dev/null 2>&1

    cp /opt/root/ca.crl /opt/root/public
fi

## List Current CA for debugging and verification
if [ "$QUIET" != true ]; then
    echo
    echo " !! Using the following Certificate Authority:"
    echo
    openssl x509 -in /opt/root/ca.crt -noout -subject -startdate -enddate -fingerprint -sha256 -serial | sed "s/^/        /g"
fi

# Functions
function generateCertificate() {
    output

    [ -f /opt/root/public/certs/${COMMONNAME}.crt ] && echo " !! Certificate ${COMMONNAME}.crt already exists..." && exit 1;

    while [ -z $EXTENSION ] && read -p "Type (server, service, client, user): " -r OPT && [ -n "${OPT}" ]; do
        case $OPT in
            server)
                EXTENSION="server"
                break
                ;;
            s)
                EXTENSION="server"
                break
                ;;
            service)
                EXTENSION="service"
                break
                ;;
            v)
                EXTENSION="service"
                break
                ;;
            client)
                EXTENSION="client"
                break
                ;;
            c)
                EXTENSION="client"
                break
                ;;
            user)
                EXTENSION="user"
                break
                ;;
            u)
                EXTENSION="user"
                break
                ;;
        esac
    done

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

    if [ $EXTENSION == "server" ]; then
        echo "" >> /opt/openssl.runtime.cnf
        echo "[ san_custom ]" >> /opt/openssl.runtime.cnf

        echo -e "Please list your IP SANs. End with a blank line..."
        i=1
        while read -p "$(echo IP.${i} = ) "  -r line && [ -n "${line}" ]; do
            echo "IP.${i} = ${line}" >> /opt/openssl.runtime.cnf
            i=$((i+1))
        done

        echo "DNS.1 = ${COMMONNAME}" >> /opt/openssl.runtime.cnf
        echo -e "Please list your additional DNS SANs. End with a blank line..."
        i=2
        while read -p "$(echo DNS.${i} = ) " -r line && [ -n "${line}" ]; do
            echo "DNS.${i} = ${line}" >> /opt/openssl.runtime.cnf
            i=$((i+1))
        done
    fi

    output " !! Generating a ${EXTENSION} certificate for ${COMMONNAME}"

    if [ "$NONINTERACTIVE" = true ] ; then
        SUBJECT=$(echo $SUBJECT | sed -e "s/CN=[^/]\+/CN=${COMMONNAME}/")
        NOPASS=" -passout pass:"
        openssl req -new -newkey rsa:4096 -keyout /opt/root/private/${COMMONNAME}.key -out /opt/root/private/${COMMONNAME}.csr -nodes \
            -subj "${SUBJECT}" \
            -config /opt/openssl.runtime.cnf > /dev/null 2>&1
    else
        output
        openssl req -new -newkey rsa:4096 -keyout /opt/root/private/${COMMONNAME}.key -out /opt/root/private/${COMMONNAME}.csr -nodes \
            -config /opt/openssl.runtime.cnf
    fi

    openssl ca -name CA_root \
            -extensions v3_${EXTENSION} \
            -in /opt/root/private/${COMMONNAME}.csr \
            -out /opt/root/private/${COMMONNAME}.crt \
            -notext \
            -policy policy_optional \
            -updatedb -config /opt/openssl.runtime.cnf -batch > /dev/null 2>&1

    md5cert="$(openssl x509 -in /opt/root/private/${COMMONNAME}.crt -noout -modulus | openssl md5)"
    md5key="$(openssl rsa -in /opt/root/private/${COMMONNAME}.key -noout -modulus | openssl md5)"
    md5req="$(openssl req -in /opt/root/private/${COMMONNAME}.csr -noout -modulus | openssl md5)"

    if [ "${md5key}" == "${md5req}" ] && [ "${md5key}" == "${md5cert}" ]; then
        openssl pkcs12 -export -nodes -clcerts \
            -in /opt/root/private/${COMMONNAME}.crt \
            -inkey /opt/root/private/${COMMONNAME}.key \
            -certfile /opt/root/ca.crt \
            ${NOPASS} \
            -out /opt/root/private/${COMMONNAME}.p12 > /dev/null 2>&1

        cat /opt/root/private/${COMMONNAME}.key > /opt/root/private/${COMMONNAME}.pem
        cat /opt/root/private/${COMMONNAME}.crt >> /opt/root/private/${COMMONNAME}.pem

        SERIAL=`openssl x509 -in /opt/root/private/${COMMONNAME}.crt -noout -serial | awk -F "=" -e '{ print $2; }'`
        openssl x509 -in /opt/root/private/${COMMONNAME}.crt -text > /opt/root/certs/${SERIAL}.pem
        rm /opt/root/private/${COMMONNAME}.csr

        if [ "$QUIET" != true ]; then
            echo
            openssl x509 -in /opt/root/private/${COMMONNAME}.crt -noout -subject -startdate -enddate -fingerprint -sha256 -serial | sed "s/^/        /g"
            echo
        fi
        mv /opt/root/private/${COMMONNAME}.crt /opt/root/public/certs/${COMMONNAME}.crt
    else
        output "ERROR: Keys did not generate properly.  Start crying now."
        exit 1
    fi

    unset EXTENSION
}

function revokeCertificate() {
    if [ -f /opt/root/public/certs/${REVOKE}.crt ]; then

        if [ "$QUIET" != true ]; then
            echo
            echo " !! Revoking ${REVOKE}.crt"
            openssl x509 -in /opt/root/public/certs/${REVOKE}.crt -noout -subject -startdate -enddate -fingerprint -sha256 -serial | sed "s/^/        /g"
            echo
        fi;

        openssl ca -name CA_root -revoke /opt/root/public/certs/${REVOKE}.crt -config /opt/openssl.cnf > /dev/null 2>&1
        openssl ca -name CA_root -gencrl -out /opt/root/ca.crl -config /opt/openssl.cnf > /dev/null 2>&1

        SERIAL=`openssl x509 -in /opt/root/public/certs/${REVOKE}.crt -noout -serial | awk -F "=" -e '{ print $2; }'`
        mkdir -p /opt/root/private/.revoked/${SERIAL}/
        mv /opt/root/certs/${SERIAL}.pem /opt/root/private/.revoked/${SERIAL}/
        mv /opt/root/private/${REVOKE}.* /opt/root/private/.revoked/${SERIAL}/
        rm /opt/public/certs/${REVOKE}.crt

        if [ "$QUIET" != true ]; then
            openssl crl -in /opt/root/ca.crl -noout -crlnumber -lastupdate -nextupdate
        fi;
        cp /opt/root/ca.crl /opt/public
        cat /opt/root/ca.crl
    else
        output
        output " !! /opt/root/private/${REVOKE}.crt does not exist..."
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

