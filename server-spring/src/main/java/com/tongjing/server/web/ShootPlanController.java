package com.tongjing.server.web;

import com.tongjing.server.security.CurrentUser;
import com.tongjing.server.service.ShootPlanService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/shoot-plans")
@RequiredArgsConstructor
public class ShootPlanController {

    private final ShootPlanService shootPlanService;

    @GetMapping
    public Map<String, Object> list() {
        return shootPlanService.list(requireUser());
    }

    @PutMapping
    public Map<String, Object> upsert(@RequestBody Map<String, Object> body) {
        int uid = requireUser();
        int photoId = intVal(body.get("photo_id"));
        if (photoId <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "photo_id 无效");
        }
        return shootPlanService.upsert(
                uid,
                photoId,
                str(body.get("title")),
                str(body.get("location")),
                str(body.get("image_url")),
                str(body.get("camera_line")),
                str(body.get("tips")),
                bool(body.get("done")));
    }

    @PatchMapping("/{id:\\d+}")
    public Map<String, Object> patchDone(@PathVariable long id, @RequestBody Map<String, Object> body) {
        Boolean done = bool(body.get("done"));
        if (done == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "缺少 done");
        }
        return shootPlanService.setDone(requireUser(), id, done);
    }

    @DeleteMapping("/{id:\\d+}")
    public Map<String, Object> delete(@PathVariable long id) {
        return shootPlanService.delete(requireUser(), id);
    }

    private static int requireUser() {
        return CurrentUser.id()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "请先登录"));
    }

    private static String str(Object o) {
        return o == null ? null : o.toString();
    }

    private static int intVal(Object o) {
        if (o == null) {
            return 0;
        }
        if (o instanceof Number n) {
            return n.intValue();
        }
        try {
            return Integer.parseInt(o.toString());
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private static Boolean bool(Object o) {
        if (o == null) {
            return null;
        }
        if (o instanceof Boolean b) {
            return b;
        }
        return Boolean.parseBoolean(o.toString());
    }
}
