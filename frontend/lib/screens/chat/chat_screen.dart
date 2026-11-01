// lib/screens/chat/chat_screen.dart
//
// FIX (history lost on back): the messages list used to live inside
// _ChatScreenState, so leaving the screen disposed it and re-opening started
// a fresh chat with only the greeting. History now lives in ChatHistoryStore,
// an app-wide singleton (ChangeNotifier) that outlives the screen:
//   - re-opening the screen shows the earlier conversation
//   - a reply that arrives after you left the screen is still saved
//   - the "sending" flag is shared too, so the typing bubble is correct
//   - "New chat" button (app bar) clears it
// It is in-memory only: a full app restart still starts a fresh chat.
// Call ChatHistoryStore.instance.clear() on logout so the next user doesn't
// see the previous user's chat.
//
// Earlier fix kept: status == 'smalltalk' shows the backend `message`, and any
// empty-results response prefers the backend `message` over hardcoded text.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/places_provider.dart';
import '../../services/api_client.dart';
import '../../utils/app_theme.dart';
import '../../models/place_model.dart';
import '../home/restaurant_detail_page.dart';
import '../../widgets/restaurant_card.dart';

enum ChatSender { user, bot }

class ChatRecommendation {
  final String name;
  final String cuisine;
  final double rating;
  final double price;
  final String? explanation;
  final String? imageUrl;
  // Full backend JSON for this restaurant (score, sim_score, rating_score,
  // budget_score, ...). Kept so tapping a card can build a complete
  // PlaceModel with real scores instead of zeros.
  final Map<String, dynamic> raw;

  ChatRecommendation({
    required this.name,
    required this.cuisine,
    required this.rating,
    required this.price,
    this.explanation,
    this.imageUrl,
    this.raw = const {},
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
      raw: Map<String, dynamic>.from(j),
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

/// App-wide chat history. Lives outside the screen so it survives the screen
/// being closed and re-opened.
class ChatHistoryStore extends ChangeNotifier {
  ChatHistoryStore._();
  static final ChatHistoryStore instance = ChatHistoryStore._();

  static const String greeting =
      "Hey! Tell me what you're craving and I'll find something for you. "
      "Try a follow-up too — 'cheaper option?' or 'the first one, I loved it!' "
      "after I show results.";

  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;

  /// Seeds the greeting only when there is no history yet. Does not notify
  /// (it is called from initState).
  void ensureGreeting() {
    if (_messages.isEmpty) _messages.add(ChatMessage.botText(greeting));
  }

  void add(ChatMessage m) {
    _messages.add(m);
    notifyListeners();
  }

  void setSending(bool v) {
    _isSending = v;
    notifyListeners();
  }

  /// "New chat" button and logout.
  void clear() {
    _messages
      ..clear()
      ..add(ChatMessage.botText(greeting));
    _isSending = false;
    notifyListeners();
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatHistoryStore _store = ChatHistoryStore.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _store.ensureGreeting();
    _store.addListener(_scrollToBottom);
    // Re-opening the screen: jump to the latest message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController
            .jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _store.isSending) return;

    // Read everything needed from context BEFORE any await. After this point
    // the store is global, so no mounted checks are needed: a reply that lands
    // after the screen was closed is still saved to history.
    final places = context.read<PlacesProvider>();
    final city = places.currentCity;
    final budget = places.budget;
    final userLat = places.userLat;
    final userLng = places.userLng;
    final knownName = places.userName;

    _store.add(ChatMessage.user(text));
    _store.setSending(true);
    _controller.clear();

    try {
      final username =
          knownName.isNotEmpty ? knownName : await ApiClient.getUsername();

      final result = await ApiClient.converse(
        username: username,
        query: text,
        city: city,
        budget: budget,
        userLat: userLat,
        userLng: userLng,
      );

      final status = result['status'] as String?;

      if (status == 'click_recorded') {
        final name = result['clicked_name'] as String? ?? 'that one';
        _store.add(
            ChatMessage.botText("Nice pick — saved your interest in $name!"));
      } else if (status == 'click_unresolved') {
        final msg = result['message'] as String? ??
            "Couldn't match that to a restaurant from the last results — "
                "could you name it directly?";
        _store.add(ChatMessage.botText(msg));
      } else if (status == 'smalltalk') {
        // greeting / thanks / bye / help answered directly by the backend.
        final msg = result['message'] as String? ??
            "Hey! What are you craving today?";
        _store.add(ChatMessage.botText(msg));
      } else {
        final recsRaw = (result['recommendations'] as List?) ?? [];
        if (recsRaw.isEmpty) {
          // Prefer the backend's message if it sent one.
          final msg = result['message'] as String? ??
              "Couldn't find anything matching that — try widening your "
                  "budget or a different cuisine?";
          _store.add(ChatMessage.botText(msg));
        } else {
          final recs = recsRaw
              .map((e) =>
                  ChatRecommendation.fromJson(e as Map<String, dynamic>))
              .toList();
          _store.add(ChatMessage.botRecommendations(recs));
        }
      }
    } catch (e) {
      _store.add(ChatMessage.botText("Something went wrong — ${e.toString()}"));
    } finally {
      _store.setSending(false);
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
    _store.removeListener(_scrollToBottom);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask GeoTaste'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _store.clear,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          final messages = _store.messages;
          final sending = _store.isSending;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length + (sending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) return const _TypingBubble();
                    return _MessageBubble(
                      message: messages[index],
                      onLike: _onRecommendationLiked,
                    );
                  },
                ),
              ),
              _ChatInputBar(
                controller: _controller,
                enabled: !sending,
                onSend: _send,
              ),
            ],
          );
        },
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
      return _RecommendationGrid(
        recs: message.recommendations!,
        onLike: onLike,
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

// Responsive "boxes" layout (Swiggy style): 1 column on narrow screens,
// 2 on medium, 3 on wide. Uses Wrap + fixed card width (instead of GridView)
// so each card can size itself to its text and never overflows.
class _RecommendationGrid extends StatelessWidget {
  final List<ChatRecommendation> recs;
  final void Function(ChatRecommendation) onLike;

  const _RecommendationGrid({required this.recs, required this.onLike});

  void _openDetail(BuildContext context, ChatRecommendation rec) {
    final city = context.read<PlacesProvider>().currentCity;
    PlaceModel place;
    try {
      // Same parser the Discover list and Favourites use, so score and the
      // score breakdown (sim/rating/budget/...) come through properly.
      final json = Map<String, dynamic>.from(rec.raw);
      json.putIfAbsent('city', () => city);
      place = PlaceModel.fromJson(json);
    } catch (_) {
      // Fallback: still carry the real overall score if present.
      place = PlaceModel(
        name: rec.name,
        cuisine: rec.cuisine,
        price: rec.price.toInt(),
        rating: rec.rating,
        score: (rec.raw['score'] as num?)?.toDouble() ?? 0.0,
        whyRecommended: rec.explanation ?? '',
        city: city,
        lat: null,
        lng: null,
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailPage(place: place, rank: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final available = constraints.maxWidth;
        final cols = available >= 900 ? 3 : (available >= 460 ? 2 : 1);
        final cardWidth = (available - spacing * (cols - 1)) / cols;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final rec in recs)
                SizedBox(
                  width: cardWidth,
                  child: RestaurantBoxCard(
                    name: rec.name,
                    cuisine: rec.cuisine,
                    rating: rec.rating,
                    price: rec.price,
                    imageUrl: rec.imageUrl,
                    note: rec.explanation,
                    onTap: () => _openDetail(context, rec),
                    onLike: () => onLike(rec),
                  ),
                ),
            ],
          ),
        );
      },
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