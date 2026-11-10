part of '../top_bar.dart';

class _PropAngleControl extends StatefulWidget {
  final PropModel prop;
  final PropsController propsController;

  const _PropAngleControl({
    required this.prop,
    required this.propsController,
  });

  @override
  State<_PropAngleControl> createState() => _PropAngleControlState();
}

class _PropAngleControlState extends State<_PropAngleControl> {
  late double _angle;
  late TextEditingController _textController;
  
  double? _panStartPropRotation;
  List<Offset>? _panStartCorners;
  List<Offset>? _panStartMesh;

  @override
  void initState() {
    super.initState();
    _angle = widget.prop.rotation;
    _textController = TextEditingController(text: '${_angle.round()}');
  }

  @override
  void didUpdateWidget(covariant _PropAngleControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_panStartCorners == null && oldWidget.prop.rotation != widget.prop.rotation) {
      _angle = widget.prop.rotation;
      final roundedStr = '${_angle.round()}';
      if (_textController.text != roundedStr) {
        _textController.text = roundedStr;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onDialPanStart(Offset localPos, Size size) {
    widget.propsController.recordSnapshot();
    _panStartPropRotation = widget.prop.rotation;
    _panStartCorners = List.of(widget.prop.corners);
    _panStartMesh = List.of(widget.prop.mesh);
    _updateAngleFromOffset(localPos, size);
  }

  void _onDialPanUpdate(Offset localPos, Size size) {
    _updateAngleFromOffset(localPos, size);
  }

  void _onDialPanEnd() {
    if (_panStartCorners == null) return;
    final updated = _rotatePropFromBase(_angle);
    widget.propsController.updateProp(updated, saveToDisk: true);
    _panStartCorners = null;
    _panStartMesh = null;
    _panStartPropRotation = null;
  }

  void _updateAngleFromOffset(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final vx = localPos.dx - center.dx;
    final vy = localPos.dy - center.dy;

    double deg = math.atan2(vx, -vy) * 180 / math.pi;
    deg = deg.roundToDouble();

    if (deg == _angle) return;

    setState(() {
      _angle = deg;
    });

    final roundedStr = '${deg.round()}';
    if (_textController.text != roundedStr) {
      _textController.text = roundedStr;
    }

    final updated = _rotatePropFromBase(deg);
    widget.propsController.updateProp(updated, saveToDisk: false);
  }

  PropModel _rotatePropFromBase(double targetAngleDeg) {
    if (_panStartCorners == null || _panStartMesh == null || _panStartPropRotation == null) {
      return widget.prop.withRotation(targetAngleDeg);
    }

    final deltaDeg = targetAngleDeg - _panStartPropRotation!;
    if (deltaDeg == 0.0) return widget.prop;

    final alpha = deltaDeg * math.pi / 180.0;
    final cosA = math.cos(alpha);
    final sinA = math.sin(alpha);

    final cx = (_panStartCorners![0].dx + _panStartCorners![1].dx + _panStartCorners![2].dx + _panStartCorners![3].dx) / 4.0;
    final cy = (_panStartCorners![0].dy + _panStartCorners![1].dy + _panStartCorners![2].dy + _panStartCorners![3].dy) / 4.0;

    Offset rotatePt(Offset p) {
      final dx = p.dx - cx;
      final dy = p.dy - cy;
      return Offset(
        cx + dx * cosA - dy * sinA,
        cy + dx * sinA + dy * cosA,
      );
    }

    final newCorners = _panStartCorners!.map(rotatePt).toList();
    final newMesh = _panStartMesh!.map(rotatePt).toList();

    return widget.prop.copyWith(
      rotation: targetAngleDeg,
      corners: newCorners,
      mesh: newMesh,
    );
  }

  void _applyTextAngle(String val) {
    final clean = val.replaceAll('°', '').trim();
    if (clean.isEmpty || clean == '-') {
      _textController.text = '${_angle.round()}';
      return;
    }

    final parsed = double.tryParse(clean);
    if (parsed != null) {
      double normalized = parsed % 360;
      if (normalized > 180) normalized -= 360;
      if (normalized < -180) normalized += 360;
      normalized = normalized.roundToDouble();

      setState(() {
        _angle = normalized;
        _textController.text = '${normalized.round()}';
      });

      widget.propsController.recordSnapshot();
      final updated = widget.prop.withRotation(normalized);
      widget.propsController.updateProp(updated, saveToDisk: true);
    } else {
      _textController.text = '${_angle.round()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    const dialSize = Size(28, 28);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onPanStart: (details) => _onDialPanStart(details.localPosition, dialSize),
            onPanUpdate: (details) => _onDialPanUpdate(details.localPosition, dialSize),
            onPanEnd: (_) => _onDialPanEnd(),
            child: CustomPaint(
              size: dialSize,
              painter: _DialPainter(
                angleDeg: _angle,
                borderColor: AppTheme.textSecondary.withValues(alpha: 0.6),
                needleColor: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        Container(
          width: 54,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.bg1,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _textController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*')),
              LengthLimitingTextInputFormatter(5),
            ],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
            onSubmitted: _applyTextAngle,
            onTapOutside: (_) {
              _applyTextAngle(_textController.text);
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        const SizedBox(width: 4),
        const Text('°', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  final double angleDeg;
  final Color borderColor;
  final Color needleColor;

  _DialPainter({
    required this.angleDeg,
    required this.borderColor,
    required this.needleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final circlePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, circlePaint);

    final rad = (angleDeg - 90) * math.pi / 180;
    final needleEnd = Offset(
      center.dx + radius * math.cos(rad),
      center.dy + radius * math.sin(rad),
    );

    final needlePaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(center, needleEnd, needlePaint);

    final dotPaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(needleEnd, 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      angleDeg != oldDelegate.angleDeg ||
      borderColor != oldDelegate.borderColor ||
      needleColor != oldDelegate.needleColor;
}