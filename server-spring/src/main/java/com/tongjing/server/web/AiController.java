package com.tongjing.server.web;

import com.tongjing.server.security.CurrentUser;
import com.tongjing.server.service.AiAssistantService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/ai")
@RequiredArgsConstructor
public class AiController {

    private final AiAssistantService aiAssistantService;

    @PostMapping("/publish-assist")
    public Map<String, Object> publishAssist(@RequestBody Map<String, Object> body) {
        requireUser();
        @SuppressWarnings("unchecked")
        Map<String, Object> exif =
                body.get("exif_data") instanceof Map
                        ? (Map<String, Object>) body.get("exif_data")
                        : Map.of();
        return aiAssistantService.suggestPublishAssist(
                str(body.get("title")), str(body.get("description")), str(body.get("location_name")), exif);
    }

    private static int requireUser() {
        return CurrentUser.id()
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "请先登录"));
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }
}
