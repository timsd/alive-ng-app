# ALIVE NG App - Tagging System Documentation

## Overview

The ALIVE NG app implements a Discord-like tagging system that allows users to target specific groups or individuals in messages and conversations. This system ensures that only relevant parties see tagged content, improving communication efficiency and maintaining appropriate visibility levels.

## Tagging Types

### 1. Role-Based Tags (# prefix)

Role-based tags target specific organizational roles and positions. Only users with the specified role can see messages containing these tags.

#### Board and Leadership Tags
- `#bod` - Board of Directors
- `#trustees` - Board Trustees
- `#executive` - Executive Committee
- `#leadership` - All leadership positions

#### Directorial Tags
- `#director` - All Directors
- `#field_director` - Field Work Director
- `#campus_director` - Campus Mission Director
- `#program_director` - Programming Director
- `#evangelism_director` - Evangelism Director
- `#amtc_director` - AMTC Director

#### Coordinator Tags
- `#chap_coor` - Chapter Coordinators
- `#field_coor` - Field Work Coordinators
- `#campus_coor` - Campus Mission Coordinators
- `#program_coor` - Programming Coordinators
- `#evangelism_coor` - Evangelism Coordinators
- `#amtc_coor` - AMTC Coordinators

#### Team and Department Tags
- `#admin` - Administrative Team
- `#treasurer` - Treasurers
- `#secretary` - Secretaries
- `#media` - Media Team
- `#tech` - Technical Team
- `#health` - Health Ministry Team

#### Chapter and Group Tags
- `#chapter_[name]` - Specific chapter (e.g., `#chapter_lagos`, `#chapter_abuja`)
- `#fieldwork` - Field Work Team
- `#campus_mission` - Campus Mission Team
- `#amtc` - AMTC Team
- `#youth` - Youth Ministry
- `#women` - Women's Ministry
- `#men` - Men's Ministry

#### Regional Tags
- `#north` - Northern Region
- `#south` - Southern Region
- `#east` - Eastern Region
- `#west` - Western Region
- `#central` - Central Region

### 2. Individual Tags (@ prefix)

Individual tags target specific users by their username or display name.

#### Format
- `@username` - Target specific user by username
- `@firstname.lastname` - Target user by name format
- `@display_name` - Target user by display name

#### Examples
- `@john.doe` - Tags user John Doe
- `@pastor_mike` - Tags user with username pastor_mike
- `@admin` - Tags user with username admin

### 3. Special Tags

#### System Tags
- `#all` - All authenticated users (use sparingly)
- `#online` - Currently online users
- `#active` - Recently active users (within 24 hours)
- `#new` - New users (joined within 30 days)

#### Event Tags
- `#meeting` - Meeting participants
- `#conference` - Conference attendees
- `#training` - Training participants
- `#event_[name]` - Specific event participants

## Tag Visibility Rules

### Role-Based Visibility

1. **Hierarchical Access**: Higher roles can see lower role tags
   - BOD can see all tags
   - Directors can see coordinator and team tags
   - Coordinators can see their team tags

2. **Peer Access**: Same-level roles can see each other's tags
   - All directors can see director tags
   - All coordinators can see coordinator tags

3. **Team Access**: Team members can see their team tags
   - Chapter members see chapter tags
   - Team members see team tags

### Individual Visibility

1. **Direct Mentions**: Tagged individuals always see the message
2. **Privacy Respect**: Only tagged users see individual mentions
3. **Group Context**: Individual tags in group contexts visible to group

### Special Visibility Rules

1. **Public Channels**: Role tags visible to all channel members
2. **Private Channels**: Tags only visible to channel members with appropriate roles
3. **Direct Messages**: All tags visible to conversation participants

## Implementation Examples

### Message Examples

```
"Greetings all #bod - Please review the quarterly report"
// Only BOD members will see this message

"@john.doe can you handle the #media setup for tomorrow?"
// John Doe and media team members will see this

"#chap_coor please submit your monthly reports by Friday"
// All chapter coordinators will see this

"Great job on the event #chapter_lagos #youth!"
// Lagos chapter members and youth ministry will see this

"#director #chap_coor - Joint meeting scheduled for next week"
// Directors and chapter coordinators will see this
```

### Multi-Tag Messages

```
"#bod #director - Strategic planning session tomorrow at 10 AM"
// Both BOD and Directors will see this message

"@pastor_mike @admin #tech - Server maintenance tonight"
// Pastor Mike, admin user, and tech team will see this

"#chapter_abuja #chapter_lagos - Inter-chapter collaboration meeting"
// Members of both Abuja and Lagos chapters will see this
```

## Database Schema

### Message Tags Table

```sql
CREATE TABLE message_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  tag_type VARCHAR(20) NOT NULL, -- 'role', 'user', 'special', 'chapter'
  tag_value VARCHAR(100) NOT NULL, -- actual tag value
  created_at TIMESTAMP DEFAULT NOW(),
  
  INDEX idx_message_tags_message_id (message_id),
  INDEX idx_message_tags_type_value (tag_type, tag_value)
);
```

### User Roles Table

```sql
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(50) NOT NULL,
  chapter_id UUID REFERENCES chapters(id),
  region VARCHAR(20),
  is_active BOOLEAN DEFAULT true,
  assigned_at TIMESTAMP DEFAULT NOW(),
  assigned_by UUID REFERENCES users(id),
  
  UNIQUE(user_id, role, chapter_id)
);
```

### Tag Visibility Rules Table

