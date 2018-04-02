# my-cert-authority

Quick and easy generate a Certificate Authority (CA), Certificate
Revocation List (CRL) and many client Certificates (CRTs).

## Quick Start

You will most likely wish to mount your CA directory externally, in
which case, you will want to run as follows:

```
docker run -it -v /path/to/ca/:/opt/ --rm jnovack/my-cert-authority
```

Or more appropriately, with volume containers:

```
docker volume create --name ca-project.example
docker run -it --rm \
    --mount source=ca-project.example,target=/opt/
    jnovack/my-cert-authority
```

## Command-Line Arguments and Environment Variables

Running `jnovack/my-cert-authority` without options will run in
interactive mode where you will create a Certificate Authority (CA),
followed by prompts for client certificates (CRTs).

Subsequent running of the container will prompt you for additional
client certificates to create.

### Command-Line Arguments

* `-q` - No output (can be combined with some other options)
* `-a` - Print the Certificate Authority signing certificate
* `-l` - Print the Certificate Revocation List certificate

#### Actions

* `-i name` - Print client certificate information
* `-g name` - Create a client certificate
* `-r name` - Revoke a client certificate

**WARNING:** It is not recommented to mix actions. No error-checking is
performed.

## Environment Variables for CSRs

Environment variables can override any field on a client certificate.

* `C`  = country
* `ST` = state or province name
* `L`  = locality or city name
* `O`  = organization
* `OU` = department or organizational unit
* `EMAIL` = email addressed assigned to

**WARNING:** If you are using anything other than the default
`policy = policy_optional`, changing the wrong environment variable can
prevent your certificate from being generated.

## Automation

You can use the non-interactive flag (`-n`) to generate and revoke
client certificates without user input.

* `-n` - Perform actions non-interactively

Once you complete the initial CA setup, you can quickly and easily
generate client certificates with a simple command-line.

### Generate a certificate (non-interactively)

```
docker run -it --rm \
    --mount source=ca-project.example,target=/opt/
    jnovack/my-cert-authority -n -g jnovack.project.example
```


### Revoke a certificate (non-interactively)
```
docker run -it --rm \
    --mount source=ca-project.example,target=/opt/
    jnovack/my-cert-authority -n -r jnovack.project.example
```

## Container Structure

```
 /(root)
  |-- opt/
       |-- ca/
       |    |-- private/
       |    |    \-- ca.key        (Certificate Authority Private Key)
       |    |
       |    |-- ca.crt             (Certificate Authority Certficate)
       |    |-- ca.crl             (Certificate Revocation List)
       |    |-- ca.serial          (Next Certificate Serial Number)
       |    \-- crl.serial         (Current CRL serial number)
       |
       |-- private/
       |    |-- filename.key       (Client Private Key)
       |    |-- filename.p12       (Client PKCS12 File)
       |    \-- filename.pem       (Client Key+Certificate)
       |
       |-- public/                 (Public Sharable Directory)
       |    |-- certs/             (Client Certificates)
       |    |    \-- filename.pem  (Client Certificate)
       |    |
       |    |-- ca.crt             (Certificate Authority Certficate)
       |    \-- ca.crl             (Certificate Revocation List)
       |
       |-- database                (Log of Certificate Authority activity)
       |-- openssl.cnf             (OpenSSL Configuration File)

```


## Why This Is a Bad Idea(tm)

This is not for production.  Repeat, this is **NOT for production**.

1. You never, ever, ever want to store a CA key unencrypted.
1. You never, ever, ever want to have a password-less CA key.
1. You never, ever, ever want to leave a CA key lying around.

This is intended to be a quick-and-dirty CA management tool for
development or home use.  This container violates the above rules
as a trade-off for a barrier-of-entry to development requiring
certificates.

There is NO security on the CA key (no password, no encryption), and
volumes and containers are just extensions of your file system.

### Then, why did you make it?

I am constantly developing or testing some software that requires a
CA and signed client certificates, and in order to minimize my setup
time, I use this.  I have no expectation that this is secure.
