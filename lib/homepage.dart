import 'package:flutter/material.dart';
import 'services/history_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;

  static const List<Map<String, dynamic>> _classMetadata = [
    {
      'name': 'National ID',
      'description': 'Philippine national identification card',
      'icon': Icons.badge,
      'color': Color(0xFF6366F1),
    },
    {
      'name': 'Drivers License',
      'description': 'Official driving permit document',
      'icon': Icons.credit_card,
      'color': Color(0xFF8B5CF6),
    },
    {
      'name': 'Voters ID',
      'description': 'Philippine voter registration card',
      'icon': Icons.how_to_vote,
      'color': Color(0xFFEC4899),
    },
    {
      'name': 'Passport',
      'description': 'International travel document',
      'icon': Icons.travel_explore,
      'color': Color(0xFF10B981),
    },
    {
      'name': 'SSS ID',
      'description': 'Social Security System card',
      'icon': Icons.card_membership,
      'color': Color(0xFFF59E0B),
    },
    {
      'name': 'Health ID',
      'description': 'PhilHealth identification card',
      'icon': Icons.health_and_safety,
      'color': Color(0xFFEF4444),
    },
    {
      'name': 'OWWA ID',
      'description': 'Overseas Workers Welfare card',
      'icon': Icons.travel_explore,
      'color': Color(0xFF3B82F6),
    },
    {
      'name': 'PAG-IBIG ID',
      'description': 'Home development fund card',
      'icon': Icons.savings,
      'color': Color(0xFFEC4899),
    },
    {
      'name': 'Postal ID',
      'description': 'Philippine postal identification',
      'icon': Icons.mail,
      'color': Color(0xFF10B981),
    },
    {
      'name': 'TIN ID',
      'description': 'Tax identification number card',
      'icon': Icons.receipt,
      'color': Color(0xFF6366F1),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Listen for history changes to update counts on the homepage
    HistoryService.instance.recordsNotifier.addListener(_onHistoryChanged);

    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    HistoryService.instance.recordsNotifier.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      _isLoading = false;
    });
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading ? _buildLoadingState() : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Classes...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildStatsRow(),
              const SizedBox(height: 32),
              _buildClassesGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Philippine ID Classification Classes',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Explore our AI-powered image classification categories',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final stats = HistoryService.instance.getStats();
    final totalClassifications = stats['total'] as int;
    final totalClasses = _classMetadata.length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.category_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  '$totalClasses',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Classes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: const Color(0xFF10B981),
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  '$totalClassifications',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Classifications',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Classes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/classify');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start Classifying',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: _classMetadata.length,
          itemBuilder: (context, index) {
            final classItem = _classMetadata[index];
            return _buildClassCard(classItem, index);
          },
        ),
      ],
    );
  }

  static const Map<String, String> _classImageMap = {
    'National ID': 'assets/images/philippine_national_id.jpg',
    'Drivers License': 'assets/images/philippine_drivers_license.jpg',
    'Voters ID': 'assets/images/philippine_voters_id.jpg',
    'Passport': 'assets/images/philippine_passport.jpg',
    'SSS ID': 'assets/images/philippine_sss_id.jpg',
    'Health ID': 'assets/images/philippine_health_id.jpg',
    'OWWA ID': 'assets/images/philippine_owwa_id.jpg',
    'PAG-IBIG ID': 'assets/images/philippine_pag_ibig_id.jpg',
    'Postal ID': 'assets/images/philippine_postal_id.jpg',
    'TIN ID': 'assets/images/philippine_tin_id.jpg',
  };

  Widget _buildClassCard(Map<String, dynamic> classItem, int index) {
    final assetPath = _classImageMap[classItem['name'] as String] ?? 'assets/images/philippine_national_id.jpg';
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (value * 0.1),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showClassDetails(classItem),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                child: Image.asset(
                                  assetPath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFF9FAFB),
                                      child: Icon(
                                        classItem['icon'] as IconData,
                                        color: classItem['color'] as Color,
                                        size: 40,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  classItem['icon'] as IconData,
                                  color: classItem['color'] as Color,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classItem['name'] as String,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              classItem['description'] as String,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showClassDetails(Map<String, dynamic> classItem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (classItem['color'] as Color).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    classItem['icon'] as IconData,
                    color: classItem['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classItem['name'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Classification Class',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              classItem['description'] as String,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4B5563),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final records = HistoryService.instance.getAll();
                    final nameKey = (classItem['name'] as String).toLowerCase().trim();
                    final count = records.where((r) {
                      final cat = (r['category'] as String? ?? '').toLowerCase().trim();
                      return cat == nameKey;
                    }).length;

                    return Text(
                      'Classified $count times',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamed(context, '/classify');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: classItem['color'] as Color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Classify Image'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
