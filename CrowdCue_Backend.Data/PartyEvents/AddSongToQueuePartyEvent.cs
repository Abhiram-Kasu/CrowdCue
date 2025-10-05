using System;

namespace CrowdCue_Backend.Data.PartyEvents;

public sealed record AddSongToQueuePartyEvent(Song SongToAdd) : PartyEvent
{
    public override bool TryApply(PartyState state, out PartyState updatedState)
    {
        updatedState = state with { SongQueue = [.. state.SongQueue, SongToAdd] };
        return true;
    }
}
