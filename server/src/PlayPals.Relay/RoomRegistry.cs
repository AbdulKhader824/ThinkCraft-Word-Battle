using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;

namespace PlayPals.Relay;

/// <summary>Every open room, by code. Nothing is saved: a restart empties it.</summary>
public sealed class RoomRegistry(RelayOptions options, TimeProvider time)
{
    private readonly ConcurrentDictionary<string, Room> _rooms = new();
    private readonly Lock _openGate = new();

    public int Count => _rooms.Count;

    public Room? Find(string code) => _rooms.GetValueOrDefault(code);

    /// <summary>Opens a new room with the host's code.</summary>
    public (Room? Room, Refusal? Refusal) Open(string code, string game, Peer host)
    {
        Room room;
        lock (_openGate)
        {
            if (_rooms.ContainsKey(code)) return (null, RelayClose.CodeTaken);
            if (_rooms.Count >= options.MaxRooms) return (null, RelayClose.ServerFull);
            room = new Room(code, game, NewKey(), time.GetUtcNow());
            _rooms[code] = room;
        }
        room.AttachHost(host);
        return (room, null);
    }

    /// <summary>
    /// Lets a host whose connection dropped back into their room. The key,
    /// given when the room opened, proves it's the same host.
    /// </summary>
    public (Room? Room, Refusal? Refusal) Resume(string code, string game, string key, Peer host)
    {
        var room = Find(code);
        if (room is null) return (null, RelayClose.NoRoom);
        if (room.Game != game) return (null, RelayClose.WrongGame);
        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.ASCII.GetBytes(room.Key), Encoding.ASCII.GetBytes(key)))
        {
            return (null, RelayClose.WrongKey);
        }
        return room.AttachHost(host) ? (room, null) : (null, RelayClose.NoRoom);
    }

    public void HostGone(Room room, Peer host, bool saidGoodbye)
    {
        if (room.HostGone(host, saidGoodbye, time.GetUtcNow())) Close(room, RelayClose.RoomClosed);
    }

    public void Close(Room room, Refusal why)
    {
        room.Close(why);
        _rooms.TryRemove(new KeyValuePair<string, Room>(room.Code, room));
    }

    /// <summary>Closes rooms that are too old, or whose host hasn't come back in time.</summary>
    public void Sweep()
    {
        var now = time.GetUtcNow();
        foreach (var room in _rooms.Values)
        {
            if (now - room.OpenedAt >= options.MaxRoomAge)
            {
                Close(room, RelayClose.Expired);
            }
            else if (room.HostLostAt is { } lost && now - lost >= options.HostGrace)
            {
                Close(room, RelayClose.HostLeft);
            }
        }
    }

    private static string NewKey() => Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(16));
}
