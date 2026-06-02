import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../models/room_model.dart';
import '../services/outlet_service.dart';
import 'room.dart';

class AllRoomsScreen extends StatefulWidget {
  const AllRoomsScreen({super.key});

  @override
  State<AllRoomsScreen> createState() => _AllRoomsScreenState();
}

class _AllRoomsScreenState extends State<AllRoomsScreen> {
  final OutletService _service = OutletService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'All'; // All, Active, Idle

  @override
  void initState() {
    super.initState();
    _service.addListener(() => setState(() {}));
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RoomModel> get _filteredRooms {
    List<RoomModel> rooms = _service.rooms;
    // Filter by search
    if (_searchQuery.isNotEmpty) {
      rooms = rooms.where((r) =>
          r.name.toLowerCase().contains(_searchQuery)).toList();
    }
    // Filter by status
    if (_filter == 'Active') {
      rooms = rooms.where((r) => r.hasActiveOutlet).toList();
    } else if (_filter == 'Idle') {
      rooms = rooms.where((r) => !r.hasActiveOutlet).toList();
    }
    return rooms;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.lightBackground;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final surfaceColor = isDark ? AppColors.surfaceColor : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.border : AppColors.lightBorder;

    final rooms = _filteredRooms;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: textColor, size: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('All Rooms',
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w700, color: textColor)),
              ),
              Text('${rooms.length} rooms',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.primary)),
            ]),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search rooms...',
                  hintStyle: TextStyle(color: mutedColor, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: mutedColor, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear_rounded,
                        color: mutedColor, size: 18),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              _FilterChip(
                label: 'All',
                selected: _filter == 'All',
                count: _service.rooms.length,
                onTap: () => setState(() => _filter = 'All'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Active',
                selected: _filter == 'Active',
                count: _service.rooms
                    .where((r) => r.hasActiveOutlet).length,
                color: AppColors.primary,
                onTap: () => setState(() => _filter = 'Active'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Idle',
                selected: _filter == 'Idle',
                count: _service.rooms
                    .where((r) => !r.hasActiveOutlet).length,
                color: AppColors.textMuted,
                onTap: () => setState(() => _filter = 'Idle'),
              ),
            ]),
          ),

          // Summary bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(children: [
                _SummaryItem(
                  value: '${_service.totalOutlets}',
                  label: 'Total Outlets',
                  color: AppColors.purple,
                ),
                Container(width: 1, height: 30, color: borderColor),
                _SummaryItem(
                  value: '${_service.totalActiveOutlets}',
                  label: 'Active Now',
                  color: AppColors.primary,
                ),
                Container(width: 1, height: 30, color: borderColor),
                _SummaryItem(
                  value: _service.totalKwhToday.toStringAsFixed(1),
                  label: 'kWh Today',
                  color: AppColors.amber,
                ),
              ]),
            ),
          ),

          // Rooms list
          Expanded(
            child: rooms.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.meeting_room_rounded,
                      size: 48, color: mutedColor),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No rooms found for "$_searchQuery"'
                        : 'No rooms yet',
                    style: TextStyle(
                        color: mutedColor, fontSize: 14),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: rooms.length,
              itemBuilder: (context, index) =>
                  _buildRoomCard(context, rooms[index]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, RoomModel room) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceColor : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.border : AppColors.lightBorder;
    final textColor = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final mutedColor = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RoomScreen(room: room))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: room.hasActiveOutlet
                ? AppColors.primary.withOpacity(0.2)
                : borderColor,
          ),
        ),
        child: Row(children: [
          // Room icon
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: room.hasActiveOutlet
                  ? AppColors.primary.withOpacity(0.12)
                  : borderColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(room.icon,
                style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          // Room info
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room.name,
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 4),
              Text(
                '${room.totalOutlets} outlets · '
                    '${room.activeCount} active · '
                    '${room.totalKwh.toStringAsFixed(1)} kWh',
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
              const SizedBox(height: 6),
              // WiFi connected outlets count
              Row(children: [
                Icon(Icons.wifi_rounded, size: 12,
                    color: room.hasActiveOutlet
                        ? AppColors.primary : mutedColor),
                const SizedBox(width: 4),
                Text(
                  '${room.outlets.where((o) => o.wifiConnected).length} outlets connected',
                  style: TextStyle(fontSize: 11,
                      color: room.hasActiveOutlet
                          ? AppColors.primary : mutedColor),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          // Status badge + arrow
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: room.hasActiveOutlet
                    ? AppColors.primary.withOpacity(0.12)
                    : borderColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                room.hasActiveOutlet ? 'Active' : 'Idle',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: room.hasActiveOutlet
                      ? AppColors.primary : mutedColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: mutedColor),
          ]),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.count,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? color : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.textMuted,
              )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.2)
                  : AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textMuted,
                )),
          ),
        ]),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value, label;
  final Color color;
  const _SummaryItem(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textMuted)),
      ]),
    );
  }
}
