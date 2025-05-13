package com.abhiramkasu.crowdcue_backend.Models.Db;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.DBRef;
import org.springframework.data.mongodb.core.mapping.Document;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Document(collection = "parties")
@Builder
public class Party {
    @Id
    private String id;
    
    @DBRef
    private User owner;
    
    @DBRef
    private List<User> members;
    
    private String code;
    
    private String name;
    
    
}
