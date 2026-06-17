import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for Delhi Nights Food Delivery Ecosystem
/// Provides consistent design language across all apps in the ecosystem
class DesignTokens {
  // Private constructor to prevent instantiation
  DesignTokens._();

  /// Brand Colors
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color primaryOrange = Color(0xFFFF5722);
  static const Color secondaryGold = Color(0xFFFFB300);
  static const Color accentSpice = Color(0xFFE65100);
  
  /// Neutral Colors
  static const Color neutralWhite = Color(0xFFFFFFFF);
  static const Color neutralGrey50 = Color(0xFFFAFAFA);
  static const Color neutralGrey100 = Color(0xFFF5F5F5);
  static const Color neutralGrey200 = Color(0xFFEEEEEE);
  static const Color neutralGrey300 = Color(0xFFE0E0E0);
  static const Color neutralGrey400 = Color(0xFFBDBDBD);
  static const Color neutralGrey500 = Color(0xFF9E9E9E);
  static const Color neutralGrey600 = Color(0xFF757575);
  static const Color neutralGrey700 = Color(0xFF616161);
  static const Color neutralGrey800 = Color(0xFF424242);
  static const Color neutralGrey900 = Color(0xFF212121);
  static const Color neutralBlack = Color(0xFF000000);
  
  /// Semantic Colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFFC107);
  static const Color warningOrange = Color(0xFFFF5722);
  static const Color errorRed = Color(0xFFF44336);
  static const Color infoBlue = Color(0xFF2196F3);
  static const Color brandPrimary = primaryRed;
  
  /// Food Category Colors
  static const Color vegetarianGreen = Color(0xFF8BC34A);
  static const Color spicyRed = Color(0xFFFF5722);
  static const Color nonVegBrown = Color(0xFF8D6E63);
  
  /// App-Specific Colors
  static const Color customerApp = primaryOrange;
  static const Color dasherBlue = Color(0xFF2196F3);
  static const Color dasherApp = infoBlue;
  static const Color restaurantOrange = Color(0xFFFF9800);
  static const Color dasherGreen = Color(0xFF4CAF50);
  static const Color managerBlue = Color(0xFF3F51B5);
  static const Color restaurantRed = Color(0xFFE91E63);
  static const Color restaurantApp = successGreen;
  static const Color managerApp = Color(0xFF9C27B0);
  static const Color adminApp = Color(0xFF673AB7);
  static const Color waiterApp = Color(0xFF4CAF50);
  static const Color adminPurple = Color(0xFF9C27B0);
  static const Color dangerRed = errorRed;
  
  /// Spacing Scale (4pt grid system)
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  
  /// Border Radius Scale
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
  static const double radiusXXLarge = 24.0;
  static const double radiusRound = 1000.0;
  
  /// Elevation Scale
  static const double elevationNone = 0.0;
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationLarge = 8.0;
  static const double elevationXLarge = 12.0;
  
  /// Animation Durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
}

/// Theme configurations for different apps in the ecosystem
class EcosystemThemes {
  // Alias for backward compatibility
  static ThemeData get adminTheme => getAdminAppTheme();
  static ThemeData get customerApp => getCustomerAppTheme();
  static ThemeData getCustomerAppTheme() {
    return ThemeData(
      primarySwatch: Colors.deepOrange,
      primaryColor: DesignTokens.customerApp,
      scaffoldBackgroundColor: DesignTokens.neutralGrey50,
      textTheme: GoogleFonts.poppinsTextTheme(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.customerApp,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }
  
  static ThemeData getDasherAppTheme() {
    return getCustomerAppTheme().copyWith(
      primaryColor: DesignTokens.dasherApp,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.dasherApp,
        brightness: Brightness.light,
      ),
    );
  }
  
  static ThemeData getRestaurantAppTheme() {
    return getCustomerAppTheme().copyWith(
      primaryColor: DesignTokens.restaurantApp,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.restaurantApp,
        brightness: Brightness.light,
      ),
    );
  }
  
  static ThemeData getManagerAppTheme() {
    return getCustomerAppTheme().copyWith(
      primaryColor: DesignTokens.managerApp,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.managerApp,
        brightness: Brightness.light,
      ),
    );
  }
  
  static ThemeData getAdminAppTheme() {
    return getCustomerAppTheme().copyWith(
      primaryColor: DesignTokens.adminApp,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DesignTokens.adminApp,
        brightness: Brightness.light,
      ),
    );
  }
}