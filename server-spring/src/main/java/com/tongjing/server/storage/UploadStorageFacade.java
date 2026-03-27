package com.tongjing.server.storage;

import com.tongjing.server.config.TongjingUploadProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * 优先 S3；未配置 bucket 时写入本地目录并返回可通过 {@code /api/v1/local-media/} 访问的 URL。
 */
@Component
@RequiredArgsConstructor
public class UploadStorageFacade {

    private static final int PRESIGN_SECONDS = 30 * 24 * 60 * 60;

    private final S3StorageService s3StorageService;
    private final TongjingUploadProperties uploadProperties;

    public record StoredObject(String publicUrl, String storageKey) {}

    /**
     * 写入对象并返回客户端可访问的 URL 与存储键。
     */
    public StoredObject store(byte[] bytes, String key, String contentType) throws Exception {
        validateKey(key);
        if (s3StorageService.isConfigured()) {
            s3StorageService.uploadFile(bytes, key, contentType);
            String url = s3StorageService.generatePresignedUrl(key, PRESIGN_SECONDS);
            return new StoredObject(url, key);
        }
        Path base = Path.of(uploadProperties.localDirResolved()).toAbsolutePath().normalize();
        Path target = base.resolve(key).normalize();
        if (!target.startsWith(base)) {
            throw new IllegalArgumentException("非法存储路径");
        }
        Files.createDirectories(target.getParent());
        Files.write(target, bytes);
        String encodedPath =
                java.util.Arrays.stream(key.split("/"))
                        .map(s -> URLEncoder.encode(s, StandardCharsets.UTF_8))
                        .reduce((a, b) -> a + "/" + b)
                        .orElse("");
        String url =
                uploadProperties.publicBaseUrlResolved()
                        + "/api/v1/local-media/"
                        + encodedPath;
        return new StoredObject(url, key);
    }

    public static void validateKey(String key) {
        if (key == null || key.isBlank()) {
            throw new IllegalArgumentException("存储键不能为空");
        }
        if (key.contains("..") || key.startsWith("/") || key.startsWith("\\")) {
            throw new IllegalArgumentException("非法存储键");
        }
    }
}
