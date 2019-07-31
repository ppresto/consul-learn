# consul-learn

# Getting Started

## Run echo app

```
source socatRunEcho.sh
socat_echo
```

## Start Server

`consul agent -dev -ui -node presto-macbook -config-dir=./consul.d`

## Start Consul connect sidecar-proxy for socat in new terminal/tab.

`consul connect proxy -sidecar-for socat`
You will see Errors until you start a consul connect proxy process in another terminal
agent: Check "service:socat-sidecar-proxy:1" socket connection failed: … refused

## Start service proxy
Configure and run a local proxy that represents a service called web.  It will have an upstream dependency on “socat”.  All TCP connections to 9191 will perform service discovery for a connect-capable “socat” endpoint and establish a mutual TLS connection identifying as the service “web”.  Connection between proxies is now encrypted and authorized.  Local connections to/from the proxy are unencrypted but in prod these will be loopback-only connections.
`consul connect proxy -service web -upstream socat:9191`

# Test echo app through web service on port 9191
```
nc 127.0.0.1 9191
Hello Consul Connect
```
