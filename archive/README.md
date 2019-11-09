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

# Envoy Proxy - Lab 4 (Requires Docker Containers)
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

# Lab 5: Containers - Run Consul Server/Agent

## Start Server and Client nodes
Start the consul server with container name: badger.  Mount /consul/config volume to pass configurations.  We will need to reload consul.
```
source load_consul_functions.sh
consul-server
```

Discover the Server IP address using consul members command inside server container
```
docker exec badger consul members
```

Deploy client and join cluster
```
# If IP isn't 172.17.0.2 then update the client.sh -join <IP>
source load_consul_functions.sh
consul-client

# verify client joined cluster
docker logs fox
docker exec fox consul members  

# export Env variable to use local consul binary.
# Note: use localhost if using container that's exporting port to host network
export CONSUL_HTTP_ADDR=localhost:8500
consul members
```

## Register service
Use hashi counting service.
```
docker pull hashicorp/counting-service:0.0.2
docker run -d -p 9001:9001 --name=weasel hashicorp/counting-service:0.0.2
# Test at http://localhost:9001
```

Add service definition to the client
```
docker exec fox /bin/sh -c "echo '{\"service\": {\"name\": \"counting\", \"tags\": [\"go\"], \"port\": 9001}}' >> /consul/config/counting.json"

# Reload Client and verify
docker exec fox consul reload
docker logs fox

# Discover Service in DNS
dig @127.0.0.1 -p 8600 counting.service.consul
```

## Backup data
```
docker exec badger consul snapshot save backup.snap
# if persistant volume isn't set copy it.
docker cp badger:backup.snap ./
```

## Enable ACLs on servers
./consul.d/acl.json will enable ACL's.  Look for acl messages in logs. The consul CLI on servers will not work until fully setup.
```
cp ./acl/acl.json ./consul.d/acl.json
# Restart cluster with volume mounted.
docker logs badger | grep -i acl
docker logs badger2 | grep -i acl
docker logs badger3 | grep -i acl
```
### Create Bootstrap Token
```
docker exec badger consul acl bootstrap
# save SecretID: d2c38aac-7d5b-a6b0-ceda-bc1e6f6242fe

## list cluster members with the Token
docker exec badger consul members -token "d2c38aac-7d5b-a6b0-ceda-bc1e6f6242fe"
```
### Export Token for better security and simplicity
```
export CONSUL_HTTP_TOKEN=d2c38aac-7d5b-a6b0-ceda-bc1e6f6242fe
export CONSUL_HTTP_ADDR=localhost:8500
consul members
```

### Create Policy (dev only) for Token
```
consul acl policy create -name "agent-token" -description "Agent Token Policy" -rules @acl/agent-policy.hcl
ID:           60c048f0-610b-b83d-9623-3196e6d3594b
Name:         agent-token
Description:  Agent Token Policy
Datacenters:
Rules:
node_prefix "" {
   policy = "write"
}
service_prefix "" {
   policy = "read"
}
```
### Create an Agent Token with the policy
```
consul acl token create -description "Agent Token" -policy-name "agent-token"
# save SecretID: 2d8d24b0-e77c-b3f2-bc24-26c5a757348f
```

### Add the Agent Token to all the Servers
Update the configuration file with the agent token.
```
# reload all consul Servers with updated acl config
cp ./acl/acl_token.json ./consul.d/acl.json
docker exec badger consul reload -token 07b96db4-44dc-3ab1-6f92-17a5b4feb9e7
docker exec badger2 consul reload -token 07b96db4-44dc-3ab1-6f92-17a5b4feb9e7
docker exec badger3 consul reload -token 07b96db4-44dc-3ab1-6f92-17a5b4feb9e7

# We shouldn't see the coordinate warning in the servers logs.  Look for "Node info in sync".
docker logs badger | grep "Node info in sync"
```

### Test ACL configurations via API before adding ACL's to clients  
Look at TaggedAddress. it should not be "null"!
```
curl http://127.0.0.1:8500/v1/catalog/nodes -H 'x-consul-token: 07b96db4-44dc-3ab1-6f92-17a5b4feb9e7'
```

### Troubleshooting (Reset ACL system)
```
# If issues aren't resolvable or you misplaced the bootsrap token reset the ACL system.
# Get Index # by rerunning bootstrap command. Ex: 13
consul acl bootstrap
echo 13 >> <data-dir>/acl-bootstrap-reset
```

### Add ACL config to consul clients
We can use the same token since we configured it to match any prefix.  We can start up a new client or reload with the current acl.json.  Check the logs for any errors.
```
consul-client   #alias from load_consul_functions.sh

# full command
docker run \
--rm -d --name=fox \
-v ${DIRECTORY}/consul.d:/consul/config \
consul:latest \
agent -node=client-1 -join=172.17.0.2
```
Verify client is properly configured using the API catalog endpoint.

`url http://127.0.0.1:8500/v1/catalog/nodes -H 'x-consul-token: 07b96db4-44dc-3ab1-6f92-17a5b4feb9e7'`

### Add Anonymous token to read members without passing token.
```
#create policy
consul acl policy create -name 'list-all-nodes' -rules 'node_prefix "" { policy = "read" }'

#create token for anonymous
consul acl token update -id 00000000-0000-0000-0000-000000000002 -policy-name list-all-nodes -description "Anonymous Token - Can List Nodes"

#validate consul
unset CONSUL_HTTP_TOKEN
consul members
#validate dns (get NXDOMAIN error)
dig @127.0.0.1 -p 8600 consul.service.consul
```

### Update Anonymous token's policy to read consul services
```
#create Policy
consul acl policy create -name 'service-consul-read' -rules 'service "consul" { policy = "read" }'

#merge policy with anonymous
consul acl token update -id 00000000-0000-0000-0000-000000000002 --merge-policies -description "Anonymous Token - Can List Nodes" -policy-name service-consul-read

#test dns query (noerror)
dig @127.0.0.1 -p 8600 consul.service.consul
```

### Create UI Token
```
consul acl policy create -name "ui-policy" \
                           -description "Necessary permissions for UI functionality" \
                           -rules 'key_prefix"" { policy = "write" } node_prefix "" { policy = "read" } service_prefix "" { policy = "read" }'

consul acl token create -description "UI Token" -policy-name "ui-policy"
```
Test in UI : http://localhost:8500/ui

## TLS

### Create CA pub/private keys
```
cd ./tls
consul tls ca create
```

### Create Server cert
```
cd ./tls
# repeat cert creation and copy for each node #
consul tls cert create -server
cp server*-1*pem consul.d/server1
cp consul-agent-ca.pe, consul.d/server1
```

Verify the consul.d mount point is updated to include the new server# directory with keys and tls configuration.
```
# reload or restart each server
docker stop badger
docker start badger
```
