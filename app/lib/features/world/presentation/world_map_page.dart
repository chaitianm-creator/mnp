import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:design_kingdom/core/state/user_progress.dart';
import 'package:design_kingdom/core/theme/kd_colors.dart';
import 'package:design_kingdom/core/theme/kd_theme.dart';
import 'package:design_kingdom/core/widgets/kd_widgets.dart';
import 'package:design_kingdom/core/widgets/pn_shell.dart';
import 'package:design_kingdom/features/onboarding/presentation/story_scenes.dart';

/// エリア定義(Phase 8 §1.2 の確定マッピング)。
/// 本番は areas コレクション(Phase 5 §2.1)から取得 — DEMO は静的定義。
class AreaDef {
  const AreaDef({
    required this.id,
    required this.order,
    required this.name,
    required this.mindTheme,
    required this.skillLabel,
    required this.icon,
    required this.color,
  });
  final String id;
  final int order;
  final String name;
  final String mindTheme;
  final String skillLabel;
  final IconData icon;
  final Color color;
}

const kAreas = [
  AreaDef(
      id: 'area_01_hajimari',
      order: 1,
      name: 'はじまりの街（みぽりん村）',
      mindTheme: '冒険のスタート',
      skillLabel: '仕事の型',
      icon: Icons.home_work,
      color: KdColors.pink500),
  AreaDef(
      id: 'area_02_migaki',
      order: 2,
      name: 'みがき上げの森',
      mindTheme: '自分磨き・習慣化',
      skillLabel: '自己管理',
      icon: Icons.forest,
      color: KdColors.forest700),
  AreaDef(
      id: 'area_03_commu',
      order: 3,
      name: 'コミュ力の湖',
      mindTheme: '対話力・伝え方',
      skillLabel: 'ヒアリング',
      icon: Icons.water,
      color: KdColors.ocean500),
  AreaDef(
      id: 'area_04_jishin',
      order: 4,
      name: '自信の塔',
      mindTheme: '自己肯定感',
      skillLabel: '提案力',
      icon: Icons.castle,
      color: KdColors.gold500),
  AreaDef(
      id: 'area_05_yaruki',
      order: 5,
      name: 'やる気の火山',
      mindTheme: '行動力・継続力',
      skillLabel: '継続',
      icon: Icons.local_fire_department,
      color: KdColors.lava500),
  AreaDef(
      id: 'area_06_nakama',
      order: 6,
      name: '仲間の大草原',
      mindTheme: '仲間・チームワーク',
      skillLabel: 'コミュニティ',
      icon: Icons.grass,
      color: KdColors.grass500),
  AreaDef(
      id: 'area_07_shiren',
      order: 7,
      name: '試練の洞窟',
      mindTheme: '壁を乗り越える',
      skillLabel: '改善力',
      icon: Icons.landscape,
      color: KdColors.wood700),
  AreaDef(
      id: 'area_08_miporin',
      order: 8,
      name: 'みぽりん城',
      mindTheme: '理想の未来・ゴール',
      skillLabel: '王国認定',
      icon: Icons.favorite,
      color: KdColors.pink700),
];

/// SC-30 冒険マップ(PRO NAVI ワイヤーフレーム準拠・共通シェル使用)。
/// 現在地カード + クリア状況 + エリア一覧カード。キャラはドット絵のまま。
class WorldMapPage extends ConsumerWidget {
  const WorldMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(userProgressProvider);
    // DEMO: エリア①のみ解放。②以降は①クリア(12件)で解放(Phase 5 §2.1)
    bool unlockedOf(AreaDef a) =>
        a.order == 1 ||
        (progress.areaDelivered['area_01_hajimari'] ?? 0) >= 12;
    final clearedAreas =
        kAreas.where((a) => progress.stageOf(a.id) >= 3).length;

