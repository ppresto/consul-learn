# consul-learn

# LAB 1

## Run echo app
This app will be used as the running service in these labs so be sure this is working.
```
source socatRunEcho.sh
socat_echo

#validate your echo app
docker ps
nc 127.0.0.1 8181
echo hello to me
echo hello to me
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

## Test echo app through web service on port 9191
```
nc 127.0.0.1 9191
Hello Consul Connect
Hello Consul Connect
```

# LAB 2
We previously established a connection by directly running consul connect proxy in developer mode. Realistically, services need to establish connections to dependencies over Connect. Let's register a service "web" that registers "socat" as an upstream dependency in its sidecar registration

## Configure web services
./consul.d/web.json:
```
{
  "service": {
    "name": "web",
    "port": 8080,
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [{
             "destination_name": "socat",
             "local_bind_port": 8181
          }]
        }
      }
    }
  }
}
```

Reload consul Server and terminate previous proxy
```
# Terminate Previous Proxy
# consul connect proxy -service web -upstream socat:9191

# reload
consul reload
```

Start consul connect proxy sidecar-for web without defining upstream.
`consul connect proxy -sidecar-for web`

## Test
```
nc 127.0.0.1 9191
Hello Consul Connect
Hello Consul Connect
```

# LAB 3 - Intentions
Intentions are used to define which services may communicate. Our connections above succeeded because in a development mode agent, the ACL system is "allow all" by default.

## create deny intension and test

```
consul intention create -deny web socat
# Now connection should fail on 9191
nc 127.0.0.1 9191
```
## delete deny intension and Test
```
consul intention delete web socat
```
