package com.tongjing.server.repository;

import com.tongjing.server.entity.PhotoLike;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface PhotoLikeRepository extends JpaRepository<PhotoLike, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByPhotoIdAndUserId</p>
     */
    Optional<PhotoLike> findByPhotoIdAndUserId(Integer photoId, Integer userId);

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
}
