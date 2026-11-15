# Examples

Made-up calls; the numbers aren't a real system's.

| File | What it shows |
|---|---|
| [`trunk-recorder-trunked.json`](trunk-recorder-trunked.json) | Trunk Recorder style, trunked node: the `metadata` file for a patched P25 call (talkgroups 1201 and 1305: filed under 1201 unless the system's patch priority list puts 1305 first) with two transmissions |
| [`trunk-recorder-conventional.json`](trunk-recorder-conventional.json) | Trunk Recorder style, conventional node: `talkgroup` is the slot (2). Sent with `callDuration=9.04` |

The same calls in the form-field style:

```
tg=1201,1305  freq=851.1625  ts=1794590100  callDuration=6.12  src=4801123
tg=2          freq=154.25    ts=1794590200  callDuration=9.04
```

The timestamps are in the past, so sending these as they are gets
`REJECTED-CALL-SKEW-TOO-LONG`: a real call is registered as soon as it ends.
