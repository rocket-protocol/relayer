FROM alpine:3.12
RUN apk add -U --no-cache ca-certificates

WORKDIR /data
ENV HOME=/data
COPY ./build/rly /usr/bin/rly

["rly", "start"]