# Damage Assessor - Flutter Project Structure

Complete Flutter project architecture for a vehicle damage assessment mobile application with multi-language support, authentication, photo capture, AI analysis, subscription management, and reporting.

## 📁 Project Structure

```
lib/
├── main.dart                              # GetMaterialApp setup
│
├── core/
│   ├── config/
│   │   ├── env.dart                      # API base URL, Firebase config
│   │   └── theme.dart                    # Colors, text styles (matching PDF brand)
│   ├── routes/
│   │   ├── app_routes.dart               # Route name constants
│   │   └── app_pages.dart                # GetPage list + bindings, middleware
│   ├── middleware/
│   │   ├── auth_middleware.dart          # Redirects to login if no session
│   │   └── subscription_middleware.dart  # Redirects to paywall if gate fails
│   ├── network/
│   │   ├── api_client.dart               # Dio client with base interceptors
│   │   └── auth_interceptor.dart         # Attaches backend JWT to requests
│   ├── errors/
│   │   └── failures.dart                 # Typed failure classes
│   ├── storage/
│   │   └── local_storage.dart            # Secure storage for JWT
│   └── widgets/
│       ├── app_button.dart
│       ├── app_badge.dart                # Condition/severity colored pill
│       ├── loading_view.dart
│       └── error_view.dart               # Retry-capable error widget
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── models/user_model.dart
│   │   ├── controllers/
│   │   │   └── auth_controller.dart
│   │   ├── bindings/
│   │   │   └── auth_binding.dart
│   │   └── presentation/
│   │       ├── login_screen.dart
│   │       └── otp_verification_screen.dart
│   │
│   ├── dashboard/
│   │   ├── data/
│   │   │   └── dashboard_repository.dart
│   │   ├── controllers/
│   │   │   └── dashboard_controller.dart
│   │   ├── bindings/
│   │   │   └── dashboard_binding.dart
│   │   └── presentation/
│   │       ├── dashboard_screen.dart
│   │       └── widgets/
│   │           ├── status_banner.dart
│   │           └── recent_assessment_card.dart
│   │
│   ├── assessment/
│   │   ├── data/
│   │   │   ├── assessment_repository.dart
│   │   │   └── models/
│   │   │       ├── assessment_model.dart
│   │   │       └── photo_model.dart
│   │   ├── controllers/
│   │   │   └── capture_controller.dart
│   │   ├── bindings/
│   │   │   └── assessment_binding.dart
│   │   └── presentation/
│   │       ├── vehicle_info_screen.dart
│   │       ├── capture_screen.dart
│   │       └── widgets/
│   │           ├── angle_overlay.dart
│   │           └── capture_progress_bar.dart
│   │
│   ├── analysis/
│   │   ├── data/
│   │   │   └── analysis_repository.dart
│   │   ├── controllers/
│   │   │   └── analysis_controller.dart
│   │   ├── bindings/
│   │   │   └── analysis_binding.dart
│   │   └── presentation/
│   │       ├── analyzing_screen.dart
│   │       ├── results_screen.dart
│   │       └── widgets/
│   │           ├── condition_badges_row.dart
│   │           ├── cost_summary_card.dart
│   │           └── damage_region_tile.dart
│   │
│   ├── subscription/
│   │   ├── data/
│   │   │   └── subscription_repository.dart
│   │   ├── controllers/
│   │   │   └── subscription_controller.dart
│   │   ├── bindings/
│   │   │   └── subscription_binding.dart
│   │   └── presentation/
│   │       ├── paywall_screen.dart
│   │       └── widgets/
│   │           └── plan_card.dart
│   │
│   ├── report/
│   │   ├── data/
│   │   │   └── report_repository.dart
│   │   ├── controllers/
│   │   │   └── report_controller.dart
│   │   ├── bindings/
│   │   │   └── report_binding.dart
│   │   └── presentation/
│   │       ├── report_preview_screen.dart
│   │       └── export_share_sheet.dart
│   │
│   └── history/
│       ├── data/
│       │   └── history_repository.dart
│       ├── controllers/
│       │   └── history_controller.dart
│       ├── bindings/
│       │   └── history_binding.dart
│       └── presentation/
│           ├── history_screen.dart
│           └── widgets/
│               └── history_list_item.dart
│
└── l10n/
    ├── app_en.arb                        # English
    ├── app_fr.arb                        # French
    └── app_ar.arb                        # Arabic
```

## 🚀 Getting Started

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Generate Localization Files

```bash
flutter pub global activate intl_utils
dart run intl_utils:generate
```

### 3. Build Localization Resources

```bash
flutter gen-l10n
```

### 4. Configure Environment Variables

Update `lib/core/config/env.dart` with your configuration:

- API Base URL
- Firebase Project ID
- Firebase API Key
- App Version

### 5. Setup Local Secure Storage

The app uses `flutter_secure_storage` for storing JWT tokens. No additional setup required beyond `flutter pub get`.

### 6. Implement Repository Methods

All repository methods have TODO comments. Implement them by:

1. Calling your backend API using the `ApiClient` from `lib/core/network/api_client.dart`
2. Handling responses and errors appropriately
3. Returning typed `Result` objects

### 7. Replace Placeholder Screens

- Replace `Placeholder()` widgets in `app_pages.dart` with actual screen references
- Uncomment and implement bindings in GetPage definitions

## 📦 Key Dependencies

- **get**: State management and routing
- **dio**: HTTP client with interceptors
- **flutter_secure_storage**: Secure JWT storage
- **firebase_auth**: Firebase authentication
- **firebase_core**: Firebase setup
- **image_picker**: Photo selection
- **camera**: Camera access
- **pdf/printing**: PDF generation and printing
- **stripe_flutter**: Payment processing
- **share_plus**: Social sharing
- **intl**: Localization

## 🔐 Authentication Flow

1. User enters phone number on login screen
2. Backend sends OTP via SMS
3. User enters OTP on verification screen
4. App sends phone + OTP to backend: `POST /auth/firebase`
5. Backend returns JWT token
6. App stores JWT in secure storage
7. JWT is automatically attached to all requests via `AuthInterceptor`

## 🎨 Theming

The app uses a consistent theme system with:

- Primary: Blue (#1976D2)
- Accent: Orange (#FF6F00)
- Condition colors for severity levels
- Light and dark theme support

## 📱 Localization

Currently supports: English, French, Arabic

Add more languages by:

1. Creating new `.arb` files in `lib/l10n/`
2. Adding translations to `Messages` class in `main.dart`

## 🔄 State Management (GetX)

All controllers extend `GetxController` with reactive state management:

- Observable variables (`.obs`)
- Reactive methods
- Automatic state updates
- Built-in lifecycle management

## 🛣️ Routing

Routes are defined in `AppPages` with:

- Built-in authentication middleware
- Subscription middleware
- Automatic bindings via `GetPages`

## 📝 Next Steps

1. Implement all repository methods with actual API calls
2. Setup Firebase authentication
3. Connect to backend API
4. Implement camera functionality
5. Add image processing/AI analysis integration
6. Setup payment processing with Stripe
7. Implement PDF report generation
8. Add push notifications
9. Write unit and widget tests
10. Configure CI/CD pipeline

## 🐛 Common TODOs

Search for `TODO:` comments throughout the codebase to find:

- API integration points
- Firebase setup
- Camera functionality
- Payment processing
- Report generation
- Error handling improvements

## 📄 License

This is a complete scaffold for the Damage Assessor app. Customize it according to your specific requirements.
