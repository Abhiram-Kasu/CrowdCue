using System;
using System.Runtime.Remoting;
using System.Text.Json.Serialization;
using MongoDB.Bson;

namespace CrowdCue_Backend.Data.PartyEvents;

public sealed record CreateInitialPartyEvent(PartyCode PartyCode, string PartyName, string UserId) : PartyEvent
{

    [JsonIgnore]
    public PartyState InitialState => new (
        PartyCode,
        PartyName,
        UserId,
        DateTime.UtcNow,
        Guid.NewGuid(),
        [],
        [],
        null
    );
    public override bool TryApply(PartyState state, out PartyState updatedState)
    {
        updatedState = InitialState;
        return true;
    }
}
