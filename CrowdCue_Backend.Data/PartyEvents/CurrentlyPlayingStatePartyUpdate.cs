namespace CrowdCue_Backend.Data.PartyEvents;

public sealed record CurrentlyPlayingStatePartyUpdate(CurrentlyPlayingState CurrState) : PartyEvent
{
    public override bool TryApply(PartyState state, out PartyState updatedState)
    {
        updatedState = state with { CurrentlyPlayingState = CurrState };
        return true;
    }
}