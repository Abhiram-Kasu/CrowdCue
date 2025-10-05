using System.Collections.Concurrent;
using System.Diagnostics.CodeAnalysis;
using System.Text;
using System.Text.Json;
using System.Threading.Channels;
using CrowdCue_Backend.Data;

namespace CrowdCue_Backend.ClientListenerApi.Services;

public sealed class ChannelManagerService<T> : IDisposable
{
    private readonly ConcurrentDictionary<string, Channel<T>> _channels = [];
    
    public Channel<T> GetOrCreateChannel(string partyCode)
     {
         return _channels.GetOrAdd(partyCode, _ => Channel.CreateUnbounded<T>());
     }
    
    public async Task SendUpdateAsync(string partyCode,[StringSyntax(StringSyntaxAttribute.Json)] string state)
    {
        var item =  JsonSerializer.Deserialize<T>(state);
        if (item is null)
            throw new InvalidOperationException("Deserialized item is null");
        if (_channels.TryGetValue(partyCode, out var channel))
        {
            await channel.Writer.WriteAsync(item);
        }
        else
        {
            var createdChannel = _channels.GetOrAdd(partyCode, _ => Channel.CreateUnbounded<T>());
            await createdChannel.Writer.WriteAsync(item);
            
        }
        
    }
    
    public void Dispose()
    {
        foreach (var channelsValue in _channels.Values)
        {
            channelsValue.Writer.Complete();
        }
    }
}