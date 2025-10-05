using System;
using System.Text.Json.Serialization;

namespace CrowdCue_Backend.Data.PartyEvents;
[JsonPolymorphic(TypeDiscriminatorPropertyName = "$type")]
[JsonDerivedType(typeof(AddSongToQueuePartyEvent), typeDiscriminator: nameof(AddSongToQueuePartyEvent))]
[JsonDerivedType(typeof(CreateInitialPartyEvent), typeDiscriminator:nameof(CreateInitialPartyEvent))]
[JsonDerivedType(typeof(SongVotePartyEvent), typeDiscriminator: nameof(SongVotePartyEvent))]
[JsonDerivedType(typeof(JoinPartyEvent), typeDiscriminator: nameof(JoinPartyEvent))]
public abstract record PartyEvent
{
    public abstract bool TryApply(PartyState state, out PartyState updatedState);
}
