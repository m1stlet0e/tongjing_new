package com.tongjing.server.service;

import com.tongjing.server.entity.Equipment;
import com.tongjing.server.entity.UserEquipment;
import com.tongjing.server.repository.EquipmentRepository;
import com.tongjing.server.repository.UserEquipmentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class EquipmentApiService {

    private final EquipmentRepository equipmentRepository;
    private final UserEquipmentRepository userEquipmentRepository;

    /**
     * 按条件查询列表数据并返回分页或集合结果。
     *
     * <p>方法名：listCatalog</p>
     */
    public Map<String, Object> listCatalog(String type, String brand) {
        List<Equipment> all = equipmentRepository.findAll(Sort.by("brand", "model"));
        List<Equipment> filtered =
                all.stream()
                        .filter(e -> type == null || type.isEmpty() || type.equals(e.getType()))
                        .filter(
                                e ->
                                        brand == null
                                                || brand.isEmpty()
                                                || (e.getBrand() != null
                                                        && e.getBrand().toLowerCase().contains(brand.toLowerCase())))
                        .toList();
        Map<String, List<Equipment>> grouped =
                filtered.stream().collect(Collectors.groupingBy(Equipment::getBrand));
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("equipment", filtered);
        data.put("groupedByBrand", grouped);
        return Map.of("success", true, "data", data);
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：brands</p>
     */
    public Map<String, Object> brands() {
        List<String> brands =
                equipmentRepository.findAll().stream()
                        .map(Equipment::getBrand)
                        .filter(Objects::nonNull)
                        .distinct()
                        .sorted()
                        .toList();
        return Map.of("success", true, "data", brands);
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：userEquipment</p>
     */
    public Map<String, Object> userEquipment(int userId) {
        List<UserEquipment> rows = userEquipmentRepository.findByUserIdOrderByCreatedAtDesc(userId);
        List<Map<String, Object>> equipment = new ArrayList<>();
        for (UserEquipment ue : rows) {
            if (ue.getEquipmentId() == null) {
                continue;
            }
            Equipment e = equipmentRepository.findById(ue.getEquipmentId()).orElse(null);
            if (e == null) {
                continue;
            }
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", e.getId());
            m.put("brand", e.getBrand());
            m.put("model", e.getModel());
            m.put("type", e.getType());
            m.put("specs", e.getSpecs());
            m.put("added_at", ue.getCreatedAt() != null ? ue.getCreatedAt().toString() : null);
            equipment.add(m);
        }
        Map<String, List<Map<String, Object>>> byType =
                equipment.stream().collect(Collectors.groupingBy(m -> (String) m.get("type")));
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("equipment", equipment);
        data.put("groupedByType", byType);
        return Map.of("success", true, "data", data);
    }

    @Transactional
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：addToUser</p>
     */
    public Map<String, Object> addToUser(int userId, int equipmentId) {
        if (userEquipmentRepository.findByUserIdAndEquipmentId(userId, equipmentId).isPresent()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Equipment already added");
        }
        UserEquipment ue = new UserEquipment();
        ue.setUserId(userId);
        ue.setEquipmentId(equipmentId);
        userEquipmentRepository.save(ue);
        return Map.of("success", true, "message", "Equipment added to your collection");
    }

    @Transactional
    /**
     * 移除目标数据并返回执行结果。
     *
     * <p>方法名：removeFromUser</p>
     */
    public void removeFromUser(int userId, int equipmentId) {
        userEquipmentRepository.deleteByUserIdAndEquipmentId(userId, equipmentId);
    }
}
