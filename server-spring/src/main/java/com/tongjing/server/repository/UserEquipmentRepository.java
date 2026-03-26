package com.tongjing.server.repository;

import com.tongjing.server.entity.UserEquipment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserEquipmentRepository extends JpaRepository<UserEquipment, Integer> {

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByUserIdOrderByCreatedAtDesc</p>
     */
    List<UserEquipment> findByUserIdOrderByCreatedAtDesc(Integer userId);

    /**
     * 按条件检索数据并返回匹配结果。
     *
     * <p>方法名：findByUserIdAndEquipmentId</p>
     */
    Optional<UserEquipment> findByUserIdAndEquipmentId(Integer userId, Integer equipmentId);

    /**
     * 删除目标数据并处理关联关系。
     *
     * <p>方法名：deleteByUserIdAndEquipmentId</p>
     */
    void deleteByUserIdAndEquipmentId(Integer userId, Integer equipmentId);
}
