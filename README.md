# consul-learn

# LAB 1

## Run echo app
This app will be used as the running service in these labs so be sure this is working.
```
source socatRunEchoContainer.sh
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

# Envoy Proxy - Lab 4
We'll start all containers using Docker's host network mode and will have a total of five containers running.

1. A single Consul server
2. An example TCP echo service as a destination
3. An Envoy sidecar proxy for the echo service
4. An Envoy sidecar proxy for the client service
5. An example client service (netcat)

## Build Envoy image with Consul.
Using the Dockerfile...

`docker build -t consul-envoy .`

## Deploy Consul server
This will load the docker run command as a function "envoy" in your shell you can execute.  This run command will load the envoy_demo.hcl which starts the server and configures both services.
```
source envoydemoRunContainer
envoy

```
## Create services
In order to start a proxy instance, a proxy service definition must exist on the local Consul agent. We'll create one using the sidecar service registration syntax in envoy_demo_hcl.
```
source envoydemoRunContainer.sh
envoy
docker logs -f consul-agent
```

## Run Echo service
```
docker run -d --network host abrarov/tcp-echo --port 9090
```

## Run proxies
For verbose debug add "-- -l debug" to the end of these commands.  The consul connect envoy command here is connecting to the local agent directly via gRPC on port 8502 (avail by default with -dev), getting the proxy configuration from the proxy service registration and generating the required Envoy bootstrap configuration
```
docker run --rm -d --network host --name echo-proxy \
  consul-envoy -sidecar-for echo

docker run --rm -d --network host --name client-proxy \
  consul-envoy -sidecar-for client -admin-bind localhost:19001
```

* "-admin-bind" on the second proxy command is needed because both proxies are running on the host network and so can't bind to the same port for their admin API.
* "consul connect proxy" command is now "consul connect envoy" and in the ENTRYPOINT.

## Run Client Service and test
Lets simulate the service with a simple netcat process that will only talk to the client-sidecar-proxy Envoy instance.
```
docker run -ti --rm --network host gophernet/netcat localhost 9191
Hello consul
Hello consul
```

## Test Authorization
Add a deny rule and test again.  Be sure to terminate the last test.  Open TCP sessions will work.
```
docker run -ti --rm --network host consul:latest intention create -deny client echo
docker run -ti --rm --network host gophernet/netcat localhost 9191
Hello?
```
Lets restore the connection and test again
```
docker run -ti --rm --network host consul:latest intention delete client echo
docker run -ti --rm --network host gophernet/netcat localhost 9191
Hello consul
Hello consul
```
