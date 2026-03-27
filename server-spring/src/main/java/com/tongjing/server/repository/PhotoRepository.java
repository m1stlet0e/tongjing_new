package com.tongjing.server.repository;

import com.tongjing.server.entity.Photo;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;

public interface PhotoRepository extends JpaRepository<Photo, Integer>, JpaSpecificationExecutor<Photo> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByUserIdOrderByCreatedAtDesc</p>
     */
    Page<Photo> findByUserIdOrderByCreatedAtDesc(Integer userId, Pageable pageable);

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：countByUserId</p>
     */
    long countByUserId(Integer userId);

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByUserId</p>
     */
    List<Photo> findByUserId(Integer userId);

    List<Photo> findAllByIdIn(List<Integer> ids);

    List<Photo> findAll(org.springframework.data.jpa.domain.Specification<Photo> spec, Sort sort);

    @Query(
            "SELECT p FROM Photo p WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL "
                    + "AND p.latitude >= :latMin AND p.latitude <= :latMax "
                    + "AND p.longitude >= :lngMin AND p.longitude <= :lngMax "
                    + "ORDER BY p.likesCount DESC")
    List<Photo> findInBounds(
            @Param("latMin") BigDecimal latMin,
            @Param("latMax") BigDecimal latMax,
            @Param("lngMin") BigDecimal lngMin,
            @Param("lngMax") BigDecimal lngMax,
            Pageable pageable);
}
