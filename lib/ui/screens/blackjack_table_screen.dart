import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/blackjack_models.dart';
import '../../providers/blackjack_provider.dart';
import '../widgets/player_seat_card.dart';
import 'lobby_screen.dart';

class BlackjackTableScreen extends StatefulWidget {
  final bool isMultiplayer;
  final bool isHost;
  const BlackjackTableScreen({super.key, this.isMultiplayer = false, this.isHost = true});

  @override
  State<BlackjackTableScreen> createState() => _BlackjackTableScreenState();
}

class _BlackjackTableScreenState extends State<BlackjackTableScreen> with TickerProviderStateMixin {
  late double _s;
  late double _screenW;
  final Map<String, AnimationController> _cardAnims = {};
  double _betSliderValue = 50;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    _screenW = size.width;
    _s = (_screenW / 400).clamp(0.75, 1.5);
  }

  AnimationController _animFor(String key) {
    if (!_cardAnims.containsKey(key)) {
      final ctrl = AnimationController(duration: const Duration(milliseconds: 320), vsync: this);
      ctrl.forward();
      _cardAnims[key] = ctrl;
    }
    return _cardAnims[key]!;
  }

  @override
  void dispose() {
    for (final c in _cardAnims.values) { c.dispose(); }
    _cardAnims.clear();
    super.dispose();
  }

  Future<void> _confirmExit() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('¿Abandonar partida?', style: TextStyle(color: Colors.amber)),
        content: const Text('¿Estás seguro que quieres salir?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldPop ?? false) {
      if (context.mounted) {
        for (final c in _cardAnims.values) { c.dispose(); }
        _cardAnims.clear();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LobbyScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [Color(0xFF0D5C32), Color(0xFF0A4D28), Color(0xFF052915)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Consumer<BlackjackProvider>(
              builder: (context, bj, child) {
                if (bj.players.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                return _buildTable(bj);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(BlackjackProvider bj) {
    final dealer = bj.dealer;
    final others = bj.activePlayers.where((p) => !p.isLocal).toList();
    final localP = bj.activePlayers.where((p) => p.isLocal).toList();
    final isWaiting = bj.phase == BlackjackPhase.waiting;
    final isBetting = bj.phase == BlackjackPhase.betting;
    final isPlayerTurn = bj.phase == BlackjackPhase.playerTurn;
    final isRoundEnd = bj.phase == BlackjackPhase.roundEnd;

    return Column(
      children: [
        // Header bar
        _buildHeader(bj),

        // Dealer area
        if (dealer != null) _buildDealerArea(dealer, bj),

        // Table rules (only during betting)
        if (isBetting && others.isEmpty) _buildTableRules(),

        // Waiting room
        if (isWaiting) Expanded(child: _buildWaitingRoom(bj)),

        // Other players (horizontal scroll)
        if (!isWaiting && others.isNotEmpty) _buildOtherPlayersRow(others, bj),

        // Result message
        if (bj.message != null && isRoundEnd) _buildResultBanner(bj),

        // Spacer
        if (!isWaiting) const Spacer(),

        // Local player area
        if (!isWaiting && localP.isNotEmpty) _buildLocalPlayerArea(localP.first, bj),

        // Controls
        if (isBetting && localP.isNotEmpty) _buildBettingControls(localP.first, bj),
        if (isPlayerTurn && localP.isNotEmpty) _buildActionButtons(localP.first, bj),
        if (isRoundEnd && bj.isHost) _buildNewRoundButton(bj),

        SizedBox(height: 8 * _s),
      ],
    );
  }

  // ─── HEADER ──────────────────────────────────────────────

  Widget _buildHeader(BlackjackProvider bj) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 4 * _s),
      child: Row(
        children: [
          GestureDetector(
            onTap: _confirmExit,
            child: Container(
              padding: EdgeInsets.all(6 * _s),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8 * _s),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white70, size: 22 * _s),
            ),
          ),
          SizedBox(width: 12 * _s),
          Icon(Icons.style, color: Colors.amber.withOpacity(0.6), size: 18 * _s),
          SizedBox(width: 4 * _s),
          Text(
            'Mazo: ${bj.state.deck.length}',
            style: TextStyle(color: Colors.white38, fontSize: 11 * _s),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10 * _s, vertical: 4 * _s),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12 * _s),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Text(
              '♠ BLACKJACK',
              style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 11 * _s, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ─── DEALER AREA ─────────────────────────────────────────

  Widget _buildDealerArea(BlackjackPlayer dealer, BlackjackProvider bj) {
    final showAll = bj.phase == BlackjackPhase.dealerTurn || bj.phase == BlackjackPhase.roundEnd;
    final hand = dealer.hands.isEmpty ? BlackjackHand() : dealer.hands[0];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 4 * _s),
      padding: EdgeInsets.symmetric(horizontal: 12 * _s, vertical: 8 * _s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12 * _s),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dealer label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, color: Colors.redAccent, size: 16 * _s),
              SizedBox(width: 4 * _s),
              Text('DEALER', style: TextStyle(color: Colors.redAccent, fontSize: 13 * _s, fontWeight: FontWeight.bold, letterSpacing: 1)),
              if (showAll && hand.cards.isNotEmpty) ...[
                SizedBox(width: 8 * _s),
                _handValueBadge(hand.handValue, hand.isBusted),
              ] else if (hand.cards.isNotEmpty) ...[
                SizedBox(width: 8 * _s),
                Text('${_singleCardValue(hand)} + ?', style: TextStyle(color: Colors.white54, fontSize: 11 * _s)),
              ],
            ],
          ),
          SizedBox(height: 6 * _s),
          // Dealer cards
          if (hand.cards.isNotEmpty) _buildCardRow(hand.cards, dealer.id, 0, showAll, hideSecondCard: !showAll),
          if (hand.isBlackjack && showAll)
            Padding(
              padding: EdgeInsets.only(top: 4 * _s),
              child: Text('¡BLACKJACK!', style: TextStyle(color: Colors.amber, fontSize: 14 * _s, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  String _singleCardValue(BlackjackHand hand) {
    if (hand.cards.isEmpty) return '?';
    final v = hand.cards[0].value;
    switch (v) {
      case 'A': return '11';
      case 'K': case 'Q': case 'J': return '10';
      default: return v;
    }
  }

  Widget _handValueBadge(int value, bool isBusted) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 3 * _s),
      decoration: BoxDecoration(
        color: isBusted ? Colors.red.withOpacity(0.6) : Colors.blue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10 * _s),
      ),
      child: Text(
        isBusted ? 'BUST $value' : '$value',
        style: TextStyle(color: Colors.white, fontSize: 12 * _s, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── TABLE RULES ─────────────────────────────────────────

  Widget _buildTableRules() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8 * _s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('BLACKJACK PAGA 3 A 2',
            style: TextStyle(color: Colors.amber.withOpacity(0.25), fontSize: 14 * _s, fontWeight: FontWeight.bold, letterSpacing: 2)),
          SizedBox(height: 2 * _s),
          Text('Crupier se planta en 17  •  5-Card Charlie paga 1:1',
            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10 * _s)),
        ],
      ),
    );
  }

  // ─── WAITING ROOM ────────────────────────────────────────

  Widget _buildWaitingRoom(BlackjackProvider bj) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people, size: 48 * _s, color: Colors.white24),
        SizedBox(height: 8 * _s),
        Text('Esperando jugadores... (${bj.activePlayers.length})',
          style: TextStyle(color: Colors.white54, fontSize: 14 * _s)),
        SizedBox(height: 16 * _s),
        if (widget.isHost && bj.activePlayers.isNotEmpty)
          ElevatedButton(
            onPressed: bj.startMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: EdgeInsets.symmetric(horizontal: 32 * _s, vertical: 14 * _s),
            ),
            child: Text('Iniciar Partida', style: TextStyle(fontSize: 16 * _s, color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        SizedBox(height: 12 * _s),
        ...bj.activePlayers.map((p) => Padding(
          padding: EdgeInsets.symmetric(vertical: 4 * _s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(p.isBot ? Icons.smart_toy : Icons.person,
                color: p.isLocal ? Colors.amber : Colors.white38, size: 18 * _s),
              SizedBox(width: 6 * _s),
              Text(p.name, style: TextStyle(color: p.isLocal ? Colors.amber : Colors.white54, fontSize: 13 * _s)),
              if (p.isBot) Text(' 🤖', style: TextStyle(fontSize: 11 * _s)),
            ],
          ),
        )),
      ],
    );
  }

  // ─── OTHER PLAYERS (HORIZONTAL SCROLL) ───────────────────

  Widget _buildOtherPlayersRow(List<BlackjackPlayer> others, BlackjackProvider bj) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4 * _s),
      height: 165 * _s,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12 * _s),
        itemCount: others.length,
        separatorBuilder: (_, __) => SizedBox(width: 8 * _s),
        itemBuilder: (context, i) {
          final p = others[i];
          return _buildCompactSeat(p, bj);
        },
      ),
    );
  }

  Widget _buildCompactSeat(BlackjackPlayer player, BlackjackProvider bj) {
    final isCurrent = _isCurrentPlayer(player, bj);
    final status = _getPlayerStatus(player, bj);
    final showCards = bj.phase != BlackjackPhase.betting && bj.phase != BlackjackPhase.waiting;
    final hand = player.hands.isNotEmpty ? player.hands[0] : BlackjackHand();

    return PlayerSeatCard(
      name: player.name,
      chipBalance: player.chipBalance,
      cards: hand.cards,
      isFaceUp: showCards,
      currentBet: player.totalBet > 0 ? player.totalBet : null,
      handValue: showCards && hand.cards.isNotEmpty ? hand.handValue : null,
      status: status,
      isLocal: false,
      isCompact: true,
      isCurrentTurn: isCurrent,
      isBot: player.isBot,
      scaleFactor: _s,
    );
  }

  // ─── LOCAL PLAYER AREA ───────────────────────────────────

  Widget _buildLocalPlayerArea(BlackjackPlayer player, BlackjackProvider bj) {
    final isCurrent = _isCurrentPlayer(player, bj);
    final showCards = bj.phase != BlackjackPhase.betting && bj.phase != BlackjackPhase.waiting;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12 * _s),
      padding: EdgeInsets.all(10 * _s),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.amber.withOpacity(0.12) : Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14 * _s),
        border: Border.all(
          color: isCurrent ? Colors.amber : const Color(0xFFD4AF37).withOpacity(0.4),
          width: isCurrent ? 2.5 : 1.0,
        ),
        boxShadow: isCurrent
          ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)]
          : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player info row
          Row(
            children: [
              Text('★', style: TextStyle(color: Colors.amber, fontSize: 16 * _s)),
              SizedBox(width: 4 * _s),
              Text(player.name, style: TextStyle(color: const Color(0xFFD4AF37), fontSize: 15 * _s, fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(Icons.monetization_on, color: Colors.greenAccent, size: 16 * _s),
              SizedBox(width: 4 * _s),
              Text('${player.chipBalance}', style: TextStyle(color: Colors.greenAccent, fontSize: 13 * _s, fontWeight: FontWeight.w600)),
              if (player.totalBet > 0) ...[
                SizedBox(width: 10 * _s),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 3 * _s),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(6 * _s),
                  ),
                  child: Text('Apuesta: ${player.totalBet}',
                    style: TextStyle(color: Colors.white, fontSize: 11 * _s, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          SizedBox(height: 8 * _s),
          // Hands
          if (showCards) ...player.hands.asMap().entries.map((e) {
            final hIdx = e.key;
            final hand = e.value;
            final isActiveHand = hIdx == player.activeHandIndex && isCurrent;
            return _buildLocalHand(player, hIdx, hand, isActiveHand, bj);
          }),
        ],
      ),
    );
  }

  Widget _buildLocalHand(BlackjackPlayer player, int handIdx, BlackjackHand hand, bool isActiveHand, BlackjackProvider bj) {
    if (hand.cards.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 4 * _s),
      padding: EdgeInsets.symmetric(horizontal: 8 * _s, vertical: 6 * _s),
      decoration: BoxDecoration(
        color: isActiveHand ? Colors.amber.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8 * _s),
        border: isActiveHand ? Border.all(color: Colors.amber.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          // Split hand indicator
          if (player.hands.length > 1)
            SizedBox(
              width: 24 * _s,
              child: Text('M${handIdx + 1}', style: TextStyle(color: Colors.white38, fontSize: 10 * _s)),
            ),
          // Cards
          Expanded(child: _buildCardRow(hand.cards, player.id, handIdx, true)),
          SizedBox(width: 8 * _s),
          // Hand value
          _handValueBadge(hand.handValue, hand.isBusted),
          if (hand.isBlackjack)
            Padding(
              padding: EdgeInsets.only(left: 4 * _s),
              child: Text('BJ!', style: TextStyle(color: Colors.amber, fontSize: 12 * _s, fontWeight: FontWeight.bold)),
            ),
          if (hand.isCharlie)
            Padding(
              padding: EdgeInsets.only(left: 4 * _s),
              child: Text('5CC!', style: TextStyle(color: Colors.green, fontSize: 12 * _s, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ─── CARD ROW (reusable) ─────────────────────────────────

  Widget _buildCardRow(List<Object?> cards, String playerId, int handIdx, bool showFace, {bool hideSecondCard = false}) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final cardScale = 0.55 * _s;
    final overlap = 22.0 * _s;
    final cardW = 65.0 * cardScale;

    return SizedBox(
      height: 92 * cardScale,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: cardW + (cards.length - 1) * overlap,
          child: Stack(
            clipBehavior: Clip.none,
            children: cards.asMap().entries.map((e) {
              final idx = e.key;
              final faceUp = showFace && !(hideSecondCard && idx == 1);
              return Positioned(
                left: idx * overlap,
                child: SizedBox(
                  width: cardW,
                  height: 92 * cardScale,
                  child: _AnimatedSlideIn(
                    controller: _animFor('$playerId-${handIdx}_$idx'),
                    card: e.value,
                    scale: cardScale,
                    faceUp: faceUp,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─── BETTING CONTROLS ────────────────────────────────────

  Widget _buildBettingControls(BlackjackPlayer player, BlackjackProvider bj) {
    final maxBet = player.chipBalance.toDouble();
    if (maxBet <= 0) return const SizedBox.shrink();
    _betSliderValue = _betSliderValue.clamp(10, maxBet);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12 * _s, vertical: 6 * _s),
      padding: EdgeInsets.all(12 * _s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16 * _s),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('APUESTA', style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 11 * _s, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          SizedBox(height: 4 * _s),
          // Amount display
          Text(
            '\$${_betSliderValue.round()}',
            style: TextStyle(color: Colors.amber, fontSize: 28 * _s, fontWeight: FontWeight.bold),
          ),
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.amber,
              inactiveTrackColor: Colors.amber.withOpacity(0.2),
              thumbColor: Colors.amber,
              overlayColor: Colors.amber.withOpacity(0.2),
              trackHeight: 4 * _s,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10 * _s),
            ),
            child: Slider(
              min: 10,
              max: maxBet,
              divisions: ((maxBet - 10) / 10).round().clamp(1, 100),
              value: _betSliderValue,
              onChanged: (v) => setState(() => _betSliderValue = (v / 10).round() * 10.0),
            ),
          ),
          // Quick bet buttons
          Wrap(
            spacing: 6 * _s,
            runSpacing: 4 * _s,
            alignment: WrapAlignment.center,
            children: [25, 50, 100, 200, 500].where((v) => v <= maxBet).map((amt) => _quickBetChip(amt, player, bj)).toList(),
          ),
          SizedBox(height: 8 * _s),
          // Deal button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => bj.placeBet(player.id, _betSliderValue.round()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                padding: EdgeInsets.symmetric(vertical: 12 * _s),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10 * _s)),
              ),
              child: Text('APOSTAR', style: TextStyle(fontSize: 16 * _s, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickBetChip(int amount, BlackjackPlayer player, BlackjackProvider bj) {
    final canAfford = player.chipBalance >= amount;
    return GestureDetector(
      onTap: canAfford ? () => setState(() => _betSliderValue = amount.toDouble()) : null,
      child: Container(
        width: 48 * _s,
        height: 32 * _s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: canAfford ? Colors.amber.shade800 : Colors.grey.shade700,
          borderRadius: BorderRadius.circular(16 * _s),
          border: _betSliderValue.round() == amount
            ? Border.all(color: Colors.white, width: 2)
            : null,
        ),
        child: Text('\$$amount', style: TextStyle(color: Colors.white, fontSize: 11 * _s, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── ACTION BUTTONS ──────────────────────────────────────

  Widget _buildActionButtons(BlackjackPlayer player, BlackjackProvider bj) {
    final isCurrent = _isCurrentPlayer(player, bj);
    if (!isCurrent) return const SizedBox.shrink();

    final hand = player.currentHand;
    final canDouble = hand.cards.length == 2 && !hand.isDoubledDown && player.chipBalance >= hand.betAmount;
    final canSplit = player.canSplit && player.chipBalance >= hand.betAmount;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12 * _s, vertical: 6 * _s),
      padding: EdgeInsets.symmetric(horizontal: 12 * _s, vertical: 10 * _s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14 * _s),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(child: _actionButton('PEDIR', Icons.add_card, Colors.green.shade700, () => bj.hit(player.id))),
          SizedBox(width: 6 * _s),
          Expanded(child: _actionButton('PLANTAR', Icons.pan_tool, Colors.red.shade700, () => bj.stand(player.id))),
          if (canDouble) ...[
            SizedBox(width: 6 * _s),
            Expanded(child: _actionButton('DOBLAR', Icons.double_arrow, Colors.orange.shade700, () => bj.doubleDown(player.id))),
          ],
          if (canSplit) ...[
            SizedBox(width: 6 * _s),
            Expanded(child: _actionButton('DIVIDIR', Icons.call_split, Colors.blue.shade700, () => bj.splitPair(player.id))),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(10 * _s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10 * _s),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10 * _s),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20 * _s),
              SizedBox(height: 2 * _s),
              Text(label, style: TextStyle(color: Colors.white, fontSize: 10 * _s, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── NEW ROUND BUTTON ────────────────────────────────────

  Widget _buildNewRoundButton(BlackjackProvider bj) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12 * _s, vertical: 6 * _s),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: bj.newRound,
          icon: Icon(Icons.replay, size: 20 * _s),
          label: Text('Nueva Ronda', style: TextStyle(fontSize: 16 * _s, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 14 * _s),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * _s)),
          ),
        ),
      ),
    );
  }

  // ─── RESULT BANNER ───────────────────────────────────────

  Widget _buildResultBanner(BlackjackProvider bj) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16 * _s, vertical: 6 * _s),
      padding: EdgeInsets.all(12 * _s),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12 * _s),
        border: Border.all(color: Colors.amber, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.15), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: Text(
        bj.message!,
        style: TextStyle(color: Colors.amber, fontSize: 13 * _s, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────

  bool _isCurrentPlayer(BlackjackPlayer player, BlackjackProvider bj) {
    if (bj.phase != BlackjackPhase.playerTurn) return false;
    final active = bj.activePlayers;
    if (active.isEmpty || bj.currentPlayerIndex >= active.length) return false;
    return active[bj.currentPlayerIndex].id == player.id;
  }

  PlayerSeatStatus _getPlayerStatus(BlackjackPlayer player, BlackjackProvider bj) {
    if (bj.phase == BlackjackPhase.waiting || bj.phase == BlackjackPhase.betting) return PlayerSeatStatus.waiting;
    final hand = player.hands.isNotEmpty ? player.hands[0] : null;
    if (hand == null) return PlayerSeatStatus.waiting;
    if (hand.isBusted) return PlayerSeatStatus.busted;
    if (hand.isBlackjack) return PlayerSeatStatus.blackjack;
    if (hand.isCharlie) return PlayerSeatStatus.charlie;
    if (hand.isStanding) return PlayerSeatStatus.standing;
    if (_isCurrentPlayer(player, bj)) return PlayerSeatStatus.active;
    return PlayerSeatStatus.waiting;
  }
}

// ─── ANIMATED CARD SLIDE-IN ──────────────────────────────

class _AnimatedSlideIn extends StatelessWidget {
  final dynamic card;
  final double scale;
  final AnimationController controller;
  final bool faceUp;
  const _AnimatedSlideIn({required this.controller, required this.card, required this.scale, this.faceUp = true});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -25 * (1 - Curves.easeOutBack.transform(controller.value))),
          child: Opacity(opacity: controller.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: faceUp
        ? Image.asset(card.assetPath, width: 65 * scale, height: 92 * scale, fit: BoxFit.cover)
        : Image.asset('assets/images/cards/cardBack_red5.png', width: 65 * scale, height: 92 * scale, fit: BoxFit.cover),
    );
  }
}
