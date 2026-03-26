package com.tongjing.server.web;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/api/v1/health")
    /**
     * 健康检查接口，返回服务可用状态，供网关、监控与部署探针调用。
     *
     * <p>方法名：health</p>
     */
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }
}
