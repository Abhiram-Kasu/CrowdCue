namespace CrowdCue_Backend.Data.PartyEvents;

public sealed record JoinPartyEvent(PartyUser User) : PartyEvent
{
    public override bool TryApply(PartyState state, out PartyState updatedState)
    {
        if (state.PartyMembers.Contains(User.Id))
        {
            updatedState = state;
            return false;
        }
        updatedState = state with { PartyMembers = [..state.PartyMembers, User.Id]};
        return true;
    }
}
