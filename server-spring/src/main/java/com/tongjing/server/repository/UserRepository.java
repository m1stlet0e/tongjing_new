package com.tongjing.server.repository;

import com.tongjing.server.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByPhone</p>
     */
    Optional<User> findByPhone(String phone);

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：existsByUsername</p>
     */
    boolean existsByUsername(String username);
}
