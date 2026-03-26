package com.tongjing.server.repository;

import com.tongjing.server.entity.UserFollow;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserFollowRepository extends JpaRepository<UserFollow, Integer> {

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：countByFollowingId</p>
     */
    long countByFollowingId(Integer followingId);

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：countByFollowerId</p>
     */
    long countByFollowerId(Integer followerId);

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByFollowerIdAndFollowingId</p>
     */
    Optional<UserFollow> findByFollowerIdAndFollowingId(Integer followerId, Integer followingId);

    /**
     * 删除目标数据并处理关联关系。
     *
     * <p>方法名：deleteByFollowerIdAndFollowingId</p>
     */
    void deleteByFollowerIdAndFollowingId(Integer followerId, Integer followingId);
}
