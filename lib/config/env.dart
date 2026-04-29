import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // ── Appwrite Config ──
  static String get appwriteEndpoint =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_ENDPOINT'] ?? '';
  static String get appwriteProjectId =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_PROJECT_ID'] ?? '';
  static String get appwriteDatabaseId =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_DATABASE_ID'] ?? '';

  // ── Collections ──
  static String get outfitsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_OUTFITS'] ?? '';
  static String get usersCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_USERS'] ?? '';
  static String get plansCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_PLANS'] ??
      dotenv.env['PLANS_COLLECTION_ID'] ??
      '';
  static String get savedBoardsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_SAVED_BOARDS'] ?? '';
  static String get skincareCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_SKINCARE'] ?? '';
  static String get workoutOutfitsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_WORKOUT_OUTFITS'] ?? '';
  static String get billsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_BILLS'] ?? '';
  static String get couponsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_COUPONS'] ?? '';
  static String get medsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_MEDICATIONS'] ??
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_MEDS'] ??
      '';
  static String get medLogsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_LOGS'] ??
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_MED_LOGS'] ??
      '';
  static String get memoriesCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_MEMORIES'] ?? '';
  static String get chatThreadsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_CHAT_THREADS'] ?? '';
  static String get chatMessagesCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_CHAT_MESSAGES'] ?? '';

  // ── Cloudflare R2 Credentials ──
  static String get r2AccountId =>
      dotenv.env['EXPO_PUBLIC_R2_ACCOUNT_ID'] ?? '';
  static String get r2S3ApiUrl => dotenv.env['EXPO_PUBLIC_R2_S3_API_URL'] ?? '';
  static String get r2AccessKeyId =>
      dotenv.env['EXPO_PUBLIC_R2_ACCESS_KEY_ID'] ?? '';
  static String get r2SecretAccessKey =>
      dotenv.env['EXPO_PUBLIC_R2_SECRET_ACCESS_KEY'] ?? '';

  // ── Raw Images Bucket Details ──
  static String get rawBucketId =>
      dotenv.env['EXPO_PUBLIC_R2_BUCKET_RAW_IMAGES'] ?? '';
  static String get r2UrlRaw =>
      dotenv.env['EXPO_PUBLIC_R2_URL_RAW_IMAGES'] ?? '';

  // ── Wardrobe R2 Bucket Details ──
  static String get wardrobeBucketId =>
      dotenv.env['EXPO_PUBLIC_R2_BUCKET_WARDROBE'] ?? '';
  static String get r2UrlWardrobe =>
      dotenv.env['EXPO_PUBLIC_R2_URL_WARDROBE'] ?? '';
  static String get lifeGoalsCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_LIFE_GOALS'] ?? '';
  // ── AI Python Backend ──
  static String get backendApiUrl =>
      dotenv.env['EXPO_PUBLIC_BACKEND_API_URL'] ?? '';
  static String get mealPlansCollection =>
      dotenv.env['EXPO_PUBLIC_APPWRITE_COLLECTION_MEAL_PLANS'] ?? '';
}
