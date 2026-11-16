using PlayPals.Relay;

var builder = WebApplication.CreateBuilder(args);

// Hosts such as Render say which port to listen on.
if (Environment.GetEnvironmentVariable("PORT") is { Length: > 0 } port)
{
    builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
}

// No request logs: they would list room codes, and nothing is kept.
builder.Logging.AddFilter("Microsoft.AspNetCore", LogLevel.Warning);

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton(new RelayOptions());
builder.Services.AddSingleton<RoomRegistry>();
builder.Services.AddHostedService<RoomSweeper>();

var app = builder.Build();

// Pings every 15 seconds keep connections open through phone networks,
// and a phone that stops answering them is noticed as gone.
app.UseWebSockets(new WebSocketOptions
{
    KeepAliveInterval = TimeSpan.FromSeconds(15),
    KeepAliveTimeout = TimeSpan.FromSeconds(15),
});

app.MapGet("/", () => "PlayPals relay is running.");
app.Map("/host", (HttpContext context, RoomRegistry rooms, RelayOptions options) =>
    RelayEndpoints.HostAsync(context, rooms, options));
app.Map("/join", (HttpContext context, RoomRegistry rooms, RelayOptions options) =>
    RelayEndpoints.JoinAsync(context, rooms, options));

app.Run();

/// <summary>Visible to the tests, which start the relay in memory.</summary>
public partial class Program;
