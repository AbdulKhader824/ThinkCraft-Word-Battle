namespace PlayPals.Relay;

/// <summary>The relay's limits. Small on purpose: a free server has little memory.</summary>
public sealed class RelayOptions
{
    /// <summary>Rooms open at once across the whole server.</summary>
    public int MaxRooms { get; init; } = 300;

    /// <summary>
    /// Guest connections per room. Rooms hold 8 players (the host and 7
    /// friends), and the host's phone turns away the 9th. The relay allows
    /// a few more, because a phone that switches from Wi-Fi to mobile data
    /// reconnects before its old connection has been noticed as dead.
    /// </summary>
    public int MaxGuests { get; init; } = 10;

    /// <summary>The biggest message, enough for a full drawing.</summary>
    public int MaxMessageBytes { get; init; } = 64 * 1024;

    /// <summary>Messages waiting for a slow phone before it is cut off.</summary>
    public int MaxQueuedMessages { get; init; } = 256;

    /// <summary>Rooms close after this long, whatever is happening.</summary>
    public TimeSpan MaxRoomAge { get; init; } = TimeSpan.FromHours(2);

    /// <summary>
    /// How long a room waits for a host whose connection dropped (rather
    /// than one who left) to come back.
    /// </summary>
    public TimeSpan HostGrace { get; init; } = TimeSpan.FromSeconds(20);

    /// <summary>How often old and hostless rooms are looked for.</summary>
    public TimeSpan SweepEvery { get; init; } = TimeSpan.FromSeconds(10);

    /// <summary>How long a phone gets to answer the relay's goodbye.</summary>
    public TimeSpan CloseWait { get; init; } = TimeSpan.FromSeconds(5);

    /// <summary>How long one message may take to send before the phone is cut off.</summary>
    public TimeSpan SendTimeout { get; init; } = TimeSpan.FromSeconds(10);
}
