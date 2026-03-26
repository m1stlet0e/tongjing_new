package com.tongjing.server.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.tongjing.server.entity.Photo;
import com.tongjing.server.entity.Spot;
import com.tongjing.server.entity.UserSpot;
import com.tongjing.server.repository.PhotoRepository;
import com.tongjing.server.repository.SpotRepository;
import com.tongjing.server.repository.UserSpotRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
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
public class SpotService {

    private final UserSpotRepository userSpotRepository;
    private final SpotRepository spotRepository;
    private final PhotoRepository photoRepository;
    private final ObjectMapper objectMapper;

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：mySpots</p>
     */
    public Map<String, Object> mySpots(int userId, int page, int limit) {
        Pageable pageable = PageRequest.of(Math.max(0, page - 1), limit, Sort.by(Sort.Order.desc("createdAt")));
        Page<UserSpot> pageResult = userSpotRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        List<Map<String, Object>> spots = new ArrayList<>();
        for (UserSpot us : pageResult.getContent()) {
            if (us.getSpotId() == null) {
                continue;
            }
            Spot s = spotRepository.findById(us.getSpotId()).orElse(null);
            if (s == null) {
                continue;
            }
            spots.add(formatSpot(s));
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("spots", spots);
        data.put(
                "pagination",
                Map.of("page", page, "limit", limit, "total", userSpotRepository.countByUserId(userId)));
        return Map.of("success", true, "data", data);
    }

    /**
     * 查询并返回目标数据，必要时进行存在性校验与异常处理。
     *
     * <p>方法名：getSpot</p>
     */
    public Map<String, Object> getSpot(int id) {
        Spot s =
                spotRepository
                        .findById(id)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Spot not found"));
        List<Photo> photos =
                photoRepository.findAll().stream()
                        .filter(
                                p ->
                                        s.getLocationName() != null
                                                && s.getLocationName().equals(p.getLocationName()))
                        .limit(10)
                        .toList();
        Map<String, Object> data = new LinkedHashMap<>(formatSpot(s));
        List<Map<String, Object>> pl = new ArrayList<>();
        for (Photo p : photos) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", p.getId());
            m.put("image_url", p.getImageUrl());
            m.put("title", p.getTitle());
            m.put("likes_count", p.getLikesCount());
            pl.add(m);
        }
        data.put("photos", pl);
        return Map.of("success", true, "data", data);
    }

    @Transactional
    public Map<String, Object> createSpot(
            int userId,
            String name,
            String locationName,
            java.math.BigDecimal latitude,
            java.math.BigDecimal longitude,
            String coverImage,
            List<String> tags,
            String bestTime,
            boolean isPublic) {
        Spot s = new Spot();
        s.setName(name);
        s.setLocationName(locationName);
        s.setLatitude(latitude);
        s.setLongitude(longitude);
        s.setCoverImage(coverImage);
        if (tags != null && !tags.isEmpty()) {
            ArrayNode arr = objectMapper.createArrayNode();
            for (String t : tags) {
                arr.add(t);
            }
            s.setTags(arr);
        }
        s.setBestTime(bestTime != null ? bestTime : "全天");
        s.setIsPublic(isPublic);
        s.setCreatedBy(userId);
        s.setPhotoCount(0);
        s = spotRepository.save(s);
        UserSpot us = new UserSpot();
        us.setUserId(userId);
        us.setSpotId(s.getId());
        userSpotRepository.save(us);
        return Map.of("success", true, "data", formatSpot(s), "message", "Spot created successfully");
    }

    @Transactional
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：unlinkSpot</p>
     */
    public void unlinkSpot(int userId, int spotId) {
        userSpotRepository.deleteByUserIdAndSpotId(userId, spotId);
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：formatSpot</p>
     */
    private Map<String, Object> formatSpot(Spot s) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", s.getId());
        m.put("name", s.getName());
        m.put("location_name", s.getLocationName());
        m.put("image_url", s.getCoverImage());
        m.put("photo_count", s.getPhotoCount());
        if (s.getTags() != null && s.getTags().isArray()) {
            List<String> tl = new ArrayList<>();
            s.getTags().forEach(n -> tl.add(n.asText()));
            m.put("tags", tl);
        } else {
            m.put("tags", List.of());
        }
        m.put("best_time", s.getBestTime());
        m.put("is_public", s.getIsPublic());
        m.put("latitude", s.getLatitude());
        m.put("longitude", s.getLongitude());
        return m;
    }
}
