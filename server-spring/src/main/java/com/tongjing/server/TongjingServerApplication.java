package com.tongjing.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class TongjingServerApplication {

    /**
     * 应用启动入口，负责引导 Spring Boot 容器并加载全部业务配置。
     *
     * <p>方法名：main</p>
     */
    public static void main(String[] args) {
        SpringApplication.run(TongjingServerApplication.class, args);
    }
}
