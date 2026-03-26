package com.tongjing.server.repository;

import com.tongjing.server.entity.Equipment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface EquipmentRepository extends JpaRepository<Equipment, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByType</p>
     */
    List<Equipment> findByType(String type);

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByBrandContainingIgnoreCase</p>
     */
    List<Equipment> findByBrandContainingIgnoreCase(String brand);
}
