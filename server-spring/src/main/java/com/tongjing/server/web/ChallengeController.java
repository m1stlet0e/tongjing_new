package com.tongjing.server.web;

import com.tongjing.server.security.CurrentUser;
import com.tongjing.server.service.ChallengeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/challenges")
@RequiredArgsConstructor
public class ChallengeController {

    private final ChallengeService challengeService;

    @GetMapping
    public Map<String, Object> list() {
        Integer uid = CurrentUser.id().orElse(null);
        return challengeService.list(uid);
    }

    @GetMapping("/{id:\\d+}")
    public Map<String, Object> detail(@PathVariable long id) {
        Integer uid = CurrentUser.id().orElse(null);
        return challengeService.detail(id, uid);
    }

    @PostMapping("/{id:\\d+}/join")
    public Map<String, Object> join(@PathVariable long id, @RequestBody(required = false) Map<String, Object> body) {
        int uid = requireUser();
        Integer photoId = null;
        if (body != null && body.get("photo_id") != null) {
            photoId = intVal(body.get("photo_id"));
            if (photoId != null && photoId <= 0) {
                photoId = null;
            }
        }
        return challengeService.join(id, uid, photoId);
    }

    private static int requireUser() {
        return CurrentUser.id()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "请先登录"));
    }

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
}
