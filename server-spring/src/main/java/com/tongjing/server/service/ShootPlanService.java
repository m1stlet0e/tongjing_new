package com.tongjing.server.service;

import com.tongjing.server.entity.ShootPlan;
import com.tongjing.server.repository.PhotoRepository;
import com.tongjing.server.repository.ShootPlanRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ShootPlanService {

    private final ShootPlanRepository shootPlanRepository;
    private final PhotoRepository photoRepository;

    public Map<String, Object> list(int userId) {
        List<ShootPlan> rows = shootPlanRepository.findByUserIdOrderByCreatedAtDesc(userId);
        List<Map<String, Object>> plans = new ArrayList<>();
        for (ShootPlan p : rows) {
            plans.add(toMap(p));
        }
        return Map.of("success", true, "data", Map.of("plans", plans));
    }

    @Transactional
    public Map<String, Object> upsert(
            int userId,
            int photoId,
            String title,
            String location,
            String imageUrl,
            String cameraLine,
            String tips,
            Boolean done) {
        photoRepository
                .findById(photoId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "作品不存在"));
        if (imageUrl == null || imageUrl.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "image_url 不能为空");
        }
        ShootPlan p =
                shootPlanRepository
                        .findByUserIdAndPhotoId(userId, photoId)
                        .orElseGet(
                                () -> {
                                    ShootPlan n = new ShootPlan();
                                    n.setUserId(userId);
                                    n.setPhotoId(photoId);
                                    return n;
                                });
        p.setTitle(title);
        p.setLocation(location);
        p.setImageUrl(imageUrl);
        p.setCameraLine(cameraLine);
        p.setTips(tips);
        if (done != null) {
            p.setDone(done);
        }
        p = shootPlanRepository.save(p);
        return Map.of("success", true, "data", toMap(p), "message", "已更新拍摄计划");
    }

    @Transactional
    public Map<String, Object> setDone(int userId, long planId, boolean done) {
        ShootPlan p =
                shootPlanRepository
                        .findById(planId)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "计划不存在"));
        if (!p.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作");
        }
        p.setDone(done);
        shootPlanRepository.save(p);
        return Map.of("success", true, "data", toMap(p));
    }

    @Transactional
    public Map<String, Object> delete(int userId, long planId) {
        ShootPlan p =
                shootPlanRepository
                        .findById(planId)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "计划不存在"));
        if (!p.getUserId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权操作");
        }
        shootPlanRepository.delete(p);
        return Map.of("success", true, "message", "已移除");
    }

    private static Map<String, Object> toMap(ShootPlan p) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", p.getId());
        m.put("photo_id", p.getPhotoId());
        m.put("title", p.getTitle());
        m.put("location", p.getLocation());
        m.put("image_url", p.getImageUrl());
        m.put("camera_line", p.getCameraLine());
        m.put("tips", p.getTips());
        m.put("done", p.isDone());
        m.put("created_at", p.getCreatedAt() != null ? p.getCreatedAt().toString() : null);
        m.put("updated_at", p.getUpdatedAt() != null ? p.getUpdatedAt().toString() : null);
        return m;
    }
}
