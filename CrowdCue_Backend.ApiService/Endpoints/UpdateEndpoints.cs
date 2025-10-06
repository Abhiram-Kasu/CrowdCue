using CrowdCue_Backend.ApiService.Services;
using CrowdCue_Backend.Data;
using CrowdCue_Backend.Data.PartyEvents;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using JsonSerializer = System.Text.Json.JsonSerializer;

namespace CrowdCue_Backend.ApiService.Endpoints;

public static class UpdateEndpointsMapper
{
    public static void MapUpdateEndpoints(this WebApplication app)
    {
        app.MapPost("/update", UpdateEndpoints.PostUpdate);
    }
}

internal class UpdateEndpoints
{
    public sealed record UpdateRequest(PartyCode PartyCode, string Jwt, PartyEvent PartyEvent);

    public static async Task<IResult> PostUpdate([FromBody] UpdateRequest request,
        [FromServices] KafkaProducer producer,
        [FromServices] ILogger<UpdateEndpoints> logger)
    {
        var result = JwtService.ValidateToken(request.Jwt);
        
        if (result is null) return Results.Unauthorized();
        
        var (username, userType) = result.Value;

        var isValid = (userType, request.PartyEvent) switch
        {
            // Make this logic extnesible? or tbh it doesn't matter since set of events is finite and won't grow
            (UserTypes.PartyUser, CreateInitialPartyEvent or CurrentlyPlayingStatePartyUpdate) => false,
            _ => true
        };
        
        if (!isValid)
        {
            logger.LogWarning("User {Username} with type {UserType} attempted to perform invalid action", username,
                userType);
            return Results.Forbid();
        }
        
        var res = await producer.ProduceAsync(request.PartyCode, JsonSerializer.Serialize(request.PartyEvent));

        if (res.success is { Status: Confluent.Kafka.PersistenceStatus.Persisted })
        {
            return Results.Ok();
        }

        logger.LogError("Failed to produce message: {Error}", res.error);
        return Results.StatusCode(500);
    }
    
}