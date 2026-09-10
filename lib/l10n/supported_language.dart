enum SupportedLanguage {
  english('en', 'English'),
  yoruba('yo', 'Yorùbá'),
  igbo('ig', 'Igbo'),
  hausa('ha', 'Hausa');

  const SupportedLanguage(this.code, this.name);
  final String code;
  final String name;
}
