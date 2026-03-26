package com.tongjing.server.web;

import com.tongjing.server.service.EquipmentApiService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/equipment")
@RequiredArgsConstructor
public class EquipmentController {

    private final EquipmentApiService equipmentApiService;

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String brand) {
        return equipmentApiService.listCatalog(type, brand);
    }

    @GetMapping("/brands")
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：brands</p>
     */
    public Map<String, Object> brands() {
        return equipmentApiService.brands();
    }

    @GetMapping("/user/{userId:\\d+}")
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：userEquipment</p>
     */
    public Map<String, Object> userEquipment(@PathVariable int userId) {
        return equipmentApiService.userEquipment(userId);
    }

    @PostMapping("/user/{userId:\\d+}")
    public Map<String, Object> add(
            @PathVariable int userId, @RequestBody Map<String, Object> body) {
        int equipmentId = ((Number) body.get("equipment_id")).intValue();
        return equipmentApiService.addToUser(userId, equipmentId);
    }

    @DeleteMapping("/user/{userId:\\d+}/{equipmentId:\\d+}")
    /**
     * 移除目标数据并返回执行结果。
     *
     * <p>方法名：remove</p>
     */
    public Map<String, Object> remove(@PathVariable int userId, @PathVariable int equipmentId) {
        equipmentApiService.removeFromUser(userId, equipmentId);
        return Map.of("success", true, "message", "Equipment removed from your collection");
    }
}
