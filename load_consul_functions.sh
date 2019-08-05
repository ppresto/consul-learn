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

# Get Server IP from consul members command and join to that.
echo "consul-client"
consul-client() {
  docker run \
  --rm -d --name=fox \
  -v ${DIRECTORY}/consul.d/client:/consul/config \
  consul:latest \
  agent -node=client-1 -join=172.17.0.2
}

echo "consul-server"
# Configuration default is /consul/config.  Use Env Var: CONSUL_LOCAL_CONFIG to pass configs.
consul-server() {
  docker run \
  --rm -d -p 8500:8500 -p 8600:8600/udp --name=badger \
  consul:latest \
  agent -server -ui -node=server-1 -bootstrap-expect=1 -client=0.0.0.0
  # Add additional servers to the cluster.
}

echo "consul-cluster"
# Mount ./consul.d volume to enable server configurations hosted there.
# acl.json will lock down servers.  you must create bootstrap token.
consul-cluster() {
  docker run -d -p 8500:8500 -p 8600:8600/udp --name=badger \
    -v ${DIRECTORY}/consul.d/server1:/consul/config \
    -v ${DIRECTORY}/consul_data:/consul/data \
    consul:latest \
    agent -server -ui -node=server-1 -bootstrap-expect=1 -client=0.0.0.0
  # Add additional servers to the cluster.
  sleep 5
  docker run -d --name=badger2 -e CONSUL_BIND_INTERFACE=eth0 \
    -v ${DIRECTORY}/consul.d/server2:/consul/config \
    consul agent -node=server-2 -dev -join=172.17.0.2

  docker run -d --name=badger3 -e CONSUL_BIND_INTERFACE=eth0 \
    -v ${DIRECTORY}/consul.d/server3:/consul/config \
    consul agent -node=server-3 -dev -join=172.17.0.2
}

# You can also add configuration by passing the configuration JSON via environment variable
# CONSUL_LOCAL_CONFIG.

# Expose Consul DNS Server
# -e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' consul -dns-port=53 -recursor=8.8.8.8

# Setting CONSUL_CLIENT_INTERFACE or CONSUL_BIND_INTERFACE on docker run
# is equivalent to passing in the -client flag(documented here) or
# -bind flag(documented here) to Consul on startup.

# Setting the CONSUL_ALLOW_PRIVILEGED_PORTS runs setcap on the Consul binary, allowing it to bind to privileged ports.
# Note that not all Docker storage backends support this feature (notably AUFS).
# docker run -d --net=host -e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' consul -dns-port=53 -recursor=8.8.8.8

consul-server-envVar-EX(){
  docker run \
  --rm -d -p 8500:8500 -p 8600:8600/udp --name=badger \
  -e CONSUL_LOCAL_CONFIG='{
    "datacenter":"us_west",
    "server":true,
    "enable_debug":true
    }' \
  consul:latest \
  agent -server -ui -bootstrap-expect=3 -client=0.0.0.0
}
