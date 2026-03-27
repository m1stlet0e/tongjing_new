package com.tongjing.server.repository;

import com.tongjing.server.entity.ShootPlan;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ShootPlanRepository extends JpaRepository<ShootPlan, Long> {

    List<ShootPlan> findByUserIdOrderByCreatedAtDesc(Integer userId);

    Optional<ShootPlan> findByUserIdAndPhotoId(Integer userId, Integer photoId);
}
