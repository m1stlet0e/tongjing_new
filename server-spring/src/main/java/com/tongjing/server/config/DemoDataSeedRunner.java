package com.tongjing.server.config;

import com.tongjing.server.entity.Photo;
import com.tongjing.server.entity.PhotoTag;
import com.tongjing.server.entity.User;
import com.tongjing.server.repository.PhotoRepository;
import com.tongjing.server.repository.PhotoTagRepository;
import com.tongjing.server.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
/**
 * 在空库时写入演示作品与标签，供客户端从数据库拉取真实列表。
 *
 * <p>启用方式：{@code tongjing.seed-demo-data=true} 或环境变量 {@code TONGJING_SEED_DEMO=true}。
 * 若 {@code photos} 表已有数据则跳过。
 */
@Component
@Order(Integer.MAX_VALUE)
@ConditionalOnProperty(name = "tongjing.seed-demo-data", havingValue = "true")
@Slf4j
@RequiredArgsConstructor
public class DemoDataSeedRunner implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PhotoRepository photoRepository;
    private final PhotoTagRepository photoTagRepository;

    @Override
    @Transactional
    public void run(String... args) {
        if (photoRepository.count() > 0) {
            log.info("tongjing: skip demo seed (photos table not empty)");
            return;
        }

        User demo =
                userRepository
                        .findByPhone("13800138000")
                        .orElseGet(
                                () -> {
                                    User u = new User();
                                    u.setUsername("同镜演示用户");
                                    u.setPhone("13800138000");
                                    u.setBio("演示账号，数据由启动种子写入数据库。");
                                    String name =
                                            URLEncoder.encode("同镜演示", StandardCharsets.UTF_8);
                                    u.setAvatarUrl(
                                            "https://ui-avatars.com/api/?name="
                                                    + name
                                                    + "&background=002FA7&color=fff&format=png");
                                    return userRepository.save(u);
                                });

        int uid = demo.getId();
        log.info("tongjing: seeding demo photos for user_id={}", uid);

        seed(
                uid,
                "外滩蓝调时刻",
                "蓝调时段城市风光示例。",
                "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1200&q=80",
                "Sony",
                "A7M4",
                "FE 50mm",
                "50mm",
                "1.8",
                "1/125",
                320,
                new BigDecimal("31.2400"),
                new BigDecimal("121.4900"),
                "上海外滩观景台",
                "建议日落后约 20 分钟拍摄，保留天空层次。",
                128,
                new String[][] {{"夜景", "scene"}, {"城市", "scene"}});
        seed(
                uid,
                "城市夜景长曝光",
                "车流光轨与建筑线条。",
                "https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1200&q=80",
                "Canon",
                "R6",
                "RF 24-70mm",
                "24-70mm",
                "8",
                "4s",
                100,
                new BigDecimal("31.2350"),
                new BigDecimal("121.5070"),
                "陆家嘴滨江",
                "三脚架必备，注意路面反光。",
                96,
                new String[][] {{"长曝光", "style"}, {"夜景", "scene"}});
        seed(
                uid,
                "武康大楼街拍",
                "历史建筑与街景。",
                "https://images.unsplash.com/photo-1482192596544-9eb780fc7f66?auto=format&fit=crop&w=1200&q=80",
                "Fujifilm",
                "X-T5",
                "XF 35mm",
                "35mm",
                "2.0",
                "1/250",
                200,
                new BigDecimal("31.2044"),
                new BigDecimal("121.4338"),
                "武康路",
                "避开人流高峰，侧逆光更有层次。",
                73,
                new String[][] {{"街拍", "scene"}, {"建筑", "scene"}});
        seed(
                uid,
                "星轨练习",
                "郊外弱光环境。",
                "https://images.unsplash.com/photo-1446776877081-d282a0f896e2?auto=format&fit=crop&w=1200&q=80",
                "Nikon",
                "Z6",
                "Z 20mm",
                "20mm",
                "2.8",
                "20s",
                1600,
                new BigDecimal("31.6230"),
                new BigDecimal("121.3970"),
                "崇明郊外",
                "远离光污染，注意电池与防寒。",
                54,
                new String[][] {{"星空", "scene"}});
        seed(
                uid,
                "雪山日出",
                "高海拔日出层次。",
                "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1200&q=80",
                "Sony",
                "A7R5",
                "FE 70-200mm",
                "70-200mm",
                "5.6",
                "1/500",
                400,
                new BigDecimal("30.8000"),
                new BigDecimal("102.0000"),
                "川西垭口",
                "注意高反与镜头起雾。",
                210,
                new String[][] {{"风光", "scene"}});
        seed(
                uid,
                "森林晨雾",
                "中长焦压缩空间。",
                "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80",
                "Canon",
                "R5",
                "RF 85mm",
                "85mm",
                "1.4",
                "1/160",
                640,
                new BigDecimal("30.2500"),
                new BigDecimal("119.1500"),
                "天目山古道",
                "清晨湿度高易出现薄雾。",
                92,
                new String[][] {{"风光", "scene"}});
        seed(
                uid,
                "湖畔倒影",
                "小光圈保证景深。",
                "https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=1200&q=80",
                "Nikon",
                "Z8",
                "Z 24mm",
                "24mm",
                "11",
                "1/60",
                100,
                new BigDecimal("29.5500"),
                new BigDecimal("118.9800"),
                "千岛湖",
                "偏振镜可压反光。",
                145,
                new String[][] {{"风光", "scene"}});
        seed(
                uid,
                "赛博霓虹",
                "夜景霓虹与雨面反光。",
                "https://images.unsplash.com/photo-1518837695005-2083093ee35b?auto=format&fit=crop&w=1200&q=80",
                "Sony",
                "A7C",
                "FE 35mm",
                "35mm",
                "1.8",
                "1/80",
                800,
                new BigDecimal("31.2304"),
                new BigDecimal("121.4737"),
                "城市夜景参考",
                "适当提高 ISO，注意白平衡偏冷。",
                412,
                new String[][] {{"赛博朋克", "style"}, {"夜景", "scene"}});

        log.info("tongjing: demo seed finished, {} photos", photoRepository.count());
    }

    private void seed(
            int userId,
            String title,
            String description,
            String imageUrl,
            String brand,
            String model,
            String lensModel,
            String focal,
            String aperture,
            String shutter,
            Integer iso,
            BigDecimal lat,
            BigDecimal lng,
            String locationName,
            String tips,
            int likes,
            String[][] tagPairs) {
        Photo p = new Photo();
        p.setUserId(userId);
        p.setImageUrl(imageUrl);
        p.setTitle(title);
        p.setDescription(description);
        p.setCameraBrand(brand);
        p.setCameraModel(model);
        p.setLensModel(lensModel);
        p.setFocalLength(focal);
        p.setAperture(aperture);
        p.setShutterSpeed(shutter);
        p.setIso(iso);
        p.setLatitude(lat);
        p.setLongitude(lng);
        p.setLocationName(locationName);
        p.setShootingTips(tips);
        p.setLikesCount(likes);
        p.setCommentsCount(0);
        p.setFavoritesCount(0);
        p = photoRepository.save(p);

        for (String[] pair : tagPairs) {
            PhotoTag t = new PhotoTag();
            t.setPhotoId(p.getId());
            t.setTagName(pair[0]);
            t.setTagType(pair[1]);
            photoTagRepository.save(t);
        }
    }
}
