package com.tongjing.server.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * photo_likes 表：存储用户点赞关系。
 * 用于判断当前用户是否点赞、去重点赞行为，并驱动照片点赞数统计。
 */
@Entity
@Table(name = "photo_likes", uniqueConstraints = @UniqueConstraint(columnNames = {"photo_id", "user_id"}))
@Getter
@Setter
public class PhotoLike {

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
