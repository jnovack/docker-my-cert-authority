FROM alpine:latest

RUN apk update && \
	apk add ca-certificates openssl && \
	rm -rf /var/cache/apk/*

VOLUME /opt
WORKDIR /opt
ENTRYPOINT ["/entrypoint.sh"]

ADD openssl.tmpl /
ADD entrypoint.sh /