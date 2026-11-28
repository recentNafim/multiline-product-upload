class ApiConstants {
  ApiConstants._();

  // Existing HTTPS Oracle ORDS endpoints. No Docker or Node proxy is needed.
  static const String uploadItem =
      'https://e501.sihirbox.com:8071/ords/rpro/multiline-display-room/item-upload';
  static const String listItems = uploadItem;
  static const String updateItem = uploadItem;
  static const String deleteItem = uploadItem;

  // The ORDS POST handler calls APPS.USER_LOGIN_VALIDATION on the server.
  // Can be overridden when deploying to a different ORDS instance:
  // flutter run -d chrome --dart-define=MLIL_LOGIN_URL=https://.../login
  static const String loginUrl = String.fromEnvironment(
    'MLIL_LOGIN_URL',
    defaultValue: 'https://e501.sihirbox.com:8071/ords/rpro/mlil-admin-auth/login',
  );

  static const String imageBase =
      'https://e501.sihirbox.com:8071/ords/rpro/image_service/get/';
}
