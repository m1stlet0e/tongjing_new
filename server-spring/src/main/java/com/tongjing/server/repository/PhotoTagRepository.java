package com.tongjing.server.repository;

import com.tongjing.server.entity.PhotoTag;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;

public interface PhotoTagRepository extends JpaRepository<PhotoTag, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByPhotoId</p>
     */
    List<PhotoTag> findByPhotoId(Integer photoId);

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByPhotoIdIn</p>
     */
    List<PhotoTag> findByPhotoIdIn(Collection<Integer> photoIds);
}