```sql
CREATE TABLE tag_visibility_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tag_pattern VARCHAR(100) NOT NULL, -- e.g., '#bod', '#director', '@*'
  required_role VARCHAR(50), -- role required to see this tag
  required_permission VARCHAR(50), -- specific permission required
  hierarchy_level INTEGER, -- for hierarchical access
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Tag Processing Logic

### Message Parsing

```dart
class TagParser {
  static List<MessageTag> parseMessage(String content) {
    List<MessageTag> tags = [];
    
    // Parse role tags (#tag)
    RegExp roleTagRegex = RegExp(r'#([a-zA-Z0-9_]+)');
    roleTagRegex.allMatches(content).forEach((match) {
      tags.add(MessageTag(
        type: TagType.role,
        value: match.group(1)!,
      ));
    });
    
    // Parse user tags (@username)
    RegExp userTagRegex = RegExp(r'@([a-zA-Z0-9_.]+)');
    userTagRegex.allMatches(content).forEach((match) {
      tags.add(MessageTag(
        type: TagType.user,
        value: match.group(1)!,
      ));
    });
    
    return tags;
  }
}
```

### Visibility Check

```dart
class TagVisibilityChecker {
  static Future<bool> canUserSeeMessage(
    String userId, 
    List<MessageTag> tags
  ) async {
    // If no tags, message is public
    if (tags.isEmpty) return true;
    
    // Check each tag
    for (MessageTag tag in tags) {
      if (await canUserSeeTag(userId, tag)) {
        return true; // User can see at least one tag
      }
    }
    
    return false;
  }
  
  static Future<bool> canUserSeeTag(
    String userId, 
    MessageTag tag
  ) async {
    switch (tag.type) {
      case TagType.role:
        return await hasRoleAccess(userId, tag.value);
      case TagType.user:
        return await isUserTagged(userId, tag.value);
      case TagType.special:
        return await hasSpecialAccess(userId, tag.value);
      default:
        return false;
    }
  }
}
```

## User Interface Implementation

### Tag Input Widget

```dart
class TagInputWidget extends StatefulWidget {
  final Function(List<MessageTag>) onTagsChanged;
  
  @override
  _TagInputWidgetState createState() => _TagInputWidgetState();
}

class _TagInputWidgetState extends State<TagInputWidget> {
  TextEditingController _controller = TextEditingController();
  List<MessageTag> _currentTags = [];
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tag suggestions dropdown
        if (_showSuggestions)
          TagSuggestionsWidget(
            query: _currentQuery,
            onTagSelected: _addTag,
          ),
        
        // Text input with tag highlighting
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Type your message... Use #role or @username to tag',
          ),
          onChanged: _onTextChanged,
        ),
        
        // Active tags display
        if (_currentTags.isNotEmpty)
          TagsDisplayWidget(tags: _currentTags),
      ],
    );
  }
}
```

### Tag Display Widget

```dart
class TagChip extends StatelessWidget {
  final MessageTag tag;
  final VoidCallback? onRemove;
  
  @override
  Widget build(BuildContext context) {
    Color chipColor = _getTagColor(tag.type);
    IconData chipIcon = _getTagIcon(tag.type);
    
    return Chip(
      avatar: Icon(chipIcon, size: 16),
      label: Text('${tag.prefix}${tag.value}'),
      backgroundColor: chipColor,
      deleteIcon: onRemove != null ? Icon(Icons.close, size: 16) : null,
      onDeleted: onRemove,
    );
  }
  
  Color _getTagColor(TagType type) {
    switch (type) {
      case TagType.role:
        return Colors.blue.shade100;
      case TagType.user:
        return Colors.green.shade100;
      case TagType.special:
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
```

## Security Considerations

### Tag Validation

1. **Role Verification**: Verify user has permission to use role tags
2. **User Existence**: Validate that tagged users exist
3. **Spam Prevention**: Limit number of tags per message
4. **Privilege Escalation**: Prevent users from tagging higher roles inappropriately

### Privacy Protection

1. **Data Encryption**: Encrypt sensitive tagged messages
2. **Audit Logging**: Log all tag usage for security monitoring
3. **Access Control**: Implement strict access controls for tag visibility
4. **Rate Limiting**: Prevent tag spam and abuse

## Performance Optimization

### Caching Strategy

1. **User Roles Cache**: Cache user roles for quick tag resolution
2. **Tag Patterns Cache**: Cache common tag patterns and rules
3. **Visibility Cache**: Cache visibility decisions for frequently accessed messages

### Database Optimization

1. **Indexes**: Proper indexing on tag tables for fast queries
2. **Partitioning**: Partition large message tables by date
3. **Materialized Views**: Pre-compute common tag visibility queries

## Testing Strategy

### Unit Tests

- Tag parsing accuracy
- Visibility rule enforcement
- Permission validation
- Edge case handling

### Integration Tests

- End-to-end tag workflow
- Real-time message delivery
- Cross-platform compatibility
- Performance under load

## Usage Guidelines

### Best Practices

1. **Be Specific**: Use specific tags rather than broad ones
2. **Avoid Spam**: Don't overuse tags in messages
3. **Respect Privacy**: Use individual tags judiciously
4. **Stay Relevant**: Only tag relevant parties

### Tag Etiquette

1. **Professional Communication**: Maintain professional tone in tagged messages
2. **Urgent vs. Non-Urgent**: Use appropriate tags for message priority
3. **Group Dynamics**: Consider group dynamics when using tags
4. **Follow-up**: Respond appropriately to tagged messages

This tagging system provides a powerful and flexible way to manage communication visibility within the ALIVE NG organization while maintaining security and user privacy.