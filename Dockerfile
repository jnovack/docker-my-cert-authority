FROM alpine:latest

VOLUME /opt
ENTRYPOINT ["/entrypoint.sh"]

RUN apk update && \
	apk add ca-certificates openssl && \
	rm -rf /var/cache/apk/*

WORKDIR /opt

ADD openssl.tmpl /
ADD entrypoint.sh /