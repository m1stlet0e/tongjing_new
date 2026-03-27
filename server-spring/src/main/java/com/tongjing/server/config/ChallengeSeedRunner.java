package com.tongjing.server.config;

import com.tongjing.server.entity.Challenge;
import com.tongjing.server.entity.ChallengeEntry;
import com.tongjing.server.entity.Photo;
import com.tongjing.server.repository.ChallengeEntryRepository;
import com.tongjing.server.repository.ChallengeRepository;
import com.tongjing.server.repository.PhotoRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Component
@Order(Integer.MAX_VALUE - 10)
@ConditionalOnProperty(name = "tongjing.seed-demo-data", havingValue = "true")
@RequiredArgsConstructor
@Slf4j
public class ChallengeSeedRunner implements CommandLineRunner {

    private final ChallengeRepository challengeRepository;
    private final ChallengeEntryRepository challengeEntryRepository;
    private final PhotoRepository photoRepository;

    @Override
    @Transactional
    public void run(String... args) {
        if (challengeRepository.count() > 0) {
            return;
        }
        List<Photo> photos = photoRepository.findAll();
        if (photos.isEmpty()) {
            log.info("tongjing: skip challenge seed (no photos)");
            return;
        }
        Challenge c1 = new Challenge();
        c1.setTitle("城市建筑·长焦挑战");
        c1.setDescription("用长焦镜头捕捉城市建筑线条与层次光影。");
        c1.setCoverImageUrl("https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1200");
        c1.setStartAt(Instant.now().minus(2, ChronoUnit.DAYS));
        c1.setEndAt(Instant.now().plus(12, ChronoUnit.DAYS));
        c1.setIsActive(true);
        c1 = challengeRepository.save(c1);

        Challenge c2 = new Challenge();
        c2.setTitle("星空·银河挑战");
        c2.setDescription("分享你的银河、星轨与夜空风景。");
        c2.setCoverImageUrl("https://images.unsplash.com/photo-1446776877081-d282a0f896e2?w=1200");
        c2.setStartAt(Instant.now().minus(1, ChronoUnit.DAYS));
        c2.setEndAt(Instant.now().plus(28, ChronoUnit.DAYS));
        c2.setIsActive(true);
        c2 = challengeRepository.save(c2);

        int idx = 0;
        for (Photo p : photos) {
            ChallengeEntry e = new ChallengeEntry();
            e.setChallengeId(idx % 2 == 0 ? c1.getId() : c2.getId());
            e.setUserId(p.getUserId() == null ? 0 : p.getUserId());
            e.setPhotoId(p.getId());
            challengeEntryRepository.save(e);
            idx++;
        }
        log.info("tongjing: challenge seed finished, {} challenges", challengeRepository.count());
    }
}
