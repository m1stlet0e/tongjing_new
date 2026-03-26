package com.tongjing.server.repository;

import com.tongjing.server.entity.UserSpot;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserSpotRepository extends JpaRepository<UserSpot, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByUserIdOrderByCreatedAtDesc</p>
     */
    Page<UserSpot> findByUserIdOrderByCreatedAtDesc(Integer userId, Pageable pageable);

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：countByUserId</p>
     */
    long countByUserId(Integer userId);

    /**
     * 删除目标数据并处理关联关系。
     *
     * <p>方法名：deleteByUserIdAndSpotId</p>
     */
    void deleteByUserIdAndSpotId(Integer userId, Integer spotId);

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByUserIdAndSpotId</p>
     */
    Optional<UserSpot> findByUserIdAndSpotId(Integer userId, Integer spotId);
}
