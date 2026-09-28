import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/places_provider.dart';
import '../../services/api_client.dart';
import '../../utils/app_theme.dart';

enum ChatSender { user, bot }

class ChatRecommendation {
  final String name;
  final String cuisine;
  final double rating;
  final double price;
  final String? explanation;
  final String? imageUrl;

  ChatRecommendation({
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.price,
    this.explanation,
    this.imageUrl,
  });

  factory ChatRecommendation.fromJson(Map<String, dynamic> j) {
    return ChatRecommendation(
      name: j['name'] as String? ?? '',
      cuisine: j['cuisine'] as String? ?? '',
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      price: (j['price'] as num?)?.toDouble() ?? 0,
      explanation:
          (j['llm_explanation'] as String?) ?? (j['why_recommended'] as String?),
      imageUrl: j['image_url'] as String?,
    );
  }
}

class ChatMessage {
  final ChatSender sender;
  final String? text;
  final List<ChatRecommendation>? recommendations;

  ChatMessage.user(this.text)
      : sender = ChatSender.user,
        recommendations = null;

  ChatMessage.botText(this.text)
      : sender = ChatSender.bot,
        recommendations = null;

  ChatMessage.botRecommendations(this.recommendations)
      : sender = ChatSender.bot,
        text = null;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage.botText(
        "Hey! Tell me what you're craving and I'll find something for you. "
        "Try a follow-up too — 'cheaper option?' or 'the first one, I loved it!' "
        "after I show results.",
      ),
    );
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isSending) return;

    final places = context.read<PlacesProvider>();

    setState(() {
      _messages.add(ChatMessage.user(text));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final username = places.userName.isNotEmpty
          ? places.userName
          : await ApiClient.getUsername();

      final result = await ApiClient.converse(
        username: username,
        query: text,
        city: places.currentCity,
        budget: places.budget,
        userLat: places.userLat,
        userLng: places.userLng,
      );

      if (!mounted) return;

      final status = result['status'] as String?;

      if (status == 'click_recorded') {
        final name = result['clicked_name'] as String? ?? 'that one';
        setState(() => _messages.add(
              ChatMessage.botText("Nice pick — saved your interest in $name!"),
            ));
      } else if (status == 'click_unresolved') {
        final msg = result['message'] as String? ??
            "Couldn't match that to a restaurant from the last results — "
                "could you name it directly?";
        setState(() => _messages.add(ChatMessage.botText(msg)));
      } else {
        final recsRaw = (result['recommendations'] as List?) ?? [];
        if (recsRaw.isEmpty) {
          setState(() => _messages.add(
                ChatMessage.botText(
                  "Couldn't find anything matching that — try widening your "
                  "budget or a different cuisine?",
                ),
              ));
        } else {
          final recs = recsRaw
              .map((e) =>
                  ChatRecommendation.fromJson(e as Map<String, dynamic>))
              .toList();
          setState(() => _messages.add(ChatMessage.botRecommendations(recs)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(
            ChatMessage.botText("Something went wrong — ${e.toString()}"),
          ));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _onRecommendationLiked(ChatRecommendation rec) =>
      _send("I really liked ${rec.name}!");

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask GeoTaste')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return const _TypingBubble();
                return _MessageBubble(
                  message: _messages[index],
                  onLike: _onRecommendationLiked,
                );
              },
            ),
          ),
          _ChatInputBar(
            controller: _controller,
            enabled: !_isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(ChatRecommendation) onLike;

  const _MessageBubble({required this.message, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ChatSender.user;

    if (message.recommendations != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: message.recommendations!
              .map((rec) => _RecommendationCard(
                    rec: rec,
                    onLike: () => onLike(rec),
                  ))
              .toList(),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: AppTheme.glassStroke),
        ),
        child: Text(
          message.text ?? '',
          style: TextStyle(color: isUser ? Colors.white : AppTheme.textPrimary),
        ),
      ),
    );
  }
}

// NOTE: this card's background (AppTheme.bgCard) is always dark, by design —
// it does NOT follow the light/dark theme toggle. So every text style inside
// it must use the fixed AppTheme text colors (textPrimary/textSecondary/textMuted),
// never Theme.of(context), or it goes invisible when the app is in light mode.
class _RecommendationCard extends StatelessWidget {
  final ChatRecommendation rec;
  final VoidCallback onLike;

  const _RecommendationCard({required this.rec, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rec.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                rec.imageUrl!,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  rec.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '₹${rec.price.toStringAsFixed(0)}',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${rec.cuisine} · ⭐ ${rec.rating.toStringAsFixed(1)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          if (rec.explanation != null && rec.explanation!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rec.explanation!,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onLike,
              icon: const Icon(Icons.favorite_border, size: 16, color: AppTheme.primary),
              label: const Text('I like this', style: TextStyle(color: AppTheme.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassStroke),
        ),
        child: const SizedBox(
          width: 20,
          height: 14,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onSend;

  const _ChatInputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(top: BorderSide(color: AppTheme.glassStroke)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask for a recommendation…',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: AppTheme.primary),
              onPressed: enabled ? () => onSend(controller.text) : null,
            ),
          ],
        ),
      ),
    );
  }
}