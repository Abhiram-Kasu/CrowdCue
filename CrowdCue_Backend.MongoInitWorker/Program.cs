using CrowdCue_Backend.MongoInitWorker;

var builder = Host.CreateApplicationBuilder(args);
builder.AddMongoDBClient("mongodb");
builder.Services.AddHostedService<Worker>();


var host = builder.Build();
host.Run();