using System.Threading.Channels;
using Aspire.Confluent.Kafka;
using Confluent.Kafka;
using CrowdCue_Backend.ClientListenerApi;
using CrowdCue_Backend.ClientListenerApi.Services;
using CrowdCue_Backend.Data;
using Microsoft.AspNetCore.Mvc;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

builder.AddKafkaConsumer<string, string>("kafka",  static consumerBuilder =>
{
    consumerBuilder.Config.GroupId = "crowd_cue_client_listener";
    consumerBuilder.Config.AutoOffsetReset = AutoOffsetReset.Earliest;
    consumerBuilder.Config.EnableAutoCommit = false;
} );
builder.Services.AddLogging();
builder.Services.AddSingleton<ChannelManagerService<PartyState>>();
builder.Services.AddSingleton<KafkaListenerService>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<KafkaListenerService>());



if( builder.Environment.IsDevelopment())
{
    builder.Services.AddCors(x => x.AddDefaultPolicy(p => p.AllowAnyHeader().AllowAnyMethod().AllowAnyOrigin()));
}

var app = builder.Build();


// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();

app.UseCors();


app.MapGet("/listen/{code}", (KafkaListenerService service,[FromRoute] string code) =>
{
    if (!PartyCode.TryParse(code, out var partyCode))
    {
        return Results.BadRequest("Invalid party code");
    }
    
    
    var (reader, lastState) = service.Listen(partyCode);
    
    async IAsyncEnumerable<PartyState> Stream(ChannelReader<PartyState> r, PartyState initialState)
    {
        yield return initialState;
        await foreach (var item in r.ReadAllAsync())
        {
            yield return item;
        }
    }
    if (lastState is null)
    {
        //TODO maybe make a task waiting for the first state to arrive instead of immediately returning an error
        return TypedResults.InternalServerError("no initial party state yet");
    }
    return TypedResults.ServerSentEvents(Stream(reader, lastState));
    

});



app.Run();