    return PnShell(
      current: '冒険マップ',
      mainBuilder: (context, wide) => [
        _currentAreaCard(context, withSpeech: wide),
        const SizedBox(height: 10),
        _summaryCard(clearedAreas),
        const SizedBox(height: 18),
        const Row(children: [
          Text('🗺', style: TextStyle(fontSize: 16)),
          SizedBox(width: 6),
          Text('エリア一覧',
              style: TextStyle(
                  color: pnInk, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        for (final area in kAreas) ...[
          _AreaCard(
            area: area,
            unlocked: unlockedOf(area),
            current: area.order == 1,
            stage: progress.stageOf(area.id),
            onTap: () => context.push(
                area.order == 1 ? '/village' : '/area/${area.id}'),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// 現在地カード(ストライプ地 + みぽりん先生)。
  Widget _currentAreaCard(BuildContext context, {bool withSpeech = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pnLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const PnStripePainter(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: pnCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: pnLine),
                      ),
                      child: const Text('現在地',
                          style: TextStyle(
                              color: pnSub,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 8),
                    const Text('🏠 はじまりの街',
                        style: TextStyle(
                            color: pnInk,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text(
                        'すべての旅が始まる村。まずはここでデザインの基礎を身につけよう。',
                        style: TextStyle(
                            color: pnInk, fontSize: 12.5, height: 1.6)),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => context.push('/village'),
                      style: FilledButton.styleFrom(
                          backgroundColor: pnGreen,
                          foregroundColor: pnGreenInk,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8)),
                      child: const Text('村の中を見る',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ]),
            ),
            const SizedBox(width: 12),
            Column(children: [
              if (withSpeech)
                Container(
                  width: 190,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pnCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pnLine),
                  ),
                  child: const Text(
                    '行きたいエリアを選んでね！クリアするとつぎのエリアが解放されるよ。',
                    style: TextStyle(color: pnInk, fontSize: 12, height: 1.6),
                  ),
                ),
              PixelSprite(
                  rows: miporinRows(0),
                  palette: miporinPalette,
                  width: withSpeech ? 92 : 76),
              const SizedBox(height: 4),
              const Text('みぽりん先生',
                  style: TextStyle(
                      color: pnSub,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _summaryCard(int cleared) => PnPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('クリアエリア',
                style: TextStyle(
                    color: pnSub, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('$cleared / ${kAreas.length}',
                style: const TextStyle(
                    color: pnInk, fontSize: 18, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
                value: cleared / kAreas.length,
                minHeight: 8,
                backgroundColor: pnBg,
                color: pnGreen),
          ),
        ]),
      );
}

/// エリアカード(番号バブル + 名前 + テーマ + 状態チップ)。
class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.area,
    required this.unlocked,
    required this.current,
    required this.stage,
    required this.onTap,
  });
  final AreaDef area;
  final bool unlocked;
  final bool current;
  final int stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pastel = Color.lerp(area.color, Colors.white, 0.55)!;
    return Material(
      color: pnCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: current ? pnGreen : pnLine, width: current ? 1.6 : 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: unlocked ? pastel : pnBg, shape: BoxShape.circle),
              child: unlocked
                  ? Text('${area.order}'.padLeft(2, '0'),
                      style: const TextStyle(
                          color: pnInk,
                          fontSize: 13,
                          fontWeight: FontWeight.w900))
                  : const Icon(Icons.lock_rounded, size: 16, color: pnSub),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(area.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: unlocked ? pnInk : pnSub,
                                fontSize: 15,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 8),
                      if (current)
                        _chip('現在地', const Color(0xFFDDEECF))
                      else if (!unlocked)
                        _chip('ロック', const Color(0xFFF0EDE4)),
                    ]),
                    const SizedBox(height: 3),
                    Text('${area.mindTheme}　・　スキル: ${area.skillLabel}',
                        style: const TextStyle(color: pnSub, fontSize: 11.5)),
                    if (unlocked) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        for (var i = 1; i <= 3; i++)
                          Icon(Icons.local_florist,
                              size: 13,
                              color: i <= stage
                                  ? const Color(0xFFE98FA9)
                                  : pnLine),
                      ]),
                    ],
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: pnSub),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: const TextStyle(
                color: pnInk, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class _Facility {
  const _Facility(this.icon, this.color, this.name, this.desc, {this.role = ''});
  final IconData icon;
  final Color color;
  final String name;
  final String desc;
  final String role;
}

class _Reward {
  const _Reward(this.icon, this.color, this.label, this.value);
  final IconData icon;
  final Color color;
  final String label;
  final String value;
}

class _AreaGuide {
  const _AreaGuide({
    required this.subtitle,
    required this.concept,
    required this.facilities,
    required this.teacherMessage,
    this.header,
    this.highlights = const [],
    this.todos = const [],
    this.facilityTitle = 'この街でできること',
    this.powersTitle = '',
    this.powers = const [],
    this.quests = const [],
    this.rewards = const [],
    this.items = const [],
    this.footer,
  });
  final String subtitle;
  final String concept;
  final String? header;
  final List<String> highlights; // 見どころ(エリア①)
  final List<String> todos; // シンプルなできること(エリア①)
  final String facilityTitle;
  final List<_Facility> facilities;
  final String powersTitle;
  final List<(String, String)> powers; // (力の名前, 効果)
  final List<(String, String)> quests; // (クエスト名, EXP表記)
  final List<_Reward> rewards;
  final List<(String, String)> items; // (アイテム名, 効果)
  final String teacherMessage;
  final String? footer;
}

const _guides = <String, _AreaGuide>{
  // ── エリア① はじまりの街（みぽりん村） ──────────────────
  'area_01_hajimari': _AreaGuide(
    subtitle: '〜すべての冒険の第一歩〜',
    concept: 'みぽりん先生と出会い、夢に向かって一歩を踏み出すための'
        '温かく安心できる"はじまりの場所"。'
        '仲間や学びがそろい、あなたの「やってみたい！」を'
        'やさしく応援してくれる街です。',
    highlights: [
      'みぽりん先生の教えがそろう学びの拠点',
      '仲間とつながる交流の場所',
      '最初のミッションやクエストを受けられる掲示板',
      'おしゃれでかわいいショップやカフェも充実♪',
      'あなたの成長をそっと見守ってくれる街',
    ],
    todos: [
      '初めての学びを受ける（レッスン・クエスト）',
      '仲間と出会い、つながる（コミュニティ）',
      'アイテムやデザイン素材をそろえる（ショップ）',
      '今日のやることを決める（掲示板・ミッション）',
      'ほっと一息ついて、リフレッシュする（カフェ・公園）',
    ],
    facilityTitle: '主な施設紹介',
    facilities: [
      _Facility(Icons.castle, KdColors.pink700, 'みぽりん先生の城',
          'レッスンや教えがそろうこの街の中心。先生がいつも見守ってくれるよ♪',
          role: '学びの拠点'),
      _Facility(Icons.assignment, KdColors.wood700, 'クエスト掲示板',
          '今日のミッションやイベントをチェック！やることが見つかるよ♪',
          role: 'ミッション受付'),
      _Facility(Icons.cottage, KdColors.pink500, 'コミュニティハウス',
          '仲間と交流したり、相談したりできるあたたかいおうち♪',
          role: '仲間とつながる場所'),
      _Facility(Icons.storefront, KdColors.gold500, 'デザインショップ',
          'デザインに役立つアイテムや素材がそろうお店♪',
          role: 'アイテム・素材屋'),
      _Facility(Icons.palette, KdColors.lava500, 'みぽりん工房',
          '制作の練習をしたり、作品を生み出すワクワクの工房♪',
          role: '制作・練習の場所'),
      _Facility(Icons.local_cafe, KdColors.ocean500, 'みぽりんカフェ',
          'ほっと一息つけるカフェでリフレッシュ♪ おしゃべりもOK！',
          role: 'ひとやすみ'),
      _Facility(Icons.local_florist, KdColors.grass500, 'みぽりんガーデン',
          'お花や緑に囲まれた癒しの庭。気分転換にぴったり♪',
          role: '癒しの庭'),
    ],
    teacherMessage: 'ここは、あなたの冒険のはじまりの場所。\n'
        '小さな一歩が、大きな未来につながるよ！\n'
        'みぽりん村で、わくわくする毎日を\n'
        'スタートさせようね♪',
  ),

  // ── エリア② みがき上げの森 ──────────────────────────
  'area_02_migaki': _AreaGuide(
    subtitle: '〜毎日の積み重ねが才能を育てる場所〜',
    header: 'ここでの学びが、自信となり、あなたを勇者へと導くよ！',
    concept: 'デザイナーは、一日で大きく成長するわけではありません。'
        '毎日の小さな挑戦や学びの積み重ねが、やがて大きな自信につながります。'
        'この森では、「続ける力」を育てながら、自分だけの才能を磨いていきます。',
    facilityTitle: 'この森でできること',
    facilities: [
      _Facility(Icons.brush, KdColors.pink500, 'デザイン練習場',
          'バナー制作・模写・配色練習。実践を通して、スキルをみがこう！'),
      _Facility(Icons.menu_book, KdColors.wood700, '学びの図書館',
          'デザイン・Web・AI・マーケティング。知識をインプットして、未来を広げよう！'),
      _Facility(Icons.lightbulb, KdColors.gold500, 'ひらめきスポット',
          'アイデア探し・散歩・インプット。アイデアが降りてくるよ♪'),
      _Facility(Icons.rate_review, KdColors.grass500, '添削の切り株',
          '作品添削・フィードバック・改善ポイント発見。プロのフィードバックで、ぐんぐん成長しよう！'),
      _Facility(Icons.water_drop, KdColors.ocean500, '習慣の泉',
          '毎日5分チャレンジ・投稿習慣・学習記録。毎日の小さな積み重ねが、大きな力になるよ！'),
    ],
    quests: [
      ('デザインを1枚作ろう', 'EXP+100'),
      ('AIを1つ試してみよう', 'EXP+100'),
      ('模写を30分しよう', 'EXP+100'),
      ('今日の学びを記録しよう', 'EXP+100'),
      ('作品を添削に出そう', 'EXP+150'),
      ('Xへアウトプットしよう', 'EXP+100'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.eco, KdColors.grass500, '継続力', '+10'),
      _Reward(Icons.brush, KdColors.pink500, '制作力', '+10'),
      _Reward(Icons.lightbulb, KdColors.gold500, '発想力', '+5'),
      _Reward(Icons.redeem, KdColors.pink700, 'アイテムがもらえることも♪', ''),
    ],
    teacherMessage: '才能は、生まれつきじゃないよ🌸\n'
        '今日の小さな一歩が、\n'
        '明日の大きな成長になるんだ♪\n'
        '焦らず、一緒に\n'
        'レベルアップしていこうね♡',
    footer: 'この森で「続ける力」を身につけると、あなたの未来がもっと輝き出すよ！',
  ),

  // ── エリア③ コミュ力の湖 ─────────────────────────────
  'area_03_commu': _AreaGuide(
    subtitle: '〜つながりが、未来を広げる場所〜',
    header: 'つながろう、支え合おう、あなたらしい魅力を伝えよう！',
    concept: 'デザイナーは、一人では大きく飛躍できません。'
        '仲間やお客様、応援してくれる人との「つながり」が、'
        'お仕事や夢を叶える力になります。'
        'この湖では、安心して交流し、信頼関係を育てながら、'
        'あなたらしい魅力を発信していきます。',
    facilityTitle: 'この湖でできること',
    facilities: [
      _Facility(Icons.groups, KdColors.ocean500, '交流の桟橋（さんばし）',
          '仲間と気軽に交流できるエリア。あいさつやコメントでつながろう'),
      _Facility(Icons.local_cafe, KdColors.pink500, 'シェアのカフェ',
          '作品や学びをシェアできる場所。自分の想いを発信しよう'),
      _Facility(Icons.beach_access, KdColors.gold500, '相談のテラス',
          '悩みや疑問を相談できるエリア。先輩や仲間からアドバイスがもらえる'),
      _Facility(Icons.park, KdColors.grass500, 'コラボの小島',
          'コラボ企画やチーム活動ができる場所。一緒に作品やイベントをつくろう'),
      _Facility(Icons.flare, KdColors.lava500, '感謝の灯台',
          '感謝を伝え合い、信頼を育てる場所。「ありがとう」が循環するエリア'),
    ],
    powersTitle: 'この湖での行動で育つ力',
    powers: [
      ('コミュニケーション力', '人とつながる力がアップ！'),
      ('発信力', '自分の想いや魅力を伝える力がアップ！'),
      ('信頼力', '信頼関係を築き、応援される力がアップ！'),
      ('チーム力', '協力して成果を出す力がアップ！'),
      ('共感力', '相手の気持ちを理解する力がアップ！'),
    ],
    quests: [
      ('仲間にあいさつしてみよう！', 'EXP+100'),
      ('仲間の投稿にコメントしよう！', 'EXP+100'),
      ('自分の作品をシェアしよう！', 'EXP+150'),
      ('悩みを相談してみよう！', 'EXP+100'),
      ('コラボに参加してみよう！', 'EXP+200'),
      ('誰かに「ありがとう」を伝えよう！', 'EXP+100'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.favorite, KdColors.pink500, '信頼力', '+10'),
      _Reward(Icons.campaign, KdColors.lava500, '発信力', '+10'),
      _Reward(Icons.volunteer_activism, KdColors.pink700, '共感力', '+10'),
      _Reward(Icons.redeem, KdColors.pink700, '特別なごほうびアイテム', ''),
    ],
    teacherMessage: '一人ではできないことも、\n'
        '仲間とならきっとできるよ♪\n'
        '思いやりのある言葉や行動が、\n'
        'あなたの未来を\n'
        'キラキラ輝かせるの♡',
    footer: 'つながりが、チャンスを連れてくるよ！信じて、勇気を出して一歩踏み出そう！',
  ),

  // ── エリア④ 自信の塔 ────────────────────────────────
  'area_04_jishin': _AreaGuide(
    subtitle: '〜自分を信じて、未来をつかむ場所〜',
    header: '一歩ずつ登っていくたびに、あなたの自信が輝きを増していくよ！',
    concept: 'ここは、自分の成長を振り返り、「できた！」を積み重ねていく場所。'
        'ひとつひとつの階段が、あなたの自信になります。'
        '一番上には、あなたの理想の未来が待っています。',
    facilityTitle: 'この塔でできること',
    facilities: [
      _Facility(Icons.stairs, KdColors.pink500, '成長の階段（1階）',
          'これまでの実績や学びを記録して、自分の成長を見える化しよう！'),
      _Facility(Icons.photo_library, KdColors.gold500, '実績ギャラリー',
          '制作した作品や成果を飾って、自信を育てよう！'),
      _Facility(Icons.track_changes, KdColors.lava500, '目標の部屋',
          '未来の目標を設定して、やりたいことを明確にしよう！'),
      _Facility(Icons.balcony, KdColors.ocean500, '勇気のバルコニー',
          '一歩踏み出した経験を振り返り、「やってよかった！」を増やそう！'),
      _Facility(Icons.redeem, KdColors.pink700, 'ごほうびの間',
          '自分をたくさん褒めてあげよう♪ ごほうびでやる気もアップ！'),
      _Facility(Icons.travel_explore, KdColors.grass500, '未来の展望台（最上階）',
          '理想の未来をイメージして、ワクワクする未来を描こう！'),
    ],
    quests: [
      ('過去の作品を振り返ろう！', 'EXP+100'),
      ('小さな目標を設定しよう！', 'EXP+100'),
      ('できたことリストを作ろう！', 'EXP+150'),
      ('勇気を出して発信してみよう！', 'EXP+150'),
      ('自分をたくさん褒めよう！', 'EXP+100'),
      ('未来の自分に手紙を書こう！', 'EXP+200'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.favorite, KdColors.pink500, '自信力', '+20'),
      _Reward(Icons.campaign, KdColors.lava500, '行動力', '+15'),
      _Reward(Icons.eco, KdColors.grass500, '継続力', '+15'),
      _Reward(Icons.redeem, KdColors.pink700, '魅力アップアイテム', ''),
    ],
    items: [
      ('キラキラの証', '自信力UP'),
      ('勇気のチャーム', '行動力UP'),
      ('未来チケット', '目標達成率UP'),
      ('ごほうびボックス', 'やる気UP'),
    ],
    teacherMessage: '自信は、特別な人だけのものじゃないよ♪\n'
        'あなたが積み重ねてきた努力は、\n'
        'ちゃんと未来につながっているよ！\n'
        '一緒に、もっともっと高い景色を\n'
        '見に行こうね♪',
    footer: '自分を信じることが、あなたの未来を輝かせる一番の魔法だよ！',
  ),

  // ── エリア⑤ やる気の火山 ────────────────────────────
  'area_05_yaruki': _AreaGuide(
    subtitle: '〜心の火を燃やして、行動力を高める場所〜',
    header: 'やる気の炎を燃やし続けて、理想の未来に向かって進もう！',
    concept: 'やる気は、待っていても湧いてきません。'
        '小さな成功体験や仲間の応援が、あなたの心に火をつけます。'
        'この火山で、やる気の炎を燃やし続けて、'
        'どんどん行動力をアップさせていきましょう！',
    facilityTitle: 'この火山でできること',
    facilities: [
      _Facility(Icons.local_fire_department, KdColors.lava500, '炎のスイッチ広場',
          'やる気をONにする習慣づくり。毎日の習慣で火をつけよう！'),
      _Facility(Icons.hiking, KdColors.wood700, 'チャレンジの溶岩道',
          '小さな挑戦を積み重ねるエリア。自信とやる気を積み上げよう！'),
      _Facility(Icons.campaign, KdColors.pink500, '応援の展望台',
          '仲間の声援や応援で、心の火がもっと大きくなる！'),
      _Facility(Icons.flag, KdColors.gold500, '目標のマグマ部屋',
          '自分の目標をいつでも確認！夢への道がはっきり見えるよ！'),
      _Facility(Icons.rocket_launch, KdColors.lava500, '行動の噴火口',
          'ひらめいたアイデアを、すぐに行動に移そう！行動がやる気を加速させるよ！'),
      _Facility(Icons.hot_tub, KdColors.ocean500, 'ごほうびの温泉',
          'がんばった自分をしっかりほめて、心も体もリフレッシュ♪'),
    ],
    powersTitle: 'この火山で育つ力',
    powers: [
      ('行動力', 'すぐに行動する力がUP！'),
      ('継続力', '続けることでやる気が持続！'),
      ('自己肯定感', '小さな成功で自信がつく！'),
      ('目標達成力', '目標に向かう力が強くなる！'),
      ('挑戦力', '新しいことに挑戦できるようになる！'),
    ],
    quests: [
      ('やることリストを作ろう', 'EXP+100'),
      ('今日の目標を設定しよう', 'EXP+100'),
      ('小さなことから始めよう', 'EXP+150'),
      ('新しいことに挑戦しよう', 'EXP+150'),
      ('できたことを記録しよう', 'EXP+100'),
      ('自分をほめてごほうびをあげよう', 'EXP+200'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.local_fire_department, KdColors.lava500, 'やる気', '+20'),
      _Reward(Icons.campaign, KdColors.pink500, '行動力', '+20'),
      _Reward(Icons.eco, KdColors.grass500, '継続力', '+15'),
      _Reward(Icons.bolt, KdColors.gold500, '挑戦力', '+15'),
      _Reward(Icons.redeem, KdColors.pink700, 'やる気アップアイテム', ''),
    ],
    teacherMessage: 'やる気は、あなたの中にちゃんとあるよ！\n'
        '時には、火が小さくなることもあるけど、\n'
        '大丈夫♪この火山で、また火をつければいいの！\n'
        'あなたの夢に向かって、\n'
        '一緒にがんばっていこうね♡',
    footer: '心の火を消さずに、今日も一歩ずつ夢に近づいていこう！',
  ),

  // ── エリア⑥ 仲間の大草原 ────────────────────────────
  'area_06_nakama': _AreaGuide(
    subtitle: '〜つながり、支え合い、一緒に成長する場所〜',
    header: 'つながろう、支え合おう！仲間と一緒に、理想の未来へ♪',
    concept: '一人では、くじけそうになることもあるけれど、'
        '仲間がいるから、がんばれる！'
        'この大草原では、仲間と出会い、刺激し合い、'
        '支え合いながら、理想の未来へ進んでいけます。',
    facilityTitle: 'この草原でできること',
    facilities: [
      _Facility(Icons.groups, KdColors.pink500, '仲間の広場',
          '自己紹介や交流ができる場所。はじめましてのあいさつから、素敵なつながりが生まれるよ！'),
      _Facility(Icons.terrain, KdColors.grass500, 'チームワークの丘',
          'チームを組んで、一緒に目標に向かって進もう！'),
      _Facility(Icons.park, KdColors.forest700, 'シェアの木',
          '作品や学びをシェアして、みんなで成長しよう！'),
      _Facility(Icons.mail, KdColors.pink700, '応援メッセージのポスト',
          '応援のメッセージやいいねで、仲間のやる気を後押ししよう！'),
      _Facility(Icons.assignment, KdColors.wood700, 'みんなの掲示板',
          'イベントやお知らせを見逃さず、チャンスをつかもう！'),
      _Facility(Icons.festival, KdColors.pink500, 'コラボのテント',
          'コラボ企画やイベントで、新しいアイデアが生まれるよ！'),
      _Facility(Icons.local_florist, KdColors.lava500, '感謝の花畑',
          '「ありがとう」を伝え合って、信頼と絆を育てよう！'),
      _Facility(Icons.shopping_basket, KdColors.gold500, 'ピクニックエリア',
          'リラックスしながら、自由におしゃべり＆情報交換♪'),
    ],
    powersTitle: 'この草原で育つ力',
    powers: [
      ('コミュニケーション力', '伝える力がアップ！'),
      ('協調性', '協力して成長できる！'),
      ('信頼力', '信頼関係が深まる！'),
      ('モチベーション', 'やる気が続く！'),
      ('共感力', '相手の気持ちに寄り添える！'),
    ],
    quests: [
      ('仲間に自己紹介をしよう', 'EXP+100'),
      ('仲間の投稿にいいねをしよう', 'EXP+100'),
      ('チームに参加しよう', 'EXP+150'),
      ('コラボイベントに参加しよう', 'EXP+200'),
      ('仲間に応援メッセージを送ろう', 'EXP+100'),
      ('「ありがとう」を伝えよう', 'EXP+100'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100'),
      _Reward(Icons.favorite, KdColors.pink500, 'つながりポイント', '+20'),
      _Reward(Icons.campaign, KdColors.lava500, '信頼度', '+15'),
      _Reward(Icons.local_fire_department, KdColors.gold500, 'やる気', '+20'),
      _Reward(Icons.redeem, KdColors.pink700, '特別なごほうびアイテム', ''),
    ],
    teacherMessage: '一人で頑張ることも大切だけど、\n'
        '仲間と一緒だと、もっともっと\n'
        '大きな未来が待っているよ！\n'
        '支え合い、励まし合いながら、\n'
        'あなたらしく輝いていこうね♡',
    footer: '仲間とのつながりが、あなたの未来をもっと明るく、もっと楽しくしてくれるよ！',
  ),

  // ── エリア⑦ 試練の洞窟 ──────────────────────────────
  'area_07_shiren': _AreaGuide(
    subtitle: '〜自分の限界を超えて、強くなる場所〜',
    header: '試練を乗り越えた先に、新しい自分が待っている！',
    concept: '成長の道のりには、時に壁が立ちはだかります。'
        'でも、その壁を乗り越えた先に、新しい自分が待っています。'
        'ここは、あなたの「挑戦する力」と「乗り越える力」を育てる場所。'
        '試練を乗り越えて、さらにレベルアップしよう！',
    facilityTitle: 'この洞窟でできること',
    facilities: [
      _Facility(Icons.palette, KdColors.pink500, 'デザインの試練',
          '苦手なデザインや新しい表現に挑戦！'),
      _Facility(Icons.hourglass_bottom, KdColors.ocean500, '時間の試練',
          '制限時間内に課題をクリアしよう！'),
      _Facility(Icons.lightbulb, KdColors.gold500, 'アイデアの試練',
          'お題から自由にアイデアを出そう！'),
      _Facility(Icons.calendar_month, KdColors.grass500, '継続の試練',
          '毎日コツコツ取り組む力を試そう！'),
      _Facility(Icons.shield, KdColors.pink700, '自信の試練',
          '自分の作品を公開してみよう！'),
      _Facility(Icons.sports_martial_arts, KdColors.lava500, '総合の試練（ボス戦）',
          'これまでの力をすべて使って、最後のボスに挑め！'),
    ],
    powersTitle: 'この洞窟で育つ力',
    powers: [
      ('挑戦力', '新しいことに挑戦する力がアップ！'),
      ('集中力', '集中して取り組む力がアップ！'),
      ('突破力', '壁を乗り越える力がアップ！'),
      ('自己肯定感', '自分を信じる力がアップ！'),
      ('成長実感', '成長を実感して自信がつく！'),
    ],
    quests: [
      ('苦手なデザインに挑戦しよう', 'EXP+100'),
      ('制限時間内にバナーを作ろう', 'EXP+100'),
      ('お題からアイデアを10個出そう', 'EXP+150'),
      ('7日間、毎日学習しよう', 'EXP+150'),
      ('自分の作品をSNSに投稿しよう', 'EXP+150'),
      ('ボス課題にチャレンジしよう', 'EXP+200'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+100〜300'),
      _Reward(Icons.bolt, KdColors.lava500, '挑戦力', '+20'),
      _Reward(Icons.center_focus_strong, KdColors.ocean500, '集中力', '+15'),
      _Reward(Icons.shield, KdColors.grass500, '突破力', '+20'),
      _Reward(Icons.favorite, KdColors.pink500, '自信ポイント', '+20'),
      _Reward(Icons.redeem, KdColors.pink700, '特別なごほうびアイテム', ''),
    ],
    items: [
      ('勇気のブレスレット', '挑戦力UP'),
      ('集中のリング', '集中力UP'),
      ('突破の盾', '突破力UP'),
      ('自信の鏡', '自己肯定感UP'),
      ('試練の鍵', '特別エリア解放'),
    ],
    teacherMessage: '試練があるからこそ、成長できるよ！\n'
        'うまくいかなくても大丈夫。\n'
        'あきらめずに挑戦し続ければ、\n'
        '必ず乗り越えられるから、\n'
        '一緒にがんばっていこうね♡',
    footer: '試練を乗り越えたあなたは、もっと強く、もっと輝ける！未来の自分を信じて進もう！',
  ),

  // ── エリア⑧ みぽりん城 ──────────────────────────────
  'area_08_miporin': _AreaGuide(
    subtitle: '〜理想の自分に、もっと近づける場所〜',
    header: 'ここは、みぽりん先生からたくさんの学びとごほうびがもらえる特別な場所！',
    concept: 'デザインやマーケティングを学び、実践し、'
        '仲間と切磋琢磨しながら、理想の未来を叶えていく場所。'
        'みぽりん先生の想いと、みんなのがんばりがつまった、'
        'デザイン王国のシンボルです。',
    facilityTitle: 'みぽりん城でできること',
    facilities: [
      _Facility(Icons.favorite, KdColors.pink700, 'みぽりん先生の部屋',
          'みぽりん先生から特別なメッセージやアドバイスがもらえるよ♪'),
      _Facility(Icons.school, KdColors.pink500, '特別レッスンホール',
          '限定ライブやセミナー、特別レッスンに参加できるよ！'),
      _Facility(Icons.emoji_events, KdColors.gold500, '実績ギャラリー',
          'みんなのがんばりや成果が展示されるよ！'),
      _Facility(Icons.redeem, KdColors.pink500, 'ごほうび広場',
          'クエストクリアや目標達成でごほうびがもらえるよ！'),
      _Facility(Icons.menu_book, KdColors.wood700, '学びの図書館',
          'デザイン・マーケティング・AIなどの知識がたくさんつまっているよ！'),
      _Facility(Icons.auto_awesome, KdColors.ocean500, '未来の展望テラス',
          '理想の未来を描いて、目標を再確認しよう！'),
    ],
    powersTitle: 'みぽりん城で育つ力',
    powers: [
      ('専門スキル力', 'レベルアップ！'),
      ('実践力', '行動して成果につなげる力！'),
      ('継続力', 'コツコツ続ける力！'),
      ('自己肯定感', '自分を信じられる力！'),
      ('夢実現力', '理想の未来を叶える力！'),
    ],
    quests: [
      ('特別レッスンに参加しよう', 'EXP+200'),
      ('作品を提出してみよう', 'EXP+150'),
      ('仲間に応援メッセージを送ろう', 'EXP+100'),
      ('目標を見直してみよう', 'EXP+100'),
      ('イベントに参加しよう', 'EXP+150'),
      ('実績をギャラリーに追加しよう', 'EXP+200'),
      ('みぽりん先生に質問してみよう', 'EXP+100'),
    ],
    rewards: [
      _Reward(Icons.auto_awesome, KdColors.gold500, '経験値', '+200〜500'),
      _Reward(Icons.favorite, KdColors.pink500, 'みぽりんポイント', '+50'),
      _Reward(Icons.shield, KdColors.ocean500, '自信バッジ', '+1'),
      _Reward(Icons.redeem, KdColors.pink700, '特別アイテム', ''),
      _Reward(Icons.emoji_events, KdColors.gold500, '限定称号', ''),
      _Reward(Icons.confirmation_number, KdColors.pink500, 'ごほうびチケット', ''),
    ],
    teacherMessage: 'ここまで本当にがんばってきたね！\n'
        'あなたの努力は、必ず未来につながるよ。\n'
        'みぽりん先生は、あなたのことを\n'
        'いつも応援しているよ♡\n'
        'これからも一緒に、\n'
        '理想の未来を叶えていこうね！',
    footer: 'あなたの努力は、あなたの未来をつくる最高の魔法だよ！',
  ),
};

/// SC-31 エリア詳細(町ビュー)。授かり効果の中心画面。
/// 全エリアに「全体マップ提案」様式の紹介ページを表示。
class AreaDetailPage extends ConsumerWidget {
  const AreaDetailPage({super.key, required this.areaId});
  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = kAreas.firstWhere((a) => a.id == areaId,
        orElse: () => kAreas.first);
    final progress = ref.watch(userProgressProvider);
    final delivered = progress.areaDelivered[areaId] ?? 0;
    final stage = progress.stageOf(areaId);
    final guide = _guides[areaId];

    return Scaffold(
      appBar: AppBar(title: Text(area.name)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (guide != null) ...[
            // ── リボンタイトル + サブタイトル ──
            Center(child: KdRibbonBanner(area.name, fontSize: 17)),
            const SizedBox(height: 6),
            Center(
              child: Text(guide.subtitle,
                  textAlign: TextAlign.center,
                  style: KdTheme.dot(size: 13, color: KdColors.pink700)),
            ),
            const SizedBox(height: 16),
            // ── ヘッダー帯 ──
            if (guide.header != null) ...[
              KdBandMessage(guide.header!),
              const SizedBox(height: 16),
            ],
            // ── コンセプト ──
            const KdSectionHeader('コンセプト'),
            const SizedBox(height: 8),
            KdParchmentCard(
              child: Text(guide.concept,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: 20),
            // ── 見どころ(エリア①のみ) ──
            if (guide.highlights.isNotEmpty) ...[
              const KdSectionHeader('見どころ'),
              const SizedBox(height: 8),
              KdParchmentCard(
                child: _IconLines(
                    icon: Icons.local_florist,
                    color: KdColors.pink500,
                    lines: guide.highlights),
              ),
              const SizedBox(height: 20),
            ],
            // ── シンプルなできること(エリア①のみ) ──
            if (guide.todos.isNotEmpty) ...[
              const KdSectionHeader('この街でできること'),
              const SizedBox(height: 8),
              KdParchmentCard(
                child: _IconLines(
                    icon: Icons.auto_awesome,
                    color: KdColors.gold500,
                    lines: guide.todos),
              ),
              const SizedBox(height: 20),
            ],
            // ── 施設一覧 ──
            Center(child: KdRibbonBanner(guide.facilityTitle, fontSize: 14)),
            const SizedBox(height: 12),
            KdParchmentCard(
              child: Column(children: [
                for (final (i, f) in guide.facilities.indexed) ...[
                  if (i > 0) const Divider(height: 18),
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: f.color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: KdColors.wood900, width: 2),
                      ),
                      child: Icon(f.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.ideographic,
                                children: [
                                  Flexible(
                                    child: Text(f.name,
                                        style: KdTheme.dot(
                                                size: 14,
                                                color: KdColors.heading)
                                            .copyWith(
                                                fontWeight: FontWeight.w700)),
                                  ),
                                  if (f.role.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text('（${f.role}）',
                                        style: KdTheme.dot(
                                            size: 11, color: KdColors.ink900)),
                                  ],
                                ]),
                            const SizedBox(height: 2),
                            Text(f.desc,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ]),
                    ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            // ── 育つ力 ──
            if (guide.powers.isNotEmpty) ...[
              Center(child: KdRibbonBanner(guide.powersTitle, fontSize: 14)),
              const SizedBox(height: 12),
              KdParchmentCard(
                child: Column(children: [
                  for (final (i, p) in guide.powers.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.favorite,
                              size: 16, color: KdColors.pink500),
                          const SizedBox(width: 8),
                          Text(p.$1,
                              style: KdTheme.dot(
                                      size: 13, color: KdColors.ink900)
                                  .copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(p.$2,
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ),
                        ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],
            // ── おすすめクエスト ──
            if (guide.quests.isNotEmpty) ...[
              Center(child: KdRibbonBanner('おすすめクエスト', fontSize: 14)),
              const SizedBox(height: 12),
              KdParchmentCard(
                child: Column(children: [
                  for (final (i, q) in guide.quests.indexed) ...[
                    if (i > 0) const Divider(height: 14),
                    Row(children: [
                      const Icon(Icons.star,
                          size: 18, color: KdColors.gold500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(q.$1,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: KdColors.pink100,
                          borderRadius: BorderRadius.circular(3),
                          border:
                              Border.all(color: KdColors.pink500, width: 1.5),
                        ),
                        child: Text(q.$2,
                            style: KdTheme.dot(
                                size: 12, color: KdColors.pink700)),
                      ),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],
            // ── クリア報酬(例) ──
            if (guide.rewards.isNotEmpty) ...[
              Center(child: KdRibbonBanner('クリア報酬（例）', fontSize: 14)),
              const SizedBox(height: 12),
              KdParchmentCard(
                child: Column(children: [
                  for (final (i, r) in guide.rewards.indexed) ...[
                    if (i > 0) const Divider(height: 14),
                    Row(children: [
                      Icon(r.icon, size: 20, color: r.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r.label,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      if (r.value.isNotEmpty)
                        Text(r.value,
                            style:
                                KdTheme.dot(size: 15, color: KdColors.heading)
                                    .copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],
            // ── 手に入るアイテム(例) ──
            if (guide.items.isNotEmpty) ...[
              Center(child: KdRibbonBanner('手に入るアイテム（例）', fontSize: 14)),
              const SizedBox(height: 12),
              KdParchmentCard(
                child: Column(children: [
                  for (final (i, item) in guide.items.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.card_giftcard,
                          size: 18, color: KdColors.gold500),
                      const SizedBox(width: 8),
                      Text(item.$1,
                          style: KdTheme.dot(size: 13, color: KdColors.heading)
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('（${item.$2}）',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],
            // ── みぽりん先生からのメッセージ ──
            Center(
                child: KdRibbonBanner('みぽりん先生からのメッセージ', fontSize: 14)),
            const SizedBox(height: 12),
            KdParchmentCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: KdColors.pink100,
                        shape: BoxShape.circle,
                        border: Border.all(color: KdColors.pink500, width: 2),
                      ),
                      child: const Icon(Icons.favorite,
                          color: KdColors.pink500, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(guide.teacherMessage,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ]),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // ガイド未定義エリアの骨格(発展stageで色が濃くなる)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: area.color.withOpacity(0.2 + stage * 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: KdColors.border, width: 2),
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(area.icon, size: 64, color: area.color),
                  Text('発展レベル $stage / 3',
                      style: KdTheme.dot(size: 14, color: KdColors.ink900)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            KdParchmentCard(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('このエリアで育つもの',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('マインド: ${area.mindTheme}',
                    style: Theme.of(context).textTheme.bodyLarge),
                Text('スキル: ${area.skillLabel}',
                    style: Theme.of(context).textTheme.bodyLarge),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          // ── エリアクリアまで(共通) ──
          KdParchmentCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('エリアクリアまで',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                Text('$delivered / 12',
                    style: KdTheme.dot(size: 15, color: KdColors.ink900)),
              ]),
              const SizedBox(height: 8),
              KdProgressBar(value: delivered / 12),
              const SizedBox(height: 8),
              Text('12件納品でボス戦（大型案件）が解放されるよ',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          if (guide != null) ...[
            const SizedBox(height: 20),
            // ── フッター帯 ──
            if (guide.footer != null) ...[
              KdBandMessage(guide.footer!),
              const SizedBox(height: 12),
            ],
            // ── 冒険への入り口(ワールドマップへ) ──
            KdPrimaryButton(
              label: '冒険への入り口（ワールドマップへ）',
              onPressed: () => context.go('/map'),
            ),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

/// アイコン + 1行テキストのリスト(見どころ・できること用)。
class _IconLines extends StatelessWidget {
  const _IconLines(
      {required this.icon, required this.color, required this.lines});
  final IconData icon;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final (i, line) in lines.indexed) ...[
        if (i > 0) const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ]),
      ],
    ]);
  }
}
