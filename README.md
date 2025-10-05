# CrowdCue

A real-time collaborative music party application that allows users to create parties, join them, and collaboratively manage a music queue with voting capabilities.

## Overview

CrowdCue is a distributed backend system built with .NET Aspire that enables multiple users to join music parties and collaboratively curate playlists. The system uses event-driven architecture with Apache Kafka for real-time updates and MongoDB for data persistence.

## Features

- **Party Management**: Create and join music parties with unique party codes
- **Real-time Updates**: Server-Sent Events (SSE) for live party state synchronization
- **Song Queue Management**: Add songs to the party queue
- **Collaborative Voting**: Upvote or downvote songs in the queue
- **JWT Authentication**: Secure user authentication for party operations
- **Event Sourcing**: All party state changes are tracked through event streams

## Architecture

CrowdCue consists of several microservices orchestrated by .NET Aspire:

```
┌─────────────────┐
│   AppHost       │  (Orchestration)
└────────┬────────┘
         │
    ┌────┴────┬──────────┬──────────────┐
    │         │          │              │
┌───▼───┐ ┌──▼────┐ ┌───▼──────┐ ┌─────▼─────┐
│ API   │ │Client │ │ MongoDB  │ │   Kafka   │
│Service│ │Listen │ │          │ │           │
└───────┘ └───────┘ └──────────┘ └───────────┘
```

### Services

1. **ApiService** - Main REST API for party and queue management
2. **ClientListenerApi** - SSE endpoint for real-time state updates
3. **MongoInitWorker** - Database initialization service
4. **AppHost** - .NET Aspire orchestration host
5. **ServiceDefaults** - Shared service configuration
6. **Data** - Shared data models and event definitions
7. **Web** - Frontend web application (optional)

## Technology Stack

- **Framework**: ASP.NET Core 9.0 / .NET 9.0
- **Orchestration**: .NET Aspire 9.4
- **Message Queue**: Apache Kafka (via Confluent.Kafka)
- **Database**: MongoDB
- **Authentication**: JWT (JSON Web Tokens)
- **API Documentation**: Scalar OpenAPI
- **Language**: C# with nullable reference types enabled

## Data Models

### PartyState
Represents the current state of a music party:
- `JoinCode`: 6-character unique party code
- `PartyName`: Name of the party
- `HostId`: User ID of the party host
- `CreatedAt`: Party creation timestamp
- `PartyId`: Unique party identifier (GUID)
- `PartyMembers`: Set of user IDs in the party
- `SongQueue`: Ordered list of songs
- `CurrentlyPlayingState`: Current playing song and position

### Song
Represents a music track:
- `Title`: Song title
- `Artist`: Artist name
- `SpotifyId`: Spotify track identifier
- `TotalVotes`: Aggregate vote count
- Vote tracking per user (upvote/downvote)

### PartyUser
Represents a user in the system:
- `Id`: MongoDB ObjectId
- `Username`: User's display name

### Party Events
Event sourcing events that modify party state:
- `CreateInitialPartyEvent`: Creates a new party
- `JoinPartyEvent`: Adds a user to a party
- `AddSongToQueuePartyEvent`: Adds a song to the queue
- `SongVotePartyEvent`: Adds or updates a vote on a song

## API Endpoints

### Authentication & Party Management
**Base URL**: `http://localhost:<apiservice-port>`

#### Create Party
```http
POST /auth/create-party
Content-Type: application/json

{
  "username": "string",
  "partyName": "string"
}
```

**Response**:
```json
{
  "jwt": "string",
  "partyCode": "string"
}
```

Creates a new party and returns a JWT token for authentication and a unique 6-character party code.

#### Join Party
```http
POST /auth/join-party
Content-Type: application/json

{
  "username": "string",
  "partyCode": "string"
}
```

**Response**:
```json
"jwt-token-string"
```

Joins an existing party using its party code and returns a JWT token.

### Party Updates
**Base URL**: `http://localhost:<apiservice-port>`

#### Post Update
```http
POST /update
Content-Type: application/json

{
  "partyCode": "string",
  "jwt": "string",
  "partyEvent": {
    "$type": "EventType",
    // Event-specific properties
  }
}
```

Publishes an event to update the party state. Requires valid JWT authentication.

**Supported Event Types**:
- `AddSongToQueuePartyEvent`: Add a song to the queue
- `SongVotePartyEvent`: Vote on a song
- `JoinPartyEvent`: Join a party (typically used internally)

**Example - Add Song**:
```json
{
  "partyCode": "ABC123",
  "jwt": "your-jwt-token",
  "partyEvent": {
    "$type": "AddSongToQueuePartyEvent",
    "songToAdd": {
      "title": "Song Title",
      "artist": "Artist Name",
      "spotifyId": "spotify-track-id"
    }
  }
}
```

