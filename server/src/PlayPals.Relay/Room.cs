namespace PlayPals.Relay;

/// <summary>
/// One room: the host's phone and the guests' phones joined to it. The
/// relay only passes messages along; the game itself runs on the host's
/// phone, so the relay never reads them.
/// </summary>
/// <remarks>
/// Frames between the relay and the host:
/// <list type="bullet">
/// <item>to the host: <c>o:&lt;key&gt;:&lt;guest ids&gt;</c> (open, or back after a drop),
/// <c>j:&lt;id&gt;</c> (a guest joined), <c>l:&lt;id&gt;</c> (a guest left) and
/// <c>m:&lt;id&gt;:&lt;message&gt;</c> (a guest's message)</item>
/// <item>from the host: <c>m:&lt;id&gt;:&lt;message&gt;</c> (to one guest) and
/// <c>k:&lt;id&gt;</c> (close that guest's connection)</item>
/// </list>
/// Guests get <c>ready</c> once joined, then the host's messages as they are.
/// </remarks>
public sealed class Room(string code, string game, string key, DateTimeOffset openedAt)
{
    private readonly Lock _gate = new();
    private readonly Dictionary<int, Peer> _guests = [];
    private Peer? _host;
    private int _lastGuestId;
    private bool _closed;

    public string Code { get; } = code;
    public string Game { get; } = game;
    public string Key { get; } = key;
    public DateTimeOffset OpenedAt { get; } = openedAt;

    /// <summary>When the host's connection dropped, while waiting for it to come back.</summary>
    public DateTimeOffset? HostLostAt { get; private set; }

    public bool IsClosed
    {
        get
        {
            lock (_gate) return _closed;
        }
    }

    public int GuestCount
    {
        get
        {
            lock (_gate) return _guests.Count;
        }
    }

    /// <summary>Gives the room its host, at the start or after a drop. False if it has closed.</summary>
    public bool AttachHost(Peer host)
    {
        lock (_gate)
        {
            if (_closed) return false;
            var old = _host;
            _host = host;
            HostLostAt = null;
            host.Send($"o:{Key}:{string.Join(',', _guests.Keys)}");
            old?.Close(RelayClose.Replaced);
            return true;
        }
    }

    /// <summary>
    /// The host's connection ended. Returns true when the room should close
    /// now; a dropped host gets a while to come back instead.
    /// </summary>
    public bool HostGone(Peer host, bool saidGoodbye, DateTimeOffset now)
    {
        lock (_gate)
        {
            if (_host != host) return false;
            _host = null;
            if (saidGoodbye) return true;
            HostLostAt = now;
            return false;
        }
    }

    /// <summary>Adds a guest and returns their id, or null when the room is full or closed.</summary>
    public int? AddGuest(Peer guest, int maxGuests)
    {
        lock (_gate)
        {
            if (_closed || _guests.Count >= maxGuests) return null;
            var id = ++_lastGuestId;
            _guests[id] = guest;
            guest.Send("ready");
            _host?.Send($"j:{id}");
            return id;
        }
    }

    public void GuestGone(int id, Peer guest)
    {
        lock (_gate)
        {
            if (!_guests.TryGetValue(id, out var current) || current != guest) return;
            _guests.Remove(id);
            _host?.Send($"l:{id}");
        }
    }

    /// <summary>A guest's message, passed to the host. Dropped while the host is away.</summary>
    public void FromGuest(int id, string message)
    {
        lock (_gate)
        {
            if (_guests.ContainsKey(id)) _host?.Send($"m:{id}:{message}");
        }
    }

    public void FromHost(Peer host, string frame)
    {
        lock (_gate)
        {
            if (_host != host || frame.Length < 3 || frame[1] != ':') return;
            var rest = frame.AsSpan(2);
            switch (frame[0])
            {
                case 'm':
                    var colon = rest.IndexOf(':');
                    if (colon > 0 && int.TryParse(rest[..colon], out var to)
                        && _guests.TryGetValue(to, out var guest))
                    {
                        guest.Send(rest[(colon + 1)..].ToString());
                    }
                    break;
                case 'k':
                    if (int.TryParse(rest, out var removed) && _guests.Remove(removed, out var gone))
                    {
                        gone.Close(RelayClose.Removed);
                    }
                    break;
            }
        }
    }

    /// <summary>Closes every connection in the room.</summary>
    public void Close(Refusal why)
    {
        lock (_gate)
        {
            if (_closed) return;
            _closed = true;
            foreach (var guest in _guests.Values) guest.Close(why);
            _guests.Clear();
            _host?.Close(why);
            _host = null;
        }
    }
}
