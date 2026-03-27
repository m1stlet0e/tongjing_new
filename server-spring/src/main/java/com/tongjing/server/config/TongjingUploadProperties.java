package com.tongjing.server.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 本地上传目录与对外访问基址（S3 未配置时使用）。
 *
 * <p>真机/模拟器访问开发机时请将 {@code public-base-url} 设为电脑在局域网中的可访问地址
 * （如 {@code http://10.0.2.2:9091} 对应 Android 模拟器）。
 */
@ConfigurationProperties(prefix = "tongjing.upload")
public record TongjingUploadProperties(String localDir, String publicBaseUrl) {

    public String localDirResolved() {
        if (localDir == null || localDir.isBlank()) {
            return "./data/uploads";
        }
        return localDir.trim();
    }

    public String publicBaseUrlResolved() {
        if (publicBaseUrl == null || publicBaseUrl.isBlank()) {
            return "http://127.0.0.1:9091";
        }
        String u = publicBaseUrl.trim();
        return u.endsWith("/") ? u.substring(0, u.length() - 1) : u;
    }
}
