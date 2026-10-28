import 'package:image_picker/image_picker.dart';

// 채팅 촬영과 프로필 선택은 같은 원본 크기·품질로 사진을 가져와요.
Future<XFile?> pickPhoto(ImageSource source) =>
    ImagePicker().pickImage(source: source, imageQuality: 92, maxWidth: 1920);
