namespace AutoBhop.Core;

/// <summary>
/// Everything the jump decision looks at, read once per frame so the decision itself
/// never touches the game.
/// </summary>
/// <param name="JumpKeyHeld">The jump key is down right now.</param>
/// <param name="TextInputActive">A text field has the keyboard: chat, search, a rename box.</param>
/// <param name="InFlight">Airborne on a flying mount.</param>
/// <param name="Jumping">Already off the ground from a previous jump.</param>
/// <param name="Occupied">In an event, a cutscene, a summoning bell, or otherwise busy.</param>
/// <param name="BetweenAreas">Mid zone transition.</param>
/// <param name="LoggedIn">A character is actually in the world.</param>
public readonly record struct BhopSnapshot(
    bool JumpKeyHeld,
    bool TextInputActive,
    bool InFlight,
    bool Jumping,
    bool Occupied,
    bool BetweenAreas,
    bool LoggedIn);

/// <summary>
/// Decides whether this frame is the frame to jump.
/// </summary>
public static class BhopGate
{
    public static bool ShouldJump(in BhopSnapshot state)
    {
        if (!state.LoggedIn) return false;
        if (!state.JumpKeyHeld) return false;

        // The key state array is the game's, and it does not care that the keyboard is
        // currently spelling a tell.
        if (state.TextInputActive) return false;

        // Jump means descend on a flying mount, so a held key would sink you.
        if (state.InFlight) return false;

        // Already in the air. Waiting for the landing is what turns a stream of jumps
        // into a bunnyhop instead of a stream of refusals.
        if (state.Jumping) return false;

        if (state.Occupied || state.BetweenAreas) return false;

        return true;
    }
}
