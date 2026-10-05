import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/analytics_view.dart';
import 'widgets/plan_view.dart';

/// 模块二：学习计划安排与分析。
///
/// 两个分段视图：计划（任务卡/编辑/打卡/月历）与分析（连续/趋势/完成率/临逾期）。
class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({super.key});

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习计划'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _Seg(
                      label: '计划',
                      active: _index == 0,
                      onTap: () => setState(() => _index = 0)),
                  _Seg(
                      label: '分析',
                      active: _index == 1,
                      onTap: () => setState(() => _index = 1)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: const [PlanView(), AnalyticsView()],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Seg({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        key: Key('segment_$label'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(4),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.paper : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 1)),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.ink : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
