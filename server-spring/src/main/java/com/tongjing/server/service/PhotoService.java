package com.tongjing.server.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.tongjing.server.entity.*;
import com.tongjing.server.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PhotoService {

    private final PhotoRepository photoRepository;
    private final PhotoTagRepository photoTagRepository;
    private final PhotoLikeRepository photoLikeRepository;
    private final PhotoFavoriteRepository photoFavoriteRepository;
    private final PhotoCommentRepository photoCommentRepository;
    private final UserRepository userRepository;

    public Map<String, Object> listFeed(
            int page, int limit, String tab, String camera, String lens, String scene, Integer currentUserId) {
        Specification<Photo> spec =
                Specification.where(PhotoSpecifications.cameraContains(camera))
                        .and(PhotoSpecifications.lensContains(lens))
                        .and(PhotoSpecifications.hasSceneTag(scene));
        if ("following".equals(tab)) {
            spec = spec.and(PhotoSpecifications.authoredByFollowedUsers(currentUserId));
        }
        Sort sort =
                "hot".equals(tab)
                        ? Sort.by(Sort.Order.desc("likesCount"), Sort.Order.desc("createdAt"))
                        : Sort.by(Sort.Order.desc("createdAt"));
        Pageable pageable = PageRequest.of(Math.max(0, page - 1), limit, sort);
        Page<Photo> result = photoRepository.findAll(spec, pageable);
        List<Map<String, Object>> photos =
                enrichPhotos(result.getContent(), currentUserId);
        long total = result.getTotalElements();
        return wrapPage(photos, page, limit, total);
    }

    /**
     * 按条件查询列表数据并返回分页或集合结果。
     *
     * <p>方法名：listMy</p>
     */
    public Map<String, Object> listMy(int userId, int page, int limit) {
        Pageable pageable = PageRequest.of(Math.max(0, page - 1), limit, Sort.by(Sort.Order.desc("createdAt")));
        Page<Photo> result = photoRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        List<Map<String, Object>> list = new ArrayList<>();
        for (Photo p : result.getContent()) {
            list.add(photoToMap(p, null, List.of(), false, false));
        }
        return wrapPage(list, page, limit, result.getTotalElements());
    }

    /**
     * 按条件查询列表数据并返回分页或集合结果。
     *
     * <p>方法名：listFavorites</p>
     */
    public Map<String, Object> listFavorites(int userId, int page, int limit) {
        Pageable pageable = PageRequest.of(Math.max(0, page - 1), limit, Sort.by(Sort.Order.desc("createdAt")));
        Page<PhotoFavorite> favs = photoFavoriteRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        List<Photo> photos =
                favs.getContent().stream()
                        .map(f -> photoRepository.findById(f.getPhotoId()).orElse(null))
                        .filter(Objects::nonNull)
                        .toList();
        List<Map<String, Object>> list = enrichPhotos(photos, userId);
        return wrapPage(list, page, limit, photoFavoriteRepository.countByUserId(userId));
    }

    /**
     * 查询照片详情并合并作者、标签、互动状态等扩展信息。
     *
     * <p>方法名：getDetail</p>
     */
    public Map<String, Object> getDetail(int id, Integer currentUserId) {
        Photo p =
                photoRepository
                        .findById(id)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo not found"));
        User author = p.getUserId() != null ? userRepository.findById(p.getUserId()).orElse(null) : null;
        List<PhotoTag> tags = photoTagRepository.findByPhotoId(id);
        boolean liked =
                currentUserId != null
                        && photoLikeRepository.findByPhotoIdAndUserId(id, currentUserId).isPresent();
        boolean fav =
                currentUserId != null
                        && photoFavoriteRepository.findByPhotoIdAndUserId(id, currentUserId).isPresent();
        Map<String, Object> map = photoToMap(p, author, tags, liked, fav);
        Pageable cm = PageRequest.of(0, 20);
        List<PhotoComment> comments = photoCommentRepository.findByPhotoIdOrderByCreatedAtDesc(id, cm);
        List<Map<String, Object>> cmaps = new ArrayList<>();
        for (PhotoComment c : comments) {
            User u = userRepository.findById(c.getUserId()).orElse(null);
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", c.getId());
            m.put("photo_id", c.getPhotoId());
            m.put("user_id", c.getUserId());
            m.put("content", c.getContent());
            m.put("created_at", c.getCreatedAt() != null ? c.getCreatedAt().toString() : null);
            if (u != null) {
                m.put("username", u.getUsername());
                m.put("avatar_url", u.getAvatarUrl());
            }
            cmaps.add(m);
        }
        map.put("comments", cmaps);
        if (author != null) {
            map.put("user_bio", author.getBio());
        }
        return Map.of("success", true, "data", map);
    }

    @Transactional
    public Map<String, Object> publish(
            int userId,
            String imageUrl,
            String title,
            String description,
            String shootingTips,
            List<Map<String, String>> tags,
            BigDecimal latitude,
            BigDecimal longitude,
            String locationName,
            Map<String, Object> exifData) {
        Map<String, Object> ex = exifData != null ? exifData : Map.of();
        Photo p = new Photo();
        p.setUserId(userId);
        p.setImageUrl(imageUrl);
        p.setTitle(title);
        p.setDescription(description);
        p.setShootingTips(shootingTips);
        p.setLatitude(latitude);
        p.setLongitude(longitude);
        p.setLocationName(locationName);
        p.setCameraBrand(str(ex.get("camera_brand")));
        p.setCameraModel(str(ex.get("camera_model")));
        p.setLensModel(str(ex.get("lens_model")));
        p.setFocalLength(str(ex.get("focal_length")));
        p.setAperture(str(ex.get("aperture")));
        p.setShutterSpeed(str(ex.get("shutter_speed")));
        p.setIso(intVal(ex.get("iso")));
        p.setWhiteBalance(str(ex.get("white_balance")));
        p = photoRepository.save(p);
        if (tags != null) {
            for (Map<String, String> t : tags) {
                if (t == null) {
                    continue;
                }
                PhotoTag pt = new PhotoTag();
                pt.setPhotoId(p.getId());
                pt.setTagName(t.getOrDefault("name", t.get("tag_name")));
                pt.setTagType(t.getOrDefault("type", t.getOrDefault("tag_type", "scene")));
                photoTagRepository.save(pt);
            }
        }
        return Map.of("success", true, "data", photoToMap(p, null, List.of(), false, false), "message", "Photo published successfully");
    }

    @Transactional
    /**
     * 执行点赞状态切换并同步更新计数。
     *
     * <p>方法名：toggleLike</p>
     */
    public Map<String, Object> toggleLike(int photoId, int userId) {
        var existing = photoLikeRepository.findByPhotoIdAndUserId(photoId, userId);
        Photo p = photoRepository.findById(photoId).orElseThrow(() -> notFound("照片不存在"));
        if (existing.isPresent()) {
            photoLikeRepository.delete(existing.get());
            p.setLikesCount(Math.max(0, nz(p.getLikesCount()) - 1));
            photoRepository.save(p);
            return Map.of("success", true, "data", Map.of("is_liked", false), "message", "Unliked");
        }
        PhotoLike like = new PhotoLike();
        like.setPhotoId(photoId);
        like.setUserId(userId);
        photoLikeRepository.save(like);
        p.setLikesCount(nz(p.getLikesCount()) + 1);
        photoRepository.save(p);
        return Map.of("success", true, "data", Map.of("is_liked", true), "message", "Liked");
    }

    @Transactional
    /**
     * 执行收藏状态切换并同步更新计数。
     *
     * <p>方法名：toggleFavorite</p>
     */
    public Map<String, Object> toggleFavorite(int photoId, int userId) {
        var existing = photoFavoriteRepository.findByPhotoIdAndUserId(photoId, userId);
        Photo p = photoRepository.findById(photoId).orElseThrow(() -> notFound("照片不存在"));
        if (existing.isPresent()) {
            photoFavoriteRepository.delete(existing.get());
            p.setFavoritesCount(Math.max(0, nz(p.getFavoritesCount()) - 1));
            photoRepository.save(p);
            return Map.of("success", true, "data", Map.of("is_favorited", false), "message", "Unfavorited");
        }
        PhotoFavorite f = new PhotoFavorite();
        f.setPhotoId(photoId);
        f.setUserId(userId);
        photoFavoriteRepository.save(f);
        p.setFavoritesCount(nz(p.getFavoritesCount()) + 1);
        photoRepository.save(p);
        return Map.of("success", true, "data", Map.of("is_favorited", true), "message", "Favorited");
    }

    @Transactional
    /**
     * 新增评论并同步评论数，返回评论数据与操作结果。
     *
     * <p>方法名：addComment</p>
     */
    public Map<String, Object> addComment(int photoId, int userId, String content) {
        if (content == null || content.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "评论内容不能为空");
        }
        Photo p = photoRepository.findById(photoId).orElseThrow(() -> notFound("照片不存在"));
        PhotoComment c = new PhotoComment();
        c.setPhotoId(photoId);
        c.setUserId(userId);
        c.setContent(content.trim());
        c = photoCommentRepository.save(c);
        p.setCommentsCount(nz(p.getCommentsCount()) + 1);
        photoRepository.save(p);
        User u = userRepository.findById(userId).orElseThrow();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.getId());
        m.put("photo_id", c.getPhotoId());
        m.put("user_id", c.getUserId());
        m.put("content", c.getContent());
        m.put("created_at", c.getCreatedAt() != null ? c.getCreatedAt().toString() : null);
        m.put("username", u.getUsername());
        m.put("avatar_url", u.getAvatarUrl());
        return Map.of("success", true, "data", m, "message", "Comment added");
    }

    @Transactional
    /**
     * 校验权限后删除照片及关联数据。
     *
     * <p>方法名：deletePhoto</p>
     */
    public void deletePhoto(int photoId, int userId) {
        Photo p = photoRepository.findById(photoId).orElseThrow(() -> notFound("照片不存在"));
        if (!Objects.equals(p.getUserId(), userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权删除此照片");
        }
        photoLikeRepository.deleteByPhotoId(photoId);
        photoFavoriteRepository.deleteByPhotoId(photoId);
        photoCommentRepository.deleteByPhotoId(photoId);
        photoTagRepository.deleteAll(photoTagRepository.findByPhotoId(photoId));
        photoRepository.delete(p);
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：enrichPhotos</p>
     */
    private List<Map<String, Object>> enrichPhotos(List<Photo> photos, Integer currentUserId) {
        if (photos.isEmpty()) {
            return List.of();
        }
        Set<Integer> userIds =
                photos.stream().map(Photo::getUserId).filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Integer, User> users =
                userRepository.findAllById(userIds).stream()
                        .collect(Collectors.toMap(User::getId, u -> u));
        List<Integer> ids = photos.stream().map(Photo::getId).toList();
        Map<Integer, List<PhotoTag>> tagsBy =
                photoTagRepository.findByPhotoIdIn(ids).stream()
                        .collect(Collectors.groupingBy(PhotoTag::getPhotoId));
        List<Map<String, Object>> out = new ArrayList<>();
        for (Photo p : photos) {
            User u = p.getUserId() != null ? users.get(p.getUserId()) : null;
            List<PhotoTag> tags = tagsBy.getOrDefault(p.getId(), List.of());
            boolean liked =
                    currentUserId != null
                            && photoLikeRepository.findByPhotoIdAndUserId(p.getId(), currentUserId).isPresent();
            boolean fav =
                    currentUserId != null
                            && photoFavoriteRepository.findByPhotoIdAndUserId(p.getId(), currentUserId)
                                    .isPresent();
            out.add(photoToMap(p, u, tags, liked, fav));
        }
        return out;
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：wrapPage</p>
     */
    private Map<String, Object> wrapPage(List<Map<String, Object>> photos, int page, int limit, long total) {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("photos", photos);
        Map<String, Object> pagination = new LinkedHashMap<>();
        pagination.put("page", page);
        pagination.put("limit", limit);
        pagination.put("total", total);
        data.put("pagination", pagination);
        return Map.of("success", true, "data", data);
    }

    private Map<String, Object> photoToMap(
            Photo p, User author, List<PhotoTag> tags, boolean liked, boolean fav) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", p.getId());
        m.put("user_id", p.getUserId());
        m.put("image_url", p.getImageUrl());
        m.put("title", p.getTitle());
        m.put("description", p.getDescription());
        m.put("camera_brand", p.getCameraBrand());
        m.put("camera_model", p.getCameraModel());
        m.put("lens_model", p.getLensModel());
        m.put("focal_length", p.getFocalLength());
        m.put("aperture", p.getAperture());
        m.put("shutter_speed", p.getShutterSpeed());
        m.put("iso", p.getIso());
        m.put("white_balance", p.getWhiteBalance());
        m.put("latitude", p.getLatitude());
        m.put("longitude", p.getLongitude());
        m.put("location_name", p.getLocationName());
        m.put("shooting_tips", p.getShootingTips());
        m.put("likes_count", p.getLikesCount());
        m.put("comments_count", p.getCommentsCount());
        m.put("favorites_count", p.getFavoritesCount());
        m.put("created_at", p.getCreatedAt() != null ? p.getCreatedAt().toString() : null);
        m.put("updated_at", p.getUpdatedAt() != null ? p.getUpdatedAt().toString() : null);
        if (author != null) {
            m.put("username", author.getUsername());
            m.put("avatar_url", author.getAvatarUrl());
        }
        List<Map<String, Object>> tagList = new ArrayList<>();
        for (PhotoTag t : tags) {
            Map<String, Object> tm = new LinkedHashMap<>();
            tm.put("tag_name", t.getTagName());
            tm.put("tag_type", t.getTagType());
            tagList.add(tm);
        }
        m.put("tags", tagList);
        m.put("is_liked", liked);
        m.put("is_favorited", fav);
        return m;
    }

    /**
     * 将对象安全转换为字符串，空值时返回 null。
     *
     * <p>方法名：str</p>
     */
    private static String str(Object o) {
        return o == null ? null : o.toString();
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：intVal</p>
     */
    private static Integer intVal(Object o) {
        if (o == null) {
            return null;
        }
        if (o instanceof Number n) {
            return n.intValue();
        }
        try {
            return Integer.parseInt(o.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：nz</p>
     */
    private static int nz(Integer i) {
        return i == null ? 0 : i;
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：notFound</p>
     */
    private static ResponseStatusException notFound(String m) {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, m);
    }
}
