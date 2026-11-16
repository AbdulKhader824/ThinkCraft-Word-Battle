using System.Text.RegularExpressions;

namespace PlayPals.Relay;

/// <summary>The two WebSocket addresses: <c>/host</c> opens a room, <c>/join</c> joins one.</summary>
public static partial class RelayEndpoints
{
    /// <summary>Room codes: 6 characters from A-Z and 2-9, without I, O, 0 or 1.</summary>
    [GeneratedRegex("^[A-HJ-NP-Z2-9]{6}$")]
    private static partial Regex CodePattern();

    [GeneratedRegex("^[a-z_]{1,32}$")]
    private static partial Regex GamePattern();

    [GeneratedRegex("^[0-9a-f]{32}$")]
    private static partial Regex KeyPattern();

    /// <summary>
    /// <c>/host?code=ABC234&amp;game=word_battle</c> opens a room;
    /// adding <c>&amp;key=...</c> comes back to it after a drop.
    /// </summary>
    public static async Task HostAsync(HttpContext context, RoomRegistry rooms, RelayOptions options)
    {
        if (!context.WebSockets.IsWebSocketRequest)
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            return;
        }
        var code = context.Request.Query["code"].ToString();
        var game = context.Request.Query["game"].ToString();
        var key = context.Request.Query["key"].ToString();

        using var socket = await context.WebSockets.AcceptWebSocketAsync();
        var host = new Peer(socket, options);
        var (room, refusal) =
            !IsValid(code, game) || (key.Length > 0 && !KeyPattern().IsMatch(key))
                ? (null, RelayClose.BadRequest)
                : key.Length == 0
                    ? rooms.Open(code, game, host)
                    : rooms.Resume(code, game, key, host);

        if (room is null)
        {
            await RefuseAsync(host, refusal!, context.RequestAborted);
            return;
        }
        var saidGoodbye = await host.RunAsync(
            frame => room.FromHost(host, frame), context.RequestAborted);
        rooms.HostGone(room, host, saidGoodbye);
    }

    /// <summary><c>/join?code=ABC234&amp;game=word_battle</c> joins a room.</summary>
    public static async Task JoinAsync(HttpContext context, RoomRegistry rooms, RelayOptions options)
    {
        if (!context.WebSockets.IsWebSocketRequest)
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            return;
        }
        var code = context.Request.Query["code"].ToString();
        var game = context.Request.Query["game"].ToString();

        using var socket = await context.WebSockets.AcceptWebSocketAsync();
        var guest = new Peer(socket, options);
        if (!IsValid(code, game))
        {
            await RefuseAsync(guest, RelayClose.BadRequest, context.RequestAborted);
            return;
        }
        var room = rooms.Find(code);
        if (room is null || room.IsClosed)
        {
            await RefuseAsync(guest, RelayClose.NoRoom, context.RequestAborted);
            return;
        }
        if (room.Game != game)
        {
            await RefuseAsync(guest, RelayClose.WrongGame, context.RequestAborted);
            return;
        }
        if (room.AddGuest(guest, options.MaxGuests) is not { } id)
        {
            await RefuseAsync(guest, RelayClose.RoomFull, context.RequestAborted);
            return;
        }
        await guest.RunAsync(message => room.FromGuest(id, message), context.RequestAborted);
        room.GuestGone(id, guest);
    }

    private static bool IsValid(string code, string game) =>
        CodePattern().IsMatch(code) && GamePattern().IsMatch(game);

    private static Task RefuseAsync(Peer peer, Refusal why, CancellationToken cancel)
    {
        peer.Close(why);
        return peer.RunAsync(_ => { }, cancel);
    }
}
