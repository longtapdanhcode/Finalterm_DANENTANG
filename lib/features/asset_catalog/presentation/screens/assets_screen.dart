import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:field_inventory_edge_ai/core/data/demo_data.dart';
import 'package:field_inventory_edge_ai/core/theme/fieldline_theme.dart';
import 'package:field_inventory_edge_ai/core/utils/responsive_layout.dart';
import 'package:field_inventory_edge_ai/core/widgets/fieldline_widgets.dart';

enum _AssetFilter { all, needsCheck, notAudited }

/// Màn hình Tài sản & thiết bị (Figma 02 / M06).
///
/// Danh mục là dữ liệu minh họa cho tới khi có nguồn danh mục tài sản thật.
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final _search = TextEditingController();
  _AssetFilter _filter = _AssetFilter.all;
  String? _area;
  String? _status;
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DemoAsset> get _visible {
    final q = _search.text.trim().toLowerCase();
    return DemoData.assets.where((a) {
      if (q.isNotEmpty &&
          !a.name.toLowerCase().contains(q) &&
          !a.code.toLowerCase().contains(q)) {
        return false;
      }
      if (_area != null && a.area != _area) return false;
      if (_status != null && a.status != _status) return false;
      return switch (_filter) {
        _AssetFilter.all => true,
        _AssetFilter.needsCheck => a.tone != FlTone.success,
        // Danh mục minh họa không có tài sản chưa kiểm kê.
        _AssetFilter.notAudited => false,
      };
    }).toList();
  }

  void _notReady() =>
      showFlSnack(context, 'Thêm tài sản sẽ có khi kết nối danh mục thật.');

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout.isDesktop(context)
        ? _buildDesktop(context)
        : _buildMobile(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final assets = _visible;
    final areas = {for (final a in DemoData.assets) a.area}.toList();
    final statuses = {for (final a in DemoData.assets) a.status}.toList();

    return DesktopPage(
      heading: DesktopPageHeading(
        title: 'Tài sản & thiết bị',
        subtitle: 'Danh mục tài sản và tình trạng mới nhất từ các đợt kiểm kê.',
        action: FilledButton.icon(
          onPressed: _notReady,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Thêm tài sản'),
        ),
      ),
      children: [
        FlCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (final (i, m) in const [
                  (DemoData.totalAssets, 'Tổng tài sản'),
                  (DemoData.goodAssets, 'Hoạt động tốt'),
                  (DemoData.needsCheckAll, 'Cần kiểm tra'),
                  (DemoData.retired, 'Ngừng sử dụng'),
                ].indexed) ...[
                  if (i > 0)
                    const VerticalDivider(width: 48, color: FlColors.border),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          flNumber(m.$1),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Gap(18),
                        Flexible(
                          child: Text(
                            m.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FlColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Gap(16),
        FlCard(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Tìm theo tên, mã tài sản, số serial…',
                          fillColor: FlColors.background,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: FlColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 3,
                      child: _FilterDropdown(
                        hint: 'Tất cả khu vực',
                        value: _area,
                        options: areas,
                        onChanged: (v) => setState(() => _area = v),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      flex: 3,
                      child: _FilterDropdown(
                        hint: 'Tất cả tình trạng',
                        value: _status,
                        options: statuses,
                        onChanged: (v) => setState(() => _status = v),
                      ),
                    ),
                    const Spacer(flex: 2),
                    OutlinedButton(
                      onPressed: () => showFlSnack(
                        context,
                        'Đã chuẩn bị ${assets.length} tài sản để xuất.',
                      ),
                      child: const Text('Xuất danh sách'),
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _Tabs(
                  value: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
              ),
              const Gap(12),
              Container(
                color: FlColors.surfaceAlt,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 36),
                    Expanded(
                      flex: 5,
                      child: SectionLabel('Tài sản / Mã thiết bị'),
                    ),
                    Expanded(flex: 3, child: SectionLabel('Khu vực')),
                    Expanded(flex: 2, child: SectionLabel('Số lượng')),
                    Expanded(flex: 3, child: SectionLabel('Tình trạng')),
                    Expanded(flex: 2, child: SectionLabel('Kiểm kê gần nhất')),
                  ],
                ),
              ),
              if (assets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Không có tài sản phù hợp với bộ lọc.',
                    style: TextStyle(fontSize: 13, color: FlColors.muted),
                  ),
                ),
              for (final a in assets) _buildTableRow(a),
              const Gap(20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Hiển thị 1–${assets.length} trong ${flNumber(DemoData.totalAssets)} tài sản',
                      style: const TextStyle(
                        fontSize: 12,
                        color: FlColors.muted,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 62,
                      child: OutlinedButton(
                        onPressed: null,
                        child: const Icon(Icons.arrow_back, size: 16),
                      ),
                    ),
                    const Gap(6),
                    SizedBox(
                      width: 52,
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text('1'),
                      ),
                    ),
                    const Gap(6),
                    SizedBox(
                      width: 62,
                      child: OutlinedButton(
                        onPressed: () => showFlSnack(
                          context,
                          'Danh mục minh họa chỉ có một trang.',
                        ),
                        child: const Text('2'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(DemoAsset a) {
    final checked = _selected.contains(a.code);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FlColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Checkbox(
              value: checked,
              visualDensity: VisualDensity.compact,
              onChanged: (v) => setState(
                () => v! ? _selected.add(a.code) : _selected.remove(a.code),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                const IconTile(
                  icon: Icons.inventory_2_outlined,
                  tone: FlTone.neutral,
                  size: 38,
                  iconSize: 18,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(3),
                      Text(
                        a.code,
                        style: const TextStyle(
                          fontSize: 11,
                          color: FlColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(a.area, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${a.quantity}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(label: a.status, tone: a.tone),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              a.lastAudit,
              style: const TextStyle(fontSize: 12, color: FlColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final assets = _visible;
    final chips = [
      (_AssetFilter.all, 'Tất cả ${flNumber(DemoData.totalAssets)}'),
      (_AssetFilter.notAudited, 'Chưa kiểm ${DemoData.notAudited}'),
      (_AssetFilter.needsCheck, 'Cần xử lý ${DemoData.needsCheckAll}'),
    ];

    return MobilePage(
      title: 'Tài sản & thiết bị',
      trailing: IconButton.filled(
        onPressed: _notReady,
        tooltip: 'Thêm tài sản',
        style: IconButton.styleFrom(backgroundColor: FlColors.primary),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Tìm theo tên hoặc mã tài sản',
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: FlColors.muted,
            ),
          ),
        ),
        const Gap(16),
        Row(
          children: [
            for (final (i, c) in chips.indexed) ...[
              if (i > 0) const Gap(8),
              Expanded(
                child: _MobileChip(
                  label: c.$2,
                  active: _filter == c.$1,
                  onTap: () => setState(() => _filter = c.$1),
                ),
              ),
            ],
          ],
        ),
        const Gap(20),
        SectionLabel('${assets.length} tài sản  ·  tất cả khu vực'),
        const Gap(10),
        if (assets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Không có tài sản phù hợp.',
              style: TextStyle(fontSize: 13, color: FlColors.muted),
            ),
          ),
        for (final a in assets) ...[
          FlCard(
            padding: const EdgeInsets.all(13),
            onTap: () => context.push(
              '/audit-form',
              extra: {'scanCode': a.code, 'aiLabel': a.name},
            ),
            child: Row(
              children: [
                const IconTile(
                  icon: Icons.crop_square_rounded,
                  tone: FlTone.info,
                  size: 56,
                  iconSize: 22,
                ),
                const Gap(13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        '${a.code}  ·  ${a.category}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: FlColors.muted,
                        ),
                      ),
                      const Gap(6),
                      StatusPill(label: a.status, tone: a.tone, bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),
        ],
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: FlColors.ink,
      ),
      decoration: const InputDecoration(),
      items: [
        DropdownMenuItem(value: null, child: Text(hint)),
        for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.value, required this.onChanged});

  final _AssetFilter value;
  final ValueChanged<_AssetFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_AssetFilter.all, 'Tất cả tài sản'),
      (_AssetFilter.needsCheck, 'Cần kiểm tra ${DemoData.needsCheckAll}'),
      (_AssetFilter.notAudited, 'Chưa kiểm kê ${DemoData.notAudited}'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FlColors.border)),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            InkWell(
              onTap: () => onChanged(t.$1),
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 6, 40, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: value == t.$1
                          ? FlColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  t.$2,
                  style: TextStyle(
                    fontSize: 14,
                    color: value == t.$1 ? FlColors.primary : FlColors.muted,
                    fontWeight: value == t.$1
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileChip extends StatelessWidget {
  const _MobileChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? FlColors.primary : FlColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: active ? FlColors.primary : FlColors.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : FlColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
