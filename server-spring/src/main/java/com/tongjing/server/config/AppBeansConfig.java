package com.tongjing.server.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties({S3Properties.class, TongjingUploadProperties.class})
public class AppBeansConfig {}
