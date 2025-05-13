package com.abhiramkasu.crowdcue_backend.Repositories;

import com.abhiramkasu.crowdcue_backend.Models.Db.Party;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface PartyRepository extends MongoRepository<Party,String> {
    Object getDistinctFirstByCode(String code);
}
