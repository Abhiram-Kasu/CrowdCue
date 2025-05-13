package com.abhiramkasu.crowdcue_backend.Repositories;


import com.abhiramkasu.crowdcue_backend.Models.Db.User;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface UserRepository extends MongoRepository<User,String> {
    Object getById(String id);
}
