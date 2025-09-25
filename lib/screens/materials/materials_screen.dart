import 'package:flutter/material.dart';
import '../../models/donation_models.dart';
import '../../services/donation_service.dart';
import '../../utils/app_theme.dart';
import 'donation_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen>
    with SingleTickerProviderStateMixin {
  final DonationService _donationService = DonationService();
  late TabController _tabController;

  List<DownloadableMaterial> _materials = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _showDonationRequired = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final categories = await _donationService.getMaterialCategories();
      final materials = await _donationService.getMaterials();

      setState(() {
        _categories = ['All', ...categories];
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load materials: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchMaterials() async {
    if (_searchQuery.isEmpty) {
      _loadData();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final materials = await _donationService.searchMaterials(
        query: _searchQuery,
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );

      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _filterByCategory(String? category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    try {
      final materials = await _donationService.getMaterials(
        category: category == 'All' ? null : category,
      );

      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Filter failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadMaterial(DownloadableMaterial material) async {
    try {
      // Check if user can download
      final canDownload =
          await _donationService.canUserDownloadMaterial(material.id);

      if (!canDownload && material.requiresDonation) {
        // Show donation dialog
        if (!mounted) return;
        final donated = await showDialog<bool>(
          context: context,
          builder: (context) => DonationDialog(
            material: material,
            donationType: material.category == 'Tracts'
                ? DonationType.tractReprint
                : DonationType.materialDownload,
          ),
        );

        if (donated != true) return;
      }

      // Generate download URL
      final downloadUrl =
          await _donationService.generateDownloadUrl(material.id);

      // Launch download
      if (await canLaunchUrl(Uri.parse(downloadUrl))) {
        await launchUrl(Uri.parse(downloadUrl));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading ${material.title}...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Could not launch download');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<DownloadableMaterial> get _filteredMaterials {
    var materials = _materials;

    if (_showDonationRequired) {
      materials = materials.where((m) => m.requiresDonation).toList();
    }

    return materials;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Materials & Downloads'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All Materials'),
            Tab(text: 'Study Guides'),
            Tab(text: 'Tracts'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search materials...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _loadData();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    if (value.isEmpty) {
                      _loadData();
                    }
                  },
                  onSubmitted: (_) => _searchMaterials(),
                ),
                const SizedBox(height: 12),

                // Category Filter and Options
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: _filterByCategory,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Donation Required'),
                      selected: _showDonationRequired,
                      onSelected: (selected) {
                        setState(() => _showDonationRequired = selected);
                      },
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                      checkmarkColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Materials List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMaterialsList(_filteredMaterials),
                _buildMaterialsList(
                  _filteredMaterials
                      .where((m) => m.category == 'Study Guides')
                      .toList(),
                ),
                _buildMaterialsList(
                  _filteredMaterials
                      .where((m) => m.category == 'Tracts')
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsList(List<DownloadableMaterial> materials) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (materials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No materials found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: materials.length,
        itemBuilder: (context, index) {
          final material = materials[index];
          return _buildMaterialCard(material);
        },
      ),
    );
  }

  Widget _buildMaterialCard(DownloadableMaterial material) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and category
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          material.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (material.requiresDonation)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volunteer_activism,
                          size: 14,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Donation Required',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            if (material.description.isNotEmpty)
              Text(
                material.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),

            const SizedBox(height: 16),

            // Footer with stats and download button
            Row(
              children: [
                // File info
                Icon(
                  Icons.insert_drive_file,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '${material.formattedFileSize} • ${material.downloadCount} downloads',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),

                const Spacer(),

                // Minimum donation amount
                if (material.requiresDonation)
                  Text(
                    'Min: \$${material.minimumDonation.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                const SizedBox(width: 12),

                // Download button
                ElevatedButton.icon(
                  onPressed: () => _downloadMaterial(material),
                  icon: Icon(
                    material.requiresDonation
                        ? Icons.volunteer_activism
                        : Icons.download,
                    size: 18,
                  ),
                  label: Text(
                    material.requiresDonation
                        ? 'Donate & Download'
                        : 'Download',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: material.requiresDonation
                        ? Colors.orange
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
