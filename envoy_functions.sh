#!/bin/bash
DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#Description
# socat is a decades-old Unix utility and our process is configured to only
# accept a basic TCP connection. It has no concept of encryption, the TLS protocol,
# etc. This can be representative of an existing service in your datacenter
# such as a database, backend web service, etc.

# Use socat to start echo service on port 8181
# Test using 'nc 127.0.0.1 8181' <enter>
# "any text you enter now should be echoed back to you"


echo "consul_envoy"
consul_envoy() {
  docker run \
  --rm -d -v${DIRECTORY}/consul.d/envoy/:/consul/config \
  --network host --name consul-envoy \
  consul:latest agent -dev
}

# Lab 4 - Envoyproxy uses 9090 on network "host"
echo "echo_app"
echo_app() {
  docker run -d --rm --network host --name echo_app \
  abrarov/tcp-echo --port 9090
}

echo "sidecar-echo"
sidecar-echo() {
  docker run --rm -d --network host --name echo-proxy \
  consul-envoy -sidecar-for echo
}

echo "sidecar-client"
sidecar-client() {
  docker run --rm -d --network host --name client-proxy \
  consul-envoy -sidecar-for client -admin-bind localhost:19001
}
