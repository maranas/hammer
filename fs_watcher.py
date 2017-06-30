import os
import sys
import time
from watchdog.events import PatternMatchingEventHandler
from watchdog.observers import Observer

class ChangeEventHandler(PatternMatchingEventHandler):
    def on_created(self, event):
        os.system("python hammer.py")

event_handler = ChangeEventHandler(patterns=['*.m'],
                                ignore_patterns=['*Hammer.m'],
                                ignore_directories=False)

path = None
try:
    path = sys.argv[1]
except:
    path = "."
observer = Observer()
observer.schedule(event_handler, path, recursive=True)
observer.start()
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    observer.stop()
observer.join()
