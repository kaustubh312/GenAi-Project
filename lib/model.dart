class ModelMessage
{
  final String message;
  final DateTime time;
  final String? imagePath;

  ModelMessage({ required this.message, required this.time, this.imagePath});
}