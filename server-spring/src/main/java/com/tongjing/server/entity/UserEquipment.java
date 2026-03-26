package com.tongjing.server.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * user_equipment 表：存储用户与器材的关联关系。
 * 用于维护用户器材清单，支持个人器材展示与管理操作。
 */
@Entity
@Table(name = "user_equipment", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "equipment_id"}))
@Getter
@Setter
public class UserEquipment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "user_id")
    private Integer userId;

    @Column(name = "equipment_id")
    private Integer equipmentId;

    @Column(name = "created_at")
    private Instant createdAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "equipment_id", insertable = false, updatable = false)
    private Equipment equipment;

    @PrePersist
    void prePersist() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
