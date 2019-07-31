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


echo "envoy"
envoy() {
  docker run \
  --rm -d -v${DIRECTORY}/envoy_demo.hcl:/etc/consul/envoy_demo.hcl \
  --network host --name consul-agent consul:latest \
  agent -dev -config-file /etc/consul/envoy_demo.hcl
}
