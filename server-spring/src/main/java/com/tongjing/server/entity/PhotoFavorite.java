package com.tongjing.server.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * photo_favorites 表：存储用户收藏关系。
 * 用于收藏夹列表、收藏状态判断与收藏数统计。
 */
@Entity
@Table(name = "photo_favorites", uniqueConstraints = @UniqueConstraint(columnNames = {"photo_id", "user_id"}))
@Getter
@Setter
public class PhotoFavorite {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "photo_id")
    private Integer photoId;

    @Column(name = "user_id")
    private Integer userId;

    @Column(name = "created_at")
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
