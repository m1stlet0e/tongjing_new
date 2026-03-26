package com.tongjing.server.security;

import java.util.Optional;

public final class CurrentUser {

    private static final ThreadLocal<Integer> USER_ID = new ThreadLocal<>();

    private CurrentUser() {}

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：set</p>
     */
    public static void set(Integer userId) {
        USER_ID.set(userId);
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：clear</p>
     */
    public static void clear() {
        USER_ID.remove();
    }

    /**
     * 执行业务处理流程，完成参数处理、服务调用与结果返回。
     *
     * <p>方法名：id</p>
     */
    public static Optional<Integer> id() {
        return Optional.ofNullable(USER_ID.get());
    }
}
