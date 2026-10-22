import 'package:flutter/material.dart';
import '../constants/categories.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';

/// Dedicated screen for managing both default and custom expense & income categories.
/// Provides editing (name, icon, color), deletion safeguards (reassignment or archiving),
/// and atomic updates to historical transactions when renamed.
class CategoryManagementScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final VoidCallback onDataChanged;

  const CategoryManagementScreen({
    super.key,
    required this.transactions,
    required this.onDataChanged,
  });

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  late TabController _tabController;
  late List<Transaction> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didUpdateWidget(covariant CategoryManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactions != widget.transactions) {
      _transactions = List.from(widget.transactions);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _getTransactionCount(String categoryName, TransactionType type) {
    return _transactions.where((tx) =>
        tx.type == type &&
        tx.category.trim().toLowerCase() == categoryName.trim().toLowerCase()).length;
  }

  // =========================================================================
  // ADD / EDIT CATEGORY DIALOG
  // =========================================================================

  Future<void> _showAddOrEditDialog({
    CategoryItem? existing,
    TransactionType defaultType = TransactionType.expense,
  }) async {
    final isEditing = existing != null;
    TransactionType catType = defaultType;

    // Detect type if editing
    if (isEditing) {
      final isIncome = AppCategories.incomeCategories.any((c) => c.id == existing.id || c.name == existing.name);
      catType = isIncome ? TransactionType.income : TransactionType.expense;
    }

    final nameController = TextEditingController(text: existing?.name ?? '');
    String selectedIconKey = existing?.iconKey ?? 'shopping_bag';
    Color selectedColor = existing?.color ?? (catType == TransactionType.expense
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981));
    String? nameError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isExpense = catType == TransactionType.expense;

          return AlertDialog(
            title: Text(isEditing ? 'Edit Category' : 'New Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type selection (only when adding new)
                  if (!isEditing) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Expense')),
                            selected: isExpense,
                            selectedColor: const Color(0xFFEF4444),
                            labelStyle: TextStyle(
                              color: isExpense ? Colors.white : null,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) => setDialogState(() {
                              catType = TransactionType.expense;
                              if (selectedColor == const Color(0xFF10B981)) {
                                selectedColor = const Color(0xFFEF4444);
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Income')),
                            selected: !isExpense,
                            selectedColor: const Color(0xFF10B981),
                            labelStyle: TextStyle(
                              color: !isExpense ? Colors.white : null,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) => setDialogState(() {
                              catType = TransactionType.income;
                              if (selectedColor == const Color(0xFFEF4444)) {
                                selectedColor = const Color(0xFF10B981);
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Category Name
                  TextField(
                    controller: nameController,
                    autofocus: !isEditing,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      errorText: nameError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      if (nameError != null) {
                        setDialogState(() => nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Icon Selector
                  const Text('Select Icon:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CategoryItem.availableIcons.map((entry) {
                      final isSel = selectedIconKey == entry.key;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIconKey = entry.key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? selectedColor.withValues(alpha: 0.18)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSel ? selectedColor : Colors.grey.withValues(alpha: 0.3),
                              width: isSel ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(entry.value, size: 20, color: selectedColor),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Color Selector
                  const Text('Select Color:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CategoryItem.availableColors.map((col) {
                      final isSel = selectedColor == col;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = col),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: isSel
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: isSel
                                ? [BoxShadow(color: col.withValues(alpha: 0.6), blurRadius: 6)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setDialogState(() => nameError = 'Category name cannot be empty.');
                    return;
                  }

                  // Check duplicate name within the same type
                  final currentList = catType == TransactionType.income
                      ? AppCategories.incomeCategories
                      : AppCategories.expenseCategories;

                  final isDuplicate = currentList.any((c) =>
                      c.id != existing?.id &&
                      c.name.trim().toLowerCase() == name.toLowerCase());

                  if (isDuplicate) {
                    setDialogState(() => nameError = 'A category named "$name" already exists.');
                    return;
                  }

                  Navigator.of(ctx).pop();

                  if (isEditing) {
                    final updatedItem = existing.copyWith(
                      name: name,
                      icon: CategoryItem.getIconByKey(selectedIconKey),
                      iconKey: selectedIconKey,
                      color: selectedColor,
                    );
                    await _storageService.updateCategory(
                      oldName: existing.name,
                      updatedItem: updatedItem,
                      type: catType,
                    );
                  } else {
                    final newItem = CategoryItem(
                      id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
                      name: name,
                      icon: CategoryItem.getIconByKey(selectedIconKey),
                      iconKey: selectedIconKey,
                      color: selectedColor,
                      isCustom: true,
                    );
                    await _storageService.addCategory(newItem, catType);
                  }

                  // Reload transactions to reflect any renamed categories
                  final freshTx = await _storageService.loadTransactions();
                  if (!mounted) return;
                  setState(() {
                    _transactions = freshTx;
                  });
                  widget.onDataChanged();
                },
                child: Text(isEditing ? 'Save Changes' : 'Add Category'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // SAFE DELETE / ARCHIVE CATEGORY DIALOG
  // =========================================================================

  Future<void> _showDeleteCategoryDialog(CategoryItem category, TransactionType type) async {
    final usageCount = _getTransactionCount(category.name, type);
    final availableCategories = (type == TransactionType.income
            ? AppCategories.incomeCategories
            : AppCategories.expenseCategories)
        .where((c) => c.name.trim().toLowerCase() != category.name.trim().toLowerCase())
        .toList();

    if (usageCount == 0) {
      // Direct deletion confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete "${category.name}"?'),
          content: const Text(
            'This category is not used by any transactions. Are you sure you want to delete it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _storageService.deleteCategory(categoryName: category.name, type: type);
        if (!mounted) return;
        setState(() {});
        widget.onDataChanged();
      }
      return;
    }

    // Category is in use: provide Safe Reassignment or Archiving
    String? selectedReassignCategory = availableCategories.isNotEmpty
        ? availableCategories.first.name
        : null;
    int deletionOption = 0; // 0: Reassign, 1: Archive

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: Text('Delete "${category.name}"?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This category is linked to $usageCount historical transaction${usageCount == 1 ? '' : 's'}. Choose how to preserve them:',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (availableCategories.isNotEmpty) ...[
                    // Option 0: Reassign
                    // ignore: deprecated_member_use
                    RadioListTile<int>(
                      title: const Text('Reassign transactions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Safely move existing transactions to another category', style: TextStyle(fontSize: 11)),
                      value: 0,
                      // ignore: deprecated_member_use
                      groupValue: deletionOption,
                      contentPadding: EdgeInsets.zero,
                      // ignore: deprecated_member_use
                      onChanged: (val) => setDialogState(() => deletionOption = val ?? 0),
                    ),
                    if (deletionOption == 0) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 32, right: 8, bottom: 8),
                        child: DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: selectedReassignCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'New Category for Transactions',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: availableCategories.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.name,
                              child: Row(
                                children: [
                                  Icon(c.icon, size: 16, color: c.color),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedReassignCategory = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ],

                  // Option 1: Archive
                  // ignore: deprecated_member_use
                  RadioListTile<int>(
                    title: const Text('Archive category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: const Text('Keep historical transactions untouched, but hide category from future pickers', style: TextStyle(fontSize: 11)),
                    value: 1,
                    // ignore: deprecated_member_use
                    groupValue: deletionOption,
                    contentPadding: EdgeInsets.zero,
                    // ignore: deprecated_member_use
                    onChanged: (val) => setDialogState(() => deletionOption = val ?? 1),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                onPressed: () async {
                  Navigator.of(ctx).pop();

                  if (deletionOption == 0 && selectedReassignCategory != null) {
                    await _storageService.deleteCategory(
                      categoryName: category.name,
                      type: type,
                      reassignToCategoryName: selectedReassignCategory,
                    );
                  } else {
                    await _storageService.deleteCategory(
                      categoryName: category.name,
                      type: type,
                      archiveOnly: true,
                    );
                  }

                  final freshTx = await _storageService.loadTransactions();
                  if (!mounted) return;
                  setState(() {
                    _transactions = freshTx;
                  });
                  widget.onDataChanged();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(deletionOption == 0
                          ? 'Transactions reassigned and "${category.name}" deleted.'
                          : 'Category "${category.name}" archived.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(deletionOption == 0 ? 'Reassign & Delete' : 'Archive Category'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // CATEGORIES LIST BUILDER
  // =========================================================================

  Widget _buildCategoryList(List<CategoryItem> categories, TransactionType type) {
    final theme = Theme.of(context);

    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'No Categories',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Add custom categories using the button below.',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final usageCount = _getTransactionCount(category.name, type);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(category.icon, color: category.color, size: 22),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              '${category.isCustom ? "Custom" : "Default"} • $usageCount transaction${usageCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  tooltip: 'Edit Category',
                  onPressed: () => _showAddOrEditDialog(
                    existing: category,
                    defaultType: type,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFEF4444)),
                  tooltip: 'Delete Category',
                  onPressed: () => _showDeleteCategoryDialog(category, type),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseCategories = AppCategories.expenseCategories;
    final incomeCategories = AppCategories.incomeCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Category Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Expense (${expenseCategories.length})'),
            Tab(text: 'Income (${incomeCategories.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(expenseCategories, TransactionType.expense),
          _buildCategoryList(incomeCategories, TransactionType.income),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final activeType = _tabController.index == 0
              ? TransactionType.expense
              : TransactionType.income;
          _showAddOrEditDialog(defaultType: activeType);
        },
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
