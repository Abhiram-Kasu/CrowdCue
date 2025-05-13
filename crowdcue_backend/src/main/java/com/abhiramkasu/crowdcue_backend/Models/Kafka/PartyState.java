package com.abhiramkasu.crowdcue_backend.Models.Kafka;

import com.abhiramkasu.crowdcue_backend.Models.Song;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@AllArgsConstructor
@Data
@NoArgsConstructor
@Builder
public class PartyState {
    private String id;
    private String title;
    private String description;
    private List<Song> songQueue;
    private Song currentSong;
    private int currentDuration;
    private boolean playing;
}
