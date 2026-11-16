using System.Buffers;
using System.Net.WebSockets;
using System.Text;
using System.Threading.Channels;

namespace PlayPals.Relay;

/// <summary>
/// One phone's WebSocket. Messages to it wait in a queue with a single
/// writer, because a WebSocket can only send one message at a time.
/// </summary>
public sealed class Peer
{
    private readonly WebSocket _socket;
    private readonly RelayOptions _options;
    private readonly Channel<string> _outbox;
    private Refusal _goodbye = RelayClose.RoomClosed;
    private int _closing;

    public Peer(WebSocket socket, RelayOptions options)
    {
        _socket = socket;
        _options = options;
        _outbox = Channel.CreateBounded<string>(
            new BoundedChannelOptions(options.MaxQueuedMessages) { SingleReader = true });
    }

    public bool IsClosing => Volatile.Read(ref _closing) == 1;

    /// <summary>Queues a message. A phone this far behind is cut off.</summary>
    public void Send(string text)
    {
        if (!IsClosing && !_outbox.Writer.TryWrite(text)) Close(RelayClose.TooSlow);
    }

    /// <summary>Sends what is queued, then says goodbye with [why]. Only the first call counts.</summary>
    public void Close(Refusal why)
    {
        if (Interlocked.Exchange(ref _closing, 1) == 1) return;
        _goodbye = why;
        _outbox.Writer.TryComplete();
    }

    /// <summary>
    /// Reads messages until the phone goes, while sending queued ones.
    /// Returns true when the phone said goodbye properly, rather than
    /// dropping (lost signal, app killed).
    /// </summary>
    public async Task<bool> RunAsync(Action<string> onMessage, CancellationToken cancel)
    {
        using var readCancel = CancellationTokenSource.CreateLinkedTokenSource(cancel);
        var writer = WriteLoopAsync(readCancel);
        var saidGoodbye = false;
        try
        {
            saidGoodbye = await ReadLoopAsync(onMessage, readCancel.Token);
        }
        catch (Exception error) when (error is WebSocketException or OperationCanceledException)
        {
            // The connection broke; nothing to tell.
        }
        Close(RelayClose.RoomClosed);
        await writer;
        return saidGoodbye;
    }

    private async Task<bool> ReadLoopAsync(Action<string> onMessage, CancellationToken cancel)
    {
        // A small buffer for each read, and a growing one only for messages
        // that don't fit, so idle phones use little memory.
        var chunk = new byte[4096];
        var whole = new ArrayBufferWriter<byte>(chunk.Length);
        while (true)
        {
            whole.ResetWrittenCount();
            ValueWebSocketReceiveResult result;
            do
            {
                result = await _socket.ReceiveAsync(chunk.AsMemory(), cancel);
                if (result.MessageType == WebSocketMessageType.Close)
                {
                    var status = _socket.CloseStatus;
                    return !IsClosing && status is WebSocketCloseStatus.NormalClosure
                        or WebSocketCloseStatus.EndpointUnavailable;
                }
                // While saying goodbye, the rest is read only to be thrown away.
                if (IsClosing) continue;
                if (whole.WrittenCount + result.Count > _options.MaxMessageBytes)
                {
                    Close(RelayClose.TooBig);
                    continue;
                }
                whole.Write(chunk.AsSpan(0, result.Count));
            } while (!result.EndOfMessage);

            if (IsClosing) continue;
            if (result.MessageType != WebSocketMessageType.Text)
            {
                Close(RelayClose.TextOnly);
                continue;
            }
            onMessage(Encoding.UTF8.GetString(whole.WrittenSpan));
        }
    }

    private async Task WriteLoopAsync(CancellationTokenSource readCancel)
    {
        try
        {
            await foreach (var text in _outbox.Reader.ReadAllAsync())
            {
                using var timeout = new CancellationTokenSource(_options.SendTimeout);
                await _socket.SendAsync(
                    Encoding.UTF8.GetBytes(text), WebSocketMessageType.Text, true, timeout.Token);
            }
            if (_socket.State is WebSocketState.Open or WebSocketState.CloseReceived)
            {
                using var timeout = new CancellationTokenSource(_options.SendTimeout);
                // Some hosts' proxies (Render's) drop close frames, so the
                // reason goes ahead as a text frame too: x:<close code>.
                if (_socket.State == WebSocketState.Open)
                {
                    await _socket.SendAsync(
                        Encoding.UTF8.GetBytes($"x:{(int)_goodbye.Status}"),
                        WebSocketMessageType.Text, true, timeout.Token);
                }
                await _socket.CloseOutputAsync(_goodbye.Status, _goodbye.Reason, timeout.Token);
            }
        }
        catch (Exception error) when (error is WebSocketException or OperationCanceledException
            or ObjectDisposedException)
        {
            Close(RelayClose.RoomClosed);
        }
        finally
        {
            // Give the phone a moment to answer the goodbye, then stop reading.
            try
            {
                readCancel.CancelAfter(_options.CloseWait);
            }
            catch (ObjectDisposedException)
            {
            }
        }
    }
}
