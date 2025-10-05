using System;
using System.Collections.Frozen;
using System.Collections.ObjectModel;
using System.Diagnostics.Contracts;

namespace CrowdCue_Backend.Data;

public enum Vote
{
    Upvote = 1,
    Downvote = -1,
}
public record Song(string Title, string Artist, string SpotifyId)
{
    public int TotalVotes { get; private set; } = 0;
    private readonly Dictionary<string, Vote> Voters = [];
    ReadOnlyDictionary<string, Vote> ReadOnlyVoters => Voters.AsReadOnly();

    public bool TryAddorUpdateVote(string userId, Vote vote)
    {
        var userDoesExist = Voters.TryGetValue(userId, out var existingVote);

        switch (userDoesExist, vote)
        {
            case (true, var newVote) when newVote == existingVote:
                //User exists and the vote is the same
                return false;
            case (true, var newVote):
                // User exists and the vote is different
                TotalVotes += (int)newVote - (int)existingVote;
                Voters[userId] = newVote;
                return true;
            case (false, _):
                // New vote
                TotalVotes += (int)vote;
                Voters[userId] = vote;
                return true;
        }
    }
};

