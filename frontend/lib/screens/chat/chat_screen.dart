// lib/screens/chat/chat_screen.dart
//
// FIX: _send() only handled click_recorded / click_unresolved / recommendations.
// The backend's new `status: "smalltalk"` (hello / thanks / bye / help) fell
// into the final else-branch, saw an empty recommendations list, and showed a
// hardcoded "Couldn't find anything matching that" message. It now:
//   1. handles status == 'smalltalk' and shows the backend's `message`
//   2. for any other empty-results response, prefers the backend `message`
//      over the hardcoded fallback text.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/places_provider.dart';
import '../../services/api_client.dart';
import '../../utils/app_theme.dart';
import '../../models/place_model.dart';
import '../home/restaurant_detail_page.dart';

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
      } else if (status == 'smalltalk') {
        // NEW: greeting / thanks / bye / help answered directly by the backend.
        final msg = result['message'] as String? ??
            "Hey! What are you craving today?";
        setState(() => _messages.add(ChatMessage.botText(msg)));
      } else {
        final recsRaw = (result['recommendations'] as List?) ?? [];
        if (recsRaw.isEmpty) {
          // Prefer the backend's message if it sent one.
          final msg = result['message'] as String? ??
              "Couldn't find anything matching that — try widening your "
                  "budget or a different cuisine?";
          setState(() => _messages.add(ChatMessage.botText(msg)));
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
    final scheme = Theme.of(context).colorScheme;

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

    // Bot bubble uses the theme's surface color (white card in light mode,
    // dark card in dark mode). User bubble stays on brand primary either way.
    final bubbleColor = isUser ? AppTheme.primary : scheme.surface;
    final textColor = isUser ? Colors.white : scheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          message.text ?? '',
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }
}

// Card follows the active theme and is wrapped in an InkWell so tapping it
// opens RestaurantDetailPage. The "I like this" button keeps its own
// onPressed, which works independently of the outer tap.
class _RecommendationCard extends StatelessWidget {
  final ChatRecommendation rec;
  final VoidCallback onLike;

  const _RecommendationCard({required this.rec, required this.onLike});

  void _openDetail(BuildContext context) {
    final place = PlaceModel(
      name: rec.name,
      cuisine: rec.cuisine,
      price: rec.price.toInt(),
      rating: rec.rating,
      score: 0.0,
      whyRecommended: rec.explanation ?? '',
      city: context.read<PlacesProvider>().currentCity,
      lat: null,
      lng: null,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailPage(place: place, rank: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onSurface = scheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openDetail(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: onSurface,
                    ),
                  ),
                ),
                Text(
                  '₹${rec.price.toStringAsFixed(0)}',
                  style: TextStyle(color: onSurface),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${rec.cuisine} · ⭐ ${rec.rating.toStringAsFixed(1)}',
              style: TextStyle(color: onSurface.withOpacity(0.7), fontSize: 11),
            ),
            if (rec.explanation != null && rec.explanation!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                rec.explanation!,
                style: TextStyle(color: onSurface.withOpacity(0.55), fontSize: 11),
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
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
                style: TextStyle(color: onSurface),
                decoration: InputDecoration(
                  hintText: 'Ask for a recommendation…',
                  hintStyle: TextStyle(color: onSurface.withOpacity(0.4)),
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