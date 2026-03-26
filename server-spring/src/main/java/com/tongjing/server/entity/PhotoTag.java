package com.tongjing.server.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * photo_tags 表：存储照片标签明细。
 * 用于按标签检索内容、展示标签信息和构建内容分类维度。
 */
@Entity
@Table(name = "photo_tags")
@Getter
@Setter
public class PhotoTag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "photo_id")
    private Integer photoId;

    @Column(name = "tag_name", nullable = false, length = 50)
    private String tagName;

    @Column(name = "tag_type", nullable = false, length = 20)
    private String tagType;

    @Column(name = "created_at")
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
