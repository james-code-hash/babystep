import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bubu/bubu_view.dart';
import '../../bubu/greeting.dart';
import '../../copy/home.dart';
import '../../copy/plan.dart';
import '../../core/clock.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import 'peek_counter.dart';

/// 首頁：步步＋問候、今天的計畫卡、唯一一個主要按鈕（依今天的狀態）、安靜的次要導覽。
///
/// - 沒有計畫 → 邀請「想想今天要做什麼」（可以不理）。
/// - 有計畫、還沒聊完 → 計畫卡＋「來聊聊今天」。
/// - 聊完了 → 「今天聊完了」，步步放鬆，沒有任何行動呼籲（C8）。
///
/// 刻意沒有：完成數、進度條、小紅點、「上次開啟」。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum _PeekReply { go, later, notToday }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _greeting;
  AgeTone? _greetingTone;

  /// 這次進到首頁時決定一次要不要探頭（每次掛上首頁最多一張卡）。
  bool _peekDecided = false;
  bool _peekShown = false;
  _PeekReply? _peekReply;
  int _peekVariant = 0;

  String _greetingFor(AgeTone tone) {
    if (_greeting == null || _greetingTone != tone) {
      _greeting = greeting(tone, ref.read(clockProvider).now(), ref.read(randomProvider));
      _greetingTone = tone;
    }
    return _greeting!;
  }

  void _decidePeek(AppSettings settings, List<Plan> plans, DayRecord? record) {
    if (_peekDecided) return;
    _peekDecided = true;
    final day = ref.read(todayKeyProvider);
    final counter = ref.read(peekCounterProvider.notifier);
    final show = shouldPeek(
      now: ref.read(clockProvider).now(),
      settings: settings,
      plans: plans,
      record: record,
      underDailyLimit: counter.canShow(day),
    );
    if (!show) return;
    _peekShown = true;
    _peekVariant = ref.read(randomProvider).nextInt(HomeCopy.peek.length);
    // 在 build 裡不能改 provider；下一個 frame 再記一次。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) counter.markShown(day);
    });
  }

  void _open(String route) => GoRouter.of(context).push(route);

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final settings = ref.watch(settingsProvider);
    final plansAsync = ref.watch(todayPlansProvider);
    final recordAsync = ref.watch(todayRecordProvider);
    final loaded = settings.hasValue && plansAsync.hasValue && recordAsync.hasValue;

    final plans = plansAsync.value ?? const <Plan>[];
    final record = recordAsync.value;
    final ended = record?.ended ?? false;
    if (loaded) _decidePeek(settings.value!, plans, record);
    final peekVisible = loaded && _peekShown && plans.isNotEmpty && !ended;

    final BubuExpression expression;
    if (ended) {
      expression = BubuExpression.relaxed;
    } else if (peekVisible && _peekReply == null) {
      expression = BubuExpression.curious;
    } else {
      expression = plans.isEmpty ? BubuExpression.calm : BubuExpression.happy;
    }

    final children = <Widget>[
      const SizedBox(height: AppSpace.m),
      Center(child: BubuView(expression: expression, size: 160)),
      const SizedBox(height: AppSpace.m),
      _Bubble(text: ended ? HomeCopy.dayEndedBubu.of(tone) : _greetingFor(tone)),
      const SizedBox(height: AppSpace.l),
    ];

    if (loaded) {
      if (ended) {
        children.add(Center(
          key: const ValueKey('home-ended'),
          child: Text(HomeCopy.dayEnded.of(tone), style: Theme.of(context).textTheme.headlineSmall),
        ));
      } else if (plans.isEmpty) {
        children.addAll([
          Center(
            child: FilledButton(
              key: const ValueKey('home-plan'),
              onPressed: () => _open(Routes.plan),
              child: Text(HomeCopy.planInvite.of(tone)),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Center(
            child: Text(
              HomeCopy.planInviteHint.of(tone),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ]);
      } else {
        if (peekVisible) {
          children.addAll([
            _PeekCard(
              tone: tone,
              plan: plans.first,
              variant: _peekVariant,
              reply: _peekReply,
              onReply: (r) => setState(() => _peekReply = r),
            ),
            const SizedBox(height: AppSpace.m),
          ]);
        }
        children.addAll([
          Text(HomeCopy.todayTitle.of(tone), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpace.s),
          for (final p in plans) _PlanCard(plan: p, tone: tone),
          const SizedBox(height: AppSpace.l),
          Center(
            child: FilledButton(
              key: const ValueKey('home-review'),
              onPressed: () => _open(Routes.review),
              child: Text(HomeCopy.reviewInvite.of(tone)),
            ),
          ),
          Center(
            child: TextButton(
              key: const ValueKey('home-replan'),
              onPressed: () => _open(Routes.plan),
              child: Text(HomeCopy.replan.of(tone)),
            ),
          ),
        ]);
      }
    }

    children.addAll([
      const SizedBox(height: AppSpace.xl),
      _QuietNav(tone: tone, onOpen: _open),
    ]);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: AppSpace.m),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          key: const ValueKey('home-bubble'),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: AppSpace.s + AppSpace.xs),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
}

/// 一件計畫：圖示＋「如果⋯，我就⋯」。不顯示任何狀態或數量。
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.tone});
  final Plan plan;
  final AgeTone tone;

  @override
  Widget build(BuildContext context) => Card(
        key: ValueKey('home-plan-card-${plan.order}'),
        margin: const EdgeInsets.only(bottom: AppSpace.s),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            children: [
              Text(plan.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Text(
                  PlanCopy.ifThen.fill(tone, {'cue': plan.cue, 'task': plan.task}),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      );
}

/// 探頭邀請卡。三個選項份量相同，回應只換成一句步步的話，什麼都不記。
class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.tone,
    required this.plan,
    required this.variant,
    required this.reply,
    required this.onReply,
  });

  final AgeTone tone;
  final Plan plan;
  final int variant;
  final _PeekReply? reply;
  final ValueChanged<_PeekReply> onReply;

  @override
  Widget build(BuildContext context) {
    final r = reply;
    if (r != null) {
      final line = switch (r) {
        _PeekReply.go => HomeCopy.peekGoReply,
        _PeekReply.later => HomeCopy.peekLaterReply,
        _PeekReply.notToday => HomeCopy.peekNotTodayReply,
      };
      return Card(
        key: const ValueKey('home-peek-reply'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Text(line.of(tone), style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }
    final text = HomeCopy.peek.lines[variant % HomeCopy.peek.length]
        .fill(tone, {'cue': PlanCopy.cueBody(plan.cue), 'task': plan.task});
    Widget option(_PeekReply value, String label, String key) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
            child: OutlinedButton(
              key: ValueKey(key),
              onPressed: () => onReply(value),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        );
    return Card(
      key: const ValueKey('home-peek'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(plan.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: AppSpace.s),
                Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
              ],
            ),
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                option(_PeekReply.go, HomeCopy.peekGo.of(tone), 'peek-go'),
                option(_PeekReply.later, HomeCopy.peekLater.of(tone), 'peek-later'),
                option(_PeekReply.notToday, HomeCopy.peekNotToday.of(tone), 'peek-not-today'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 安靜的次要導覽：沒有數字、沒有小紅點。
class _QuietNav extends StatelessWidget {
  const _QuietNav({required this.tone, required this.onOpen});
  final AgeTone tone;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, String route, String key) => TextButton.icon(
          key: ValueKey(key),
          onPressed: () => onOpen(route),
          icon: Icon(icon),
          label: Text(label),
        );
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpace.s,
          runSpacing: AppSpace.xs,
          children: [
            item(Icons.menu_book_outlined, HomeCopy.notebook.of(tone), Routes.notebook, 'nav-notebook'),
            item(Icons.route_outlined, HomeCopy.path.of(tone), Routes.path, 'nav-path'),
            item(Icons.tune, HomeCopy.settings.of(tone), Routes.settings, 'nav-settings'),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        TextButton.icon(
          key: const ValueKey('nav-parent'),
          onPressed: () => onOpen(Routes.parent),
          style: TextButton.styleFrom(textStyle: Theme.of(context).textTheme.bodyMedium),
          icon: const Icon(Icons.lock_outline, size: 18),
          label: Text(HomeCopy.parent.of(tone)),
        ),
      ],
    );
  }
}
