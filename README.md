# Broadcastify Calls upload API

How a recorder (Trunk Recorder, SDRTrunk, Trunking Recorder, VoxCall, or your own) sends calls to
[Broadcastify Calls](https://www.broadcastify.com/calls/), and the process for getting a node set
up to send them.

- **[The specification](upload-api.md)**: the process, registering a call (the three upload
  styles, patches, slots), timing, every answer and what to do about it, uploading the audio.
- **[Examples](examples/)**: Trunk Recorder call files, and the same calls as form fields.
- **[`scripts/test-credentials.sh`](scripts/test-credentials.sh)**: checks a node's system ID and
  API key. Records nothing.
- **[`scripts/upload-call.sh`](scripts/upload-call.sh)**: sends one call the way a form-field-style
  recorder does. It sends a real call to the node.

## In short

1. Apply at <https://www.broadcastify.com/apply/calls>. The approval email has the node's system
   ID and API key.
2. For each call, as soon as it ends: `POST https://api.broadcastify.com/call-upload`
   (`multipart/form-data`) with the node's credentials and the call's fields.
3. On `0 <url>`, `PUT` the audio to `<url>` within 180 s, with `Content-Type: audio/aac` (M4A) or
   `audio/mpeg` (MP3).

Keep the recorder's clock synchronized: a call more than 15 s off is refused.

Recorders can also report how well they hear their system: see
[node health reports](https://github.com/blantonl/bcfy-calls-node-health).

## Questions and changes

Questions about a node: <support@broadcastify.com>. Corrections to the spec: an issue or a pull
request here.

## License

MIT: see [LICENSE](LICENSE). It covers the spec, the examples and the scripts.
