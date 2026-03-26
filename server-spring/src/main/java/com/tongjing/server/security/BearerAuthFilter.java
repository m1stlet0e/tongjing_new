package com.tongjing.server.security;

import com.tongjing.server.entity.UserSession;
import com.tongjing.server.repository.UserSessionRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 20)
@RequiredArgsConstructor
public class BearerAuthFilter extends OncePerRequestFilter {

    private final UserSessionRepository userSessionRepository;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        try {
            String auth = request.getHeader("Authorization");
            if (auth != null && auth.startsWith("Bearer ")) {
                String token = auth.substring(7).trim();
                if (!token.isEmpty()) {
                    Instant now = Instant.now();
                    userSessionRepository
                            .findByTokenAndExpiresAtAfter(token, now)
                            .map(UserSession::getUserId)
                            .ifPresent(CurrentUser::set);
                }
            }
            filterChain.doFilter(request, response);
        } finally {
            CurrentUser.clear();
        }
    }
}
