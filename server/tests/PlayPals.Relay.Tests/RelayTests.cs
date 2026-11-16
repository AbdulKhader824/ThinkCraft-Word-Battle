using System.Net.WebSockets;

namespace PlayPals.Relay.Tests;

public sealed class RelayTests : IAsyncLifetime
{
    private readonly RelayFactory _relay = new();

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync() => await _relay.DisposeAsync();

    [Fact]
    public async Task The_home_page_says_the_relay_is_running()
    {
        var text = await _relay.CreateClient().GetStringAsync("/");
        Assert.Equal("PlayPals relay is running.", text);
    }

    [Fact]
    public async Task A_host_opens_a_room_and_gets_a_key()
    {
        var host = await _relay.ConnectAsync("/host?code=ABC234&game=word_battle");
        Assert.Matches("^o:[0-9a-f]{32}:$", await host.NextAsync());
        Assert.NotNull(_relay.Rooms.Find("ABC234"));
    }

    [Fact]
    public async Task A_guest_and_the_host_pass_messages()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        Assert.Equal("j:1", await host.NextAsync());

        await guest.SendAsync("""{"type":"join","name":"Riya"}""");
        Assert.Equal("""m:1:{"type":"join","name":"Riya"}""", await host.NextAsync());

        // Colons inside the message travel untouched.
        await host.SendAsync("""m:1:{"type":"welcome","at":"10:30"}""");
        Assert.Equal("""{"type":"welcome","at":"10:30"}""", await guest.NextAsync());
    }

    [Fact]
    public async Task Messages_reach_only_the_guest_they_are_for()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var riya = await _relay.JoinAsync();
        var ali = await _relay.JoinAsync();
        Assert.Equal("j:1", await host.NextAsync());
        Assert.Equal("j:2", await host.NextAsync());

        await host.SendAsync("m:2:for ali");
        await host.SendAsync("m:1:for riya");
        Assert.Equal("for riya", await riya.NextAsync());
        Assert.Equal("for ali", await ali.NextAsync());

        await ali.SendAsync("hi");
        Assert.Equal("m:2:hi", await host.NextAsync());
    }

    [Fact]
    public async Task Nonsense_from_the_host_is_ignored()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        await host.SendAsync("hello");
        await host.SendAsync("m:9:nobody");
        await host.SendAsync("m:x:bad id");
        await host.SendAsync("m:1:still here");
        Assert.Equal("still here", await guest.NextAsync());
    }

    [Theory]
    [InlineData("/join?code=ZZZ999&game=word_battle", 4003)]
    [InlineData("/join?code=ABC234&game=the_impostor", 4005)]
    [InlineData("/join?code=abc234&game=word_battle", 4000)]
    [InlineData("/join?code=ABC2I4&game=word_battle", 4000)]
    [InlineData("/join?code=ABC234", 4000)]
    [InlineData("/host?code=ABC234&game=word_battle", 4001)]
    [InlineData("/host?code=ABC234&game=Word-Battle", 4000)]
    [InlineData("/host?code=ABC234&game=word_battle&key=nope", 4000)]
    public async Task Bad_requests_are_refused_with_a_reason(string path, int code)
    {
        await _relay.OpenRoomAsync();
        var phone = await _relay.ConnectAsync(path);
        var (closeCode, _) = await phone.ClosedAsync();
        Assert.Equal(code, closeCode);
    }

    [Fact]
    public async Task A_plain_web_request_to_a_socket_address_is_refused()
    {
        var response = await _relay.CreateClient().GetAsync("/join?code=ABC234&game=word_battle");
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task A_guest_leaving_is_told_to_the_host()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        Assert.Equal("j:1", await host.NextAsync());

        await guest.CloseAsync();
        Assert.Equal("l:1", await host.NextAsync());
    }

    [Fact]
    public async Task The_host_can_close_a_guests_connection()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        await host.SendAsync("m:1:you are removed");
        await host.SendAsync("k:1");

        Assert.Equal("you are removed", await guest.NextAsync());
        Assert.Equal((1000, "removed"), await guest.ClosedAsync());
    }

    [Fact]
    public async Task The_host_leaving_closes_the_room()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        await host.CloseAsync();

        Assert.Equal((1000, "room closed"), await guest.ClosedAsync());
        await Eventually.TrueAsync(() => _relay.Rooms.Find("ABC234") is null);
        var late = await _relay.ConnectAsync("/join?code=ABC234&game=word_battle");
        Assert.Equal(4003, (await late.ClosedAsync()).Code);
    }

    [Fact]
    public async Task A_host_whose_connection_drops_can_come_back()
    {
        var (host, key) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        Assert.Equal("j:1", await host.NextAsync());

        // Anything but a proper goodbye counts as a drop.
        await host.CloseAsync(WebSocketCloseStatus.InternalServerError);
        await Eventually.TrueAsync(() => _relay.Rooms.Find("ABC234")!.HostLostAt is not null);

        var back = await _relay.ConnectAsync($"/host?code=ABC234&game=word_battle&key={key}");
        Assert.Equal($"o:{key}:1", await back.NextAsync());
        await guest.SendAsync("hello again");
        Assert.Equal("m:1:hello again", await back.NextAsync());
        await back.SendAsync("m:1:welcome back");
        Assert.Equal("welcome back", await guest.NextAsync());
    }

    [Fact]
    public async Task Coming_back_needs_the_right_key()
    {
        await _relay.OpenRoomAsync();
        var other = await _relay.ConnectAsync(
            $"/host?code=ABC234&game=word_battle&key={new string('a', 32)}");
        Assert.Equal(4006, (await other.ClosedAsync()).Code);
    }

    [Fact]
    public async Task A_second_connection_with_the_key_replaces_the_first()
    {
        var (host, key) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        var back = await _relay.ConnectAsync($"/host?code=ABC234&game=word_battle&key={key}");
        Assert.Equal($"o:{key}:1", await back.NextAsync());

        Assert.Equal("j:1", await host.NextAsync());
        Assert.Equal(4009, (await host.ClosedAsync()).Code);
        await guest.SendAsync("hi");
        Assert.Equal("m:1:hi", await back.NextAsync());
    }

    [Fact]
    public async Task A_host_who_does_not_come_back_in_time_closes_the_room()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        await host.CloseAsync(WebSocketCloseStatus.InternalServerError);
        await Eventually.TrueAsync(() => _relay.Rooms.Find("ABC234")!.HostLostAt is not null);

        _relay.Time.Advance(TimeSpan.FromSeconds(19));
        _relay.Rooms.Sweep();
        Assert.NotNull(_relay.Rooms.Find("ABC234"));

        _relay.Time.Advance(TimeSpan.FromSeconds(1));
        _relay.Rooms.Sweep();
        Assert.Equal(4008, (await guest.ClosedAsync()).Code);
        Assert.Null(_relay.Rooms.Find("ABC234"));
    }

    [Fact]
    public async Task Rooms_close_after_two_hours()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();

        _relay.Time.Advance(TimeSpan.FromHours(2));
        _relay.Rooms.Sweep();

        Assert.Equal(4007, (await guest.ClosedAsync()).Code);
        Assert.Equal("j:1", await host.NextAsync());
        Assert.Equal(4007, (await host.ClosedAsync()).Code);
    }

    [Fact]
    public async Task A_message_up_to_64_KB_passes_and_a_bigger_one_is_refused()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        var guest = await _relay.JoinAsync();
        Assert.Equal("j:1", await host.NextAsync());

        var drawing = new string('x', 64 * 1024);
        await guest.SendAsync(drawing);
        Assert.Equal($"m:1:{drawing}", await host.NextAsync());

        await guest.SendAsync(drawing + "x");
        Assert.Equal(1009, (await guest.ClosedAsync()).Code);
        Assert.Equal("l:1", await host.NextAsync());
    }

    [Fact]
    public async Task A_room_turns_away_guests_past_its_limit()
    {
        await _relay.OpenRoomAsync();
        for (var i = 0; i < new RelayOptions().MaxGuests; i++) await _relay.JoinAsync();

        var oneTooMany = await _relay.ConnectAsync("/join?code=ABC234&game=word_battle");
        Assert.Equal(4004, (await oneTooMany.ClosedAsync()).Code);
    }

    [Fact]
    public async Task A_full_server_turns_away_new_rooms()
    {
        await using var relay = new RelayFactory(new RelayOptions { MaxRooms = 1 });
        await relay.OpenRoomAsync("ABC234");
        var second = await relay.ConnectAsync("/host?code=XYZ789&game=word_battle");
        Assert.Equal(4002, (await second.ClosedAsync()).Code);
    }

    [Fact]
    public async Task The_same_code_can_be_used_again_after_a_room_closes()
    {
        var (host, _) = await _relay.OpenRoomAsync();
        await host.CloseAsync();
        await Eventually.TrueAsync(() => _relay.Rooms.Find("ABC234") is null);
        var (again, _) = await _relay.OpenRoomAsync();
        Assert.NotNull(again);
    }
}
