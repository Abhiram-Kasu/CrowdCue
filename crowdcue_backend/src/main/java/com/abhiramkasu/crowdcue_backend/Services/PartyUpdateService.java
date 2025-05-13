package com.abhiramkasu.crowdcue_backend.Services;

import com.abhiramkasu.crowdcue_backend.Models.Db.Party;
import com.abhiramkasu.crowdcue_backend.Models.Kafka.PartyState;
import com.abhiramkasu.crowdcue_backend.Models.Kafka.PartyUpdate;
import com.abhiramkasu.crowdcue_backend.Models.Kafka.UpdateType;
import com.abhiramkasu.crowdcue_backend.Models.Song;
import com.abhiramkasu.crowdcue_backend.Repositories.PartyRepository;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;

@Service
public class PartyUpdateService {
    private final KafkaTemplate<String, PartyUpdate> kafkaTemplate;
    private final AdminClient adminClient;
    private final PartyRepository partyRepository;
    private final Map<String, PartyState> partyStateCache = new ConcurrentHashMap<>();

    public PartyUpdateService(KafkaTemplate<String, PartyUpdate> kafkaTemplate,
                             AdminClient adminClient,
                             PartyRepository partyRepository) {
        this.kafkaTemplate = kafkaTemplate;
        this.adminClient = adminClient;
        this.partyRepository = partyRepository;
    }

    public void createTopicForParty(String partyCode) {
        try {
            String topicName = getTopicName(partyCode);
            if (!adminClient.listTopics().names().get().contains(topicName)) {
                NewTopic topic = new NewTopic(topicName, 1, (short) 1);
                adminClient.createTopics(Collections.singleton(topic)).all().get();
            }
        } catch (InterruptedException | ExecutionException e) {
            throw new RuntimeException("Failed to create Kafka topic for party", e);
        }
    }

    public PartyState getPartyState(String partyCode) {
        return partyStateCache.getOrDefault(partyCode, new PartyState());
    }

    public void updatePartyState(String partyCode, PartyUpdate update) {
        String topicName = getTopicName(partyCode);
        kafkaTemplate.send(topicName, update);

        // Update the cached state
        PartyState currentState = partyStateCache.getOrDefault(partyCode, new PartyState());
        updateStateFromUpdate(currentState, update);
        partyStateCache.put(partyCode, currentState);
    }

    private String getTopicName(String partyCode) {
        return "party-" + partyCode;
    }

    private void updateStateFromUpdate(PartyState state, PartyUpdate update) {
        Object payload = update.getPayload();
        switch (update.getType()) {
            case SONG_VOTE_UPDATE -> {
                if (payload instanceof Song votedSong) {
                    state.getSongQueue().stream()
                            .filter(song -> song.getSpotifyId().equals(votedSong.getSpotifyId()))
                            .findFirst()
                            .ifPresent(song -> song.setVotes(votedSong.getVotes()));
                }
            }
            case SONG_QUEUE_ADDITION -> {
                if (payload instanceof Song newSong) {
                    state.getSongQueue().add(newSong);
                }
            }
            case CURRENT_SONG_UPDATE -> {
                if (payload instanceof Song currentSong) {
                    state.setCurrentSong(currentSong);
                }
            }
            case PLAYBACK_STATUS_UPDATE -> {
                if (payload instanceof Boolean playing) {
                    state.setPlaying(playing);
                }
            }
            case DURATION_UPDATE -> {
                if (payload instanceof Integer duration) {
                    state.setCurrentDuration(duration);
                }
            }
        }
    }

    public boolean isPartyOwner(String partyCode, String userId) {
        Party party = (Party) partyRepository.getDistinctFirstByCode(partyCode);
        return party != null && party.getOwner().getId().equals(userId);
    }
}