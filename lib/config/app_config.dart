class AppConfig {
  // Environment configuration
  static const String environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
  static const String mockCustomerId = "";
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', 
      defaultValue: 'https://api.delhinightsapps.com');
  
  // Google Maps Configuration
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', 
      defaultValue: 'your-google-maps-api-key');
  
  // Firebase Configuration
  static const String firebaseProjectId = 'delhinightsapps';
  
  // App Configuration
  static const String appName = 'Restaurant Ecosystem';
  static const String appVersion = '1.0.0';
  
  // Business Configuration
  static const double defaultDeliveryRadius = 10.0; // km
  static const double deliveryFee = 2.99;
  static const int maxDeliveryTimeMinutes = 45;
  static const int preparationTimeMinutes = 15;
  
  // Real-time Configuration
  static const int orderUpdateIntervalSeconds = 5;
  static const int locationUpdateIntervalSeconds = 10;
  
  // Production Configuration
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  
  // Error Handling Configuration
  static const int maxRetryAttempts = 3;
  static const int retryDelaySeconds = 2;
  
  // Notification Configuration
  static const bool enablePushNotifications = true;
  static const bool enableInAppNotifications = true;
  
  // Security Configuration
  static const int sessionTimeoutMinutes = 30;
  static const bool enableBiometricAuth = true;
  
  // Performance Configuration
  static const int cacheExpirationMinutes = 15;
  static const int maxConcurrentRequests = 5;
}