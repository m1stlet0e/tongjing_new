package com.tongjing.server.entity;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * spots 表：存储拍摄机位/地点信息。
 * 包含地点名称、坐标、封面与标签等，用于地图与机位推荐相关业务。
 */
@Entity
@Table(name = "spots")
@Getter
@Setter
public class Spot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false)
    private String name;

    @Column(name = "location_name", columnDefinition = "text")
    private String locationName;

    private BigDecimal latitude;

    private BigDecimal longitude;

    @Column(name = "cover_image", columnDefinition = "text")
    private String coverImage;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private JsonNode tags;

    @Column(name = "best_time", length = 100)
    private String bestTime;

    @Column(name = "is_public")
    private Boolean isPublic = true;

    @Column(name = "created_by")
    private Integer createdBy;

    @Column(name = "photo_count")
    private Integer photoCount = 0;

    @Column(name = "created_at")
    private Instant createdAt;

    @PrePersist
    void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
        if (isPublic == null) {
            isPublic = true;
        }
        if (photoCount == null) {
            photoCount = 0;
        }
    }
}
