import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/database_helper.dart';

void main() {
  runApp(const DictionaryApp());
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<Color> colorNotifier = ValueNotifier(Colors.blue);

class DictionaryApp extends StatelessWidget {
  const DictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return ValueListenableBuilder<Color>(
          valueListenable: colorNotifier,
          builder: (_, Color currentColor, __) {
            return MaterialApp(
              title: 'Grammar Dictionary',
              themeMode: currentMode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: currentColor),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: currentColor,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              home: const MainScreen(),
            );
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final ids = await DatabaseHelper.instance.getAllFavoriteIds();
    if (mounted) {
      setState(() {
        _favoriteIds = ids.toSet();
      });
    }
  }

  Future<void> _toggleFavorite(String id, bool isFav) async {
    await DatabaseHelper.instance.toggleFavorite(id, isFav);
    setState(() {
      final newFavorites = Set<String>.from(_favoriteIds);
      if (isFav) {
        newFavorites.add(id);
      } else {
        newFavorites.remove(id);
      }
      _favoriteIds = newFavorites;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          SearchTab(
            favoriteIds: _favoriteIds,
            onToggleFavorite: _toggleFavorite,
          ),
          FavoriteTab(
            favoriteIds: _favoriteIds,
            onToggleFavorite: _toggleFavorite,
          ),
          const SettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorite',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class SearchTab extends StatefulWidget {
  final Set<String> favoriteIds;
  final Function(String, bool) onToggleFavorite;

  const SearchTab({
    super.key,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _grammarList = [];
  bool _isLoading = true;
  Set<String> _selectedLevels = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    var results = await DatabaseHelper.instance.searchGrammar(
      _searchController.text,
      levels: _selectedLevels.toList(),
    );

    results = results.map((item) {
      final levelStr = item['level']?.toString();
      if (levelStr != null) {
        final levelNum = int.tryParse(levelStr);
        if (levelNum != null && levelNum >= 6) {
          final newItem = Map<String, dynamic>.from(item);
          newItem['level'] = '5';
          return newItem;
        }
      }
      return item;
    }).toList();
    if (!mounted) return;
    setState(() {
      _grammarList = results;
      _isLoading = false;
    });
  }

  void _filterWords(String query) {
    _fetchData();
  }

  void _showFilterDialog() {
    final Set<String> tempSelectedLevels = Set.from(_selectedLevels);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by JLPT Level'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ['1', '2', '3', '4', '5'].map((level) {
                    return CheckboxListTile(
                      title: Text('N$level'),
                      value: tempSelectedLevels.contains(level),
                      onChanged: (bool? checked) {
                        setDialogState(() {
                          if (checked == true) {
                            tempSelectedLevels.add(level);
                          } else {
                            tempSelectedLevels.remove(level);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedLevels = tempSelectedLevels;
                    });
                    Navigator.of(context).pop();
                    _fetchData();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter by level',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterWords,
              decoration: InputDecoration(
                hintText: 'Search for grammar (e.g. てある)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterWords('');
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _grammarList.isEmpty
                ? const Center(
                    child: Text(
                      'No grammar points found.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _grammarList.length,
                    itemBuilder: (context, index) {
                      final grammar = _grammarList[index];
                      return GrammarListItem(
                        grammar: grammar,
                        isFavorite: widget.favoriteIds.contains(
                          grammar['id']?.toString(),
                        ),
                        onToggleFavorite: (isFav) => widget.onToggleFavorite(
                          grammar['id'].toString(),
                          isFav,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class FavoriteTab extends StatefulWidget {
  final Set<String> favoriteIds;
  final Function(String, bool) onToggleFavorite;

  const FavoriteTab({
    super.key,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  @override
  State<FavoriteTab> createState() => _FavoriteTabState();
}

class _FavoriteTabState extends State<FavoriteTab> {
  List<Map<String, dynamic>> _favoriteList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  @override
  void didUpdateWidget(FavoriteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.favoriteIds != oldWidget.favoriteIds) {
      _fetchFavorites();
    }
  }

  Future<void> _fetchFavorites() async {
    setState(() {
      _isLoading = true;
    });
    final results = await DatabaseHelper.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _favoriteList = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFavorites,
              child: _favoriteList.isEmpty
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          child: Center(
                            child: const Text(
                              'No favorite grammar points yet.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _favoriteList.length,
                      itemBuilder: (context, index) {
                        final grammar = _favoriteList[index];
                        return GrammarListItem(
                          grammar: grammar,
                          isFavorite: widget.favoriteIds.contains(
                            grammar['id']?.toString(),
                          ),
                          onToggleFavorite: (isFav) => widget.onToggleFavorite(
                            grammar['id'].toString(),
                            isFav,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class GrammarListItem extends StatelessWidget {
  final Map<String, dynamic> grammar;
  final bool isFavorite;
  final Function(bool) onToggleFavorite;

  const GrammarListItem({
    super.key,
    required this.grammar,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final title = grammar['showkey']?.toString() ?? 'Unknown';
    final meaning =
        grammar['allcnmean']?.toString() ??
        grammar['search']?.toString() ??
        'No meaning';
    final level = grammar['level']?.toString() ?? '-';

    String follow = '';
    final knowledgeStr = grammar['KownLedge']?.toString() ?? '';
    if (knowledgeStr.isNotEmpty && knowledgeStr != 'null') {
      try {
        final knowledgeList = jsonDecode(knowledgeStr) as List<dynamic>;
        if (knowledgeList.isNotEmpty) {
          follow = knowledgeList[0]['follow']?.toString() ?? '';
        }
      } catch (e) {
        // Ignore decode error for list view
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GrammarDetailPage(grammarData: grammar),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark
                    ? Colors.blue.shade900.withOpacity(0.5)
                    : Colors.blue.shade50,
                child: Text(
                  'N$level',
                  style: TextStyle(
                    color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (follow.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          follow,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                ),
                onPressed: () {
                  onToggleFavorite(!isFavorite);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GrammarDetailPage extends StatelessWidget {
  final Map<String, dynamic> grammarData;

  const GrammarDetailPage({super.key, required this.grammarData});

  List<InlineSpan> _parseSentence(String text, BuildContext context) {
    final spans = <InlineSpan>[];
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');

    final pattern = RegExp(r'<hi>(.*?)</hi>');
    int lastMatchEnd = 0;

    for (var match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      );
    }

    return spans;
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = grammarData['showkey']?.toString() ?? 'Unknown';
    final fallbackMeaning =
        grammarData['allcnmean']?.toString() ??
        grammarData['tag']?.toString() ??
        'No meaning';
    final level = grammarData['level']?.toString() ?? '-';
    final discriminationStr = grammarData['discrimination']?.toString() ?? '';
    List<dynamic> discriminationList = [];
    if (discriminationStr.isNotEmpty && discriminationStr != 'null') {
      try {
        discriminationList = jsonDecode(discriminationStr);
      } catch (e) {
        debugPrint('Error decoding discrimination: $e');
      }
    }
    final knowledgeStr = grammarData['KownLedge']?.toString() ?? '';

    List<dynamic> knowledgeList = [];
    if (knowledgeStr.isNotEmpty && knowledgeStr != 'null') {
      try {
        knowledgeList = jsonDecode(knowledgeStr);
      } catch (e) {
        debugPrint('Error decoding KownLedge: $e');
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammar Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.shade900.withOpacity(0.5)
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'JLPT N$level',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),

              if (knowledgeList.isEmpty) ...[
                // Fallback UI if JSON parsing fails or is empty
                _buildSectionTitle('Meaning', context),
                Text(
                  fallbackMeaning,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (knowledgeStr.isNotEmpty && knowledgeStr != 'null') ...[
                  _buildSectionTitle('Knowledge (Raw)', context),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.green.shade900.withOpacity(0.3)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.green.shade800
                            : Colors.green.shade100,
                      ),
                    ),
                    child: Text(
                      knowledgeStr,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Render parsed JSON
                ...knowledgeList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  final cat = item['cat']?.toString() ?? '';
                  final cnmean = item['cnmean']?.toString() ?? '';
                  final cnexplain = item['cnexplain']?.toString() ?? '';
                  final jpexplain = item['jpexplain']?.toString() ?? '';
                  final cnattention = item['cnattention']?.toString() ?? '';
                  final examples = item['example'] as List<dynamic>? ?? [];

                  return Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cnmean.isNotEmpty || cat.isNotEmpty)
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cnmean,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (cat.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (cnmean.isNotEmpty || cat.isNotEmpty)
                          const SizedBox(height: 16),
                        if (cnexplain.isNotEmpty || jpexplain.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.blue.shade900.withOpacity(0.2)
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (cnexplain.isNotEmpty)
                                  Text(
                                    cnexplain,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                if (cnexplain.isNotEmpty &&
                                    jpexplain.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black12,
                                    ),
                                  ),
                                if (jpexplain.isNotEmpty)
                                  Text(
                                    jpexplain,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (cnattention.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cnattention,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.deepOrange,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (examples.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Examples',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...examples.map((ex) {
                            final sentence = ex['sentence']?.toString() ?? '';
                            if (sentence.isEmpty)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6.0,
                                      right: 8.0,
                                    ),
                                    child: Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey,
                                    ),
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: _parseSentence(
                                          sentence,
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ],

              if (discriminationList.isNotEmpty) ...[
                _buildSectionTitle('Discrimination / Notes', context),
                ...discriminationList.map((item) {
                  final info = item['discrimination_info']?.toString() ?? '';
                  final kidsList = item['kids_list'] as List<dynamic>? ?? [];
                  if (info.isEmpty) return const SizedBox.shrink();

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.shade900.withOpacity(0.2)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.orange.shade800
                            : Colors.orange.shade100,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (kidsList.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kidsList.map((k) {
                                final kStr = k.toString();
                                final parts = kStr.split(':');
                                final display = parts.length > 1
                                    ? parts[1]
                                    : kStr;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.orange.shade800
                                        : Colors.orange.shade200,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    display,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.orange.shade200
                                          : Colors.orange.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        Text(
                          info,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ] else if (discriminationStr.isNotEmpty &&
                  discriminationStr != 'null') ...[
                _buildSectionTitle('Notes / Discrimination', context),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.orange.shade900.withOpacity(0.2)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.orange.shade800
                          : Colors.orange.shade100,
                    ),
                  ),
                  child: Text(
                    discriminationStr,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentMode, child) {
              return Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('System Default'),
                    value: ThemeMode.system,
                    groupValue: currentMode,
                    onChanged: (mode) => themeNotifier.value = mode!,
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Light Mode'),
                    value: ThemeMode.light,
                    groupValue: currentMode,
                    onChanged: (mode) => themeNotifier.value = mode!,
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark Mode'),
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                    onChanged: (mode) => themeNotifier.value = mode!,
                  ),
                ],
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Theme Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ValueListenableBuilder<Color>(
            valueListenable: colorNotifier,
            builder: (context, currentColor, child) {
              final colors = [
                Colors.blue,
                Colors.red,
                Colors.green,
                Colors.purple,
                Colors.orange,
                Colors.teal,
                Colors.pink,
              ];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: colors.map((color) {
                    final isSelected = currentColor.value == color.value;
                    return GestureDetector(
                      onTap: () => colorNotifier.value = color,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
