// Board Report Model
import 'dart:convert';

class BoardReport {
  final String id;
  final String title;
  final String description;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String category; // 'financial', 'operational', 'strategic', 'ministry'
  final List<String> attachments;
  final String status; // 'draft', 'submitted', 'reviewed', 'approved'
  final Map<String, dynamic>? metadata;

  BoardReport({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.updatedAt,
    required this.category,
    this.attachments = const [],
    this.status = 'draft',
    this.metadata,
  });

  factory BoardReport.fromJson(Map<String, dynamic> json) {
    return BoardReport(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      content: json['content'] ?? '',
      authorId: json['author_id'] ?? '',
      authorName: json['author_name'] ?? '',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      category: json['category'] ?? 'operational',
      attachments: List<String>.from(json['attachments'] ?? []),
      status: json['status'] ?? 'draft',
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'author_id': authorId,
      'author_name': authorName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'category': category,
      'attachments': attachments,
      'status': status,
      'metadata': metadata,
    };
  }
}

// Board Decision Model
class BoardDecision {
  final String id;
  final String title;
  final String description;
  final String proposedBy;
  final String proposerId;
  final DateTime proposedAt;
  final DateTime? votingDeadline;
  final String
      status; // 'proposed', 'voting', 'approved', 'rejected', 'deferred'
  final List<DecisionVote> votes;
  final String? resolution;
  final DateTime? resolvedAt;
  final String category; // 'policy', 'financial', 'strategic', 'operational'
  final bool requiresUnanimous;

  BoardDecision({
    required this.id,
    required this.title,
    required this.description,
    required this.proposedBy,
    required this.proposerId,
    required this.proposedAt,
    this.votingDeadline,
    this.status = 'proposed',
    this.votes = const [],
    this.resolution,
    this.resolvedAt,
    required this.category,
    this.requiresUnanimous = false,
  });

  factory BoardDecision.fromJson(Map<String, dynamic> json) {
    return BoardDecision(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      proposedBy: json['proposed_by'] ?? '',
      proposerId: json['proposer_id'] ?? '',
      proposedAt: DateTime.parse(
          json['proposed_at'] ?? DateTime.now().toIso8601String()),
      votingDeadline: json['voting_deadline'] != null
          ? DateTime.parse(json['voting_deadline'])
          : null,
      status: json['status'] ?? 'proposed',
      votes: _parseVotes(json['votes']),
      resolution: json['resolution'],
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      category: json['category'] ?? 'operational',
      requiresUnanimous: json['requires_unanimous'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'proposed_by': proposedBy,
      'proposer_id': proposerId,
      'proposed_at': proposedAt.toIso8601String(),
      'voting_deadline': votingDeadline?.toIso8601String(),
      'status': status,
      'votes': votes.map((vote) => vote.toJson()).toList(),
      'resolution': resolution,
      'resolved_at': resolvedAt?.toIso8601String(),
      'category': category,
      'requires_unanimous': requiresUnanimous,
    };
  }
}

// Decision Vote Model
List<DecisionVote> _parseVotes(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((vote) => DecisionVote.fromJson(Map<String, dynamic>.from(vote)))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((vote) => DecisionVote.fromJson(Map<String, dynamic>.from(vote)))
        .toList();
  }
  return const [];
}

class DecisionVote {
  final String id;
  final String decisionId;
  final String voterId;
  final String voterName;
  final String vote; // 'approve', 'reject', 'abstain'
  final String? comment;
  final DateTime votedAt;

  DecisionVote({
    required this.id,
    required this.decisionId,
    required this.voterId,
    required this.voterName,
    required this.vote,
    this.comment,
    required this.votedAt,
  });

  factory DecisionVote.fromJson(Map<String, dynamic> json) {
    return DecisionVote(
      id: json['id'] ?? '',
      decisionId: json['decision_id'] ?? '',
      voterId: json['voter_id'] ?? '',
      voterName: json['voter_name'] ?? '',
      vote: json['vote'] ?? 'abstain',
      comment: json['comment'],
      votedAt:
          DateTime.parse(json['voted_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'decision_id': decisionId,
      'voter_id': voterId,
      'voter_name': voterName,
      'vote': vote,
      'comment': comment,
      'voted_at': votedAt.toIso8601String(),
    };
  }
}

// Board Document Model
class BoardDocument {
  final String id;
  final String title;
  final String description;
  final String fileName;
  final String fileUrl;
  final String fileType; // 'pdf', 'doc', 'xlsx', 'ppt', etc.
  final int fileSize;
  final String uploadedBy;
  final String uploaderId;
  final DateTime uploadedAt;
  final String
      category; // 'policy', 'financial', 'meeting_minutes', 'strategic', 'legal'
  final String
      accessLevel; // 'public', 'board_only', 'trustees_only', 'admin_only'
  final List<String> tags;
  final bool isArchived;

  BoardDocument({
    required this.id,
    required this.title,
    required this.description,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedBy,
    required this.uploaderId,
    required this.uploadedAt,
    required this.category,
    this.accessLevel = 'board_only',
    this.tags = const [],
    this.isArchived = false,
  });

  factory BoardDocument.fromJson(Map<String, dynamic> json) {
    return BoardDocument(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      fileName: json['file_name'] ?? '',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? '',
      fileSize: json['file_size'] ?? 0,
      uploadedBy: json['uploaded_by'] ?? '',
      uploaderId: json['uploader_id'] ?? '',
      uploadedAt: DateTime.parse(
          json['uploaded_at'] ?? DateTime.now().toIso8601String()),
      category: json['category'] ?? 'policy',
      accessLevel: json['access_level'] ?? 'board_only',
      tags: List<String>.from(json['tags'] ?? []),
      isArchived: json['is_archived'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_by': uploadedBy,
      'uploader_id': uploaderId,
      'uploaded_at': uploadedAt.toIso8601String(),
      'category': category,
      'access_level': accessLevel,
      'tags': tags,
      'is_archived': isArchived,
    };
  }
}




