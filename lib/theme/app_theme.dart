import 'package:flutter/material.dart';

/// Paleta e tokens visuais centralizados, inspirados no visual "engine
/// profissional" do Blender/Godot: cinzas frios escuros, painéis planos
/// sem sombras pesadas, um único acento de cor para foco/seleção.
///
/// REGRA: nenhum widget da UI deve escrever um `Color(0x...)` solto —
/// tudo referencia [AppTheme]. Isso mantém a interface consistente e
/// fácil de retemperar (ex: criar um tema "claro" no futuro).
class AppTheme {
  AppTheme._();

  // Escala de cinzas (do mais escuro ao mais claro).
  static const Color bg0 = Color(0xFF16171B); // fundo do canvas 3D/mapa
  static const Color bg1 = Color(0xFF1C1E24); // fundo geral da janela
  static const Color bg2 = Color(0xFF23252C); // painéis (toolbar, sidebar)
  static const Color bg3 = Color(0xFF2B2E37); // cards/itens dentro de painéis
  static const Color bg4 = Color(0xFF363944); // hover/estado ativo

  static const Color border = Color(0xFF3A3D47);
  static const Color borderSubtle = Color(0xFF2A2C34);

  static const Color textPrimary = Color(0xFFE7E8EC);
  static const Color textSecondary = Color(0xFF9A9DA8);
  static const Color textDisabled = Color(0xFF5C5F6A);

  /// Acento único (laranja Blender-esque) — usado para ferramenta ativa,
  /// seleção e ações primárias.
  static const Color accent = Color(0xFFFF8A3D);
  static const Color accentMuted = Color(0x33FF8A3D);

  static const Color success = Color(0xFF63D471);
  static const Color danger = Color(0xFFE5484D);
  static const Color info = Color(0xFF4FA3E3);

  static const double radiusSm = 4;
  static const double radiusMd = 8;

  static ThemeData themeData() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg1,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: bg2,
        error: danger,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      dividerColor: border,
      iconTheme: const IconThemeData(color: textSecondary, size: 20),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: bg4,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: border),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: bg3,
          foregroundColor: textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            side: const BorderSide(color: border),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: bg2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg1,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: accent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accentMuted : bg3,
        ),
      ),
    );
  }
}

