namespace CrowdCue_Backend.Data.PartyEvents;

public sealed record SongVotePartyEvent(string UserId, string SongSpotifyId, Vote Vote) : PartyEvent
{
 

    public override bool TryApply(PartyState state, out PartyState updatedState)
    {
        updatedState = state;
        var song = state.SongQueue.FirstOrDefault(s => s.SpotifyId == SongSpotifyId);
        if (song is null) return false;
        if(!song.TryAddorUpdateVote(UserId, Vote)) return false;
        updatedState = state with { SongQueue = state.SongQueue };
        return true;

    }
}