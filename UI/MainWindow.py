import sys
import cv2
from PyQt5.QtWidgets import *
from PyQt5.QtGui import *
from PyQt5.QtCore import *
import google.generativeai as genai
import asyncio
from qasync import QEventLoop, asyncSlot
from PIL import Image
import speech_recognition as sr
import pyttsx3
import threading
import time

# Set up your Gemini API key for genai
API_KEY = ""
genai.configure(api_key=API_KEY)

# Initialize generative model
model = genai.GenerativeModel('gemini-pro-vision')

class MainWindow(QWidget):
    def __init__(self, loop=None):
        super().__init__()
        self.initUI()

        # Start the timer in the constructor
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_webcam_feed)
        self.timer.start(50)  # Update the webcam feed every 50 milliseconds
        self.loop = loop or asyncio.get_event_loop()

        # Initialize webcam capture
        self.cap = cv2.VideoCapture(0)  # 0 refers to the default webcam

        # Initialize speech recognizer and TTS engine
        self.recognizer = sr.Recognizer()
        self.tts_engine = pyttsx3.init()

        # Initialize memory for interactions
        self.interaction_memory = []

        # Start capturing video
        self.start_video_capture()

    def initUI(self):
        with open('UI/styles.qss', 'r') as f:
            self.setStyleSheet(f.read())

        main_layout = QVBoxLayout(self)

        # Webcam section
        webcam_frame = QFrame(self)
        webcam_frame.setFrameShape(QFrame.StyledPanel)
        webcam_frame_layout = QVBoxLayout(webcam_frame)

        self.label = QLabel(webcam_frame)
        self.label.setFixedSize(640, 480)
        self.label.setStyleSheet("border-radius: 10px; border: 2px solid #007BFF;")
        webcam_frame_layout.addWidget(self.label, alignment=Qt.AlignCenter)

        # Answer section for real-time webcam response
        webcam_response_frame = QFrame(self)
        webcam_response_frame.setFrameShape(QFrame.StyledPanel)
        webcam_response_layout = QVBoxLayout(webcam_response_frame)

        self.webcam_response_label = QLabel("Webcam AI Response =>")
        self.webcam_response_edit = QTextEdit()
        self.webcam_response_edit.setReadOnly(True)

        webcam_response_layout.addWidget(self.webcam_response_label)
        webcam_response_layout.addWidget(self.webcam_response_edit)

        # Question section
        question_frame = QFrame(self)
        question_frame.setFrameShape(QFrame.StyledPanel)
        question_layout = QVBoxLayout(question_frame)

        self.question_label = QLabel("Question ?")
        self.question_edit = QTextEdit()

        question_layout.addWidget(self.question_label)
        question_layout.addWidget(self.question_edit)

        # Answer section for user-asked questions
        user_response_frame = QFrame(self)
        user_response_frame.setFrameShape(QFrame.StyledPanel)
        user_response_layout = QVBoxLayout(user_response_frame)

        self.answer_label = QLabel("Answer =>")
        self.answer_edit = QTextEdit()
        self.answer_edit.setReadOnly(True)

        user_response_layout.addWidget(self.answer_label)
        user_response_layout.addWidget(self.answer_edit)

        # Control buttons
        control_buttons_frame = QFrame(self)
        control_buttons_frame.setFrameShape(QFrame.StyledPanel)
        control_buttons_layout = QHBoxLayout(control_buttons_frame)

        self.send_button = QPushButton("Send")
        self.send_button.setObjectName("sendButton")
        self.speech_button = QPushButton("Speak")
        self.speech_button.setObjectName("speakButton")

        control_buttons_layout.addWidget(self.speech_button)
        control_buttons_layout.addWidget(self.send_button)

        main_layout.addWidget(webcam_frame)
        main_layout.addWidget(webcam_response_frame)
        main_layout.addWidget(question_frame)
        main_layout.addWidget(user_response_frame)
        main_layout.addWidget(control_buttons_frame)

        self.setLayout(main_layout)
        self.setGeometry(100, 100, 1280, 960)
        self.setWindowTitle('Vision AI - Real-time Webcam App')

        # Connect button click events to functions
        self.send_button.clicked.connect(self.on_send_button_clicked)
        self.speech_button.clicked.connect(self.speech_to_text)

    def start_video_capture(self):
        # Start the video capture in a separate thread
        threading.Thread(target=self.video_capture_thread, daemon=True).start()

    def video_capture_thread(self):
        while True:
            ret, frame = self.cap.read()
            if ret:
                image_pil = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                try:
                    response = model.generate_content(["Describe what is happening in front of the camera.", image_pil]).parts[0].text
                    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
                    self.interaction_memory.append({'timestamp': timestamp, 'description': response})
                    self.loop.call_soon_threadsafe(self.update_webcam_response, response)
                except Exception as e:
                    print(f"Failed to generate content: {e}")
                time.sleep(2)  # Adjust the delay as needed for video processing

    @asyncSlot()
    async def capture_question(self):
        question = self.question_edit.toPlainText()

        if not question.strip():
            question = "Describe the image..."
            self.question_edit.setPlainText(question)

        ret, frame = self.cap.read()
        if ret:
            image_pil = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
            try:
                history_texts = [f"At {item['timestamp']}, you saw: {item['description']}" for item in self.interaction_memory]
                full_context = "\n".join(history_texts)
                response = await self.loop.run_in_executor(None, lambda: model.generate_content([f"Context:\n{full_context}\n\nQuestion: {question}", image_pil]).parts[0].text)
                timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
                self.interaction_memory.append({'timestamp': timestamp, 'description': response, 'question': question})

                self.answer_edit.clear()
                self.answer_edit.append(f"AI Response: {response}")

                # Use TTS to speak the response after displaying it
                self.tts_engine.say(response)
                self.tts_engine.runAndWait()

                # Re-enable buttons after speaking
                self.send_button.setEnabled(True)
                self.speech_button.setEnabled(True)

            except Exception as e:
                print(f"Failed to generate content: {e}")

    @asyncSlot()
    async def speech_to_text(self):
        with sr.Microphone() as source:
            print("Listening for question...")
            audio = self.recognizer.listen(source)

        try:
            question = self.recognizer.recognize_google(audio)
            self.question_edit.setPlainText(question)
            await self.capture_question()
        except sr.UnknownValueError:
            print("Could not understand audio")
        except sr.RequestError as e:
            print(f"Could not request results; {e}")

    def update_webcam_feed(self):
        ret, frame = self.cap.read()
        if ret:
            frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frame = QImage(frame.data, frame.shape[1], frame.shape[0], QImage.Format_RGB888)
            self.label.setPixmap(QPixmap.fromImage(frame))

    @asyncSlot()
    async def update_webcam_response(self, response):
        self.webcam_response_edit.clear()
        self.webcam_response_edit.append(f"AI Response: {response}")

    def on_send_button_clicked(self):
        # Disable buttons during AI processing
        self.send_button.setEnabled(False)
        self.speech_button.setEnabled(False)
        asyncio.ensure_future(self.capture_question())
