import 'package:flutter/material.dart';
import 'dart:io';
import 'services/history_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyItems = [];
  String _selectedFilter = 'All';
  List<String> _filters = ['All'];
  late VoidCallback _recordsListener;

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
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Load history from HistoryService and listen for updates
    _historyItems = HistoryService.instance.getAll();
    _recordsListener = () {
      if (!mounted) return;
      setState(() {
        _historyItems = HistoryService.instance.getAll();
      });
    };
    HistoryService.instance.recordsNotifier.addListener(_recordsListener);

    // mark as loaded
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    HistoryService.instance.recordsNotifier.removeListener(_recordsListener);
    super.dispose();
  }



  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedFilter == 'All') {
      return _historyItems;
    }
    return _historyItems.where((item) => item['category'] == _selectedFilter).toList();
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
            'Loading History...',
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildFilterChips(),
                ],
              ),
            ),
            Expanded(
              child: _buildHistoryList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Classification History',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'View your past classification results',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_filteredItems.length} items',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    // Build unique categories from history + 'All'
    _filters = ['All'];
    final Set<String> categories = {};
    for (final item in _historyItems) {
      categories.add(item['category'] as String);
    }
    _filters.addAll(categories.toList()..sort());
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final isSelected = filter == _selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF6366F1),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey[300]!,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No history found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different filter or classify some images',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return _buildHistoryItem(item, index);
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item, int index) {
    final category = item['category'] as String;
    final confidence = item['confidence'] as double;
    final timestamp = item['timestamp'] as DateTime;
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
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
                  onTap: () => _showItemDetails(item),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: (item['imagePath'] != null && (item['imagePath'] as String).isNotEmpty)
                                ? Image.file(
                                    File(item['imagePath'] as String),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _getCategoryColor(category).withOpacity(0.3),
                                              _getCategoryColor(category).withOpacity(0.1),
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(category),
                                          color: _getCategoryColor(category),
                                          size: 28,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getCategoryColor(category).withOpacity(0.3),
                                          _getCategoryColor(category).withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(category),
                                      color: _getCategoryColor(category),
                                      size: 28,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    category,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getConfidenceColor(confidence).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${(confidence * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: _getConfidenceColor(confidence),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
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
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Cat':
        return const Color(0xFF6366F1);
      case 'Dog':
        return const Color(0xFF8B5CF6);
      case 'Bird':
        return const Color(0xFFEC4899);
      case 'Car':
        return const Color(0xFF10B981);
      case 'Tree':
        return const Color(0xFFF59E0B);
      case 'Building':
        return const Color(0xFFEF4444);
      case 'Person':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Cat':
        return Icons.pets;
      case 'Dog':
        return Icons.pets;
      case 'Bird':
        return Icons.flight;
      case 'Car':
        return Icons.directions_car;
      case 'Tree':
        return Icons.park;
      case 'Building':
        return Icons.apartment;
      case 'Person':
        return Icons.person;
      default:
        return Icons.category;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return const Color(0xFF10B981);
    if (confidence >= 0.8) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else {
      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    }
  }

  void _showItemDetails(Map<String, dynamic> item) {
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
                    color: _getCategoryColor(item['category']).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCategoryIcon(item['category']),
                    color: _getCategoryColor(item['category']),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['category'],
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Classification Result',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Confidence', '${(item['confidence'] * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 12),
            _buildDetailRow('Timestamp', _formatTimestamp(item['timestamp'])),
            const SizedBox(height: 12),
            _buildDetailRow('ID', item['id']),
            const SizedBox(height: 24),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final trueLabel = item['trueLabel'] as String?;
                return Column(
                  children: [
                    if (trueLabel != null)
                      _buildDetailRow('True Label', trueLabel),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showSetTrueLabelDialog(item);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(trueLabel == null ? 'Set True Label' : 'Edit True Label'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (trueLabel != null)
                          SizedBox(
                            width: 120,
                            child: OutlinedButton(
                              onPressed: () {
                                // remove true label
                                HistoryService.instance.setTrueLabel(item['id'] as String, '');
                                Navigator.of(context).pop();
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSetTrueLabelDialog(Map<String, dynamic> item) async {
    final existingCategories = <String>{};
    for (final rec in HistoryService.instance.getAll()) {
      final cat = rec['category'] as String? ?? '';
      if (cat.isNotEmpty) existingCategories.add(cat);
      final t = rec['trueLabel'] as String? ?? '';
      if (t.isNotEmpty) existingCategories.add(t);
    }

    final List<String> options = existingCategories.toList()..sort();
    String? selected = item['trueLabel'] as String? ?? (options.isNotEmpty ? options.first : null);
    final TextEditingController customController = TextEditingController(text: selected);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Set True Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (options.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selected,
                  items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    selected = v;
                    customController.text = v ?? '';
                  },
                  decoration: const InputDecoration(labelText: 'Choose existing label'),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: customController,
                decoration: const InputDecoration(labelText: 'Or enter custom label'),
                onChanged: (v) => selected = v,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final val = (selected ?? '').trim();
                if (val.isNotEmpty) {
                  HistoryService.instance.setTrueLabel(item['id'] as String, val);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': '),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF1F2937),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}