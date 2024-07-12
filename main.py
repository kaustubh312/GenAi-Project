from PyQt5.QtWidgets import QApplication
from qasync import QEventLoop
from ui.mainwindow import MainWindow
import sys
import asyncio

def main():
    app = QApplication(sys.argv)
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)
    window = MainWindow(loop)
    window.show()

    with loop:
        loop.run_forever()

if __name__ == "__main__":
    main()
