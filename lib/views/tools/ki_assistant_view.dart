import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/edge_api.dart';
import '../../services/insights_controller.dart';

class KiAssistantView extends StatefulWidget {
  const KiAssistantView({required this.controller, super.key});

  final InsightsController controller;

  @override
  State<KiAssistantView> createState() => _KiAssistantViewState();
}

class _KiAssistantViewState extends State<KiAssistantView> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final EdgeApi _edgeApi;
  final List<Map<String, String>> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _edgeApi = EdgeApi.fromInitialized();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    final insights = widget.controller.insights;
    if (text.isEmpty || insights == null || _isSending) {
      return;
    }
    if (text.length > 4000) {
      _showMessage('Die Nachricht darf höchstens 4.000 Zeichen lang sein.');
      return;
    }

    _inputController.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isSending = true;
    });
    try {
      final contextMessages = _messages.length > 20
          ? _messages.sublist(_messages.length - 20)
          : List<Map<String, String>>.of(_messages);
      final answer = await _edgeApi.askAssistant(
        messages: contextMessages,
      );
      if (mounted) {
        setState(() => _messages.add({
              'role': 'assistant',
              'content': answer,
            }));
        _scrollToBottom();
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Die Anfrage ist fehlgeschlagen: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final insights = widget.controller.insights;
        return Scaffold(
          appBar: AppBar(title: const Text('KI-Assistent')),
          body: Column(
            children: [
              if (insights == null)
                MaterialBanner(
                  content: const Text(
                    'Verbinde zuerst dein Instagram-Konto, damit der Assistent mit aktuellen Insights antworten kann.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Zurück'),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: const Icon(Icons.insights, size: 18),
                      label: Text(
                        'Kontext: @${insights.username.isEmpty ? 'Instagram' : insights.username} · ${NumberFormat.decimalPattern().format(insights.followerCount)} Follower',
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Stelle eine Frage zu deiner Reichweite, deinen Impressionen oder deinen Beiträgen.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUser = message['role'] == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 680),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SelectableText(
                                message['content']!,
                                style: isUser
                                    ? TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_isSending) const LinearProgressIndicator(minHeight: 2),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          enabled: insights != null && !_isSending,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 4000,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Frage deine Insights …',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Senden',
                        onPressed:
                            insights == null || _isSending ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
