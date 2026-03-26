package com.tongjing.server.web;

import com.tongjing.server.security.CurrentUser;
import com.tongjing.server.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/me")
    /**
     * 查询当前用户资料与统计信息并返回标准响应对象。
     *
     * <p>方法名：me</p>
     */
    public Map<String, Object> me() {
        return userService.me(requireUser());
    }

    @PatchMapping("/me")
    /**
     * 部分更新当前用户资料，仅修改请求中显式提供的字段。
     *
     * <p>方法名：patchMe</p>
     */
    public Map<String, Object> patchMe(@RequestBody Map<String, Object> body) {
        String username = body.get("username") != null ? body.get("username").toString() : null;
        String bio = body.containsKey("bio") ? str(body.get("bio")) : null;
        String avatarUrl = body.get("avatar_url") != null ? body.get("avatar_url").toString() : null;
        return userService.patchMe(requireUser(), username, bio, avatarUrl);
    }

    @GetMapping("/{id:\\d+}")
    /**
     * 按用户 ID 查询公开资料，并补充当前登录用户的关注关系状态。
     *
     * <p>方法名：getUser</p>
     */
    public Map<String, Object> getUser(@PathVariable int id) {
        Integer cur = CurrentUser.id().orElse(null);
        return userService.getUser(id, cur);
    }

    @GetMapping("/{id:\\d+}/photos")
    public Map<String, Object> userPhotos(
            @PathVariable int id,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "12") int limit) {
        Integer cur = CurrentUser.id().orElse(null);
        return userService.userPhotos(id, page, limit, cur);
    }

    @GetMapping("/{id:\\d+}/favorites")
    public Map<String, Object> userFavorites(
            @PathVariable int id,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "12") int limit) {
        Integer cur = CurrentUser.id().orElse(null);
        return userService.userFavorites(id, page, limit, cur);
    }

    @GetMapping("/{id:\\d+}/footprint")
    /**
     * 聚合用户拍摄足迹坐标，生成地图展示所需的地点与照片数据。
     *
     * <p>方法名：footprint</p>
     */
    public Map<String, Object> footprint(@PathVariable int id) {
        return userService.footprint(id);
    }

    @PostMapping("/{id:\\d+}/follow")
    /**
     * 切换当前用户对目标用户的关注状态，返回关注关系结果。
     *
     * <p>方法名：follow</p>
     */
    public Map<String, Object> follow(@PathVariable int id) {
        return userService.toggleFollow(requireUser(), id);
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
}
