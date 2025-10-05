using Scalar.Aspire;

var builder = DistributedApplication.CreateBuilder(args);

var kafka = builder.AddKafka("kafka").WithKafkaUI().WithDataVolume(isReadOnly: false);
var mongoDb = builder.AddMongoDB("mongodb").WithDataVolume(isReadOnly: false);
var db = mongoDb.AddDatabase("crowdcue");

var mongoWorker = builder.AddProject<Projects.CrowdCue_Backend_MongoInitWorker>("mongoinitworker").WithReference(db).WithReference(mongoDb).WaitFor(db);
var apiService = builder.AddProject<Projects.CrowdCue_Backend_ApiService>("apiservice").WithReference(kafka).WithReference(db).WithReference(mongoDb).WaitFor(db).WaitFor(kafka).WaitForCompletion(mongoWorker);
var clientService = builder.AddProject<Projects.CrowdCue_Backend_ClientListenerApi>("clientlistenerapi").WithReference(kafka).WithReference(db).WithReference(mongoDb).WaitFor(db).WaitFor(kafka).WaitForCompletion(mongoWorker);

builder.AddScalarApiReference().WithReference(apiService).WithReference(clientService).WaitFor(apiService).WaitFor(clientService);



builder.Build().Run();
