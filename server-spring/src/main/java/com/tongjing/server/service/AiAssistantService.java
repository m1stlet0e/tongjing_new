package com.tongjing.server.service;

import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * 轻量 AI 辅助：在未接外部大模型时，基于规则生成发布文案与标签建议。
 */
@Service
public class AiAssistantService {

    public Map<String, Object> suggestPublishAssist(
            String title, String description, String location, Map<String, Object> exifData) {
        String t = safe(title);
        String d = safe(description);
        String loc = safe(location);
        String camera = safe(exifData.get("camera_model"));
        String lens = safe(exifData.get("lens_model"));
        String aperture = safe(exifData.get("aperture"));
        String shutter = safe(exifData.get("shutter_speed"));
        String iso = safe(exifData.get("iso"));

        List<Map<String, String>> tags = new ArrayList<>();
        addTag(tags, camera.contains("Sony") ? "索尼" : camera, "device");
        addTag(tags, containsAny(t, d, "夜", "霓虹", "蓝调") ? "夜景" : null, "scene");
        addTag(tags, containsAny(t, d, "街", "扫街") ? "街拍" : null, "scene");
        addTag(tags, containsAny(t, d, "建筑", "城市") ? "建筑" : null, "scene");
        addTag(tags, containsAny(t, d, "星", "银河") ? "星空" : null, "scene");
        addTag(tags, containsAny(t, d, "人像", "肖像") ? "人像" : null, "scene");
        if (tags.isEmpty()) {
            addTag(tags, "光影", "scene");
            addTag(tags, "旅行", "scene");
            addTag(tags, "城市", "scene");
        }
        String copy =
                "在"
                        + (loc.isBlank() ? "这处机位" : loc)
                        + "完成本次拍摄，"
                        + (camera.isBlank() ? "使用相机" : "使用 " + camera)
                        + (lens.isBlank() ? "" : " 搭配 " + lens)
                        + "。"
                        + "参数建议参考："
                        + "f/"
                        + (aperture.isBlank() ? "-" : aperture)
                        + "、"
                        + (shutter.isBlank() ? "-" : shutter)
                        + "、ISO "
                        + (iso.isBlank() ? "-" : iso)
                        + "。"
                        + "建议先观察现场主次关系，再根据光线变化微调曝光。";

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("copy", copy);
        data.put("tags", tags);
        return Map.of("success", true, "data", data);
    }

    private static void addTag(List<Map<String, String>> tags, String tagName, String type) {
        if (tagName == null || tagName.isBlank()) {
            return;
        }
        if (tags.stream().anyMatch(t -> tagName.equals(t.get("name")))) {
            return;
        }
        tags.add(Map.of("name", tagName, "type", type));
    }

    private static boolean containsAny(String t, String d, String... kws) {
        String text = (t + " " + d).toLowerCase(Locale.ROOT);
        for (String k : kws) {
            if (text.contains(k.toLowerCase(Locale.ROOT))) {
                return true;
            }
        }
        return false;
    }

    private static String safe(Object o) {
        return o == null ? "" : o.toString().trim();
    }
}
