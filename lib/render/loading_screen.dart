import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_preferences.dart';
import '../core/language_controller.dart';
import '../init.dart';
import '../theme/app_theme.dart';

class LoadingScreen extends StatefulWidget {
  final BootOrchestrator orchestrator;
  final LanguageController lang;
  final VoidCallback onTeardownComplete;

  const LoadingScreen({
    super.key,
    required this.orchestrator,
    required this.lang,
    required this.onTeardownComplete,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _teardownController;
  final FocusNode _focusNode = FocusNode();
  bool _isTearingDown = false;
  File? _logoFile;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _teardownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _teardownController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onTeardownComplete();
      }
    });

    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final dir = await getEngineDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}logo${Platform.pathSeparator}icon-mapeditor.webp');
    if (await file.exists() && mounted) {
      setState(() {
        _logoFile = file;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _teardownController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTeardown() {
    if (!widget.orchestrator.isFinished || _isTearingDown) return;
    setState(() {
      _isTearingDown = true;
    });
    _teardownController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          _startTeardown();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _startTeardown,
        child: AnimatedBuilder(
          animation: _teardownController,
          builder: (context, child) {
            final double teardownValue = _teardownController.value;
            // 0.0 -> 0.7: A Logo e os textos desvanecem suavemente
            final double contentOpacity = 1.0 - (teardownValue / 0.7).clamp(0.0, 1.0);
            
            // 0.7 -> 1.0: O Fundo preto desvanece rapidamente para revelar o MapEditor
            final double bgOpacity = teardownValue < 0.7 
                ? 1.0 
                : 1.0 - ((teardownValue - 0.7) / 0.3).clamp(0.0, 1.0);

            return Opacity(
              opacity: bgOpacity,
              child: Container(
                color: AppTheme.bg0,
                child: Opacity(
                  opacity: contentOpacity,
                  child: _buildContent(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo da Engine
          if (_logoFile != null)
            Image.file(
              _logoFile!,
              width: 104,
              height: 104,
              filterQuality: FilterQuality.medium,
            )
          else
            const Icon(Icons.map_outlined, color: AppTheme.accent, size: 96),
          
          const SizedBox(height: 24),
          
          // Nome do App vindo do JSON de linguagem
          Text(
            widget.lang.get('app_name'),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          
          const SizedBox(height: 56),

          SizedBox(
            width: 400,
            height: 60, // Travado para a tela não dar solavanco ao trocar da barra pro texto.
            child: widget.orchestrator.isFinished
                ? _buildProceedState()
                : _buildLoadingState(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final progress = widget.orchestrator.currentStep / widget.orchestrator.totalSteps;
    final statusKey = widget.orchestrator.currentLoadingKey;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // A Barra Honesta
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.bg3,
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(color: AppTheme.accentMuted, blurRadius: 10)
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // O Texto Exato
        Text(
          statusKey.isNotEmpty ? widget.lang.get(statusKey) : '',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProceedState() {
    return Center(
      child: FadeTransition(
        opacity: _pulseController,
        child: Text(
          widget.lang.get('boot_press_any_key'),
          style: const TextStyle(
            color: AppTheme.success,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}