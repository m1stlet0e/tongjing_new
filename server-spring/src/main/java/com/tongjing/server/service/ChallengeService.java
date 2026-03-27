package com.tongjing.server.service;

import com.tongjing.server.entity.Challenge;
import com.tongjing.server.entity.ChallengeEntry;
import com.tongjing.server.entity.Photo;
import com.tongjing.server.repository.ChallengeEntryRepository;
import com.tongjing.server.repository.ChallengeRepository;
import com.tongjing.server.repository.PhotoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ChallengeService {

    private final ChallengeRepository challengeRepository;
    private final ChallengeEntryRepository challengeEntryRepository;
    private final PhotoRepository photoRepository;

    public Map<String, Object> list(Integer currentUserId) {
        List<Challenge> list = challengeRepository.findAll();
        list.sort(
                Comparator.comparing((Challenge c) -> bool(c.getIsActive())).reversed()
                        .thenComparing(Challenge::getCreatedAt, Comparator.nullsLast(Comparator.reverseOrder())));
        List<Long> ids = list.stream().map(Challenge::getId).toList();
        Map<Long, List<ChallengeEntry>> entriesBy =
                challengeEntryRepository.findByChallengeIdIn(ids).stream()
                        .collect(Collectors.groupingBy(ChallengeEntry::getChallengeId));
        List<Map<String, Object>> data = new ArrayList<>();
        for (Challenge c : list) {
            List<ChallengeEntry> entries = entriesBy.getOrDefault(c.getId(), List.of());
            data.add(toMap(c, entries, currentUserId));
        }
        return Map.of("success", true, "data", Map.of("challenges", data));
    }

    public Map<String, Object> detail(long id, Integer currentUserId) {
        Challenge c =
                challengeRepository
                        .findById(id)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "挑战不存在"));
        List<ChallengeEntry> entries = challengeEntryRepository.findByChallengeIdOrderByCreatedAtDesc(id);
        return Map.of("success", true, "data", toMap(c, entries, currentUserId));
    }

    @Transactional
    public Map<String, Object> join(long challengeId, int userId, Integer photoId) {
        Challenge c =
                challengeRepository
                        .findById(challengeId)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "挑战不存在"));
        if (!bool(c.getIsActive())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "挑战未开放");
        }
        if (c.getEndAt() != null && c.getEndAt().isBefore(Instant.now())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "挑战已结束");
        }
        if (photoId != null) {
            Photo p =
                    photoRepository
                            .findById(photoId)
                            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "作品不存在"));
            if (!Objects.equals(p.getUserId(), userId)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "只能用自己的作品参与挑战");
            }
            if (challengeEntryRepository.findByChallengeIdAndUserIdAndPhotoId(challengeId, userId, photoId)
                    .isPresent()) {
                return Map.of("success", true, "data", Map.of("joined", true), "message", "已参与");
            }
        } else if (challengeEntryRepository.findFirstByChallengeIdAndUserIdOrderByCreatedAtDesc(challengeId, userId)
                .isPresent()) {
            return Map.of("success", true, "data", Map.of("joined", true), "message", "已参与");
        }

        ChallengeEntry e = new ChallengeEntry();
        e.setChallengeId(challengeId);
        e.setUserId(userId);
        e.setPhotoId(photoId);
        challengeEntryRepository.save(e);
        return Map.of("success", true, "data", Map.of("joined", true), "message", "参与成功");
    }

    private Map<String, Object> toMap(Challenge c, List<ChallengeEntry> entries, Integer currentUserId) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.getId());
        m.put("title", c.getTitle());
        m.put("description", c.getDescription());
        m.put("cover_image_url", c.getCoverImageUrl());
        m.put("start_at", c.getStartAt() != null ? c.getStartAt().toString() : null);
        m.put("end_at", c.getEndAt() != null ? c.getEndAt().toString() : null);
        m.put("is_active", bool(c.getIsActive()));
        m.put("participant_count", entries.size());
        m.put("days_left", daysLeft(c.getEndAt()));
        boolean joined =
                currentUserId != null && entries.stream().anyMatch(it -> Objects.equals(it.getUserId(), currentUserId));
        m.put("is_joined", joined);
        List<Map<String, Object>> samples = topSamplePhotos(entries);
        m.put("sample_photos", samples);
        return m;
    }

    private List<Map<String, Object>> topSamplePhotos(List<ChallengeEntry> entries) {
        List<Integer> photoIds =
                entries.stream().map(ChallengeEntry::getPhotoId).filter(Objects::nonNull).distinct().limit(12).toList();
        if (photoIds.isEmpty()) {
            return List.of();
        }
        Map<Integer, Photo> photos =
                photoRepository.findAllById(photoIds).stream()
                        .collect(Collectors.toMap(Photo::getId, p -> p, (a, b) -> a));
        List<Map<String, Object>> out = new ArrayList<>();
        for (Integer id : photoIds) {
            Photo p = photos.get(id);
            if (p == null) {
                continue;
            }
            out.add(
                    Map.of(
                            "photo_id", p.getId(),
                            "image_url", safe(p.getImageUrl()),
                            "title", safe(p.getTitle())));
        }
        return out;
    }

    private static String safe(String s) {
        return s == null ? "" : s;
    }

    private static boolean bool(Boolean b) {
        return b != null && b;
    }

    private static int daysLeft(Instant endAt) {
        if (endAt == null) {
            return 0;
        }
        long d = Duration.between(Instant.now(), endAt).toDays();
        return (int) Math.max(0, d);
    }
}
