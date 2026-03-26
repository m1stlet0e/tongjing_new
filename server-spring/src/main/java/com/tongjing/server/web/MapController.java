package com.tongjing.server.web;

import com.tongjing.server.service.MapService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/map")
@RequiredArgsConstructor
public class MapController {

    private final MapService mapService;

    @GetMapping("/photos")
    public Map<String, Object> photos(
            @RequestParam BigDecimal lat,
            @RequestParam BigDecimal lng,
            @RequestParam(defaultValue = "50") double radius,
            @RequestParam(defaultValue = "100") int limit) {
        return mapService.photosNear(lat, lng, radius, limit);
    }

    @GetMapping("/location/{locationName}")
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：byLocation</p>
     */
    public Map<String, Object> byLocation(@PathVariable String locationName) {
        return mapService.searchLocation(locationName);
    }

    @GetMapping("/popular-spots")
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：popularSpots</p>
     */
    public Map<String, Object> popularSpots() {
        return mapService.popularSpots();
    }
}
