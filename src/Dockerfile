# Alpine's jsonnet is the C++ implementation, which lacks the -c option, so go-jsonnet is built here.
FROM docker.io/library/golang:1.26-alpine AS go-jsonnet
RUN go install github.com/google/go-jsonnet/cmd/jsonnet@v0.21.0

FROM docker.io/library/alpine:3.22
# Even `cloud-init schema` saves the datasource of the machine it runs on in /run/cloud-init.
# A user without write access there gets two warnings, so anyone may write to it.
RUN apk add --no-cache bash cloud-init libvirt-client libxml2-utils make && mkdir -m 1777 /run/cloud-init
COPY --from=go-jsonnet /go/bin/jsonnet /usr/local/bin/
WORKDIR /src
COPY . .
ENTRYPOINT ["make"]
