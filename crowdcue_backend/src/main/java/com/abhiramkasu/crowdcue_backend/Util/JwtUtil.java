package com.abhiramkasu.crowdcue_backend.Util;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.apache.kafka.common.message.ApiVersionsResponseData;
import org.apache.kafka.common.message.VoteRequestData;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.util.Date;

@Component
public class JwtUtil {


    private final long expiration;
    private final Key key;
    
    public JwtUtil(@Value("${jwt.secret}") String secretKey,
                   @Value("${jwt.expiration}") long expiration) {
        this.expiration = expiration;
        this.key = Keys.hmacShaKeyFor(secretKey.getBytes());
    }
    
    public String generateToken(String username, String id){
        return Jwts.builder()
                .setSubject(username)
                .setId(id)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + expiration))
                .signWith(key)
                .compact();
    }
    
 
    
    public record UsernameAndId(String username, String id){};
    
    public UsernameAndId extractUsernameAndId(String token){
        var body = Jwts.parserBuilder()
                .setSigningKey(key)
                .build()
                .parseClaimsJws(token)
                .getBody();
        return new UsernameAndId(body.getSubject(), body.getId());
    }
    
    
    
    
}
