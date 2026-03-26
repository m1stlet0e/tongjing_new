package com.tongjing.server.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "s3")
public record S3Properties(
        String endpointUrl,
        String bucket,
        String region,
        String accessKey,
        String secretKey) {

    /**
     * 执行布尔判定并返回判断结果。
     *
     * <p>方法名：isConfigured</p>
     */
    public boolean isConfigured() {
        return endpointUrl != null
                && !endpointUrl.isBlank()
                && bucket != null
                && !bucket.isBlank();
    }
}
