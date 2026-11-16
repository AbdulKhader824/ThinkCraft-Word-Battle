using System.Net.WebSockets;

namespace PlayPals.Relay;

/// <summary>Why the relay closed a phone's connection, sent as the WebSocket close code.</summary>
public sealed record Refusal(int Code, string Reason)
{
    public WebSocketCloseStatus Status => (WebSocketCloseStatus)Code;
}

/// <summary>
/// Close codes the app understands. 4000-4999 are free for apps to use;
/// the app turns each into a friendly message.
/// </summary>
public static class RelayClose
{
    public static readonly Refusal BadRequest = new(4000, "bad request");
    public static readonly Refusal CodeTaken = new(4001, "code taken");
    public static readonly Refusal ServerFull = new(4002, "server full");
    public static readonly Refusal NoRoom = new(4003, "no room");
    public static readonly Refusal RoomFull = new(4004, "room full");
    public static readonly Refusal WrongGame = new(4005, "wrong game");
    public static readonly Refusal WrongKey = new(4006, "wrong key");
    public static readonly Refusal Expired = new(4007, "room expired");
    public static readonly Refusal HostLeft = new(4008, "host left");
    public static readonly Refusal Replaced = new(4009, "replaced");

    public static readonly Refusal RoomClosed = new(1000, "room closed");
    public static readonly Refusal Removed = new(1000, "removed");
    public static readonly Refusal TooSlow = new(1008, "too slow");
    public static readonly Refusal TextOnly = new(1003, "text only");
    public static readonly Refusal TooBig = new(1009, "message too big");
}