**Example - Vote on Song**:
```json
{
  "partyCode": "ABC123",
  "jwt": "your-jwt-token",
  "partyEvent": {
    "$type": "SongVotePartyEvent",
    "userId": "user-id",
    "songSpotifyId": "spotify-track-id",
    "vote": 1
  }
}
```
Note: Vote values: `1` for upvote, `-1` for downvote

### Real-time Updates
**Base URL**: `http://localhost:<clientlistenerapi-port>`

#### Listen to Party Updates
```http
GET /listen/{partyCode}
```

Returns a Server-Sent Events (SSE) stream of party state updates.

**Response**: Stream of `PartyState` objects as JSON
- First event contains the current party state
- Subsequent events contain state updates as they occur

**Example**:
```
GET /listen/ABC123
```

Client receives SSE stream:
```
data: {"joinCode":"ABC123","partyName":"My Party",...}

data: {"joinCode":"ABC123","partyName":"My Party",...}
```

## Project Structure

```
CrowdCue/
├── CrowdCue_Backend.ApiService/        # Main REST API service
│   ├── Endpoints/
│   │   ├── AuthEndpoints.cs           # Party creation and joining
│   │   └── UpdateEndpoints.cs         # Party state updates
│   └── Services/
│       ├── JwtService.cs              # JWT token generation/validation
│       ├── KafkaProducer.cs           # Kafka message production
│       ├── PartyCodeService.cs        # Party code generation
│       └── PartyService.cs            # Party business logic
├── CrowdCue_Backend.ClientListenerApi/ # SSE streaming service
│   └── Services/
│       ├── KafkaListenerService.cs    # Kafka consumer
│       └── ChannelManagerService.cs   # Channel management
├── CrowdCue_Backend.Data/             # Shared data models
│   ├── PartyState.cs                  # Party state model
│   ├── PartyUser.cs                   # User model
│   ├── Song.cs                        # Song model
│   └── PartyEvents/                   # Event sourcing events
│       ├── PartyEvent.cs              # Base event class
│       ├── CreateInitialPartyEvent.cs
│       ├── JoinPartyEvent.cs
│       ├── AddSongToQueuePartyEvent.cs
│       └── SongVotePartyEvent.cs
├── CrowdCue_Backend.AppHost/          # .NET Aspire orchestration
├── CrowdCue_Backend.MongoInitWorker/  # Database initialization
├── CrowdCue_Backend.ServiceDefaults/  # Shared service configuration
└── CrowdCue_Backend.Web/              # Web frontend (optional)
```

## Getting Started

### Prerequisites

- [.NET SDK 9.0 or later](https://dotnet.microsoft.com/download)
- [Docker Desktop](https://www.docker.com/products/docker-desktop) (for MongoDB and Kafka)
- [.NET Aspire workload](https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/setup-tooling)

### Installation

1. Install .NET Aspire workload:
```bash
dotnet workload install aspire
```

2. Clone the repository:
```bash
git clone https://github.com/Abhiram-Kasu/CrowdCue.git
cd CrowdCue
```

3. Run the application:
```bash
dotnet run --project CrowdCue_Backend.AppHost
```

This will start all services including:
- MongoDB (with persistent volume)
- Apache Kafka (with Kafka UI)
- API Service
- Client Listener API
- Mongo Init Worker

### Accessing the Application

Once running, you can access:
- **Aspire Dashboard**: Check console output for the dashboard URL
- **API Service**: Check the dashboard for the assigned port
- **Client Listener API**: Check the dashboard for the assigned port
- **Kafka UI**: Available through the Aspire dashboard
- **API Documentation**: Available at `/scalar/v1` on the API Service

### Development

The application supports CORS in development mode for easier frontend integration.

API documentation is automatically generated using OpenAPI and can be viewed using Scalar at the `/scalar/v1` endpoint.

## Event Flow

1. **Create Party**: User creates a party → `CreateInitialPartyEvent` published to Kafka
2. **Join Party**: User joins with party code → `JoinPartyEvent` published to Kafka
3. **Add Song**: User adds song → `AddSongToQueuePartyEvent` published to Kafka
4. **Vote**: User votes on song → `SongVotePartyEvent` published to Kafka
5. **Listen**: Clients connect to SSE endpoint → Receive real-time state updates from Kafka

All events flow through Kafka and are consumed by the ClientListenerApi, which maintains the current party state and broadcasts updates to connected clients via SSE.

## Authentication

The system uses JWT tokens for authentication:
- Tokens are generated when creating or joining a party
- Tokens are valid for 24 hours
- Include the JWT in the `jwt` field when posting updates
- Tokens contain the user's ID as a claim

**Note**: The current implementation uses a hardcoded secret key for JWT signing. This should be replaced with a secure secret stored in configuration for production use.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Copyright (c) 2025 Abhiram Kasu
