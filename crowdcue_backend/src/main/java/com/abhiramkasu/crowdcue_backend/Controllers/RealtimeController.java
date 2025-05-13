package com.abhiramkasu.crowdcue_backend.Controllers;

import com.abhiramkasu.crowdcue_backend.Models.Kafka.PartyState;
import com.abhiramkasu.crowdcue_backend.Models.Kafka.PartyUpdate;
import com.abhiramkasu.crowdcue_backend.Models.Kafka.UpdateType;
import com.abhiramkasu.crowdcue_backend.Repositories.PartyRepository;
import com.abhiramkasu.crowdcue_backend.Services.PartyUpdateService;
import com.abhiramkasu.crowdcue_backend.Util.JwtUtil;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.Duration;
import java.util.Collections;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/realtime")
public class RealtimeController {
    private final PartyUpdateService partyUpdateService;
    private final PartyRepository partyRepository;
    private final JwtUtil jwtUtil;
    private final Map<String, Map<String, SseEmitter>> partyEmitters = new ConcurrentHashMap<>();

    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;

    public RealtimeController(
            PartyUpdateService partyUpdateService,
            PartyRepository partyRepository,
            JwtUtil jwtUtil) {
        this.partyUpdateService = partyUpdateService;
        this.partyRepository = partyRepository;
        this.jwtUtil = jwtUtil;
    }
    
    @GetMapping(value = "/{partyCode}", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter subscribeToParty(@PathVariable String partyCode, Authentication auth) {
        // Get user ID from the authentication object
        JwtUtil.UsernameAndId usernameAndId = (JwtUtil.UsernameAndId) auth.getPrincipal();
        String userId = usernameAndId.id();
        
        // Create SSE emitter with longer timeout
        var emitter = new SseEmitter(Long.MAX_VALUE);
        
        // Create topic for party if it doesn't exist
        partyUpdateService.createTopicForParty(partyCode);
        
        // Add emitter to map
        partyEmitters.computeIfAbsent(partyCode, _ -> new ConcurrentHashMap<>()).put(userId, emitter);
        
        var thread = Thread.startVirtualThread(() -> {
            Properties props = new Properties();
            props.put("bootstrap.servers", bootstrapServers);
            props.put("group.id", "party-" + partyCode + "-" + userId);
            props.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
            props.put("value.deserializer", "org.springframework.kafka.support.serializer.JsonDeserializer");
            props.put("spring.json.trusted.packages", "com.abhiramkasu.crowdcue_backend.Models.Kafka");
            
            try (KafkaConsumer<String, PartyUpdate> consumer = new KafkaConsumer<>(props)) {
                consumer.subscribe(Collections.singletonList("party-" + partyCode));
                
                // Send initial state if available
                try {
                    PartyState initialState = partyUpdateService.getPartyState(partyCode);
                    emitter.send(SseEmitter.event()
                            .name("initial-state")
                            .data(initialState));
                } catch (IOException e) {
                    emitter.completeWithError(e);
                    return;
                }
                
                // Listen for updates
                while (!Thread.interrupted()) {
                    var records = consumer.poll(Duration.ofMillis(100));
                    for (var record : records) {
                        try {
                            emitter.send(SseEmitter.event()
                                    .name(record.value().getType().toString().toLowerCase())
                                    .data(record.value()));
                        } catch (IOException e) {
                            emitter.completeWithError(e);
                            return;
                        }
                    }
                }
            } catch (Exception e) {
                emitter.completeWithError(e);
            }
        });
        
        emitter.onError(_ -> {
            thread.interrupt();
            partyEmitters.get(partyCode).remove(userId);
        });
        
        emitter.onTimeout(() -> {
            thread.interrupt();
            partyEmitters.get(partyCode).remove(userId);
        });
        
        emitter.onCompletion(() -> {
            thread.interrupt();
            partyEmitters.get(partyCode).remove(userId);
        });
        
        return emitter;
    }
    
    @PostMapping("/{partyCode}/update")
    public ResponseEntity<?> sendUpdate(
            @PathVariable String partyCode,
            @RequestBody PartyUpdate update,
            Authentication auth) {
        
        // Get user ID from authentication
        JwtUtil.UsernameAndId usernameAndId = (JwtUtil.UsernameAndId) auth.getPrincipal();
        String userId = usernameAndId.id();
        boolean isOwner = partyUpdateService.isPartyOwner(partyCode, userId);
        
        // Validate update type based on user role
        UpdateType updateType = update.getType();
        
        // Members can only send SONG_VOTE_UPDATE and SONG_QUEUE_ADDITION
        if (!isOwner && (updateType == UpdateType.CURRENT_SONG_UPDATE || 
                         updateType == UpdateType.PLAYBACK_STATUS_UPDATE || 
                         updateType == UpdateType.DURATION_UPDATE)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body("Only party owners can send this type of update");
        }
        
        // Update party state and broadcast to all listeners
        partyUpdateService.updatePartyState(partyCode, update);
        
        return ResponseEntity.ok().build();
    }
}
