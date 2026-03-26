package com.tongjing.server.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * photos 表：存储用户发布的照片主数据。
 * 包含图片地址、标题描述、拍摄参数、地理位置和互动计数，是内容流与详情页核心数据来源。
 */
@Entity
@Table(name = "photos")
@Getter
@Setter
public class Photo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "user_id")
    private Integer userId;

    @Column(name = "image_url", nullable = false, columnDefinition = "text")
    private String imageUrl;

    @Column(length = 200)
    private String title;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "camera_brand", length = 50)
    private String cameraBrand;

    @Column(name = "camera_model", length = 100)
    private String cameraModel;

    @Column(name = "lens_model", length = 100)
    private String lensModel;

    @Column(name = "focal_length", length = 20)
    private String focalLength;

    @Column(length = 20)
    private String aperture;

    @Column(name = "shutter_speed", length = 50)
    private String shutterSpeed;

    private Integer iso;

    @Column(name = "white_balance", length = 50)
    private String whiteBalance;

    private BigDecimal latitude;

    private BigDecimal longitude;

    @Column(name = "location_name", length = 200)
    private String locationName;

    @Column(name = "shooting_tips", columnDefinition = "text")
    private String shootingTips;

    @Column(name = "likes_count")
    private Integer likesCount = 0;

    @Column(name = "comments_count")
    private Integer commentsCount = 0;

    @Column(name = "favorites_count")
    private Integer favoritesCount = 0;

    @Column(name = "created_at")
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    void prePersist() {
        Instant n = Instant.now();
        if (createdAt == null) {
            createdAt = n;
        }
        if (updatedAt == null) {
            updatedAt = n;
        }
        if (likesCount == null) {
            likesCount = 0;
        }
        if (commentsCount == null) {
            commentsCount = 0;
        }
        if (favoritesCount == null) {
            favoritesCount = 0;
        }
    }
}
