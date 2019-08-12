FROM grovemountain/consul:1.6.0-beta3
FROM grovemountain/consul-envoy:1.6.0-beta3-v1.11.0
COPY --from=0 /bin/consul /bin/consul
ENTRYPOINT ["dumb-init", "consul", "connect", "envoy"]
