import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bubu/bubu_view.dart';
import '../../bubu/greeting.dart';
import '../../copy/family.dart';
import '../../copy/home.dart';
import '../../copy/plan.dart';
import '../../copy/surprise.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import 'peek_counter.dart';

/// 首頁：步步＋問候、今天的計畫卡、唯一一個主要按鈕（依今天的狀態）、安靜的次要導覽。
///
/// - 沒有計畫 → 邀請「想想今天要做什麼」（可以不理）。
/// - 有計畫、還沒聊完 → 計畫卡＋「來聊聊今天」。
/// - 聊完了 → 「今天聊完了」，沒有任何行動呼籲（C8）。
///
/// 步步的表情只看時段（[restingExpression]），和上面三種狀態無關（底線 2）；
/// 唯一的例外是探頭卡的問題正顯示著、還沒回答時，步步歪頭等回答（對話裡的反應）。
///
/// 探頭卡在這幾個時候重新決定一次（仍受每日上限限制，每次最多一張）：
/// 第一次載入、今天的計畫從無到有、App 從背景回來、從別的畫面回到首頁。
///
/// 刻意沒有：完成數、進度條、小紅點、「上次開啟」。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

enum _PeekReply { go, later, notToday }

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  String? _greeting;
  AgeTone? _greetingTone;

  /// 這次進到首頁時決定一次要不要探頭（每次進來最多一張卡）。
  bool _peekDecided = false;
  bool _peekShown = false;
  _PeekReply? _peekReply;
  int _peekVariant = 0;

  /// 這次進到首頁時，孩子對哪些家人留言說了「等一下」（只在記憶體，下次進來再問一次）。
  final Set<String> _notesLater = {};

  /// 上一次決定探頭時看到的輸入（提醒時段、今天有沒有計畫、聊完了沒）。
  /// 輸入變了、而且這次還沒探頭過，就重新決定一次（G6、H1）。
  String? _peekInputs;

  /// 輕點步步的小反應（隱藏互動，J2）：一句話＋驚訝的臉，過一下就回到原樣。不記錄。
  String? _poke;
  Timer? _pokeTimer;

  void _pokeBubu(AgeTone tone) {
    _pokeTimer?.cancel();
    setState(() => _poke = SurpriseCopy.pokes.pick(tone, ref.read(randomProvider)));
    _pokeTimer = Timer(const Duration(milliseconds: SurpriseConfig.pokeMs), () {
      if (mounted) setState(() => _poke = null);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pokeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    // 可能跨過午夜：重新算今天是哪一天。
    ref.invalidate(todayKeyProvider);
    // 早上打開、晚上才回來：問候要跟著現在的時段重抽。
    setState(() => _greeting = null);
    _newVisit();
  }

  /// 又一次「進到首頁」（從背景回來、從別的畫面回來）：重新決定要不要探頭，家人留言也再問一次。
  /// 卡片正顯示著、還沒回答時就留著，不重抽也不多算一次。
  void _newVisit() {
    if (!mounted) return;
    // 家人留言的「等一下」只算這一次：回到首頁就再問一次。
    _notesLater.clear();
    if (_peekShown && _peekReply == null) {
      setState(() {});
      return;
    }
    setState(() {
      _peekDecided = false;
      _peekShown = false;
      _peekReply = null;
    });
  }

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

  static String _peekInputsOf(AppSettings settings, List<Plan> plans, bool ended) => [
        for (final s in settings.reminderSlots) '${s.startMinute}-${s.endMinute}',
        plans.isNotEmpty,
        ended,
      ].join('|');

  /// 打開一則家人留言：原封不動顯示，步步不加評論（§4.11）。看過就不再轉達這一則。
  Future<void> _openNote(FamilyNote note, AgeTone tone) async {
    await ref.read(repositoryProvider).markFamilyNoteRead(note.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('family-note-dialog'),
        title: Text(FamilyCopy.noteFrom.fill(tone, {'who': note.who})),
        content: Text(note.text, key: const ValueKey('family-note-text'), style: Theme.of(context).textTheme.bodyLarge),
        actions: [
          FilledButton(
            key: const ValueKey('family-note-close'),
            onPressed: () => Navigator.pop(context),
            child: Text(FamilyCopy.noteClose.of(tone)),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String route) async {
    await GoRouter.of(context).push(route);
    _newVisit();
  }

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
    if (loaded) {
      // 輸入變了（例如今天的計畫從無到有、家長剛加了提醒時段）→ 這次還沒探頭過就重新決定。
      // 從別的畫面回來的第一個 frame 可能還是舊的設定（畫面被蓋住時 provider 會暫停），
      // 新的設定一到就會在這裡重新決定（H1）。
      final inputs = _peekInputsOf(settings.value!, plans, ended);
      if (inputs != _peekInputs && !_peekShown) _peekDecided = false;
      _peekInputs = inputs;
      _decidePeek(settings.value!, plans, record);
    }
    final peekVisible = loaded && _peekShown && plans.isNotEmpty && !ended;
    final peekAsking = peekVisible && _peekReply == null;

    // 只看時段；探頭問題正顯示著時歪頭等回答；被輕點時嚇一跳（底線 2）。
    final poke = _poke;
    final expression = poke != null
        ? BubuExpression.surprised
        : peekAsking
            ? BubuExpression.curious
            : restingExpression(ref.watch(clockProvider).now());

    final bubbleText = poke ?? (ended ? HomeCopy.dayEndedBubu.of(tone) : _greetingFor(tone));
    Widget bubu(double size) => GestureDetector(
          key: const ValueKey('home-bubu'),
          onTap: () => _pokeBubu(tone),
          child: BubuView(expression: expression, size: size),
        );
    // 窄版：和原本一樣在最上面；寬版（平板橫放）：自成一欄。
    Widget side(BuildContext context, bool wide) => !wide && Layout.isTablet(context)
        // 平板直放：上方舞台裡步步在左、泡泡在右（E12）。
        ? Row(
            children: [
              bubu(LayoutConfig.bubuBannerTablet),
              const SizedBox(width: AppSpace.l),
              Expanded(child: Align(alignment: Alignment.centerLeft, child: _Bubble(text: bubbleText))),
            ],
          )
        : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: wide
              ? [
                  Center(child: bubu(LayoutConfig.bubuSidePane)),
                  const SizedBox(height: AppSpace.l),
                  _Bubble(text: bubbleText),
                ]
              : [
                  const SizedBox(height: AppSpace.m),
                  Center(child: bubu(Layout.bubu(context, BubuSlot.hero))),
                  const SizedBox(height: AppSpace.m),
                  _Bubble(text: bubbleText),
                  const SizedBox(height: AppSpace.l),
                ],
        );

    final children = <Widget>[];

    // 家人的留言：一次問一則，孩子可以先不看（§4.11）。
    final notes = ref.watch(unreadFamilyNotesProvider).value ?? const <FamilyNote>[];
    final note = notes.where((n) => !_notesLater.contains(n.id)).firstOrNull;
    if (loaded && note != null) {
      children.addAll([
        _FamilyNoteInvite(
          tone: tone,
          note: note,
          onOpen: () => _openNote(note, tone),
          onLater: () => setState(() => _notesLater.add(note.id)),
        ),
        const SizedBox(height: AppSpace.m),
      ]);
    }

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

    final family = ref.watch(familyTodayProvider).value ?? const <FamilyToday>[];
    if (loaded && family.isNotEmpty) {
      children.addAll([
        const SizedBox(height: AppSpace.l),
        _FamilyTodayCard(tone: tone, family: family),
      ]);
    }

    children.addAll([
      const SizedBox(height: AppSpace.xl),
      _QuietNav(tone: tone, onOpen: _open),
    ]);

    return Scaffold(
      body: SafeArea(
        child: AdaptiveTwoPane(gap: 0, side: side, children: children),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PlanCopy.ifThen.fill(tone, {'cue': plan.cue, 'task': plan.task}),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (plan.stuck != null)
                      Text(
                        PlanCopy.stuckLine.fill(tone, {'stuck': plan.stuck!}),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                      ),
                  ],
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

/// 「某某有留話給你喔，要看嗎？」兩個選項份量相同。
class _FamilyNoteInvite extends StatelessWidget {
  const _FamilyNoteInvite({required this.tone, required this.note, required this.onOpen, required this.onLater});
  final AgeTone tone;
  final FamilyNote note;
  final VoidCallback onOpen;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) => Card(
        key: const ValueKey('home-family-note'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(FamilyCopy.noteInvite.fill(tone, {'who': note.who}), style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpace.s),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('family-note-open'),
                      onPressed: onOpen,
                      child: Text(FamilyCopy.noteOpen.of(tone)),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s),
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('family-note-later'),
                      onPressed: onLater,
                      child: Text(FamilyCopy.noteLater.of(tone)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

/// 家人今天自己想做的事：只列出來，不計數、不比較、沒有做到了沒。
class _FamilyTodayCard extends StatelessWidget {
  const _FamilyTodayCard({required this.tone, required this.family});
  final AgeTone tone;
  final List<FamilyToday> family;

  @override
  Widget build(BuildContext context) => Card(
        key: const ValueKey('home-family-today'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(FamilyCopy.homeTitle.of(tone), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpace.xs),
              for (final f in family)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Text(FamilyCopy.homeItem.fill(tone, {'who': f.who, 'text': f.text})),
                ),
            ],
          ),
        ),
      );
}

/// 安靜的次要導覽：沒有數字、沒有小紅點。
class _QuietNav extends StatelessWidget {
  const _QuietNav({required this.tone, required this.onOpen});
  final AgeTone tone;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (Icons.menu_book_outlined, HomeCopy.notebook.of(tone), Routes.notebook, 'nav-notebook'),
      (Icons.route_outlined, HomeCopy.path.of(tone), Routes.path, 'nav-path'),
      (Icons.explore_outlined, HomeCopy.explore.of(tone), Routes.explore, 'nav-explore'),
      (Icons.tune, HomeCopy.settings.of(tone), Routes.settings, 'nav-settings'),
    ];
    final parent = TextButton.icon(
      key: const ValueKey('nav-parent'),
      onPressed: () => onOpen(Routes.parent),
      style: TextButton.styleFrom(textStyle: Theme.of(context).textTheme.bodyMedium),
      icon: const Icon(Icons.lock_outline, size: 18),
      label: Text(HomeCopy.parent.of(tone)),
    );
    // 平板：四張一樣大的入口卡片（E12）；手機：一排安靜的文字連結（和原本一樣）。
    if (Layout.isTablet(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final perRow = constraints.maxWidth >= 4 * LayoutConfig.navTileMinWidth + 3 * AppSpace.m ? 4 : 2;
              final width = (constraints.maxWidth - (perRow - 1) * AppSpace.m) / perRow;
              return Wrap(
                spacing: AppSpace.m,
                runSpacing: AppSpace.m,
                children: [
                  for (final (icon, label, route, key) in entries)
                    SizedBox(
                      width: width,
                      child: _NavTile(icon: icon, label: label, onTap: () => onOpen(route), tileKey: key),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpace.m),
          Center(child: parent),
        ],
      );
    }
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpace.s,
          runSpacing: AppSpace.xs,
          children: [
            for (final (icon, label, route, key) in entries)
              TextButton.icon(key: ValueKey(key), onPressed: () => onOpen(route), icon: Icon(icon), label: Text(label)),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        parent,
      ],
    );
  }
}

/// 平板首頁的一張入口卡片：圖示在圓底上、名字在旁邊。四張一樣大，沒有數字、沒有小紅點。
class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap, required this.tileKey});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String tileKey;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(tileKey),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s + 2),
                    child: Icon(icon, size: 26, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: AppSpace.m),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
          ),
        ),
      );
}
