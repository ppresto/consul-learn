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

# Notes:
# Lab 1-3 use port 8181.

echo "socat_echo()"
socat_echo() {
  docker run \
  -d --rm --name socat_echo -p127.0.0.1:8181:8181 \
  alpine/socat tcp-listen:8181,fork exec:"/bin/cat"
}

# Lab 4 - Envoyproxy uses 9090 on network "host"
echo "tcp_echo()"
tcp_echo() {
  docker run \
  -d --rm --network host \
  abrarov/tcp-echo --port 9090
}
