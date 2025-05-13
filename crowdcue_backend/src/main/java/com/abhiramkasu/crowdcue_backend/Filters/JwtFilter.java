package com.abhiramkasu.crowdcue_backend.Filters;

import com.abhiramkasu.crowdcue_backend.Util.JwtUtil;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.mongodb.core.aggregation.ConditionalOperators;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

public class JwtFilter extends OncePerRequestFilter {
    
    private final JwtUtil jwtUtil;

    public JwtFilter(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    // Add to the existing doFilterInternal method to ensure the UsernameAndId is correctly set in the authentication
@Override
protected void doFilterInternal(HttpServletRequest request, @NonNull HttpServletResponse response, 
                                @NonNull FilterChain filterChain) throws ServletException, IOException {
    var authHeader = request.getHeader("Authorization");
    if (authHeader != null && authHeader.startsWith("Bearer ")) {
        try {
            var token = authHeader.substring(7);
            var usernameAndId = jwtUtil.extractUsernameAndId(token);
            var auth = new UsernamePasswordAuthenticationToken(usernameAndId, null, List.of());
            SecurityContextHolder.getContext().setAuthentication(auth);
        } catch(JwtException e) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid Token");
            return;
        }
    }
    filterChain.doFilter(request, response);
}
}
