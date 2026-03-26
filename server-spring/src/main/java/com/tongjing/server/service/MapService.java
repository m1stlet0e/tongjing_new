package com.tongjing.server.service;

import com.tongjing.server.entity.Photo;
import com.tongjing.server.entity.User;
import com.tongjing.server.repository.PhotoRepository;
import com.tongjing.server.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MapService {

    private final PhotoRepository photoRepository;
    private final UserRepository userRepository;

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：photosNear</p>
     */
    public Map<String, Object> photosNear(BigDecimal lat, BigDecimal lng, double radiusKm, int limit) {
        double latNum = lat.doubleValue();
        double lngNum = lng.doubleValue();
        double latRange = radiusKm / 111.0;
        double lngRange = radiusKm / (111.0 * Math.cos(Math.toRadians(latNum)));
        BigDecimal latMin = BigDecimal.valueOf(latNum - latRange);
        BigDecimal latMax = BigDecimal.valueOf(latNum + latRange);
        BigDecimal lngMin = BigDecimal.valueOf(lngNum - lngRange);
        BigDecimal lngMax = BigDecimal.valueOf(lngNum + lngRange);
        List<Photo> list =
                photoRepository.findInBounds(latMin, latMax, lngMin, lngMax, PageRequest.of(0, limit));
        Set<Integer> uids =
                list.stream().map(Photo::getUserId).filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Integer, User> users =
                userRepository.findAllById(uids).stream().collect(Collectors.toMap(User::getId, u -> u));
        List<Map<String, Object>> out = new ArrayList<>();
        for (Photo p : list) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", p.getId());
            m.put("title", p.getTitle());
            m.put("image_url", p.getImageUrl());
            m.put("latitude", p.getLatitude());
            m.put("longitude", p.getLongitude());
            m.put("location_name", p.getLocationName());
            m.put("camera_model", p.getCameraModel());
            m.put("lens_model", p.getLensModel());
            m.put("likes_count", p.getLikesCount());
            if (p.getUserId() != null && users.containsKey(p.getUserId())) {
                m.put("username", users.get(p.getUserId()).getUsername());
            }
            out.add(m);
        }
        return Map.of("success", true, "data", out);
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：searchLocation</p>
     */
    public Map<String, Object> searchLocation(String locationName) {
        List<Photo> all =
                photoRepository.findAll().stream()
                        .filter(
                                p ->
                                        p.getLocationName() != null
                                                && p.getLocationName().toLowerCase().contains(locationName.toLowerCase()))
                        .sorted(Comparator.comparingInt(p -> -nz(p.getLikesCount())))
                        .limit(20)
                        .toList();
        List<Map<String, Object>> out = new ArrayList<>();
        for (Photo p : all) {
            User u = p.getUserId() != null ? userRepository.findById(p.getUserId()).orElse(null) : null;
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", p.getId());
            m.put("image_url", p.getImageUrl());
            m.put("title", p.getTitle());
            m.put("location_name", p.getLocationName());
            m.put("likes_count", p.getLikesCount());
            if (u != null) {
                m.put("username", u.getUsername());
                m.put("avatar_url", u.getAvatarUrl());
            }
            out.add(m);
        }
        return Map.of("success", true, "data", out);
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：popularSpots</p>
     */
    public Map<String, Object> popularSpots() {
        List<Photo> withLoc =
                photoRepository.findAll().stream()
                        .filter(p -> p.getLatitude() != null && p.getLongitude() != null)
                        .filter(p -> p.getLocationName() != null && !p.getLocationName().isBlank())
                        .toList();
        Map<String, Agg> agg = new LinkedHashMap<>();
        for (Photo p : withLoc) {
            String key = p.getLocationName();
            agg.compute(
                    key,
                    (k, v) -> {
                        if (v == null) {
                            return new Agg(
                                    p.getLocationName(),
                                    p.getLatitude(),
                                    p.getLongitude(),
                                    1,
                                    nz(p.getLikesCount()));
                        }
                        v.photoCount++;
                        v.totalLikes += nz(p.getLikesCount());
                        return v;
                    });
        }
        List<Map<String, Object>> spots =
                agg.values().stream()
                        .sorted(
                                (a, b) ->
                                        b.photoCount != a.photoCount
                                                ? Integer.compare(b.photoCount, a.photoCount)
                                                : Integer.compare(b.totalLikes, a.totalLikes))
                        .limit(20)
                        .map(
                                a -> {
                                    Map<String, Object> m = new LinkedHashMap<>();
                                    m.put("location_name", a.locationName);
                                    m.put("latitude", a.lat);
                                    m.put("longitude", a.lng);
                                    m.put("photo_count", a.photoCount);
                                    m.put("total_likes", a.totalLikes);
                                    return m;
                                })
                        .toList();
        return Map.of("success", true, "data", spots);
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：nz</p>
     */
    private static int nz(Integer i) {
        return i == null ? 0 : i;
    }

    private static final class Agg {
        private final String locationName;
        private final BigDecimal lat;
        private final BigDecimal lng;
        private int photoCount;
        private int totalLikes;

        private Agg(
                String locationName,
                BigDecimal lat,
                BigDecimal lng,
                int photoCount,
                int totalLikes) {
            this.locationName = locationName;
            this.lat = lat;
            this.lng = lng;
            this.photoCount = photoCount;
            this.totalLikes = totalLikes;
        }
    }
}
