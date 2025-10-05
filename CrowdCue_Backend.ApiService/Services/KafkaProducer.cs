using Confluent.Kafka;
using CrowdCue_Backend.Data;

namespace CrowdCue_Backend.ApiService.Services;

public class KafkaProducer(IProducer<string, string> kafkaProducer, ILogger<KafkaProducer> logger)
{
    public const string TopicPrefix = "party-updates";

    // private string GetTopic(string partyCode) => $"{TopicPrefix}-{partyCode}";
    private string GetTopic(string partyCode) => $"{TopicPrefix}";
    
    
    public async Task<(DeliveryResult<string, string>? success, string? error)> ProduceAsync(PartyCode partyCode, string data, CancellationToken cancellationToken = default)
    {
        var topic = GetTopic(partyCode);
        try
        {
            logger.LogInformation("Producing to topic {Topic} with data: {Data}", topic, data);
            var result = await kafkaProducer.ProduceAsync(topic, new Message<string, string>{ Key = partyCode, Value = data }, cancellationToken);
            logger.LogInformation("Produced message to {TopicPartitionOffset}", result.TopicPartitionOffset);
            return (result, null);
        }
        catch (ProduceException<string, string> e)
        {
            logger.LogError("Failed to produce message: {Error}", e.Error.Reason);
            return (null, e.Error.Reason);
        } 
    }
}