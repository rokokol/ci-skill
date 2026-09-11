# A document about a CLI whose flags are bare words

`tool search query=… limit=10` finds notes, and `search format=json` prints them as JSON; `tool backlinks file=Garden total vault=Work` counts the links into one

```sh
$ tool backlinks file="My Note" total | head -n 3
$ tool help search
```

A misspelt parameter is ignored in silence: `tool backlinks fil=Garden total` answers for the open file <!-- check-interface: allow -->

`graph related` is some other tool's command, and `tags agree with the count` is output, not a call
