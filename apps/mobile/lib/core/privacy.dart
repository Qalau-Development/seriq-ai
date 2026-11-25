// PrivacySection — раздел страницы «Данные и приватность»: ключи заголовка и текстов
class PrivacySection {
  final String titleKey;
  final List<String> textKeys;

  const PrivacySection(this.titleKey, this.textKeys);
}

// privacySections — разделы страницы «Данные и приватность», как на сайте: только то, что реально так и есть
const privacySections = [
  PrivacySection('privacy_video_title', ['privacy_video_1']),
  PrivacySection('privacy_guest_title', ['privacy_guest_1']),
  PrivacySection('privacy_account_title', ['privacy_account_1']),
  PrivacySection('privacy_not_stored_title', ['privacy_not_stored_1']),
  PrivacySection('privacy_delete_title', ['privacy_delete_1']),
  PrivacySection('privacy_password_title', ['privacy_password_1']),
  PrivacySection('privacy_medical_title', ['privacy_medical_1']),
];
