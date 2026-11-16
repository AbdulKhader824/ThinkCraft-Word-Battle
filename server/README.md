# PlayPals relay

Lets PlayPals rooms be played over the internet ("Friends online"). The
game still runs on the host's phone, as in nearby rooms; this server only
passes messages between the host's phone and the guests' phones, grouped by
room code. It has no database, no accounts and no game rules, and it keeps
nothing: a restart empties it.

## How phones talk to it

| Address | Who | What happens |
| --- | --- | --- |
| `/host?code=ABC234&game=word_battle` | The host's phone | Opens a room. First message: `o:<key>:` |
| `/host?code=...&game=...&key=<key>` | The same host after a dropped connection | Back in the room. First message: `o:<key>:<guest ids>` |
| `/join?code=ABC234&game=word_battle` | A guest's phone | Joins. First message: `ready` |

Frames between the relay and the host:

| Direction | Frame | Meaning |
| --- | --- | --- |
| to the host | `j:<id>` | A guest joined (ids count up from 1 in each room) |
| to the host | `l:<id>` | A guest's connection ended |
| to the host | `m:<id>:<message>` | A guest's message |
| from the host | `m:<id>:<message>` | A message for one guest |
| from the host | `k:<id>` | Close that guest's connection |

Guests send and receive the game's messages as they are.

## Limits

| Limit | Value |
| --- | --- |
| Rooms on the server | 300 |
| Guest connections per room | 10 (rooms hold 8 players; the host's phone turns away the rest, and the extra room is for phones reconnecting) |
| Message size | 64 KB; bigger closes the connection (1009) |
| Room age | 2 hours |
| Host's connection drops | The room waits 20 seconds for the host to come back with its key; guests' messages meanwhile are dropped. A host who closes properly closes the room at once |
| Slow phone | Cut off after 256 waiting messages, or 10 seconds on one send |
| Connection checks | A ping every 15 seconds; no answer within 15 more ends the connection |

## Close codes

Just before closing, the relay also sends the code as a text frame,
`x:<code>` (for example `x:4003`), because some hosts' proxies (Render's)
drop WebSocket close frames. The app treats that frame as the close.

| Code | Reason |
| --- | --- |
| 1000 | `room closed` or `removed` (by the host) |
| 4000 | `bad request` (code or game name not valid) |
| 4001 | `code taken` (the app picks another code) |
| 4002 | `server full` |
| 4003 | `no room` |
| 4004 | `room full` |
| 4005 | `wrong game` |
| 4006 | `wrong key` |
| 4007 | `room expired` |
| 4008 | `host left` (didn't come back in time) |
| 4009 | `replaced` (the host connected again elsewhere) |

## Commands

Needs the .NET 10 SDK.

```powershell
dotnet test                                   # from server/
dotnet run --project src/PlayPals.Relay       # listens on http://0.0.0.0:8080
docker build -t playpals-relay .              # the image Render runs
```

It listens on `$PORT` when that is set (Render sets it), otherwise on 8080.
