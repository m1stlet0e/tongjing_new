package com.tongjing.server.web;

import com.tongjing.server.exif.ExifExtractor;
import com.tongjing.server.security.CurrentUser;
import com.tongjing.server.storage.S3StorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/upload")
@RequiredArgsConstructor
public class UploadController {

    private static final int PRESIGN_SECONDS = 30 * 24 * 60 * 60;

    private final S3StorageService s3StorageService;
    private final ExifExtractor exifExtractor;

    @PostMapping("/image")
    public Map<String, Object> uploadImage(@RequestPart("file") MultipartFile file) throws Exception {
        int uid = requireUser();
        if (!s3StorageService.isConfigured()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "对象存储未配置");
        }
        if (file == null || file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "请选择要上传的图片");
        }
        byte[] bytes = file.getBytes();
        Map<String, Object> exif = exifExtractor.extract(bytes);
        String ext = extension(file.getOriginalFilename());
        String key = "photos/" + System.currentTimeMillis() + "_" + randomSuffix() + "." + ext;
        s3StorageService.uploadFile(bytes, key, file.getContentType() != null ? file.getContentType() : "image/jpeg");
        String url = s3StorageService.generatePresignedUrl(key, PRESIGN_SECONDS);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("url", url);
        data.put("key", key);
        data.put("filename", file.getOriginalFilename());
        data.put("size", file.getSize());
        data.put("mimetype", file.getContentType());
        data.put("exif", exif);
        return Map.of("success", true, "data", data);
    }

    @PostMapping("/images")
    public Map<String, Object> uploadImages(@RequestPart("files") MultipartFile[] files) throws Exception {
        requireUser();
        if (!s3StorageService.isConfigured()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "对象存储未配置");
        }
        if (files == null || files.length == 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "请选择要上传的图片");
        }
        if (files.length > 9) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "最多9张");
        }
        java.util.List<Map<String, Object>> images = new java.util.ArrayList<>();
        for (MultipartFile file : files) {
            if (file.isEmpty()) {
                continue;
            }
            byte[] bytes = file.getBytes();
            Map<String, Object> exif = exifExtractor.extract(bytes);
            String ext = extension(file.getOriginalFilename());
            String key = "photos/" + System.currentTimeMillis() + "_" + randomSuffix() + "." + ext;
            s3StorageService.uploadFile(bytes, key, file.getContentType() != null ? file.getContentType() : "image/jpeg");
            String url = s3StorageService.generatePresignedUrl(key, PRESIGN_SECONDS);
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("url", url);
            item.put("key", key);
            item.put("filename", file.getOriginalFilename());
            item.put("size", file.getSize());
            item.put("mimetype", file.getContentType());
            item.put("exif", exif);
            images.add(item);
        }
        return Map.of("success", true, "data", Map.of("images", images));
    }

    @PostMapping("/avatar")
    public Map<String, Object> avatar(@RequestPart("file") MultipartFile file) throws Exception {
        int uid = requireUser();
        if (!s3StorageService.isConfigured()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "对象存储未配置");
        }
        if (file == null || file.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "请选择要上传的头像");
        }
        byte[] bytes = file.getBytes();
        String ext = extension(file.getOriginalFilename());
        String key = "avatars/" + uid + "_" + System.currentTimeMillis() + "." + ext;
        s3StorageService.uploadFile(bytes, key, file.getContentType() != null ? file.getContentType() : "image/jpeg");
        String url = s3StorageService.generatePresignedUrl(key, PRESIGN_SECONDS);
        return Map.of("success", true, "data", Map.of("url", url, "key", key));
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
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：extension</p>
     */
    private static String extension(String name) {
        if (name == null || !name.contains(".")) {
            return "jpg";
        }
        return name.substring(name.lastIndexOf('.') + 1).toLowerCase();
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：randomSuffix</p>
     */
    private static String randomSuffix() {
        return Long.toString((long) (Math.random() * 0x7fffffff), 36);
    }
}
