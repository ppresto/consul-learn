#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}

echo
lblue "###########################################"
lcyan "  Setup Consul Environment"
lblue "###########################################"
echo
green "Registere a service with Consul and learn how to query it using the HTTP API and DNS \
interface. Add a script based health check to the service.  Since we aren't deploying a \
service in this lab test the results of a failed healthcheck"


echo
cyan "Configure web service"
tee consul.d/web.json <<EOF
{"service":
  {"name": "web",
   "tags": ["rails"],
   "port": 80
  }
}
EOF

# Launch Consul in its own window
echo
cyan "Launch Consul"
p "consul agent -dev -enable-script-checks -config-dir=${DIR}/consul.d"
${DIR}/../launch_iterm_default.sh ${DIR} "consul agent -dev -enable-script-checks -config-dir=${DIR}/consul.d" &

green "Consul logs should show the new service is synced even though we haven't started an actual service:   Synced service \"web\""
echo

echo
cyan "Query Consul's DNS interface to discover our web service"
pe "dig @127.0.0.1 -p 8600 web.service.consul"

echo
cyan "Query DNS for a SRV record to retrieve the address/port for our web service"
pe "dig @127.0.0.1 -p 8600 web.service.consul SRV"

echo
cyan "Use DNS to filter services by tags (TAG.NAME.service.consul)"
pe "dig @127.0.0.1 -p 8600 rails.web.service.consul"

echo
cyan "The HTTP API lists all nodes by default.  Use the API to find just the healthy nodes"
pe "curl 'http://localhost:8500/v1/health/service/web?passing'|jq"

echo
cyan "Add a healthcheck to the web service and reload consul"
rm consul.d/web.json
tee consul.d/web.json <<EOF
{"service":
  {"name": "web",
    "tags": ["rails"],
    "port": 80,
    "check": {
      "args": ["curl", "localhost"],
      "interval": "10s"
    }
  }
}
EOF

echo
pe "consul reload"

echo
cyan "This Healthcheck should be failing since we have no service deployed.  DNS should return only healthy nodes.  Lets verify no IP's are being returned now."
pe "dig @127.0.0.1 -p 8600 web.service.consul"

#Cleanup
echo
cyan "Clean Up"
rm consul.d/web.json
pkill consul
