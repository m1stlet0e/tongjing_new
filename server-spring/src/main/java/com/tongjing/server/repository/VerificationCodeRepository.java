package com.tongjing.server.repository;

import com.tongjing.server.entity.VerificationCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;

public interface VerificationCodeRepository extends JpaRepository<VerificationCode, Integer> {

    @Query("SELECT v FROM VerificationCode v WHERE v.phone = :phone AND v.type = :type AND v.createdAt >= :since ORDER BY v.createdAt DESC")
    Optional<VerificationCode> findLatestSince(
            @Param("phone") String phone,
            @Param("type") String type,
            @Param("since") Instant since);

    @Query("SELECT v FROM VerificationCode v WHERE v.phone = :phone AND v.code = :code AND v.type = 'login' AND v.used = false AND v.expiresAt >= :now ORDER BY v.createdAt DESC")
    Optional<VerificationCode> findValidLoginCode(
            @Param("phone") String phone,
            @Param("code") String code,
            @Param("now") Instant now);
}
