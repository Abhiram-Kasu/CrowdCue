

using Aspire.Confluent.Kafka;
using Confluent.Kafka;
using CrowdCue_Backend.ApiService.Services;
using CrowdCue_Backend.Data;
using CrowdCue_Backend.Data.PartyEvents;
using Microsoft.AspNetCore.Mvc;
using MongoDB.Driver;

namespace CrowdCue_Backend.ApiService.Endpoints;

public static class AuthEndpointsMapper
{
    public static void MapAuthEndpoints(this WebApplication app)
    {
        app.MapPost("/auth/create-party", AuthEndpoints.CreateParty);
        app.MapPost("/auth/join-party", AuthEndpoints.JoinParty);
    }
}

public class AuthEndpoints
{
    public record CreatePartyRequest(string Username, string PartyName);

    public sealed record CreatePartyResponse(string Jwt, PartyCode partyCode);
    public static async Task<IResult> CreateParty([FromBody] CreatePartyRequest request,[FromServices] ILogger<AuthEndpoints> logger, [FromServices] PartyService partyServices,[FromServices] IMongoClient mongoClient)
    {

        var (username, partyName) = request;

        var jwt = JwtService.GenerateToken(username);
        // Create party here

        var partyUser = new PartyUser(username);
        // add to db
        await mongoClient.GetDatabase("crowdcue").GetCollection<PartyUser>("users").InsertOneAsync(partyUser);

        if (await mongoClient.GetDatabase("crowdcue").GetCollection<PartyUser>("users")
                .Find(u => u.Id == partyUser.Id).FirstOrDefaultAsync() is null)
        {
            logger.LogError("Failed to create user in database: {UserId}", partyUser.Id);
            return Results.StatusCode(500);
        }
        


    
        return await partyServices.CreateParty(partyName, partyUser) is (true, {} code ) ? Results.Ok(new CreatePartyResponse(jwt, code)) : Results.StatusCode(500);
    }
    
    public sealed record JoinPartyRequest(string Username, PartyCode PartyCode);

    public static async Task<IResult> JoinParty([FromBody] JoinPartyRequest request, [FromServices] PartyService partyService, [FromServices] IMongoClient mongoClient)
    {
        var (username, partyCode) = request;

        var jwt = JwtService.GenerateToken(username);
        // Join party here
        var partyUser = new PartyUser(username);

        var collection = mongoClient.GetDatabase("crowdcue").GetCollection<PartyUser>("users");
        await collection.InsertOneAsync(partyUser);
        
        var success = await partyService.AddToParty(partyCode, partyUser);
        return success ? Results.Ok(jwt) : Results.StatusCode(500);
    }
}


