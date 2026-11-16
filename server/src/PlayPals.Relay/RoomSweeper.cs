namespace PlayPals.Relay;

/// <summary>Every few seconds, closes rooms that are too old or have lost their host.</summary>
public sealed class RoomSweeper(RoomRegistry rooms, RelayOptions options, TimeProvider time)
    : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(options.SweepEvery, time);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken)) rooms.Sweep();
        }
        catch (OperationCanceledException)
        {
            // The server is stopping.
        }
    }
}
