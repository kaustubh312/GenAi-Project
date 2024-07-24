import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:visionverse_ai/static_values.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
as google_generative_ai;

import 'model.dart';

late List<CameraDescription> cameras;

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onImageSend});

  final Function(String)? onImageSend;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late CameraController _cameraController;
  final TextEditingController _controller = TextEditingController();
  late Future<void> cameraValue;
  bool _isTakingPicture = false; // Flag to track if a picture is being taken
  bool flash = false;
  bool isCameraFront = true;
  double transform = 0;
  String lastWords = "";
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final ImagePicker _picker = ImagePicker();

  static const apiKey = StaticValues.apiKey;
  final model = GenerativeModel(model: "gemini-1.5-flash", apiKey: apiKey);

  final List<ModelMessage> prompt = [];

  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(cameras[0], ResolutionPreset.high);
    cameraValue = _cameraController.initialize();
    _speech = stt.SpeechToText();
    setState(() {});
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      print("Speech recognition initialized");
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          print("Recognized words: ${val.recognizedWords}");
          lastWords = val.recognizedWords;
          setState(() {
            _controller.text = lastWords;
          });
        },
        partialResults: false, // Only get final results
        localeId: 'en_US',
      );
    } else {
      print("Speech recognition not available");
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: const EdgeInsets.all(0.0),
          child: Stack(
            children: [
              FutureBuilder(
                future: cameraValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: CameraPreview(_cameraController),
                    );
                  } else {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                },
              ),
              Positioned(
                top: MediaQuery.of(context).size.height *
                    0.10, // Adjust this value as needed
                left: 12.0,
                right: 12.0,
                child: Container(
                  height: 110,
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      prompt.isNotEmpty
                          ? prompt.last.message
                          : 'Response will display here',
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                flash = !flash;
                              });
                              flash
                                  ? _cameraController
                                  .setFlashMode(FlashMode.torch)
                                  : _cameraController.setFlashMode(FlashMode.off);
                            },
                            icon: flash
                                ? const Icon(Icons.flash_on,
                                color: Colors.white, size: 28)
                                : const Icon(Icons.flash_off,
                                color: Colors.white, size: 28),
                          ),
                          IconButton(
                            onPressed: () async {
                              setState(() {
                                isCameraFront = !isCameraFront;
                                transform = transform + pi;
                              });
                              int cameraPos = isCameraFront ? 0 : 1;
                              _cameraController = CameraController(
                                  cameras[cameraPos], ResolutionPreset.high);
                              cameraValue = _cameraController.initialize();
                            },
                            icon: Transform.rotate(
                              angle: transform,
                              child: const Icon(Icons.flip_camera_ios,
                                  color: Colors.white, size: 28),
                            ),
                          ),
                          GestureDetector(
                            onLongPress: _startListening,
                            onLongPressEnd: (details) => _stopListening(),
                            child: const Icon(Icons.mic,
                                color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 3.0),
                        child: TextFormField(
                          controller: _controller,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          // Allows unlimited lines
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            suffixIcon: InkWell(
                              onTap: () {
                                sendMessage();
                              },
                              child: const Icon(Icons.send, size: 28),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            hintText: 'Ask something about image here',
                            hintStyle: const TextStyle(color: Colors.black38),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> takePhoto() async {
    if (_isTakingPicture) return; // Prevent taking multiple pictures simultaneously

    setState(() {
      _isTakingPicture = true; // Indicate that a picture is being taken
    });

    try {
      // Capture the picture using image_picker
      final XFile? picture = await _picker.pickImage(source: ImageSource.camera);

      if (picture == null) {
        print("No picture taken");
        return;
      }

      // Get the app's document directory
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpeg';

      // Save the picture to the temporary directory
      final File imageFile = File(picture.path);
      await imageFile.copy(path);

      // Check if the path is valid
      if (path.isNotEmpty) {
        setState(() {
          _imagePath = path; // Store the image path
          print("Picture taken, path: $_imagePath"); // Debug information
        });
      } else {
        print("Error: Picture path is empty"); // Debug information
      }
    } catch (e) {
      // Handle any errors during picture capture
      print("Error taking picture: $e");
    } finally {
      setState(() {
        _isTakingPicture = false; // Reset the flag
      });
    }
  }

  Future<void> sendMessage() async {
    await takePhoto(); // Take a photo before sending the message

    final message = _controller.text;
    final imagePath = _imagePath; // Get the image path

    print("Image Path in sendMessage: $imagePath"); // Debug information

    if (imagePath == null) {
      _showErrorDialog(context, "Failed to capture image. Please try again.");
      return;
    }

    final bytes = File(imagePath!).readAsBytesSync();
    final mimeType = 'image/jpeg'; // Adjust MIME type if necessary

    // prompt.add(
    //   ModelMessage(
    //     message: message,
    //     time: DateTime.now(),
    //     imagePath: imagePath!,
    //   ),
    // );

    final List<google_generative_ai.Content> content = [
      google_generative_ai.Content.text(message),
      google_generative_ai.Content.data(mimeType, Uint8List.fromList(bytes)), // Send the base64 image as data
    ];

    final response = await model.generateContent(content);
    setState(() {
      prompt.add(
        ModelMessage(
          message: response.text ?? "",
          time: DateTime.now(),
          imagePath: imagePath!,
        ),
      );
    });
    _imagePath = null; // Clear the image path after sending

    // Delete the image file after sending
    try {
      final file = File(imagePath!);
      if (await file.exists()) {
        await file.delete();
        _controller.clear();
        print("Image file deleted: $imagePath");
      }
    } catch (e) {
      print("Error deleting image file: $e");
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    print(message);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
