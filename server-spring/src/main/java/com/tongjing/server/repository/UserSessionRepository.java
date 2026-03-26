package com.tongjing.server.repository;

import com.tongjing.server.entity.UserSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

public interface UserSessionRepository extends JpaRepository<UserSession, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByTokenAndExpiresAtAfter</p>
     */
    Optional<UserSession> findByTokenAndExpiresAtAfter(String token, Instant now);

    /**
     * 删除目标数据并处理关联关系。
     *
     * <p>方法名：deleteByToken</p>
     */
    void deleteByToken(String token);
}
