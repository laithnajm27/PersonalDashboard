class InstagramPost {
  const InstagramPost({
    required this.id,
    this.caption = '',
    this.permalink = '',
    this.mediaType = '',
    this.timestamp,
    this.likeCount = 0,
    this.commentsCount = 0,
    this.reach = 0,
  });

  final String id;
  final String caption;
  final String permalink;
  final String mediaType;
  final DateTime? timestamp;
  final int likeCount;
  final int commentsCount;
  final int reach;

  factory InstagramPost.fromJson(Map<String, dynamic> json) {
    return InstagramPost(
      id: json['id']?.toString() ?? '',
      caption: json['caption'] as String? ?? '',
      permalink: json['permalink'] as String? ?? '',
      mediaType: json['media_type'] as String? ?? '',
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.tryParse(json['timestamp'] as String),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      reach: (json['reach'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'caption': caption,
        'permalink': permalink,
        'media_type': mediaType,
        'timestamp': timestamp?.toIso8601String(),
        'like_count': likeCount,
        'comments_count': commentsCount,
        'reach': reach,
      };
}

class InstagramInsights {
  const InstagramInsights({
    required this.followerCount,
    required this.impressions,
    this.reach = 0,
    required this.engagementRate,
    this.username = '',
    this.topPosts = const [],
    this.updatedAt,
  });

  final int followerCount;
  final int impressions;
  final int reach;
  final double engagementRate;
  final String username;
  final List<InstagramPost> topPosts;
  final DateTime? updatedAt;

  factory InstagramInsights.fromJson(Map<String, dynamic> json) {
    final posts = json['top_posts'] as List<dynamic>? ?? const [];
    return InstagramInsights(
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      reach: (json['reach'] as num?)?.toInt() ?? 0,
      engagementRate: (json['engagement_rate'] as num?)?.toDouble() ?? 0,
      username: json['username'] as String? ?? '',
      topPosts: posts
          .whereType<Map<String, dynamic>>()
          .map(InstagramPost.fromJson)
          .toList(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'follower_count': followerCount,
        'impressions': impressions,
        'reach': reach,
        'engagement_rate': engagementRate,
        'username': username,
        'top_posts': topPosts.map((post) => post.toJson()).toList(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}
