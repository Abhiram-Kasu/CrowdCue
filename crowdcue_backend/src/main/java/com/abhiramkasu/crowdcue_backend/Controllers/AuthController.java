package com.abhiramkasu.crowdcue_backend.Controllers;

import com.abhiramkasu.crowdcue_backend.Models.Db.Party;
import com.abhiramkasu.crowdcue_backend.Models.Db.User;
import com.abhiramkasu.crowdcue_backend.Repositories.PartyRepository;
import com.abhiramkasu.crowdcue_backend.Repositories.UserRepository;
import com.abhiramkasu.crowdcue_backend.Util.JwtUtil;
import com.abhiramkasu.crowdcue_backend.Util.ShortCodeGenerator;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;


@RestController
@RequestMapping("/auth")
public class AuthController {

    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final PartyRepository partyRepository;

    public AuthController(JwtUtil jwtUtil,
                          UserRepository userRepository,
                          PartyRepository partyRepository) {
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
        this.partyRepository = partyRepository;
    }

    public record CreatePartyRequest( String username,
             String partyName){}

    @PostMapping("/createParty")
    public ResponseEntity<?> createParty(@RequestBody CreatePartyRequest req) {
        if (req.username == null || req.username.isBlank()) {
            return ResponseEntity.badRequest().body("Username cannot be blank or empty");
        }
        if (req.partyName == null || req.partyName.isBlank()) {
            return ResponseEntity.badRequest().body("Party name cannot be blank or empty");
        }

        // Create and save user
        var user = User.builder()
                .username(req.username)
                .build();
        user = userRepository.save(user);

        // Create and save party
        var party = Party.builder()
                .name(req.partyName())
                .members(new ArrayList<>())
                .owner(user)
                .code(ShortCodeGenerator.generate(6))
                .build();
        party = partyRepository.save(party);
        
        //Generate JWT
        var jwt = jwtUtil.generateToken(req.username, user.getId());

        return ResponseEntity.ok(java.util.Map.of("partyCode", party.getCode()
        , "token", jwt));
    }

    @GetMapping("/parties")
    public ResponseEntity<List<Party>> getAllParties() {
        return ResponseEntity.ok(partyRepository.findAll());
    }

    public record JoinPartyRequest( String partyCode,String username){};
    
    @PostMapping("/joinParty")
    public ResponseEntity<?> joinParty(@RequestBody JoinPartyRequest req) {
       
        if (req.username == null || req.username.isEmpty()) {
            return ResponseEntity.badRequest().body("Username cannot be empty");
        }


        if (req.partyCode == null || req.partyCode.isEmpty()) {
            return ResponseEntity.badRequest().body("PartyId cannot be empty");
        }

        var party = partyRepository.getDistinctFirstByCode(req.partyCode);
        if (party == null) {
            return ResponseEntity.badRequest().body("Party does not exist");
        }

        // Create and save the joining user
        User newUser = User.builder()
                .username(req.username)
                .build();
        User savedUser = userRepository.save(newUser);
        
        var newParty = (Party) party;

        newParty.getMembers().add(savedUser);
        partyRepository.save(newParty);

        // Generate JWT
        String token = jwtUtil.generateToken(req.username, savedUser.getId());
        return ResponseEntity.ok(java.util.Map.of("token", token));
    }
}