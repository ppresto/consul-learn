#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}
source ${DIR}/../echo_app_functions.sh

echo
lblue "###########################################"
lcyan "  Setup Consul Environment"
lblue "###########################################"
echo

# call socat_echo() to start our echo service on 8181
cyan "Start the socat echo service on port 8181"
green "The connect stanza will register a sidecar proxy on a dynamic port.  the proxy process is not automatically started for us."

socat_echo

echo
cyan "Configure the socat service"
tee consul.d/socat.json <<EOF
{
  "service": {
    "name": "socat",
    "port": 8181,
    "connect": { "sidecar_service": {} }
  }
}
EOF

# Launch Consul in its own window
echo
cyan "Launch Consul and load consul.d/"
p "consul agent -dev -enable-script-checks -config-dir=${DIR}/consul.d"
${DIR}/../launch_iterm_default.sh ${DIR} "consul agent -dev -enable-script-checks -config-dir=${DIR}/consul.d" &

echo
cyan "Start the proxy process in another terminal window"
p "consul connect proxy -sidecar-for socat"
${DIR}/../launch_iterm_default.sh ${DIR} "consul connect proxy -sidecar-for socat" &

echo
cyan "Next, register a dependent downstream service and proxy called \"web\""
green "The web service will listen on 8080"
green "Bind upstream service \"socat\" to port 9191 to establish a mTLS connection"
echo
tee consul.d/web.json <<EOF
{"service": {
    "name": "web",
    "port": 8080,
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [{
             "destination_name": "socat",
             "local_bind_port": 9191
          }]
        }
      }
    }
  }
}
EOF

echo
cyan "Reload Consul"
pe "consul reload"

echo 
cyan "verify we can't connect to the socat service on 9191"
p "nc 127.0.0.1 9191"
${DIR}/../launch_iterm_default.sh ${DIR} "nc 127.0.0.1 9191"

echo
cyan "start the web proxy using the sidecar configuration"
p "consul connect proxy -sidecar-for web"
${DIR}/../launch_iterm_default.sh ${DIR} "consul connect proxy -sidecar-for web" &


echo
cyan "Verify we can connect to port 9191 again"
p "nc 127.0.0.1 9191"
${DIR}/../launch_iterm_default.sh ${DIR} "nc 127.0.0.1 9191"

echo
cyan "Control service communication with intentions"
pe "consul intention create -deny web socat"

echo 
cyan "verify we can't connect to the socat service on 9191"
p "nc 127.0.0.1 9191"
${DIR}/../launch_iterm_default.sh ${DIR} "nc 127.0.0.1 9191"

echo
cyan "Control service communication with intentions"
pe "consul intention delete web socat"

echo
cyan "Verify we can connect to port 9191 again"
p "nc 127.0.0.1 9191"
${DIR}/../launch_iterm_default.sh ${DIR} "nc 127.0.0.1 9191"

echo
cyan "Clean Up"
p
rm consul.d/socat.json consul.d/web.json 
pkill consul
docker kill socat_echo