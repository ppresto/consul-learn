# consul-learn

## consul-template
Use consul-template to read a key/value in consul and automatically write it to the demo app.    Write a simple template
```
cd consul-template
vi in.tpl:

{{ key "monty"}}
```

run consul-template once and write the output to the location your application is reading.
```
consul-template \
-consul-addr "localhost:8500" \
-template "in.tpl:gateway/holy_grail.json" -once \
-vault-renew-token=false
```

create the key/value.  Include only 1 stanza from the month_python.json.  The consul-template should be running and looking for this one time change.  Once it sees the write it will create/update the target location : gateway/holy_grail.json.

```
consul kv put monty @monty_python_1stanzaONLY.json
or
cat monty_python.json | head -7 | consul kv put monty -
```

You should see a new file created/updated at ./gateway/holy_grail.json.  consul-template can read consul kv and update services accordingly.  This is only a simple example.

## Layer 4 Connect
