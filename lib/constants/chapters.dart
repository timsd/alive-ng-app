// Chapter Constants for ALIVE Nigeria App

class ChapterConstants {
  static const List<String> availableChapters = [
    'Ibadan',
    'Ife',
    'Abuja',
    'Lagos',
    'Benin',
    'Diaspora',
    'Kaduna',
    'Port Harcourt',
    'Lagos 1',
    'Lagos 2',
    'Lagos 3',
    'Babcock',
    'Abia',
    'Jos',
  ];

  static const Map<String, String> chapterDescriptions = {
    'Ibadan': 'ALIVE Nigeria Ibadan Chapter',
    'Ife': 'ALIVE Nigeria Ife Chapter',
    'Abuja': 'ALIVE Nigeria Abuja Chapter',
    'Lagos': 'ALIVE Nigeria Lagos Chapter',
    'Benin': 'ALIVE Nigeria Benin Chapter',
    'Diaspora': 'ALIVE Nigeria Diaspora Chapter',
    'Kaduna': 'ALIVE Nigeria Kaduna Chapter',
    'Port Harcourt': 'ALIVE Nigeria Port Harcourt Chapter',
    'Lagos 1': 'ALIVE Nigeria Lagos 1 Chapter',
    'Lagos 2': 'ALIVE Nigeria Lagos 2 Chapter',
    'Lagos 3': 'ALIVE Nigeria Lagos 3 Chapter',
    'Babcock': 'ALIVE Nigeria Babcock Chapter',
    'Abia': 'ALIVE Nigeria Abia Chapter',
    'Jos': 'ALIVE Nigeria Jos Chapter',
  };

  static const List<String> userRoles = [
    'member',
    'coordinator',
    'leader',
    'admin',
  ];

  static const List<String> teamTypes = [
    'Field Workers',
    'Campus Missionary Team',
    'AMTC Team',
  ];

  static bool isValidChapter(String chapter) {
    return availableChapters.contains(chapter);
  }

  static bool isValidRole(String role) {
    return userRoles.contains(role);
  }

  static bool isValidTeamType(String teamType) {
    return teamTypes.contains(teamType);
  }
}
