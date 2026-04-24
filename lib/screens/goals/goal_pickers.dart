import 'package:flutter/material.dart';
import '../../utils/theme.dart';

const weekDays = ['일', '월', '화', '수', '목', '금', '토'];

class DrumDatePicker extends StatefulWidget {
  final String title, value;
  final ValueChanged<String> onConfirm;
  final VoidCallback onClose;
  const DrumDatePicker({super.key, required this.title, required this.value, required this.onConfirm, required this.onClose});

  @override
  State<DrumDatePicker> createState() => _DrumDatePickerState();
}

class _DrumDatePickerState extends State<DrumDatePicker> {
  late int _year, _month, _day;
  late FixedExtentScrollController _yearCtrl, _monthCtrl, _dayCtrl;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    DateTime init;
    try {
      final p = widget.value.split('-');
      init = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) { init = today; }
    _year = init.year; _month = init.month; _day = init.day;
    final yearList = List.generate(5, (i) => today.year + i);
    _yearCtrl = FixedExtentScrollController(initialItem: yearList.indexOf(_year).clamp(0, 4));
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose(); _monthCtrl.dispose(); _dayCtrl.dispose();
    super.dispose();
  }

  int get _maxDay => DateTime(_year, _month + 1, 0).day;

  void _confirm() {
    final d = _day.clamp(1, _maxDay);
    widget.onConfirm('$_year-${_month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final years = List.generate(5, (i) => '${today.year + i}년');
    final months = List.generate(12, (i) => '${i + 1}월');
    final days = List.generate(_maxDay, (i) => '${i + 1}일');
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black45,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              decoration: BoxDecoration(color: context.modalBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(widget.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  GestureDetector(onTap: widget.onClose, child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
                ]),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  DrumColumn(controller: _yearCtrl, items: years, width: 90, onSelected: (i) => setState(() => _year = today.year + i)),
                  const SizedBox(width: 8),
                  DrumColumn(controller: _monthCtrl, items: months, width: 72, onSelected: (i) => setState(() { _month = i + 1; if (_day > _maxDay) _day = _maxDay; })),
                  const SizedBox(width: 8),
                  DrumColumn(controller: _dayCtrl, items: days, width: 72, onSelected: (i) => setState(() => _day = i + 1)),
                ]),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _confirm,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text('확인', style: TextStyle(color: context.isDark ? Colors.black : Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class AlarmPicker extends StatefulWidget {
  final String amPm;
  final int hour, min;
  final void Function(String, int, int) onConfirm;
  final VoidCallback onClose;
  const AlarmPicker({super.key, required this.amPm, required this.hour, required this.min, required this.onConfirm, required this.onClose});

  @override
  State<AlarmPicker> createState() => _AlarmPickerState();
}

class _AlarmPickerState extends State<AlarmPicker> {
  late String _amPm;
  late int _hour, _min;
  late FixedExtentScrollController _amPmCtrl, _hourCtrl, _minCtrl;

  @override
  void initState() {
    super.initState();
    _amPm = widget.amPm; _hour = widget.hour; _min = widget.min;
    _amPmCtrl = FixedExtentScrollController(initialItem: _amPm == '오전' ? 0 : 1);
    _hourCtrl = FixedExtentScrollController(initialItem: _hour - 1);
    _minCtrl = FixedExtentScrollController(initialItem: _min ~/ 5);
  }

  @override
  void dispose() {
    _amPmCtrl.dispose(); _hourCtrl.dispose(); _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amPmItems = ['오전', '오후'];
    final hourItems = List.generate(12, (i) => '${i + 1}');
    final minItems = List.generate(12, (i) => '${(i * 5).toString().padLeft(2, '0')}');
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black45,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              decoration: BoxDecoration(color: context.modalBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('알림 시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  GestureDetector(onTap: widget.onClose, child: Text('×', style: TextStyle(fontSize: 24, color: context.textSecondary))),
                ]),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  DrumColumn(controller: _amPmCtrl, items: amPmItems, width: 72, onSelected: (i) => setState(() => _amPm = amPmItems[i])),
                  const SizedBox(width: 8),
                  DrumColumn(controller: _hourCtrl, items: hourItems, width: 60, onSelected: (i) => setState(() => _hour = i + 1)),
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(':', style: TextStyle(fontSize: 24, color: context.textSecondary))),
                  DrumColumn(controller: _minCtrl, items: minItems, width: 60, onSelected: (i) => setState(() => _min = i * 5)),
                ]),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => widget.onConfirm(_amPm, _hour, _min),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: context.primaryColor, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text('확인', style: TextStyle(color: context.isDark ? Colors.black : Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class DrumColumn extends StatelessWidget {
  final FixedExtentScrollController controller;
  final List<String> items;
  final double width;
  final ValueChanged<int> onSelected;
  const DrumColumn({super.key, required this.controller, required this.items, required this.width, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const itemH = 52.0;
    final bgColor = context.modalBg;
    final transparent = bgColor.withOpacity(0);
    return SizedBox(
      width: width, height: itemH * 3,
      child: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: itemH,
            child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bgColor, transparent])))),
        Positioned(top: itemH, left: 4, right: 4, height: itemH,
            child: Container(decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: context.borderColor))))),
        Positioned(bottom: 0, left: 0, right: 0, height: itemH,
            child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [bgColor, transparent])))),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: itemH,
          perspective: 0.003,
          diameterRatio: 2.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, index) {
              if (index < 0 || index >= items.length) return null;
              final isSelected = controller.selectedItem == index;
              return Center(child: Text(items[index], style: TextStyle(
                fontSize: 22,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                color: isSelected ? context.textPrimary : context.textSecondary,
              )));
            },
            childCount: items.length,
          ),
        ),
      ]),
    );
  }
}