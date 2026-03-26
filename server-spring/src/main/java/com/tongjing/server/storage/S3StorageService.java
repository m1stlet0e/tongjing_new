package com.tongjing.server.storage;

import com.amazonaws.HttpMethod;
import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.auth.DefaultAWSCredentialsProviderChain;
import com.amazonaws.client.builder.AwsClientBuilder;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.GeneratePresignedUrlRequest;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.tongjing.server.config.S3Properties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.util.Date;

@Service
@RequiredArgsConstructor
public class S3StorageService {

    private final S3Properties props;

    /**
     * 执行布尔判定并返回判断结果。
     *
     * <p>方法名：isConfigured</p>
     */
    public boolean isConfigured() {
        return props.isConfigured();
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：uploadFile</p>
     */
    public String uploadFile(byte[] content, String fileName, String contentType) {
        if (!isConfigured()) {
            throw new IllegalStateException("S3 not configured");
        }
        AmazonS3 client = buildClient();
        try {
            ObjectMetadata md = new ObjectMetadata();
            md.setContentLength(content.length);
            md.setContentType(contentType != null ? contentType : "application/octet-stream");
            client.putObject(
                    new PutObjectRequest(props.bucket(), fileName, new ByteArrayInputStream(content), md));
            return fileName;
        } finally {
            client.shutdown();
        }
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：generatePresignedUrl</p>
     */
    public String generatePresignedUrl(String key, int expireSeconds) {
        if (!isConfigured()) {
            throw new IllegalStateException("S3 not configured");
        }
        AmazonS3 client = buildClient();
        try {
            Date exp = new Date(System.currentTimeMillis() + expireSeconds * 1000L);
            GeneratePresignedUrlRequest req =
                    new GeneratePresignedUrlRequest(props.bucket(), key).withMethod(HttpMethod.GET).withExpiration(exp);
            return client.generatePresignedUrl(req).toString();
        } finally {
            client.shutdown();
        }
    }

    /**
     * 构建并返回业务对象或响应结构。
     *
     * <p>方法名：buildClient</p>
     */
    private AmazonS3 buildClient() {
        String region = props.region() == null || props.region().isBlank() ? "cn-beijing" : props.region();
        var builder =
                AmazonS3ClientBuilder.standard()
                        .enablePathStyleAccess()
                        .withEndpointConfiguration(
                                new AwsClientBuilder.EndpointConfiguration(props.endpointUrl(), region));
        if (props.accessKey() != null
                && !props.accessKey().isBlank()
                && props.secretKey() != null
                && !props.secretKey().isBlank()) {
            builder.withCredentials(
                    new AWSStaticCredentialsProvider(
                            new BasicAWSCredentials(props.accessKey(), props.secretKey())));
        } else {
            builder.withCredentials(new DefaultAWSCredentialsProviderChain());
        }
        return builder.build();
    }
}
