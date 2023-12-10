FROM registry.k8s.io/ingress-nginx/e2e-test-runner:v20231011-8b53cabe0@sha256:ed0dad805c635e66469b4ac376010eebdd0b3fe62d753f58db1632d6f12f451d AS BASE

FROM alpine:3.19

RUN apk update \
	&& apk upgrade && apk add -U --no-cache \
  ca-certificates \
  bash \
  tzdata \
  libc6-compat \
  openssl

COPY --from=BASE /go/bin/ginkgo /usr/local/bin/
COPY --from=BASE /usr/local/bin/helm /usr/local/bin/
COPY --from=BASE /usr/local/bin/kubectl /usr/local/bin/
COPY --from=BASE /usr/bin/cfssl /usr/local/bin/
COPY --from=BASE /usr/bin/cfssljson /usr/local/bin/

COPY . /

CMD [ "/e2e.sh" ]
