import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutAliveScreen extends StatelessWidget {
  const AboutAliveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About ALIVE'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ALIVE Logo and Title
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A.L.I.V.E Nigeria',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Africans Living In View of Eternity',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // About Section
            _buildSection(
              'About A.L.I.V.E',
              'A.L.I.V.E is an acronym for Africans Living In View of Eternity. ALIVE-Nigeria is the Nigerian Chapter of this movement.\n\nWe are men, women, graduates and working professionals (and even student volunteers) whose hearts are burdened for spreading God\'s Word and works. A.L.I.V.E Nigeria exists to challenge and to equip with tools for individual missionary work.\n\nThe Lord has appointed the youth to be His helping hand. {ChS 30.1}.\n\nWith such an army of workers as our youth, rightly trained, might furnish, how soon the message of a crucified, risen, and soon-coming Saviour might be carried to the whole world!–Education, p. 271. {ChS 30.2}. Join us today and lets get the good news of the gospel to places where no one wants to go.',
            ),

            // Vision Section
            _buildSection(
              'Our Vision',
              'At ALIVE, our vision is to ignite and sustain a Bible-based, youth-led revival movement across the continent of Africa.\n\nRooted in the teachings and principles of the Holy Scriptures, we strive to empower and equip every Seventh-day Adventist young professional to become a dedicated missionary.\n\nOur goal is to foster a deep, personal relationship with Jesus Christ, encouraging a commitment to His Great Commission. By providing spiritual training, mentorship, and opportunities for service, we aim to create a network of passionate, faith-driven individuals who will actively share the message of hope and salvation, transforming their communities and the continent at large through the power of the gospel.',
            ),

            // Mission Section
            _buildSection(
              'Our Mission',
              'Our mission is to prepare Africa for the imminent return of Jesus Christ. Through biblical spiritual training and evangelistic efforts, it is our goal to challenge African Seventh-day Adventist young adults to live a lifestyle of authentic biblical excellence, instill a missionary volunteer spirit in every African Seventh-day Adventist young adult, mobilize and support young adult missionary movements across Africa, create a meaningful impact in neglected areas, and finally change the continent of Africa by ushering in the imminent return of Jesus Christ.',
            ),

            // Why Join Us Section
            _buildSection(
              'Why Join Us',
              'Consider Nigeria, our home, the most populous black nation in the world; that can boast of immense mineral resources that hold popular appeal, yet she suffers from the ravaging effects of disease, poverty, war, and crippling illiteracy. In a day when conflicting ideas about solving Nigeria\'s problems are all the rage, we believe, that the problems of our dying country belie a deeper problem, albeit a spiritual one. Generally, millions are yet to have a saving knowledge of Jesus Christ. The liberating three angels\' message, in particular, has not been presented in its true light.\n\nWe seek to augment the efforts of the Seventh – day Adventist ministers of the gospel in presenting the message of a loving Savior to a dying nation & the world at large by making our individual places of work our personal mission field. We volunteer our time, finances, talents and life to the gospel commission in a very unique way.\n\nMen and women graduates or working professionals whose hearts are burdened for the spread of God\'s Word and the present Truth, are encouraged to be a part of ALIVE-Nigeria. ALIVE-Nigeria calls for those godly, gutsy, and smart individuals who yearn to represent Christ in their places of work and study, whose minds are preoccupied with presenting the advent message anywhere, anytime. ALIVE-Nigeria exists to challenge and to equip willing hands with tools for individual missionary work.\n\nWe are committed to excellence in our service to God and humanity. In practical terms, this means, ALIVE programs and its members are committed to doing ordinary things extraordinarily well. In ALIVE, every little thing matters. Every detail counts.',
            ),

            // Leadership Section
            const Text(
              'Leadership Team',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            _buildLeaderCard(
              'Nwoko Patience Mfon',
              'Executive President',
              Icons.person,
            ),

            _buildLeaderCard(
              'Caleb Peters',
              'Secretary/Communication Director',
              Icons.chat,
            ),

            _buildLeaderCard(
              'Godstime Esuku',
              'Speaker / Director: ALIVE Mission Training Center (AMTC)',
              Icons.school,
            ),

            _buildLeaderCard(
              'Timothy Olodude',
              'Treasure / Director of Logistics',
              Icons.account_balance_wallet,
            ),

            _buildLeaderCard(
              'Emenike Ekechi',
              'Director: Evangelism/Programming/Health',
              Icons.health_and_safety,
            ),

            const SizedBox(height: 24),

            // Contact Section
            const Text(
              'Contact Us',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _launchEmail('alivenigeria2011@gmail.com'),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'alivenigeria2011@gmail.com',
                              style: TextStyle(
                                color: Colors.green,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _launchPhone('+2347068548865'),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '+2347068548865',
                            style: TextStyle(
                              color: Colors.green,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            height: 1.6,
          ),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLeaderCard(String name, String position, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          position,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=ALIVE Nigeria Inquiry',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _launchPhone(String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}
