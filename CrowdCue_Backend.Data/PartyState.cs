using System;
using System.Collections.Frozen;
using System.Collections.ObjectModel;
using System.ComponentModel.DataAnnotations;
using System.Diagnostics.CodeAnalysis;
using System.Dynamic;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;
using MongoDB.Bson;

namespace CrowdCue_Backend.Data;

public readonly struct PartyCode 
{
    [Length(maximumLength:6, minimumLength:6)]
    public string Code { get; }
    public PartyCode(string code)
    {
        if (code is null or { Length: not 6})
            throw new ArgumentException("Invalid code", nameof(code));
        Code = code;
    }

    public static PartyCode NewPartyCodeFromGuid() => new(Guid.NewGuid().ToString().ToUpper()[..6]);
    
    public static implicit operator string(PartyCode partyCode) => partyCode.Code;

    public override string ToString() => this;



    public static bool TryParse([NotNullWhen(true)] string? s, out PartyCode result)
    {
        if (s is null or { Length: not 6})
        {
            result = default;
            return false;
        }
        result = new PartyCode(s);
        return true;
    }
}

public readonly record struct CurrentlyPlayingState(Song CurrentlyPlayingSong, uint CurrMs);

public record PartyState(
    PartyCode JoinCode,
    string PartyName,
    string HostId,
    DateTime CreatedAt,
    Guid PartyId,
    FrozenSet<string> PartyMembers,
    IReadOnlyList<Song> SongQueue,
    CurrentlyPlayingState? CurrentlyPlayingState
);
