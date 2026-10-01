import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import 'card_widget.dart';

enum PlayerSeatStatus {
  active,
  waiting,
  folded,
  busted,
  standing,
  winner,
  blackjack,
  charlie,
}

class PlayerSeatCard extends StatelessWidget {
  final String name;
  final int chipBalance;
  final List<CardModel> cards;
  final bool isFaceUp;

  final int? currentBet;
  final int? handValue;
  final PlayerSeatStatus status;
  final bool isLocal;
  final bool isCompact;
  final bool isCurrentTurn;
  final List<String> badges;
  final bool isBot;
  final VoidCallback? onTap;
  final double scaleFactor;

  const PlayerSeatCard({
    Key? key,
    required this.name,
    required this.chipBalance,
    required this.cards,
    required this.isFaceUp,
    this.currentBet,
    this.handValue,
    this.status = PlayerSeatStatus.active,
    this.isLocal = false,
    this.isCompact = false,
    this.isCurrentTurn = false,
    this.badges = const [],
    this.isBot = false,
    this.onTap,
    this.scaleFactor = 1.0,
  }) : super(key: key);

  Color _getBackgroundColor() {
    if (status == PlayerSeatStatus.busted || status == PlayerSeatStatus.folded) {
      return Colors.red.withOpacity(0.15);
    }
    if (status == PlayerSeatStatus.winner || status == PlayerSeatStatus.blackjack || status == PlayerSeatStatus.charlie) {
      return const Color(0xFFD4AF37).withOpacity(0.2); // Gold tint
    }
    if (isCurrentTurn) {
      return Colors.amber.withOpacity(0.15);
    }
    return Colors.black.withOpacity(0.35);
  }

  Color _getBorderColor() {
    if (isCurrentTurn) return Colors.amber;
    if (status == PlayerSeatStatus.winner || status == PlayerSeatStatus.blackjack) return const Color(0xFFD4AF37);
    if (status == PlayerSeatStatus.busted) return Colors.red.withOpacity(0.5);
    if (isLocal) return const Color(0xFFD4AF37).withOpacity(0.5);
    return Colors.white24;
  }

  Widget _buildStatusIcon() {
    IconData? icon;
    Color? color;

    switch (status) {
      case PlayerSeatStatus.active:
        icon = Icons.play_circle_filled;
        color = Colors.green;
        break;
      case PlayerSeatStatus.waiting:
        icon = Icons.access_time;
        color = Colors.grey;
        break;
      case PlayerSeatStatus.folded:
        icon = Icons.close;
        color = Colors.red;
        break;
      case PlayerSeatStatus.busted:
        icon = Icons.broken_image;
        color = Colors.red;
        break;
      case PlayerSeatStatus.standing:
        icon = Icons.pan_tool;
        color = Colors.blue;
        break;
      case PlayerSeatStatus.winner:
      case PlayerSeatStatus.blackjack:
      case PlayerSeatStatus.charlie:
        icon = Icons.star;
        color = const Color(0xFFD4AF37);
        break;
    }

    return Icon(icon, size: 12 * scaleFactor, color: color);
  }

  Widget _buildCards() {
    if (cards.isEmpty) return const SizedBox();

    double scale = isCompact ? 0.45 : 0.65;
    double overlap = isCompact ? (20.0 * scaleFactor) : (35.0 * scaleFactor);

    return SizedBox(
      height: 100 * scale * scaleFactor,
      width: (cards.length * overlap) + (50 * scale * scaleFactor), // Rough estimation
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(cards.length, (index) {
          return Positioned(
            left: index * overlap,
            child: CardWidget(
              card: cards[index],
              isFaceUp: isFaceUp,
              scale: scale * scaleFactor,
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isCompact ? (120.0 * scaleFactor) : (200.0 * scaleFactor),
        padding: EdgeInsets.all(8.0 * scaleFactor),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(12 * scaleFactor),
          border: Border.all(
            color: _getBorderColor(),
            width: (isCurrentTurn ? 2.0 : 1.0) * scaleFactor,
          ),
          boxShadow: isCurrentTurn
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 8 * scaleFactor,
                    spreadRadius: 2 * scaleFactor,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Name and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBot) ...[
                  Text('🤖', style: TextStyle(fontSize: 12 * scaleFactor)),
                  SizedBox(width: 4 * scaleFactor),
                ],
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isLocal ? const Color(0xFFD4AF37) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14 * scaleFactor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4 * scaleFactor),
                _buildStatusIcon(),
              ],
            ),
            SizedBox(height: 4 * scaleFactor),
            
            // Chips
            Text(
              '\$${chipBalance.toString()}',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12 * scaleFactor,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            // Badges
            if (badges.isNotEmpty) ...[
              SizedBox(height: 4 * scaleFactor),
              Wrap(
                spacing: 4 * scaleFactor,
                children: badges.map((badge) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 4 * scaleFactor, vertical: 2 * scaleFactor),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4 * scaleFactor),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 10 * scaleFactor, color: Colors.white),
                  ),
                )).toList(),
              ),
            ],

            SizedBox(height: 8 * scaleFactor),

            // Cards
            _buildCards(),

            // Hand Value & Bet (Expanded or Specific needs)
            if (handValue != null || currentBet != null) ...[
              SizedBox(height: 8 * scaleFactor),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (handValue != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6 * scaleFactor, vertical: 2 * scaleFactor),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8 * scaleFactor),
                      ),
                      child: Text(
                        handValue.toString(),
                        style: TextStyle(color: Colors.white, fontSize: 12 * scaleFactor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (!isCompact && currentBet != null)
                    Text(
                      'Apuesta: \$$currentBet',
                      style: TextStyle(color: Colors.amber, fontSize: 12 * scaleFactor),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
