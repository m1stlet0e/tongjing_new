package com.tongjing.server.web;

import com.tongjing.server.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/send-code")
    /**
     * 发送验证码并记录有效期，用于登录或绑定流程校验。
     *
     * <p>方法名：sendCode</p>
     */
    public Map<String, Object> sendCode(@RequestBody Map<String, Object> body) {
        String phone = (String) body.get("phone");
        String type = body.get("type") != null ? body.get("type").toString() : "login";
        return authService.sendCode(phone, type);
    }

    @PostMapping("/login/phone")
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：loginPhone</p>
     */
    public Map<String, Object> loginPhone(@RequestBody Map<String, Object> body) {
        String phone = (String) body.get("phone");
        String code = (String) body.get("code");
        return authService.loginPhone(phone, code);
    }

    @PostMapping("/login/oauth")
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：loginOauth</p>
     */
    public Map<String, Object> loginOauth(@RequestBody Map<String, Object> body) {
        String provider = (String) body.get("provider");
        String code = body.get("code") != null ? body.get("code").toString() : null;
        String state = body.get("state") != null ? body.get("state").toString() : null;
        return authService.loginOauth(provider, code, state);
    }

    @PostMapping("/logout")
    /**
     * 使当前访问令牌失效，完成用户登出流程。
     *
     * <p>方法名：logout</p>
     */
    public Map<String, Object> logout(HttpServletRequest request) {
        String token = bearer(request);
        authService.logout(token);
        return Map.of("success", true, "message", "已退出登录");
    }

    @GetMapping("/me")
    /**
     * 查询当前用户资料与统计信息并返回标准响应对象。
     *
     * <p>方法名：me</p>
     */
    public Map<String, Object> me(HttpServletRequest request) {
        String token = bearer(request);
        if (token == null || token.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未登录");
        }
        return Map.of("success", true, "data", authService.me(token));
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：bearer</p>
     */
    private static String bearer(HttpServletRequest request) {
        String a = request.getHeader("Authorization");
        if (a != null && a.startsWith("Bearer ")) {
            return a.substring(7).trim();
        }
        return null;
    }
}
