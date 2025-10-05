using System;
using CrowdCue_Backend.Data;

namespace CrowdCue_Backend.ApiService.Services;

public static class PartyCodeService
{
    public static PartyCode GeneratePartyCode()
    {
        return new PartyCode(Guid.NewGuid().ToString().ToUpper()[..6]);
    }
}
