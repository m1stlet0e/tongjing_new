package com.tongjing.server.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.tongjing.server.entity.*;
import com.tongjing.server.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final VerificationCodeRepository verificationCodeRepository;
    private final UserRepository userRepository;
    private final UserSessionRepository userSessionRepository;
    private final UserOauthProviderRepository oauthProviderRepository;
    private final ObjectMapper objectMapper;
    private final Environment environment;

    @Transactional
    /**
     * 发送验证码并记录有效期，用于登录或绑定流程校验。
     *
     * <p>方法名：sendCode</p>
     */
    public Map<String, Object> sendCode(String phone, String type) {
        if (phone == null || !phone.matches("^1[3-9]\\d{9}$")) {
            throw badRequest("请输入正确的手机号");
        }
        if (type == null) {
            type = "login";
        }
        Instant since = Instant.now().minus(1, ChronoUnit.MINUTES);
        if (verificationCodeRepository.findLatestSince(phone, type, since).isPresent()) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "验证码发送太频繁，请1分钟后再试");
        }
        String code = String.format("%06d", RANDOM.nextInt(900000) + 100000);
        VerificationCode vc = new VerificationCode();
        vc.setPhone(phone);
        vc.setCode(code);
        vc.setType(type);
        vc.setExpiresAt(Instant.now().plus(5, ChronoUnit.MINUTES));
        vc.setUsed(false);
        verificationCodeRepository.save(vc);

        System.out.println("[SMS] 发送验证码到 " + phone + ": " + code);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("success", true);
        body.put("message", "验证码已发送");
        if (!isProdProfile()) {
            body.put("_dev_code", code);
        }
        return body;
    }

    @Transactional
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：loginPhone</p>
     */
    public Map<String, Object> loginPhone(String phone, String code) {
        if (phone == null || code == null) {
            throw badRequest("请输入手机号和验证码");
        }
        VerificationCode record =
                verificationCodeRepository
                        .findValidLoginCode(phone, code, Instant.now())
                        .orElseThrow(() -> badRequest("验证码错误或已过期"));
        record.setUsed(true);
        verificationCodeRepository.save(record);

        User user =
                userRepository
                        .findByPhone(phone)
                        .orElseGet(
                                () -> {
                                    User u = new User();
                                    u.setPhone(phone);
                                    u.setUsername("用户" + phone.substring(phone.length() - 4));
                                    String name = URLEncoder.encode(u.getUsername(), StandardCharsets.UTF_8);
                                    u.setAvatarUrl(
                                            "https://ui-avatars.com/api/?name="
                                                    + name
                                                    + "&background=002FA7&color=fff");
                                    return userRepository.save(u);
                                });

        return sessionResponse(user);
    }

    @Transactional
    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：loginOauth</p>
     */
    public Map<String, Object> loginOauth(String provider, String authCode, String state) {
        if (provider == null || authCode == null) {
            throw badRequest("参数错误");
        }
        if (!provider.equals("wechat") && !provider.equals("weibo")) {
            throw badRequest("不支持的登录方式");
        }

        String providerUserId;
        ObjectNode providerData = objectMapper.createObjectNode();
        if ("wechat".equals(provider)) {
            providerUserId = "wechat_" + System.currentTimeMillis();
            providerData.put("nickname", "微信用户");
            providerData.put(
                    "avatar",
                    "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&h=400&fit=crop");
        } else {
            providerUserId = "weibo_" + System.currentTimeMillis();
            providerData.put("nickname", "微博用户");
            providerData.put(
                    "avatar",
                    "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=400&h=400&fit=crop");
        }

        Optional<UserOauthProvider> existing =
                oauthProviderRepository.findByProviderAndProviderUserId(provider, providerUserId);
        User user;
        boolean newBinding = existing.isEmpty();
        if (existing.isPresent()) {
            user = userRepository.findById(existing.get().getUserId()).orElseThrow();
        } else {
            user = new User();
            user.setUsername(
                    ("wechat".equals(provider) ? "微信" : "微博")
                            + "用户"
                            + String.valueOf(System.currentTimeMillis()).substring(
                                    Math.max(0, String.valueOf(System.currentTimeMillis()).length() - 6)));
            String defAv =
                    "https://ui-avatars.com/api/?name="
                            + URLEncoder.encode(user.getUsername(), StandardCharsets.UTF_8)
                            + "&background=002FA7&color=fff";
            var avNode = providerData.get("avatar");
            user.setAvatarUrl(
                    avNode != null && avNode.isTextual() ? avNode.asText() : defAv);
            user = userRepository.save(user);
            UserOauthProvider link = new UserOauthProvider();
            link.setUserId(user.getId());
            link.setProvider(provider);
            link.setProviderUserId(providerUserId);
            link.setProviderData(providerData);
            oauthProviderRepository.save(link);
        }

        Map<String, Object> resp = sessionResponse(user);
        @SuppressWarnings("unchecked")
        Map<String, Object> data = (Map<String, Object>) resp.get("data");
        data.put("is_new_user", newBinding);
        return resp;
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：sessionResponse</p>
     */
    private Map<String, Object> sessionResponse(User user) {
        String token = randomHexToken();
        Instant expires = Instant.now().plus(7, ChronoUnit.DAYS);
        UserSession session = new UserSession();
        session.setUserId(user.getId());
        session.setToken(token);
        session.setExpiresAt(expires);
        session.setDeviceInfo(Map.of());
        userSessionRepository.save(session);

        Map<String, Object> inner = new LinkedHashMap<>();
        inner.put("user", user);
        inner.put("token", token);
        inner.put("expires_at", expires.toString());
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("success", true);
        out.put("data", inner);
        out.put("message", "登录成功");
        return out;
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：randomHexToken</p>
     */
    private static String randomHexToken() {
        byte[] b = new byte[32];
        RANDOM.nextBytes(b);
        StringBuilder sb = new StringBuilder(64);
        for (byte x : b) {
            sb.append(String.format("%02x", x));
        }
        return sb.toString();
    }

    @Transactional
    /**
     * 使当前访问令牌失效，完成用户登出流程。
     *
     * <p>方法名：logout</p>
     */
    public void logout(String token) {
        if (token == null || token.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未登录");
        }
        userSessionRepository.deleteByToken(token);
    }

    /**
     * 查询当前用户资料与统计信息并返回标准响应对象。
     *
     * <p>方法名：me</p>
     */
    public User me(String token) {
        if (token == null || token.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "未登录");
        }
        UserSession s =
                userSessionRepository
                        .findByTokenAndExpiresAtAfter(token, Instant.now())
                        .orElseThrow(
                                () ->
                                        new ResponseStatusException(
                                                HttpStatus.UNAUTHORIZED, "登录已过期，请重新登录"));
        return userRepository
                .findById(s.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "登录已过期，请重新登录"));
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：badRequest</p>
     */
    private static ResponseStatusException badRequest(String msg) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, msg);
    }

    /**
     * 执行布尔判定并返回判断结果。
     *
     * <p>方法名：isProdProfile</p>
     */
    private boolean isProdProfile() {
        for (String p : environment.getActiveProfiles()) {
            if ("prod".equalsIgnoreCase(p) || "production".equalsIgnoreCase(p)) {
                return true;
            }
        }
        String single = environment.getProperty("spring.profiles.active", "");
        return single.contains("prod");
    }
}
