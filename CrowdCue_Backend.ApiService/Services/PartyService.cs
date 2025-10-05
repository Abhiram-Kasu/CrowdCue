using System;
using System.Diagnostics.Contracts;
using System.Text.Json;
using Confluent.Kafka;
using CrowdCue_Backend.Data;
using CrowdCue_Backend.Data.PartyEvents;
using Grpc.Core;
using Microsoft.AspNetCore.Mvc.Filters;
using SoapExtensions;
using Error = SoapExtensions.Error;

namespace CrowdCue_Backend.ApiService.Services;


public class PartyService(KafkaProducer kafkaProducer, ILogger<PartyService> logger)
{

    public async Task<bool> AddToParty(PartyCode partyCode, PartyUser partyUser)
    {
        var joinEvent = new JoinPartyEvent(partyUser);
        return await PublishEvent(joinEvent, partyCode);
        
    }
    public async Task<(bool success, PartyCode? code)> CreateParty(string partyName, PartyUser hostUser)
    {
        //publish event to the kafka stream
        var createInitialPartyEvent = new CreateInitialPartyEvent(PartyCodeService.GeneratePartyCode(),
            partyName,
            hostUser.Id.ToString());
        var initialPartyState = createInitialPartyEvent.InitialState;
        return (await PublishEvent(createInitialPartyEvent,
            initialPartyState.JoinCode), initialPartyState.JoinCode);
    }

    private async Task<bool> PublishEvent(PartyEvent e, PartyCode code)
    {
        var json = JsonSerializer.Serialize(e);
        logger.LogInformation("json: {json}", json);
        var (result, error) = await kafkaProducer.ProduceAsync(code,json);
        if (result is { Status: PersistenceStatus.Persisted }) return true;
        logger.LogError("Failed to publish event to Kafka: {Event}, Error: {}", json, error);
        return false;

    }


}
