import asyncio
import sys
from PyQt5.QtWidgets import QApplication
from qasync import QEventLoop
from UI.MainWindow import MainWindow

def main():
    app = QApplication(sys.argv)
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)
    window = MainWindow(loop)
    window.update_webcam_feed()
    window.show()

    with loop:
        loop.run_forever()

if __name__ == "__main__":
    main()
