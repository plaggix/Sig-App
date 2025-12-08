import 'package:cloudinary_sdk/cloudinary_sdk.dart';

class CloudinaryService {
  final cloudinary = Cloudinary.full(
    apiKey: "812513655819511",
    apiSecret: "tqJWTY3YF3Sw",
    cloudName: "djwxfhlid",
  );

  Future<String?> uploadImage(String filePath) async {
    final response = await cloudinary.uploadResource(
      CloudinaryUploadResource(
        filePath: filePath,
        resourceType: CloudinaryResourceType.image,
        folder: "flutter_uploads", // ton dossier dans Cloudinary
      ),
    );

    if (response.isSuccessful) {
      return response.secureUrl; // URL finale de l’image
    } else {
      print("Erreur : ${response.error}");
      return null;
    }
  }
}
