class ChallengeSamplePhoto {
  ChallengeSamplePhoto({
    required this.photoId,
    required this.imageUrl,
    required this.title,
  });

  final int photoId;
  final String imageUrl;
  final String title;

  factory ChallengeSamplePhoto.fromJson(Map<String, dynamic> json) =>
      ChallengeSamplePhoto(
        photoId: (json['photo_id'] as num?)?.toInt() ?? 0,
        imageUrl: json['image_url']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
      );
}

class ChallengeItem {
  ChallengeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.participantCount,
    required this.daysLeft,
    required this.isJoined,
    required this.samplePhotos,
  });

  final int id;
  final String title;
  final String description;
  final String coverImageUrl;
  final int participantCount;
  final int daysLeft;
  final bool isJoined;
  final List<ChallengeSamplePhoto> samplePhotos;

  factory ChallengeItem.fromJson(Map<String, dynamic> json) {
    final raw = json['sample_photos'];
    final samples = raw is List
        ? raw
            .map((e) =>
                ChallengeSamplePhoto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <ChallengeSamplePhoto>[];
    return ChallengeItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverImageUrl: json['cover_image_url']?.toString() ?? '',
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
      isJoined: json['is_joined'] == true,
      samplePhotos: samples,
    );
  }
}
