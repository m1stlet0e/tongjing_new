package com.tongjing.server.web;

import com.tongjing.server.security.CurrentUser;
import com.tongjing.server.service.PhotoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/photos")
@RequiredArgsConstructor
public class PhotoController {

    private final PhotoService photoService;

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int limit,
            @RequestParam(defaultValue = "hot") String tab,
            @RequestParam(required = false) String camera,
            @RequestParam(required = false) String lens,
            @RequestParam(required = false) String scene) {
        Integer uid = CurrentUser.id().orElse(null);
        return photoService.listFeed(page, limit, tab, camera, lens, scene, uid);
    }

    @GetMapping("/my")
    public Map<String, Object> my(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int limit) {
        int uid = requireUser();
        return photoService.listMy(uid, page, limit);
    }

    @GetMapping("/favorites")
    public Map<String, Object> favorites(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int limit) {
        int uid = requireUser();
        return photoService.listFavorites(uid, page, limit);
    }

    @GetMapping("/{id:\\d+}")
    /**
     * 根据主键查询详情数据，包含当前用户上下文相关的附加字段。
     *
     * <p>方法名：detail</p>
     */
    public Map<String, Object> detail(@PathVariable int id) {
        Integer uid = CurrentUser.id().orElse(null);
        return photoService.getDetail(id, uid);
    }

    @PostMapping
    /**
     * 创建并发布新内容，校验请求体后调用服务层完成落库与返回。
     *
     * <p>方法名：publish</p>
     */
    public Map<String, Object> publish(@RequestBody Map<String, Object> body) {
        int uid = requireUser();
        String imageUrl = str(body.get("image_url"));
        String title = str(body.get("title"));
        @SuppressWarnings("unchecked")
        List<Map<String, String>> tags = (List<Map<String, String>>) body.get("tags");
        @SuppressWarnings("unchecked")
        Map<String, Object> exif = (Map<String, Object>) body.get("exif_data");
        BigDecimal lat = decimal(body.get("latitude"));
        BigDecimal lng = decimal(body.get("longitude"));
        return photoService.publish(
                uid,
                imageUrl,
                title,
                str(body.get("description")),
                str(body.get("shooting_tips")),
                tags,
                lat,
                lng,
                str(body.get("location_name")),
                exif);
    }

    @PostMapping("/{id:\\d+}/like")
    /**
     * 切换点赞状态，返回当前点赞结果与统计信息。
     *
     * <p>方法名：like</p>
     */
    public Map<String, Object> like(@PathVariable int id) {
        return photoService.toggleLike(id, requireUser());
    }

    @PostMapping("/{id:\\d+}/favorite")
    /**
     * 切换收藏状态，返回当前收藏结果与统计信息。
     *
     * <p>方法名：favorite</p>
     */
    public Map<String, Object> favorite(@PathVariable int id) {
        return photoService.toggleFavorite(id, requireUser());
    }

    @PostMapping("/{id:\\d+}/comments")
    /**
     * 新增评论内容并返回评论操作结果。
     *
     * <p>方法名：comment</p>
     */
    public Map<String, Object> comment(@PathVariable int id, @RequestBody Map<String, Object> body) {
        String content = str(body.get("content"));
        return photoService.addComment(id, requireUser(), content);
    }

    @DeleteMapping("/{id:\\d+}")
    /**
     * 删除指定资源，并返回删除成功标记。
     *
     * <p>方法名：delete</p>
     */
    public Map<String, Object> delete(@PathVariable int id) {
        photoService.deletePhoto(id, requireUser());
        return Map.of("success", true, "message", "照片已删除");
    }

    /**
     * 从上下文获取当前登录用户 ID；若未登录则抛出 401 异常。
     *
     * <p>方法名：requireUser</p>
     */
    private static int requireUser() {
        return CurrentUser.id()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "请先登录"));
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
     * 将输入值转换为十进制数值，适配经纬度等字段解析。
     *
     * <p>方法名：decimal</p>
     */
    private static BigDecimal decimal(Object o) {
        if (o == null) {
            return null;
        }
        if (o instanceof BigDecimal b) {
            return b;
        }
        if (o instanceof Number n) {
            return BigDecimal.valueOf(n.doubleValue());
        }
        try {
            return new BigDecimal(o.toString());
        } catch (Exception e) {
            return null;
        }
    }
}
