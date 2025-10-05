using System.Collections.Concurrent;
using System.Text.Json;
using System.Threading.Channels;
using Confluent.Kafka;
using CrowdCue_Backend.Data;
using CrowdCue_Backend.Data.PartyEvents;
using Microsoft.Extensions.Hosting;

namespace CrowdCue_Backend.ClientListenerApi.Services;

public sealed class KafkaListenerService : IHostedService, IDisposable
{
    private Task? _consumerListenerTask;
    private readonly CancellationTokenSource _cancellationTokenSource = new();
    private readonly ILogger<KafkaListenerService> _logger;
    private readonly IConsumer<string, string> _consumer;
    private readonly ConcurrentDictionary<string, PartyStateListener> _listeners = [];
    private bool _started = false;

    public KafkaListenerService(IConsumer<string, string> consumer, ILogger<KafkaListenerService> logger)
    {
        _logger = logger;
        _consumer = consumer;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        if (_started) return;
        _started = true;

        while (true)
            try
            {
                _consumer.Subscribe("^party-updates");
                break;
            }
            catch (ConsumeException)
            {
                _logger.LogWarning("Failed to subscribe to Kafka topic, retrying in 1 second");
                await Task.Delay(TimeSpan.FromSeconds(1), cancellationToken);
            }

        _consumerListenerTask = Task.Run(async () =>
        {
            _logger.LogInformation("Listening for party updates");
            while (!_cancellationTokenSource.IsCancellationRequested)
            {
                try
                {
                    if (_consumer.Consume(_cancellationTokenSource.Token) is not
                        { Message: { Key: { } code, Value: { } json } })
                        continue;
                    if (!_listeners.TryGetValue(code, out var listener))
                    {
                        _logger.LogWarning("No listeners for party code {PartyCode}", code);
                        listener = _listeners.GetOrAdd(code,
                            _ => new PartyStateListener(Channel.CreateUnbounded<PartyState>()));
                    }

                    _logger.LogInformation("Received Json: {Json}", json);
                    var partyState = JsonSerializer.Deserialize<PartyEvent>(json) ??
                                     throw new JsonException("Failed to deserialize PartyState");
                    if (partyState is CreateInitialPartyEvent { InitialState: var initialState })
                    {
                        await listener.Channel.Writer.WriteAsync(
                            initialState,
                            _cancellationTokenSource.Token);
                        listener.LatestState = initialState;
                    }
                    else
                    {
                        if (!partyState.TryApply(listener.LatestState!, out var newState))
                        {
                            _logger.LogError(
                                "Failed to apply party event to latest state for party code {PartyCode}", code);
                            continue;
                        }

                        await listener.Channel.Writer.WriteAsync(newState, _cancellationTokenSource.Token);
                        listener.LatestState = newState;
                    }

                    _logger.LogDebug("Dispatched update for party code {PartyCode}", code);
                }
                catch (Exception e)
                {
                    _logger.LogError(e, "Failed to consume message");
                }
            }
        }, cancellationToken);
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        _cancellationTokenSource.Cancel();
        return Task.CompletedTask;
    }

    sealed record PartyStateListener(Channel<PartyState> Channel)
    {
        public PartyState? LatestState { get; set; }
    };

    public (ChannelReader<PartyState> reader, PartyState? latestState) Listen(PartyCode code)
    {
        var listener = _listeners.GetOrAdd(code, _ => new PartyStateListener(Channel.CreateUnbounded<PartyState>()));
        return (listener.Channel.Reader, listener.LatestState);
    }

    public void Dispose()
    {
        _cancellationTokenSource.Cancel();
        _consumerListenerTask?.Dispose();
        _cancellationTokenSource.Dispose();
        foreach (var (_, listener) in _listeners)
        {
            listener.Channel.Writer.Complete();
        }

        _consumer.Dispose();
    }
}