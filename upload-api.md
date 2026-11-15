# Broadcastify Calls upload API

**Version 1.** How a recorder sends calls to Broadcastify Calls: one HTTP request per call to
register it, then the call's audio uploaded to the address that request answers with.

## Terms

- **Recorder:** the program that receives and records calls (Trunk Recorder, Trunk Recorder Pro,
  SDRTrunk, Trunking Recorder, VoxCall, ...).
- **Node:** what Broadcastify knows one feed of calls by: a **system ID** with its **API key**.
  Each node is set up for one radio system (trunked) or a set of channels (conventional), and for
  one **upload style**, chosen from the recorder it runs.
- **Slot:** on a node that uses them, a number standing for one of its channels: a conventional
  frequency, or a talkgroup. Broadcastify maps each slot to its database entry.

## The process

1. **Get the recorder running first.** Install and configure it, and make sure it is receiving
   calls.
2. **Apply** at <https://www.broadcastify.com/apply/calls>: which recorder, and which trunked
   system or conventional channels the calls come from.
3. **Approval.** The approval email has the node's **system ID** and its **API key**. The node is
   set up for the recorder's upload style and, for conventional channels, with its slots. The
   node's management page, <https://www.broadcastify.com/calls/manage/>, lists its slots and what
   each one is.
4. **Configure the recorder** with the endpoint, system ID and API key. Check them with
   `test=1` ([below](#checking-credentials)).
5. **Go live.** Calls appear on Broadcastify Calls as they're accepted.
   <https://www.broadcastify.com/calls/status/> shows the service's status.
6. **Keep it healthy.**
   - Keep the recorder's clock right (NTP). A call more than 15 s off is refused
     ([Timing](#timing)).
   - The node's owner is emailed when the node stops sending calls, and again when it's back.
   - A node that sends no calls for 15 days is removed. Ask support to restore it.
   - Recorders can also send [node health reports](https://github.com/blantonl/bcfy-calls-node-health)
     on how well they hear the system.

There is no separate development endpoint: credentials and calls are production from the start.
Changes to a node (more slots, another recorder, another system) and questions:
<support@broadcastify.com>.

**Writing a new recorder?** Use the [form-field style](#form-field-style); ask support to set
your node to it ("Generic").

## Registering a call

```
POST https://api.broadcastify.com/call-upload
Content-Type: multipart/form-data
```

An RFC 7578 `multipart/form-data` body. Every request has:

| Field | Type | Meaning |
|---|---|---|
| `systemId` | int | The node's system ID |
| `apiKey` | string | The node's API key: the one issued for this node |
| `enc` | string | Optional. The audio's format: `m4a` (default) or `mp3` |
| `srcId_alias` | string | Optional, trunked only. The source radio's over-the-air alias, at most 16 characters (longer is cut) |

The rest depends on the node's **upload style**, which Broadcastify sets for the node from the
recorder it runs. A recorder sends the fields of its own style.

### Trunk Recorder style

Trunk Recorder and Trunk Recorder Pro. The call's Trunk Recorder JSON goes as a file field:

| Field | Meaning |
|---|---|
| `metadata` | The call's Trunk Recorder JSON, as a file part ([example](examples/trunk-recorder-trunked.json)) |
| `callDuration` | Conventional nodes only: the call's length, seconds |

From the JSON, Broadcastify reads:

| Key | Meaning |
|---|---|
| `freq` | Frequency, Hz |
| `start_time`, `stop_time` | Unix seconds. On a conventional node the start is `stop_time − callDuration` |
| `talkgroup` | Trunked: the talkgroup, decimal. Conventional: the **slot** |
| `patched_talkgroups` | Optional: the talkgroups of a patch ([Patches](#patches)) |
| `srcList` | Required, may be empty: the transmissions; the first one's `src` is the call's source radio |

### Form-field style

SDRTrunk, Trunking Recorder, and new recorders ("Generic").

| Field | Type | Meaning |
|---|---|---|
| `tg` | string | Trunked: the talkgroup, decimal, or a patch's talkgroups separated by commas ([Patches](#patches)). Conventional: the **slot** |
| `freq` | float | Frequency, MHz |
| `ts` | int | Unix seconds the call started |
| `callDuration` | float | The call's length, seconds |
| `src` | int | Optional: the source radio's ID, decimal |

`tg`, `freq`, `ts` and `callDuration` are required (`NO-TG-SENT`, `NO-FREQ-SENT`,
`NO-TIMESTAMP-SENT`, `NO-CALL-DURATION-SENT` otherwise).

### Slot style

VoxCall and Vox Recorder. The fields of the form-field style, but `tg` is always a **slot**, on
trunked nodes too (where each slot stands for a talkgroup). Timing is looser: ±90 s instead of
±15 s.

### Patches

A patched call is filed under one talkgroup of the patch. Send all of them (form-field style:
`tg=101,205,330`; Trunk Recorder style: `patched_talkgroups`). Broadcastify files the call under
the first one that is on the system's patch priority list, if the system has one, and otherwise
under the first one sent: so send the patch's main talkgroup first.

### Slots

On a conventional node (any style) and on a slot-style node, `tg` (or the metadata's `talkgroup`)
is a slot number, not a frequency or talkgroup. The node's slots are set when it's approved and
listed on its management page. A slot the node doesn't have is refused with
`No-Freq-Table-Entry-For-Upload` (conventional) or `No-Tg-Table-Entry-For-Upload` (trunked).

## Timing

Broadcastify compares the call's **end** (start + length) with its own clock when the request
arrives. More than **15 s** either way (90 s for the slot style) and the call is refused:

```
1 REJECTED-CALL-SKEW-TOO-LONG-<seconds>-See:https://www.broadcastify.com/skew
```

So: keep the clock synchronized (NTP), and register each call as soon as it ends, not in batches.

## The answer

Always a plain-text body: a code, a space, and the rest. Read the body whatever the HTTP status:
most answers come with `200`, a few with `403` or `500`.

| Body | Meaning | The recorder |
|---|---|---|
| `0 <url>` | Accepted | Upload the audio to `<url>` now ([below](#uploading-the-audio)) |
| `1 SKIPPED---ALREADY-RECEIVED-THIS-CALL` | Broadcastify already has this call, from this node or another one hearing the same system | Nothing: don't upload. Not an error |
| `1 Skip-Unit-To-Unit-CT3`, `1 Skip-Unit-To-Unit-CT4` | A unit-to-unit (private) call (P25 or EDACS talkgroup above 65535): not taken | Nothing. Better: don't send them |
| `1 REJECTED-CALL-SKEW-TOO-LONG-…` | Outside the time window ([Timing](#timing)) | Check the clock and how soon calls are sent. Don't retry the call |
| `1 No-Freq-Table-Entry-For-Upload`, `1 No-Tg-Table-Entry-For-Upload` | The slot isn't on the node | Check the slot numbers against the node's page |
| `1 NO-TG-SENT`, `1 NO-FREQ-SENT`, `1 NO-TIMESTAMP-SENT`, `1 NO-CALL-DURATION-SENT`, `1 SLOT_ENTRY_ERROR` | A required field is missing, or the slot isn't a number | Fix the request |
| `1 NO-TRUNK-RECORDER-METADATA-FILE-SENT`, `1 TRUNK-RECORDER-METADATA-ERROR` (HTTP 500) | Trunk Recorder style: no `metadata` part, or it isn't JSON | Fix the request |
| `1 ERROR: Call Duration Must be Specified for Conventional Calls` (HTTP 500) | Trunk Recorder style, conventional node: no `callDuration` | Fix the request |
| `1 INVALID-ENCODE-TYPE` | `enc` isn't `m4a` or `mp3` | Fix the request |
| `1 NO-SYSTEM-ID-SPECIFIED`, `1 INVALID-SYSTEM-ID` | No such node | Fix the settings |
| `1 No API Key Specified` (HTTP 403), `1 Invalid-API-Key`, `1 API-Key-Access-Denied`, `1 API-Key-Not-Authorized-For-System` | The key is missing, unknown, another account's, or not this node's | Fix the settings |
| `1 Uploads-not-enabled-for-this-system` | The node is turned off | Ask support |
| `1 Uploads-disabled-systemwide` | Broadcastify isn't taking calls for now | Try later |
| `1 Nothing-Sent` | Empty request | Fix the request |
| Anything else, `5xx`, or no answer | Not taken | One retry is fine while the call is still within the time window. A retry that answers `SKIPPED---ALREADY-RECEIVED-THIS-CALL` means the first attempt was taken |

A recorder should stop sending and say so on the credential and node answers: retrying won't
help until its settings change.

## Uploading the audio

`PUT` the call's audio file to the URL from the `0 <url>` answer:

| | |
|---|---|
| Body | The audio file, as is |
| `Content-Type` | `audio/aac` for `m4a`, `audio/mpeg` for `mp3`: exactly the type of the `enc` sent. The URL is signed for it |
| When | Straight away: the URL expires **30 s** after it's issued |
| Again | Never: each URL is for one call. Don't keep or reuse it |

### Audio format

| Format | Settings |
|---|---|
| M4A (AAC), preferred | About 32 kb/s, low-pass 18 kHz (for example `fdkaac` or `libfdk_aac`) |
| MP3 | Mono, 22,050 Hz, constant bit rate, 32 kb/s or 16 kb/s |

## Checking credentials

Send `test=1` with `systemId` and `apiKey` (no call fields). Good credentials for an enabled node
answer `OK`; anything else answers as in [The answer](#the-answer). Nothing is recorded, and it
doesn't count as the node sending calls.

```bash
curl -s -F systemId=1234 -F apiKey=YOUR-KEY -F test=1 https://api.broadcastify.com/call-upload
```

## Duplicates

Several nodes often hear the same system. Broadcastify keeps one copy of each call (a call is its
talkgroup, or slot, and its start time) and answers the others
`SKIPPED---ALREADY-RECEIVED-THIS-CALL`. Which node's copy is kept is Broadcastify's choice and can
change over time; a node with a correct clock that sends calls promptly is the one that tends to
be kept. Registering the same call again within 90 s gets the same answer.

## Versions

| Date | Change |
|---|---|
| 2026-11-15 | Version 1: written down from the live service. No change to the service |
