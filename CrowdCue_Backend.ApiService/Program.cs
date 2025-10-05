using CrowdCue_Backend.ApiService;
using CrowdCue_Backend.ApiService.Endpoints;
using CrowdCue_Backend.ApiService.Services;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults & Aspire client integrations.
builder.AddServiceDefaults();

if( builder.Environment.IsDevelopment())
{
    builder.Services.AddCors(x => x.AddDefaultPolicy(p => p.AllowAnyHeader().AllowAnyMethod().AllowAnyOrigin()));
}

// Add services to the container.
builder.Services.AddProblemDetails();



// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();



builder.AddMongoDBClient("mongodb");

builder.AddKafkaProducer<string, string>("kafka");
builder.Services.AddSingleton<PartyService>();
builder.Services.AddSingleton<KafkaProducer>();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseExceptionHandler();
app.UseCors();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}




// Register Auth endpoints

app.MapAuthEndpoints();
app.MapUpdateEndpoints();

app.MapDefaultEndpoints();

app.Run();


