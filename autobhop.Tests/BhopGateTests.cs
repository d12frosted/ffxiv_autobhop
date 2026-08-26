using AutoBhop.Core;
using Xunit;

namespace AutoBhop.Tests;

public class BhopGateTests
{
    /// <summary>Standing on the ground, in the world, holding the key. The one yes.</summary>
    private static BhopSnapshot Ready() => new(
        JumpKeyHeld: true,
        TextInputActive: false,
        InFlight: false,
        Jumping: false,
        Occupied: false,
        BetweenAreas: false,
        LoggedIn: true);

    [Fact]
    public void Jumps_when_the_key_is_held_and_nothing_is_in_the_way()
    {
        Assert.True(BhopGate.ShouldJump(Ready()));
    }

    [Fact]
    public void Does_nothing_when_the_key_is_not_held()
    {
        Assert.False(BhopGate.ShouldJump(Ready() with { JumpKeyHeld = false }));
    }

    /// <summary>
    /// Space in the chat box is a space. Reading the key state without this check is how
    /// a bhop plugin makes you jump every time you type a sentence.
    /// </summary>
    [Fact]
    public void Leaves_the_key_alone_while_typing()
    {
        Assert.False(BhopGate.ShouldJump(Ready() with { TextInputActive = true }));
    }

    /// <summary>Jump is descend while flying, so spamming it fights the mount.</summary>
    [Fact]
    public void Does_not_fire_in_flight()
    {
        Assert.False(BhopGate.ShouldJump(Ready() with { InFlight = true }));
    }

    /// <summary>
    /// The whole point: wait out the jump already in progress and go again on landing.
    /// Firing mid-air is what makes this a stream of refused actions instead of a bunnyhop.
    /// </summary>
    [Fact]
    public void Waits_until_the_previous_jump_has_landed()
    {
        Assert.False(BhopGate.ShouldJump(Ready() with { Jumping = true }));
        Assert.True(BhopGate.ShouldJump(Ready() with { Jumping = false }));
    }

    [Fact]
    public void Does_not_fire_while_occupied()
    {
        Assert.False(BhopGate.ShouldJump(Ready() with { Occupied = true }));
    }

    [Fact]
    public void Does_not_fire_between_areas()
    {
        Assert.False(BhopGate.ShouldJump(Ready() with { BetweenAreas = true }));
    }

    [Fact]
    public void Does_not_fire_at_the_title_screen()
    {
        Assert.False(BhopGate.ShouldJump(Ready() with { LoggedIn = false }));
    }
}
