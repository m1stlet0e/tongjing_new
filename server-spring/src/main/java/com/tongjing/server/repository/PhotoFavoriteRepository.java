package com.tongjing.server.repository;

import com.tongjing.server.entity.PhotoFavorite;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PhotoFavoriteRepository extends JpaRepository<PhotoFavorite, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByPhotoIdAndUserId</p>
     */
    Optional<PhotoFavorite> findByPhotoIdAndUserId(Integer photoId, Integer userId);

    /**
     * 删除目标数据并处理关联关系。
     *
     * <p>方法名：deleteByPhotoIdAndUserId</p>
     */
    void deleteByPhotoIdAndUserId(Integer photoId, Integer userId);

    /**
     * 删除目标数据并处理关联关系。
     *
     * <p>方法名：deleteByPhotoId</p>
     */
    void deleteByPhotoId(Integer photoId);

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByUserIdOrderByCreatedAtDesc</p>
     */
    Page<PhotoFavorite> findByUserIdOrderByCreatedAtDesc(Integer userId, Pageable pageable);

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：countByUserId</p>
     */
    long countByUserId(Integer userId);

    List<PhotoFavorite> findByUserId(Integer userId);
}
