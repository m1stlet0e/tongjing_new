package com.tongjing.server.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "shoot_plans")
@Getter
@Setter
public class ShootPlan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Integer userId;

    @Column(name = "photo_id", nullable = false)
    private Integer photoId;

    @Column(length = 500)
    private String title;

    @Column(columnDefinition = "text")
    private String location;

    @Column(name = "image_url", nullable = false, columnDefinition = "text")
    private String imageUrl;

    @Column(name = "camera_line", length = 500)
    private String cameraLine;

    @Column(columnDefinition = "text")
    private String tips;

    @Column(nullable = false)
    private boolean done;

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
    }

    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}
