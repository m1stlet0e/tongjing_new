package com.tongjing.server.service;

import com.tongjing.server.entity.*;
import com.tongjing.server.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final PhotoRepository photoRepository;
    private final PhotoLikeRepository photoLikeRepository;
    private final PhotoFavoriteRepository photoFavoriteRepository;
    private final UserFollowRepository userFollowRepository;

    /**
     * 查询当前用户资料与统计信息并返回标准响应对象。
     *
     * <p>方法名：me</p>
     */
    public Map<String, Object> me(int userId) {
        User u =
                userRepository
                        .findById(userId)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        return Map.of("success", true, "data", enrichUserStats(u));
    }

    @Transactional
    /**
     * 部分更新当前用户资料，仅修改请求中显式提供的字段。
     *
     * <p>方法名：patchMe</p>
     */
    public Map<String, Object> patchMe(int userId, String username, String bio, String avatarUrl) {
        User u =
                userRepository
                        .findById(userId)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        if (username == null && bio == null && avatarUrl == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "没有要更新的内容");
        }
        if (username != null) {
            u.setUsername(username);
        }
        if (bio != null) {
            u.setBio(bio);
        }
        if (avatarUrl != null) {
            u.setAvatarUrl(avatarUrl);
        }
        u.setUpdatedAt(java.time.Instant.now());
        u = userRepository.save(u);
        return Map.of("success", true, "data", u, "message", "更新成功");
    }

    /**
     * 按用户 ID 查询公开资料，并补充当前登录用户的关注关系状态。
     *
     * <p>方法名：getUser</p>
     */
    public Map<String, Object> getUser(int id, Integer currentUserId) {
        User u =
                userRepository
                        .findById(id)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        Map<String, Object> data = enrichUserStats(u);
        boolean following = false;
        if (currentUserId != null) {
            following =
                    userFollowRepository
                            .findByFollowerIdAndFollowingId(currentUserId, id)
                            .isPresent();
        }
        data.put("is_following", following);
        return Map.of("success", true, "data", data);
    }

    /**
     * 查询指定用户发布的照片列表，并补充点赞/收藏状态。
     *
     * <p>方法名：userPhotos</p>
     */
    public Map<String, Object> userPhotos(int id, int page, int limit, Integer currentUserId) {
        userRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        Pageable pageable = PageRequest.of(Math.max(0, page - 1), limit, Sort.by(Sort.Order.desc("createdAt")));
        Page<Photo> result = photoRepository.findByUserIdOrderByCreatedAtDesc(id, pageable);
        List<Map<String, Object>> list = new ArrayList<>();
        for (Photo p : result.getContent()) {
            boolean liked =
                    currentUserId != null
                            && photoLikeRepository.findByPhotoIdAndUserId(p.getId(), currentUserId).isPresent();
            boolean fav =
                    currentUserId != null
                            && photoFavoriteRepository.findByPhotoIdAndUserId(p.getId(), currentUserId).isPresent();
            Map<String, Object> m = new LinkedHashMap<>();
            m.putAll(photoShallow(p));
            m.put("is_liked", liked);
            m.put("is_favorited", fav);
            list.add(m);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("photos", list);
        data.put(
                "pagination",
                Map.of("page", page, "limit", limit, "total", photoRepository.countByUserId(id)));
        return Map.of("success", true, "data", data);
    }

    /**
     * 查询指定用户收藏的照片列表并组装前端展示字段。
     *
     * <p>方法名：userFavorites</p>
     */
    public Map<String, Object> userFavorites(int id, int page, int limit, Integer currentUserId) {
        userRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        Pageable pageable = PageRequest.of(Math.max(0, page - 1), limit, Sort.by(Sort.Order.desc("createdAt")));
        Page<PhotoFavorite> favs = photoFavoriteRepository.findByUserIdOrderByCreatedAtDesc(id, pageable);
        List<Map<String, Object>> photos = new ArrayList<>();
        for (PhotoFavorite f : favs.getContent()) {
            Photo p = photoRepository.findById(f.getPhotoId()).orElse(null);
            if (p == null) {
                continue;
            }
            User author = p.getUserId() != null ? userRepository.findById(p.getUserId()).orElse(null) : null;
            boolean liked =
                    currentUserId != null
                            && photoLikeRepository.findByPhotoIdAndUserId(p.getId(), currentUserId).isPresent();
            Map<String, Object> m = new LinkedHashMap<>();
            m.putAll(photoShallow(p));
            if (author != null) {
                m.put("username", author.getUsername());
                m.put("avatar_url", author.getAvatarUrl());
            }
            m.put("favorited_at", f.getCreatedAt() != null ? f.getCreatedAt().toString() : null);
            m.put("is_liked", liked);
            m.put("is_favorited", true);
            photos.add(m);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("photos", photos);
        data.put(
                "pagination",
                Map.of("page", page, "limit", limit, "total", photoFavoriteRepository.countByUserId(id)));
        return Map.of("success", true, "data", data);
    }

    /**
     * 聚合用户拍摄足迹坐标，生成地图展示所需的地点与照片数据。
     *
     * <p>方法名：footprint</p>
     */
    public Map<String, Object> footprint(int id) {
        userRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
        List<Photo> photos =
                photoRepository.findByUserId(id).stream()
                        .filter(p -> p.getLatitude() != null && p.getLongitude() != null)
                        .toList();
        Map<String, Map<String, Object>> map = new LinkedHashMap<>();
        for (Photo p : photos) {
            String key =
                    p.getLocationName() != null
                            ? p.getLocationName()
                            : p.getLatitude() + "," + p.getLongitude();
            map.compute(
                    key,
                    (k, v) -> {
                        if (v == null) {
                            Map<String, Object> m = new LinkedHashMap<>();
                            m.put("latitude", p.getLatitude());
                            m.put("longitude", p.getLongitude());
                            m.put("location_name", p.getLocationName());
                            m.put("photo_count", 1);
                            List<Map<String, Object>> pl = new ArrayList<>();
                            pl.add(photoTiny(p));
                            m.put("photos", pl);
                            return m;
                        }
                        v.put("photo_count", (Integer) v.get("photo_count") + 1);
                        @SuppressWarnings("unchecked")
                        List<Map<String, Object>> pl = (List<Map<String, Object>>) v.get("photos");
                        pl.add(photoTiny(p));
                        return v;
                    });
        }
        return Map.of("success", true, "data", new ArrayList<>(map.values()));
    }

    @Transactional
    /**
     * 执行类型转换或结构映射并返回转换结果。
     *
     * <p>方法名：toggleFollow</p>
     */
    public Map<String, Object> toggleFollow(int currentUserId, int targetId) {
        if (currentUserId == targetId) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot follow yourself");
        }
        userRepository.findById(targetId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "用户不存在"));
        var ex = userFollowRepository.findByFollowerIdAndFollowingId(currentUserId, targetId);
        if (ex.isPresent()) {
            userFollowRepository.delete(ex.get());
            return Map.of("success", true, "data", Map.of("is_following", false), "message", "Unfollowed");
        }
        UserFollow f = new UserFollow();
        f.setFollowerId(currentUserId);
        f.setFollowingId(targetId);
        userFollowRepository.save(f);
        return Map.of("success", true, "data", Map.of("is_following", true), "message", "Followed");
    }

    /**
     * 补充用户统计字段（作品数、获赞数、关注关系等）并返回。
     *
     * <p>方法名：enrichUserStats</p>
     */
    private Map<String, Object> enrichUserStats(User u) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", u.getId());
        m.put("username", u.getUsername());
        m.put("avatar_url", u.getAvatarUrl());
        m.put("bio", u.getBio());
        m.put("phone", u.getPhone());
        m.put("created_at", u.getCreatedAt() != null ? u.getCreatedAt().toString() : null);
        m.put("updated_at", u.getUpdatedAt() != null ? u.getUpdatedAt().toString() : null);
        m.put("photos_count", photoRepository.countByUserId(u.getId()));
        m.put("followers_count", userFollowRepository.countByFollowingId(u.getId()));
        m.put("following_count", userFollowRepository.countByFollowerId(u.getId()));
        return m;
    }

    /**
     * 构建照片精简视图模型，减少列表接口返回负载。
     *
     * <p>方法名：photoShallow</p>
     */
    private static Map<String, Object> photoShallow(Photo p) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", p.getId());
        m.put("image_url", p.getImageUrl());
        m.put("title", p.getTitle());
        m.put("description", p.getDescription());
        m.put("likes_count", p.getLikesCount());
        m.put("comments_count", p.getCommentsCount());
        m.put("favorites_count", p.getFavoritesCount());
        m.put("created_at", p.getCreatedAt() != null ? p.getCreatedAt().toString() : null);
        return m;
    }

    /**
     * 构建最小化照片视图，用于地图点位或聚合结果。
     *
     * <p>方法名：photoTiny</p>
     */
    private static Map<String, Object> photoTiny(Photo p) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", p.getId());
        m.put("latitude", p.getLatitude());
        m.put("longitude", p.getLongitude());
        m.put("location_name", p.getLocationName());
        m.put("image_url", p.getImageUrl());
        m.put("title", p.getTitle());
        return m;
    }
}
