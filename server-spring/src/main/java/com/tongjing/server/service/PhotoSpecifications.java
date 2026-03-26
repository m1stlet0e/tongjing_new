package com.tongjing.server.service;

import com.tongjing.server.entity.Photo;
import com.tongjing.server.entity.PhotoTag;
import jakarta.persistence.criteria.Root;
import jakarta.persistence.criteria.Subquery;
import org.springframework.data.jpa.domain.Specification;

public final class PhotoSpecifications {

    private PhotoSpecifications() {}

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：cameraContains</p>
     */
    public static Specification<Photo> cameraContains(String camera) {
        return (root, query, cb) ->
                camera == null || camera.isEmpty()
                        ? cb.conjunction()
                        : cb.like(cb.lower(root.get("cameraModel")), "%" + camera.toLowerCase() + "%");
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：lensContains</p>
     */
    public static Specification<Photo> lensContains(String lens) {
        return (root, query, cb) ->
                lens == null || lens.isEmpty()
                        ? cb.conjunction()
                        : cb.like(cb.lower(root.get("lensModel")), "%" + lens.toLowerCase() + "%");
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：hasSceneTag</p>
     */
    public static Specification<Photo> hasSceneTag(String scene) {
        return (root, query, cb) -> {
            if (scene == null || scene.isEmpty()) {
                return cb.conjunction();
            }
            Subquery<Integer> sq = query.subquery(Integer.class);
            Root<PhotoTag> tag = sq.from(PhotoTag.class);
            sq.select(tag.get("photoId"));
            sq.where(cb.equal(tag.get("tagName"), scene));
            return root.get("id").in(sq);
        };
    }
}
