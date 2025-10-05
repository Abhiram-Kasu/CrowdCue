using MongoDB.Driver;

namespace CrowdCue_Backend.MongoInitWorker;

public class Worker(ILogger<Worker> logger, IHostApplicationLifetime hostApplicationLifetime, IMongoClient mongoClient
                ) : BackgroundService
{
    private const string DatabaseName = "crowdcue";
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var databases = await mongoClient.ListDatabasesAsync(stoppingToken);
        var dbList = await databases.ToListAsync(stoppingToken);
        var dbExists = dbList.Any(x => x["name"] == DatabaseName);

        var db = mongoClient.GetDatabase(DatabaseName);

        var collections = await db.ListCollectionNamesAsync(cancellationToken: stoppingToken);
        var collectionList = await collections.ToListAsync(stoppingToken);
        var usersCollectionExists = collectionList.Contains("users");

        if (!dbExists)
            logger.LogInformation("Database {DatabaseName} does not exist, will create.", DatabaseName);

        if (!usersCollectionExists)
        {
            logger.LogInformation("Creating 'users' collection in {DatabaseName}", DatabaseName);
            await db.CreateCollectionAsync("users", cancellationToken: stoppingToken);
        }
        else
        {
            logger.LogInformation("'users' collection already exists in {DatabaseName}", DatabaseName);
        }

        hostApplicationLifetime.StopApplication();
    }
}