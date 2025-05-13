package com.abhiramkasu.crowdcue_backend.Models;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class Song {
    private String spotifyId;
    private String title;
    private String artist;
    private String coverPhotoUrl;
    private int votes;
}
