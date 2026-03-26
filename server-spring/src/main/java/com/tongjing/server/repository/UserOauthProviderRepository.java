package com.tongjing.server.repository;

import com.tongjing.server.entity.UserOauthProvider;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserOauthProviderRepository extends JpaRepository<UserOauthProvider, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByProviderAndProviderUserId</p>
     */
    Optional<UserOauthProvider> findByProviderAndProviderUserId(String provider, String providerUserId);
}
