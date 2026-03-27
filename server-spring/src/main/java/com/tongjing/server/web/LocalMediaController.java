package com.tongjing.server.web;

import com.tongjing.server.config.TongjingUploadProperties;
import com.tongjing.server.storage.UploadStorageFacade;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletRequest;

import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * 本地上传文件的直链访问（仅 S3 未启用时有效）。生产环境建议配置对象存储并关闭对本地目录的依赖。
 */
@RestController
@RequestMapping("/api/v1/local-media")
@RequiredArgsConstructor
public class LocalMediaController {

    private final TongjingUploadProperties uploadProperties;

    @GetMapping("/**")
    public ResponseEntity<Resource> serve(HttpServletRequest request) {
        String path =
                request.getRequestURI().substring(request.getContextPath().length());
        String prefix = "/api/v1/local-media/";
        int i = path.indexOf(prefix);
        if (i < 0) {
            return ResponseEntity.notFound().build();
        }
        String rel = path.substring(i + prefix.length());
        if (rel.isBlank()) {
            return ResponseEntity.notFound().build();
        }
        rel = URLDecoder.decode(rel, StandardCharsets.UTF_8);
        UploadStorageFacade.validateKey(rel);

        Path base = Path.of(uploadProperties.localDirResolved()).toAbsolutePath().normalize();
        Path file = base.resolve(rel).normalize();
        if (!file.startsWith(base) || !Files.isRegularFile(file)) {
            return ResponseEntity.notFound().build();
        }
        FileSystemResource resource = new FileSystemResource(file);
        String ct = probeContentType(file);
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "public, max-age=86400")
                .contentType(MediaType.parseMediaType(ct))
                .body(resource);
    }

    private static String probeContentType(Path file) {
        try {
            String probed = Files.probeContentType(file);
            if (probed != null && !probed.isBlank()) {
                return probed;
            }
        } catch (Exception ignored) {
        }
        String n = file.getFileName().toString().toLowerCase();
        if (n.endsWith(".png")) {
            return "image/png";
        }
        if (n.endsWith(".webp")) {
            return "image/webp";
        }
        if (n.endsWith(".gif")) {
            return "image/gif";
        }
        return "image/jpeg";
    }
}
