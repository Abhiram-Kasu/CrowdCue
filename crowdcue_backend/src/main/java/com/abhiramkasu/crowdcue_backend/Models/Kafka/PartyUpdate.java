package com.abhiramkasu.crowdcue_backend.Models.Kafka;

import com.abhiramkasu.crowdcue_backend.Models.Song;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class PartyUpdate {
    private UpdateType type;
    private String partyId;
    private Object payload;
}