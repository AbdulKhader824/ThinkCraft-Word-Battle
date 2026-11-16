using System.Net.WebSockets;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Time.Testing;

namespace PlayPals.Relay.Tests;

/// <summary>The relay running in memory, with a clock the tests move by hand.</summary>
public sealed class RelayFactory(RelayOptions? options = null) : WebApplicationFactory<Program>
{
    public FakeTimeProvider Time { get; } = new(new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero));

    public RoomRegistry Rooms => Services.GetRequiredService<RoomRegistry>();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<TimeProvider>();
            services.AddSingleton<TimeProvider>(Time);
            services.RemoveAll<RelayOptions>();
            services.AddSingleton(options ?? new RelayOptions());
        });
    }

    public async Task<Phone> ConnectAsync(string path)
    {
        var client = Server.CreateWebSocketClient();
        var socket = await client.ConnectAsync(new Uri($"ws://localhost{path}"), CancellationToken.None);
        return new Phone(socket);
    }

    /// <summary>Opens a room and returns its host, past the opening message.</summary>
    public async Task<(Phone Host, string Key)> OpenRoomAsync(
        string code = "ABC234", string game = "word_battle")
    {
        var host = await ConnectAsync($"/host?code={code}&game={game}");
        var opened = await host.NextAsync();
        Assert.StartsWith("o:", opened);
        return (host, opened.Split(':')[1]);
    }

    /// <summary>Joins a room and returns the guest, past its ready message.</summary>
    public async Task<Phone> JoinAsync(string code = "ABC234", string game = "word_battle")
    {
        var guest = await ConnectAsync($"/join?code={code}&game={game}");
        Assert.Equal("ready", await guest.NextAsync());
        return guest;
    }
}

/// <summary>A pretend phone on the other end of a WebSocket.</summary>
public sealed class Phone(WebSocket socket) : IAsyncDisposable
{
    private static readonly TimeSpan Wait = TimeSpan.FromSeconds(5);

    public WebSocket Socket { get; } = socket;

    public Task SendAsync(string text) =>
        Socket.SendAsync(Encoding.UTF8.GetBytes(text), WebSocketMessageType.Text, true, CancellationToken.None);

    /// <summary>The next message. Fails if the connection closes instead.</summary>
    public async Task<string> NextAsync()
    {
        var text = await ReceiveAsync();
        Assert.True(text is not null, $"Closed instead: {Socket.CloseStatus} {Socket.CloseStatusDescription}");
        return text;
    }

    /// <summary>Waits for the relay to close the connection, and returns how.</summary>
    public async Task<(int Code, string? Reason)> ClosedAsync()
    {
        // The relay sends the close code as text first (x:<code>), for
        // proxies that drop close frames.
        string? said = null;
        while (await ReceiveAsync() is { } text)
        {
            if (said is null && text.StartsWith("x:")) said = text;
            else Assert.Fail($"Expected the connection to close, but got: {text}");
        }
        var code = (int)Socket.CloseStatus!;
        Assert.Equal($"x:{code}", said);
        return (code, Socket.CloseStatusDescription);
    }

    public Task CloseAsync(WebSocketCloseStatus status = WebSocketCloseStatus.NormalClosure) =>
        Socket.CloseAsync(status, "", new CancellationTokenSource(Wait).Token);

    private async Task<string?> ReceiveAsync()
    {
        using var timeout = new CancellationTokenSource(Wait);
        var buffer = new byte[128 * 1024];
        var length = 0;
        WebSocketReceiveResult result;
        do
        {
            result = await Socket.ReceiveAsync(new ArraySegment<byte>(buffer, length, buffer.Length - length), timeout.Token);
            if (result.MessageType == WebSocketMessageType.Close)
            {
                if (Socket.State == WebSocketState.CloseReceived)
                {
                    await Socket.CloseOutputAsync(WebSocketCloseStatus.NormalClosure, "", CancellationToken.None);
                }
                return null;
            }
            length += result.Count;
        } while (!result.EndOfMessage);
        return Encoding.UTF8.GetString(buffer, 0, length);
    }

    public ValueTask DisposeAsync()
    {
        Socket.Dispose();
        return ValueTask.CompletedTask;
    }
}

public static class Eventually
{
    /// <summary>Waits until [done] is true, since the relay works on its own threads.</summary>
    public static async Task TrueAsync(Func<bool> done)
    {
        for (var tries = 0; tries < 250 && !done(); tries++) await Task.Delay(20);
        Assert.True(done());
    }
}
