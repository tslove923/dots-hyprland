#!/usr/bin/env python3
"""
Wake Word Detection Service for AI Assistant
Listens for wake word and triggers voxd + AI panel activation
"""

import os
import sys
import time
import struct
import pyaudio
import numpy as np
from pathlib import Path
from openwakeword.model import Model
import socket
import json

# Configuration
WAKE_WORDS = ["hey_assistant"]  # Can add more: "alexa", "hey_jarvis", etc.
THRESHOLD = 0.5  # Confidence threshold (0.0 - 1.0)
CHUNK_SIZE = 1280  # 80ms of audio at 16kHz
SAMPLE_RATE = 16000
CHANNELS = 1
FORMAT = pyaudio.paInt16

# Socket path for IPC communication
SOCKET_PATH = "/tmp/ai-assistant.sock"

class WakeWordDetector:
    def __init__(self):
        print("Initializing wake word detector...")
        
        # Initialize openwakeword model
        self.model = Model(
            wakeword_models=WAKE_WORDS,
            inference_framework='onnx'
        )
        
        # Initialize PyAudio
        self.audio = pyaudio.PyAudio()
        
        # Get default input device
        self.input_device_index = self.get_input_device()
        
        # Create socket for IPC
        self.setup_socket()
        
        print(f"Listening for wake words: {WAKE_WORDS}")
        print(f"Using audio device index: {self.input_device_index}")
        print(f"IPC socket: {SOCKET_PATH}")
        
    def get_input_device(self):
        """Find the best input device (prefer the one voxd uses)"""
        default_device = self.audio.get_default_input_device_info()
        
        # Try to find the device that matches voxd config
        target_device = "Lunar Lake-M HD Audio Controller Microphones"
        
        for i in range(self.audio.get_device_count()):
            info = self.audio.get_device_info_by_index(i)
            if target_device in info.get('name', ''):
                print(f"Found matching device: {info['name']}")
                return i
        
        # Fallback to default
        print(f"Using default input device: {default_device['name']}")
        return default_device['index']
    
    def setup_socket(self):
        """Create Unix domain socket for IPC"""
        # Remove old socket if exists
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.bind(SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o666)  # Allow other processes to write
    
    def send_event(self, event_type, data=None):
        """Send event via socket (for future use with listener)"""
        message = {
            'type': event_type,
            'timestamp': time.time(),
            'data': data or {}
        }
        
        # For now, just trigger via file
        trigger_file = "/tmp/ai-assistant-triggered"
        with open(trigger_file, 'w') as f:
            json.dump(message, f)
        
        print(f"EVENT: {event_type}")
    
    def run(self):
        """Main detection loop"""
        # Open audio stream
        stream = self.audio.open(
            format=FORMAT,
            channels=CHANNELS,
            rate=SAMPLE_RATE,
            input=True,
            input_device_index=self.input_device_index,
            frames_per_buffer=CHUNK_SIZE
        )
        
        print("🎤 Listening for wake word...")
        
        try:
            while True:
                # Read audio chunk
                audio_data = stream.read(CHUNK_SIZE, exception_on_overflow=False)
                
                # Convert to numpy array
                audio_array = np.frombuffer(audio_data, dtype=np.int16)
                
                # Get predictions
                predictions = self.model.predict(audio_array)
                
                # Check if any wake word detected
                for wake_word, confidence in predictions.items():
                    if confidence >= THRESHOLD:
                        print(f"\n🔥 Wake word detected: {wake_word} (confidence: {confidence:.2f})")
                        self.send_event('wake_word_detected', {
                            'wake_word': wake_word,
                            'confidence': float(confidence)
                        })
                        
                        # Small delay to avoid repeated triggers
                        time.sleep(2.0)
                        
        except KeyboardInterrupt:
            print("\n\nShutting down...")
        finally:
            stream.stop_stream()
            stream.close()
            self.audio.terminate()
            if os.path.exists(SOCKET_PATH):
                os.unlink(SOCKET_PATH)

def main():
    detector = WakeWordDetector()
    detector.run()

if __name__ == "__main__":
    main()
