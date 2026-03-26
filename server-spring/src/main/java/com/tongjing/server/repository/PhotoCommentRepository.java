package com.tongjing.server.repository;

import com.tongjing.server.entity.PhotoComment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PhotoCommentRepository extends JpaRepository<PhotoComment, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByPhotoIdOrderByCreatedAtDesc</p>
     */
    List<PhotoComment> findByPhotoIdOrderByCreatedAtDesc(Integer photoId, org.springframework.data.domain.Pageable pageable);

    /**
     * 删除目标数据并处理关联关系。
     *
     * <p>方法名：deleteByPhotoId</p>
     */
    void deleteByPhotoId(Integer photoId);
}
