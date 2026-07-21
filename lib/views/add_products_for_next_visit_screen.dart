import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/app_constants.dart';
import '../app/app_text_styles.dart';
import '../widgets/liquid_glass_instruction_card.dart';
import 'cart_screen.dart';

enum PriceSortMode { none, lowToHigh, highToLow }

class AddProductsForNextVisitScreen extends StatefulWidget {
  final String userID;
  final String bookingID;
  final String visitDate;
  final String fetchCatalogUrl;
  final List<Map<String, dynamic>> cartItems;
  final ValueChanged<List<Map<String, dynamic>>> onCartUpdated;
  final String assignedMali;

  const AddProductsForNextVisitScreen({
    super.key,
    required this.userID,
    required this.bookingID,
    required this.visitDate,
    required this.cartItems,
    required this.fetchCatalogUrl,
    required this.onCartUpdated,
    this.assignedMali = '',
  });

  @override
  State<AddProductsForNextVisitScreen> createState() =>
      _AddProductsForNextVisitScreenState();
}

class _AddProductsForNextVisitScreenState
    extends State<AddProductsForNextVisitScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  late List<Map<String, dynamic>> _cart;

  List<String> _categories = [];
  List<String> _subcategories = [];

  String _selectedCategory = 'All';
  String _selectedSubcategory = 'All';
  String _searchQuery = '';

  PriceSortMode _priceSortMode = PriceSortMode.none;

  bool _isLoading = true;
  String? _errorMessage;
  bool _showSubcategories = false;
  Timer? _timer;
  DateTime _now = DateTime.now();

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _gold = Color(0xFFFFB72B);
  static List<Map<String, dynamic>> _cachedProducts = [];
  static DateTime? _cachedAt;

  static const String _inventoryUrl =
      'https://t88ws5o070.execute-api.ap-south-1.amazonaws.com/fetchInventoryForBooking';

  @override
  void initState() {
    super.initState();

    _cart = List<Map<String, dynamic>>.from(widget.cartItems);
    _fetchProducts();

    _searchController.addListener(() {
      _updateSearchQuery(_searchController.text);
    });

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _copyCartItems(List<Map<String, dynamic>> items) {
    return items
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _syncCartToParent() {
    widget.onCartUpdated(_copyCartItems(_cart));
  }

  int _sortByTitle(Map<String, dynamic> a, Map<String, dynamic> b) {
    final t1 = (a['title'] ?? '').toString().toLowerCase();
    final t2 = (b['title'] ?? '').toString().toLowerCase();
    return t1.compareTo(t2);
  }

  double _toPrice(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool? _parseAvailabilityValue(dynamic value) {
    if (value == null) return null;

    if (value is bool) return value;

    if (value is num) return value != 0;

    final normalized = value.toString().trim().toLowerCase();

    if (const {
      'true',
      '1',
      'yes',
      'y',
      'active',
      'available',
      'enabled',
    }.contains(normalized)) {
      return true;
    }

    if (const {
      'false',
      '0',
      'no',
      'n',
      'inactive',
      'unavailable',
      'not available',
      'disabled',
      'archived',
    }.contains(normalized)) {
      return false;
    }

    return null;
  }

  bool _isProductAvailable(Map<String, dynamic> product) {
    final explicitAvailability = _parseAvailabilityValue(
      product['isAvailable'] ??
          product['isActive'] ??
          product['active'] ??
          product['Active'],
    );

    if (explicitAvailability != null) {
      return explicitAvailability;
    }

    final statusAvailability = _parseAvailabilityValue(
      product['status'] ??
          product['Status'] ??
          product['productStatus'] ??
          product['inventoryStatus'] ??
          product['availabilityStatus'],
    );

    // Keep old records available when no active/inactive field exists.
    return statusAvailability ?? true;
  }

  bool _removeUnavailableCartItems(
      List<Map<String, dynamic>> products,
      ) {
    final availabilityBySku = <String, bool>{};

    for (final product in products) {
      final sku = (product['skuID'] ?? '').toString().trim();
      if (sku.isNotEmpty) {
        availabilityBySku[sku] = _isProductAvailable(product);
      }
    }

    final previousLength = _cart.length;

    _cart.removeWhere((item) {
      final sku = (item['skuID'] ?? '').toString().trim();
      return availabilityBySku.containsKey(sku) &&
          availabilityBySku[sku] == false;
    });

    return previousLength != _cart.length;
  }

  Future<void> _fetchProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // TEMP: clear cache while fixing/debugging
      _cachedProducts = [];
      _cachedAt = null;

      final response = await http.get(Uri.parse(_inventoryUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to load products');
      }

      final List list = jsonDecode(response.body);

      final products = List<Map<String, dynamic>>.from(list)
          .map(_normalizeInventoryProduct)
          .where((p) => (p['title'] ?? '').toString().trim().isNotEmpty)
          .toList();

      products.sort(_sortByTitle);

      final categorySet = products
          .map((p) => (p['category'] ?? '').toString().trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();

      categorySet.sort();

      if (categorySet.remove('Plants')) {
        categorySet.insert(0, 'Plants');
      }

      debugPrint('TOTAL PRODUCTS: ${products.length}');
      debugPrint('CATEGORY LIST: $categorySet');

      if (!mounted) return;

      final removedUnavailableCartItems =
      _removeUnavailableCartItems(products);

      setState(() {
        _products = products;
        _categories = ['All', ...categorySet];

        _selectedCategory = _categories.contains('Plants') ? 'Plants' : 'All';

        _setupSubcategories(_selectedCategory);
        _applyFilters();

        _isLoading = false;
      });

      if (removedUnavailableCartItems) {
        _syncCartToParent();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'An unavailable product was removed from your cart.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Inventory fetch error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load products. Please try again.';
      });
    }
  }

  Map<String, dynamic> _normalizeInventoryProduct(
      Map<String, dynamic> raw,
      ) {
    final title = (raw['title'] ??
        raw['Title'] ??
        raw['name'] ??
        raw['Name'] ??
        raw['itemName'] ??
        raw['Item_Name'] ??
        raw['productName'] ??
        '')
        .toString();

    final category = (raw['category'] ??
        raw['Category'] ??
        raw['productCategory'] ??
        raw['Product_Category'] ??
        '')
        .toString()
        .trim();

    final subcategory = (raw['subcategory'] ??
        raw['subCategory'] ??
        raw['Subcategory'] ??
        raw['Sub_Category'] ??
        '')
        .toString()
        .trim();

    final skuID = (raw['skuID'] ??
        raw['skuId'] ??
        raw['SKU'] ??
        raw['sku'] ??
        raw['itemID'] ??
        raw['Item_ID'] ??
        raw['id'] ??
        title)
        .toString();

    final price = raw['price'] ??
        raw['Price'] ??
        raw['sellingPrice'] ??
        raw['Selling_Price'] ??
        raw['rate'] ??
        raw['Rate'] ??
        0;

    final image = (raw['Image_1'] ??
        raw['imageUrl'] ??
        raw['imageURL'] ??
        raw['image'] ??
        raw['Image'] ??
        '')
        .toString();

    final status = (raw['status'] ??
        raw['Status'] ??
        raw['productStatus'] ??
        raw['inventoryStatus'] ??
        '')
        .toString()
        .trim();

    final explicitAvailability = _parseAvailabilityValue(
      raw['isAvailable'] ??
          raw['isActive'] ??
          raw['active'] ??
          raw['Active'],
    );

    final statusAvailability = _parseAvailabilityValue(
      status.isNotEmpty ? status : raw['availabilityStatus'],
    );

    final isAvailable =
        explicitAvailability ?? statusAvailability ?? true;

    return {
      ...raw,
      'title': title,
      'skuID': skuID,
      'price': price,
      'Image_1': image,
      'category': category,
      'subcategory': subcategory,
      'status': status.isNotEmpty
          ? status
          : (isAvailable ? 'Active' : 'Inactive'),
      'isAvailable': isAvailable,
      'availabilityStatus':
      isAvailable ? 'Available' : 'Not available',
    };
  }

  void _setupCategories() {
    final categorySet = <String>{};

    for (final product in _products) {
      final category = (product['category'] ?? '').toString().trim();
      if (category.isNotEmpty) {
        categorySet.add(category);
      }
    }

    final sorted = categorySet.toList()..sort();

    if (sorted.remove('Plants')) {
      sorted.insert(0, 'Plants');
    }

    _categories = ['All', ...sorted];
  }

  void _setupSubcategories(String category) {
    final subcategorySet = <String>{};

    for (final product in _products) {
      final productCategory = (product['category'] ?? '').toString().trim();
      final sub = (product['subcategory'] ?? '').toString().trim();

      if (sub.isEmpty) continue;

      if (category == 'All' || productCategory == category) {
        subcategorySet.add(sub);
      }
    }

    final sorted = subcategorySet.toList()..sort();

    _subcategories = ['All', ...sorted];
    _selectedSubcategory = 'All';
  }

  void _applyCategoryFilter(String category) {
    setState(() {
      if (_selectedCategory == category) {
        _showSubcategories = !_showSubcategories;
      } else {
        _selectedCategory = category;
        _setupSubcategories(category);
        _showSubcategories = true;
      }

      _selectedSubcategory = 'All';
      _applyFilters();
    });
  }

  double _chipWidth(String text) {
    final calculated = 34 + (text.length * 8.5);
    return calculated.clamp(86.0, 190.0);
  }

  void _applySubcategoryFilter(String subcategory) {
    setState(() {
      _selectedSubcategory = subcategory;
      _applyFilters();
    });
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> tempList;

    if (_selectedCategory == 'All') {
      tempList = List<Map<String, dynamic>>.from(_products);
    } else {
      tempList = _products
          .where((p) => (p['category'] ?? '').toString() == _selectedCategory)
          .toList();
    }

    if (_selectedSubcategory != 'All') {
      tempList = tempList
          .where((p) =>
      (p['subcategory'] ?? '').toString() == _selectedSubcategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempList = tempList.where((product) {
        final title = (product['title'] ?? '').toString().toLowerCase();
        final category = (product['category'] ?? '').toString().toLowerCase();
        final subcategory =
        (product['subcategory'] ?? '').toString().toLowerCase();

        return title.contains(_searchQuery) ||
            category.contains(_searchQuery) ||
            subcategory.contains(_searchQuery);
      }).toList();
    }

    if (_priceSortMode == PriceSortMode.lowToHigh) {
      tempList.sort((a, b) => _toPrice(a['price']).compareTo(_toPrice(b['price'])));
    } else if (_priceSortMode == PriceSortMode.highToLow) {
      tempList.sort((a, b) => _toPrice(b['price']).compareTo(_toPrice(a['price'])));
    } else {
      tempList.sort(_sortByTitle);
    }

    _filteredProducts = tempList;
  }

  DateTime? _parseVisitDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final yearRaw = int.parse(parts[2]);
      final year = parts[2].length == 2 ? 2000 + yearRaw : yearRaw;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  DateTime? _getProductOrderingCutoff() {
    final visitDate = _parseVisitDate(widget.visitDate);
    if (visitDate == null) return null;

    final previousDay = visitDate.subtract(const Duration(days: 1));

    return DateTime(
      previousDay.year,
      previousDay.month,
      previousDay.day,
      15,
      30,
    );
  }

  String _getProductOrderingCountdown() {
    final cutoff = _getProductOrderingCutoff();
    if (cutoff == null) return 'Ordering date unavailable';

    final diff = cutoff.difference(_now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      return 'Ordering closed';
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    if (hours <= 0) return 'Ordering closes in $minutes mins';

    return 'Ordering closes in $hours hrs $minutes mins';
  }

  int _qtyOf(String skuID) {
    final index = _cart.indexWhere((e) => e['skuID'] == skuID);
    if (index == -1) return 0;

    return int.tryParse((_cart[index]['quantity'] ?? 0).toString()) ?? 0;
  }

  bool _isOrderingOpen() {
    final cutoff = _getProductOrderingCutoff();

    if (cutoff == null) {
      return false;
    }

    return DateTime.now().isBefore(cutoff);
  }

  void _showOrderingClosedMessage() {
    final cutoff = _getProductOrderingCutoff();

    String message = 'Ordering window for this visit is closed.';

    if (cutoff != null) {
      final dateText =
          '${cutoff.day.toString().padLeft(2, '0')}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.year}';
      message =
      'Ordering window closed on $dateText at 3:30 PM. You can add products for your next eligible visit.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _updateQty(Map<String, dynamic> product, int delta) {
    final isAvailable = _isProductAvailable(product);

    // An unavailable item can never be added or increased.
    if (!isAvailable && delta > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${product['title'] ?? 'This product'} is currently not available.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isOrderingOpen()) {
      _showOrderingClosedMessage();
      return;
    }

    setState(() {
      final index = _cart.indexWhere(
            (item) => item['skuID'] == product['skuID'],
      );

      if (index == -1 && delta > 0) {
        _cart.add({
          ...product,
          'quantity': 1,
        });
      } else if (index != -1) {
        final currentQty =
            int.tryParse((_cart[index]['quantity'] ?? 1).toString()) ?? 1;
        final nextQty = currentQty + delta;

        if (nextQty <= 0) {
          _cart.removeAt(index);
        } else if (isAvailable) {
          _cart[index]['quantity'] = nextQty;
        }
      }
    });

    _syncCartToParent();
  }

  Future<void> _openCart() async {
    if (!_isOrderingOpen()) {
      _showOrderingClosedMessage();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          cartItems: _copyCartItems(_cart),
          bookingID: widget.bookingID,
          userID: widget.userID,
          date: widget.visitDate,
          assignedMali: widget.assignedMali,
          onCartUpdated: (updatedCart) {
            final copiedCart = _copyCartItems(updatedCart);

            if (mounted) {
              setState(() {
                _cart = copiedCart;
              });
            }

            widget.onCartUpdated(copiedCart);
          },
        ),
      ),
    );

    if (!mounted) return;

    if (result is Map && result['orderConfirmed'] == true) {
      setState(() {
        _cart = [];
      });

      _syncCartToParent();

      Navigator.pop(context, {
        'orderConfirmed': true,
        'cartItems': <Map<String, dynamic>>[],
      });
      return;
    }

    if (result is Map && result['cartItems'] != null) {
      final updatedCart = List<Map<String, dynamic>>.from(result['cartItems']);

      setState(() {
        _cart = _copyCartItems(updatedCart);
      });

      _syncCartToParent();
      return;
    }

    // Backward compatibility with older CartScreen versions.
    if (result == true) {
      setState(() {
        _cart = [];
      });

      _syncCartToParent();
      Navigator.pop(context, true);
    }
  }

  void _openImagePreview(Map<String, dynamic> product) {
    final imageUrl = (product['Image_1'] ?? '').toString();
    final title = (product['title'] ?? 'Product Image').toString();

    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image available')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) {
                        return const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white70,
                              size: 60,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Unable to load image',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 60,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pinch to zoom • Drag to move',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortByPriceButton() {
    String label = 'Sort';

    if (_priceSortMode == PriceSortMode.lowToHigh) {
      label = 'Low';
    } else if (_priceSortMode == PriceSortMode.highToLow) {
      label = 'High';
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_priceSortMode == PriceSortMode.none) {
            _priceSortMode = PriceSortMode.lowToHigh;
          } else if (_priceSortMode == PriceSortMode.lowToHigh) {
            _priceSortMode = PriceSortMode.highToLow;
          } else {
            _priceSortMode = PriceSortMode.none;
          }

          _applyFilters();
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _priceSortMode == PriceSortMode.highToLow
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            size: 15,
            color: _priceSortMode == PriceSortMode.none
                ? AppColors.textSecondary
                : _gold,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _priceSortMode == PriceSortMode.none
                  ? AppColors.textSecondary
                  : _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterDropCard({
    required Widget child,
    double? width,
    double? height,
    double radius = 24,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return Container(
      constraints: BoxConstraints(
        minWidth: width ?? 80,
        minHeight: height ?? 42,
      ),
      child: LiquidGlassInstructionCard(
        radius: radius,
        minHeight: height ?? 42,
        padding: padding,
        child: child,
      ),
    );
  }

  Widget _enhanceHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enhance Your Next Visit',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontWeight: FontWeight.w500,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _getProductOrderingCountdown(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE3E3),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'SHOP NOW',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: Color(0xFFC93535),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.65,
      ),
      itemBuilder: (_, __) {
        return LiquidGlassInstructionCard(
          radius: 24,
          minHeight: 0,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 108,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 90,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const Spacer(),
              Container(
                height: 18,
                width: 58,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchBar() {
    return _waterDropCard(
      radius: 22,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _updateSearchQuery('');
              },
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryBar() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final category = _categories[index];
          final selected = _selectedCategory == category;

          return GestureDetector(
            onTap: () => _applyCategoryFilter(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              constraints: const BoxConstraints(minWidth: 64),
              decoration: BoxDecoration(
                color: selected
                    ? _gold.withValues(alpha: 0.22)
                    : Colors.grey.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: selected
                      ? _gold
                      : AppColors.primaryColor.withValues(alpha: 0.08),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? _gold : _darkGreen,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _subcategoryBar() {
    if (!_showSubcategories || _subcategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _subcategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final subcategory = _subcategories[index];
          final selected = _selectedSubcategory == subcategory;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSubcategory = subcategory;
                _applyFilters();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(minWidth: 54),
              decoration: BoxDecoration(
                color: selected
                    ? _gold.withValues(alpha: 0.16)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: selected
                      ? _gold
                      : AppColors.primaryColor.withValues(alpha: 0.06),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                subcategory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? _gold : _darkGreen,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyProductsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _errorMessage == null
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ??
                  (_searchQuery.isNotEmpty
                      ? 'No products found for "$_searchQuery"'
                      : 'No products found'),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _errorMessage == null
                  ? () {
                _searchController.clear();
                _updateSearchQuery('');
              }
                  : _fetchProducts,
              child: Text(_errorMessage == null ? 'Clear search' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartButton(int cartCount) {
    return Stack(
      children: [
        IconButton(
          onPressed: _openCart,
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
        if (cartCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$cartCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = _cart.fold<int>(
      0,
          (sum, item) =>
      sum + (int.tryParse((item['quantity'] ?? 0).toString()) ?? 0),
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _syncCartToParent();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 64,
          foregroundColor: AppColors.textPrimary,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enhance Your Next Visit',
                style: AppTextStyles.cardTitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getProductOrderingCountdown(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            _cartButton(cartCount),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _searchBar()),
                      const SizedBox(width: 12),
                      _sortByPriceButton(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _categoryBar(),
                  if (_showSubcategories && _subcategories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _subcategoryBar(),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? _buildProductLoadingSkeleton()
                  : _filteredProducts.isEmpty
                  ? _emptyProductsState()
                  : GridView.builder(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                itemCount: _filteredProducts.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.65,
                ),
                itemBuilder: (_, index) {
                  final product = _filteredProducts[index];
                  final qty = _qtyOf(product['skuID'] ?? '');

                  return _ProductTile(
                    product: product,
                    qty: qty,
                    isAvailable: _isProductAvailable(product),
                    onAdd: () => _updateQty(product, 1),
                    onRemove: () => _updateQty(product, -1),
                    onImageTap: () => _openImagePreview(product),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: cartCount == 0
            ? null
            : SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: LiquidGlassInstructionCard(
              radius: 28,
              minHeight: 66,
              padding: const EdgeInsets.all(7),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    'View Cart ($cartCount)',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final int qty;
  final bool isAvailable;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onImageTap;

  const _ProductTile({
    required this.product,
    required this.qty,
    required this.isAvailable,
    required this.onAdd,
    required this.onRemove,
    required this.onImageTap,
  });

  static const Color _darkGreen = Color(0xFF063F20);
  static const Color _gold = Color(0xFFFFB72B);

  @override
  Widget build(BuildContext context) {
    final price = product['price'] ?? 0;
    final imageUrl = (product['Image_1'] ?? '').toString();
    final title = (product['title'] ?? '').toString();
    final category = (product['category'] ?? '').toString();
    final subcategory = (product['subcategory'] ?? '').toString();

    return LiquidGlassInstructionCard(
      radius: 24,
      minHeight: 0,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onImageTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 108,
                      width: double.infinity,
                      color: const Color(0xFFF8F8F8),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: isAvailable ? 1 : 0.42,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.image_outlined),
                                ),
                              ),
                            ),
                          ),
                          if (!isAvailable)
                            Positioned(
                              left: 7,
                              top: 7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.68),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'NOT AVAILABLE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            right: 7,
                            bottom: 7,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.zoom_in_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 11,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subcategory.isNotEmpty ? subcategory : category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.tiny.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹$price',
                  style: AppTextStyles.title.copyWith(
                    color: _darkGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: !isAvailable
                  ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Not available',
                  style: AppTextStyles.tiny.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
                  : qty == 0
                  ? GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              )
                  : Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _darkGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onRemove,
                      child: const SizedBox(
                        width: 24,
                        child: Icon(
                          Icons.remove,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    Text(
                      '$qty',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    GestureDetector(
                      onTap: onAdd,
                      child: const SizedBox(
                        width: 24,
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}