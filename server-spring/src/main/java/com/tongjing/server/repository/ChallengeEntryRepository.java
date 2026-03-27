package com.tongjing.server.repository;

import com.tongjing.server.entity.ChallengeEntry;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ChallengeEntryRepository extends JpaRepository<ChallengeEntry, Long> {

    long countByChallengeId(Long challengeId);

    List<ChallengeEntry> findByChallengeIdOrderByCreatedAtDesc(Long challengeId);

    List<ChallengeEntry> findByChallengeIdIn(Collection<Long> challengeIds);

    Optional<ChallengeEntry> findByChallengeIdAndUserIdAndPhotoId(Long challengeId, Integer userId, Integer photoId);

    Optional<ChallengeEntry> findFirstByChallengeIdAndUserIdOrderByCreatedAtDesc(Long challengeId, Integer userId);
}
