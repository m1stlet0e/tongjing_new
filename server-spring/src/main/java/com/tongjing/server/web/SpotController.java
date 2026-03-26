package com.tongjing.server.web;

import com.tongjing.server.security.CurrentUser;
import com.tongjing.server.service.SpotService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/spots")
@RequiredArgsConstructor
public class SpotController {

    private final SpotService spotService;

    @GetMapping("/my")
    public Map<String, Object> my(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int limit) {
        return spotService.mySpots(requireUser(), page, limit);
    }

    @GetMapping("/{id:\\d+}")
    /**
     * 查询并返回目标数据，必要时进行存在性校验与异常处理。
     *
     * <p>方法名：get</p>
     */
    public Map<String, Object> get(@PathVariable int id) {
        requireUser();
        return spotService.getSpot(id);
    }

    @PostMapping
    /**
     * 创建新数据记录并返回创建结果。
     *
     * <p>方法名：create</p>
     */
    public Map<String, Object> create(@RequestBody Map<String, Object> body) {
        int uid = requireUser();
        String name = str(body.get("name"));
        String locationName = str(body.get("location_name"));
        @SuppressWarnings("unchecked")
        List<String> tags = (List<String>) body.get("tags");
        String bestTime = str(body.get("best_time"));
        boolean isPublic =
                body.get("is_public") == null || Boolean.parseBoolean(body.get("is_public").toString());
        BigDecimal lat = decimal(body.get("latitude"));
        BigDecimal lng = decimal(body.get("longitude"));
        String cover = str(body.get("cover_image"));
        return spotService.createSpot(uid, name, locationName, lat, lng, cover, tags, bestTime, isPublic);
    }

    @DeleteMapping("/{id:\\d+}")
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：unlink</p>
     */
    public Map<String, Object> unlink(@PathVariable int id) {
        spotService.unlinkSpot(requireUser(), id);
        return Map.of("success", true, "message", "已移除");
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
