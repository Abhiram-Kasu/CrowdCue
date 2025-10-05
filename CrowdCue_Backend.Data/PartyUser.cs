using System;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace CrowdCue_Backend.Data;

public record PartyUser(string Username)
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string Id { get; set; }
};