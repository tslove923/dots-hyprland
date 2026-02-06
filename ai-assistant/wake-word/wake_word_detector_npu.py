#!/usr/bin/env python3
"""
NPU-Accelerated Wake Word Detection Service
Uses OpenVINO for Intel NPU acceleration, inspired by voxd-npu architecture
"""

import os
import sys
import time
import struct
import pyaudio
import numpy as np
from pathlib import Path
import socket
import json
import onnx
from typing import Optional

# Configuration
WAKE_WORDS = ["hey_assistant"]  # ONNX model names
THRESHOLD = 0.5
CHUNK_SIZE = 1280  # 80ms at 16kHz
SAMPLE_RATE = 16000
CHANNELS = 1
FORMAT = pyaudio.paInt16

# Device selection (NPU > GPU > CPU)
DEVICE = "NPU"  # Change to "CPU" or "GPU" if needed
FALLBACK_TO_CPU = True

SOCKET_PATH = "/tmp/ai-assistant.sock"
MODELS_DIR = Path.home() / ".local/share/ai-assistant/wake-word-models"

class NPUWakeWordDetector:
    """
    Wake word detector using OpenVINO for NPU acceleration.
    Similar architecture to voxd-npu's openvino_transcriber.py
    """
    
    def __init__(self):
        print("🚀 Initializing NPU-accelerated wake word detector...")
        
        self.device = DEVICE
        self.actual_device = None
        self.models = {}
        
        # Initialize OpenVINO
        self._initialize_openvino()
        
        # Load wake word models
        self._load_models()
        
        # Initialize PyAudio
        self.audio = pyaudio.PyAudio()
        self.input_device_index = self.get_input_device()
        
        # Create socket for IPC
        self.setup_socket()
        
        print(f"✅ Using device: {self.actual_device}")
        print(f"✅ Loaded models: {list(self.models.keys())}")
        print(f"✅ Audio device: {self.input_device_index}")
        
    def _initialize_openvino(self):
        """Initialize OpenVINO Runtime with device detection"""
        try:
            import openvino as ov
            
            print(f"[openvino] Initializing OpenVINO Runtime...")
            self.core = ov.Core()
            
            # Detect available devices
            available_devices = self.core.available_devices
            print(f"[openvino] Available devices: {available_devices}")
            
            # Try requested device
            if self.device in available_devices:
                self.actual_device = self.device
                print(f"[openvino] Using requested device: {self.device}")
            elif FALLBACK_TO_CPU and "CPU" in available_devices:
                self.actual_device = "CPU"
                print(f"[openvino] Falling back to CPU")
            else:
                raise RuntimeError(f"Device {self.device} not available and no fallback")
                
        except ImportError:
            print("❌ OpenVINO not installed. Install with: pip install openvino")
            print("   Falling back to ONNX Runtime (CPU only)")
            self.actual_device = "ONNX_CPU"
            
    def _load_models(self):
        """Load and compile wake word models for OpenVINO"""
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        
        for wake_word in WAKE_WORDS:
            model_path = self._get_or_convert_model(wake_word)
            
            if self.actual_device == "ONNX_CPU":
                # Fallback to ONNX Runtime
                self._load_onnx_model(wake_word, model_path)
            else:
                # Load with OpenVINO
                self._load_openvino_model(wake_word, model_path)
    
    def _get_or_convert_model(self, wake_word: str) -> Path:
        """Get OpenVINO IR model, converting from ONNX if needed"""
        ov_model_path = MODELS_DIR / f"{wake_word}.xml"
        onnx_model_path = MODELS_DIR / f"{wake_word}.onnx"
        
        # If OpenVINO IR exists, use it
        if ov_model_path.exists():
            print(f"[model] Using cached OpenVINO model: {ov_model_path}")
            return ov_model_path
        
        # Download ONNX model if needed
        if not onnx_model_path.exists():
            print(f"[model] Downloading {wake_word} ONNX model...")
            self._download_onnx_model(wake_word, onnx_model_path)
        
        # Convert ONNX to OpenVINO IR
        if self.actual_device != "ONNX_CPU":
            print(f"[model] Converting {wake_word} to OpenVINO IR...")
            self._convert_to_openvino(onnx_model_path, ov_model_path)
            return ov_model_path
        else:
            return onnx_model_path
    
    def _download_onnx_model(self, wake_word: str, target_path: Path):
        """Download pre-trained ONNX wake word model"""
        try:
            from openwakeword.utils import download_models
            import shutil
            
            # openwakeword downloads to ~/.local/share/openwakeword
            print(f"[download] Fetching openwakeword models...")
            download_models()
            
            # Find the downloaded model
            openwakeword_dir = Path.home() / ".local/share/openwakeword"
            source_model = openwakeword_dir / f"{wake_word}.onnx"
            
            if not source_model.exists():
                # Try tflite version (we'll need to convert)
                source_model = openwakeword_dir / f"{wake_word}.tflite"
                if source_model.exists():
                    raise RuntimeError(f"Only tflite model found. ONNX conversion needed.")
                raise FileNotFoundError(f"Model {wake_word} not found")
            
            # Copy to our models directory
            shutil.copy(source_model, target_path)
            print(f"[download] Model saved to {target_path}")
            
        except ImportError:
            print("❌ openwakeword not installed for model download")
            print("   Install with: pip install openwakeword")
            raise
    
    def _convert_to_openvino(self, onnx_path: Path, output_path: Path):
        """Convert ONNX model to OpenVINO IR format with INT8 quantization"""
        try:
            import openvino as ov
            
            # Read ONNX model
            print(f"[convert] Reading ONNX model...")
            model = ov.convert_model(str(onnx_path))
            
            # Optional: Quantize to INT8 for better NPU performance
            # (Would need calibration data for proper quantization)
            
            # Serialize to IR format
            print(f"[convert] Saving OpenVINO IR...")
            ov.save_model(model, str(output_path))
            
            print(f"[convert] ✅ Conversion complete: {output_path}")
            
        except Exception as e:
            print(f"[convert] ❌ Conversion failed: {e}")
            raise
    
    def _load_openvino_model(self, wake_word: str, model_path: Path):
        """Load and compile OpenVINO model for NPU"""
        try:
            print(f"[model] Loading {wake_word} on {self.actual_device}...")
            
            # Read model
            model = self.core.read_model(str(model_path))
            
            # Compile for target device
            compiled_model = self.core.compile_model(model, self.actual_device)
            
            # Store compiled model and input/output info
            self.models[wake_word] = {
                'compiled': compiled_model,
                'input': compiled_model.input(0),
                'output': compiled_model.output(0),
                'type': 'openvino'
            }
            
            print(f"[model] ✅ {wake_word} compiled for {self.actual_device}")
            
        except Exception as e:
            print(f"[model] ❌ Failed to load {wake_word}: {e}")
            if FALLBACK_TO_CPU:
                print(f"[model] Retrying on CPU...")
                self.actual_device = "CPU"
                self._load_openvino_model(wake_word, model_path)
    
    def _load_onnx_model(self, wake_word: str, model_path: Path):
        """Fallback: Load ONNX model with ONNX Runtime"""
        try:
            import onnxruntime as ort
            
            print(f"[model] Loading {wake_word} with ONNX Runtime...")
            
            session = ort.InferenceSession(
                str(model_path),
                providers=['CPUExecutionProvider']
            )
            
            self.models[wake_word] = {
                'session': session,
                'input_name': session.get_inputs()[0].name,
                'output_name': session.get_outputs()[0].name,
                'type': 'onnx'
            }
            
            print(f"[model] ✅ {wake_word} loaded (ONNX Runtime)")
            
        except ImportError:
            print("❌ onnxruntime not installed. Install with: pip install onnxruntime")
            raise
    
    def predict(self, audio_chunk: np.ndarray) -> dict:
        """Run inference on audio chunk"""
        predictions = {}
        
        # Prepare input (normalize audio)
        audio_input = audio_chunk.astype(np.float32) / 32768.0
        audio_input = audio_input.reshape(1, -1)  # Add batch dimension
        
        for wake_word, model_info in self.models.items():
            try:
                if model_info['type'] == 'openvino':
                    # OpenVINO inference
                    infer_request = model_info['compiled'].create_infer_request()
                    infer_request.infer({model_info['input']: audio_input})
                    output = infer_request.get_output_tensor(0).data
                    confidence = float(output[0][0])
                    
                elif model_info['type'] == 'onnx':
                    # ONNX Runtime inference
                    output = model_info['session'].run(
                        [model_info['output_name']],
                        {model_info['input_name']: audio_input}
                    )
                    confidence = float(output[0][0][0])
                
                predictions[wake_word] = confidence
                
            except Exception as e:
                print(f"[inference] Error on {wake_word}: {e}")
                predictions[wake_word] = 0.0
        
        return predictions
    
    def get_input_device(self):
        """Find the best input device"""
        default_device = self.audio.get_default_input_device_info()
        target_device = "Lunar Lake-M HD Audio Controller Microphones"
        
        for i in range(self.audio.get_device_count()):
            info = self.audio.get_device_info_by_index(i)
            if target_device in info.get('name', ''):
                return i
        
        return default_device['index']
    
    def setup_socket(self):
        """Create Unix domain socket for IPC"""
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.bind(SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o666)
    
    def send_event(self, event_type, data=None):
        """Send event via file trigger"""
        message = {
            'type': event_type,
            'timestamp': time.time(),
            'data': data or {}
        }
        
        trigger_file = "/tmp/ai-assistant-triggered"
        with open(trigger_file, 'w') as f:
            json.dump(message, f)
        
        print(f"🔥 EVENT: {event_type}")
    
    def run(self):
        """Main detection loop"""
        stream = self.audio.open(
            format=FORMAT,
            channels=CHANNELS,
            rate=SAMPLE_RATE,
            input=True,
            input_device_index=self.input_device_index,
            frames_per_buffer=CHUNK_SIZE
        )
        
        print("🎤 Listening for wake word...")
        print(f"   Device: {self.actual_device}")
        print(f"   Models: {WAKE_WORDS}")
        print(f"   Threshold: {THRESHOLD}")
        
        try:
            while True:
                # Read audio chunk
                audio_data = stream.read(CHUNK_SIZE, exception_on_overflow=False)
                audio_array = np.frombuffer(audio_data, dtype=np.int16)
                
                # Get predictions
                start = time.time()
                predictions = self.predict(audio_array)
                latency = (time.time() - start) * 1000  # ms
                
                # Check for wake word
                for wake_word, confidence in predictions.items():
                    if confidence >= THRESHOLD:
                        print(f"\n🔥 Wake word detected: {wake_word}")
                        print(f"   Confidence: {confidence:.3f}")
                        print(f"   Latency: {latency:.1f}ms")
                        print(f"   Device: {self.actual_device}")
                        
                        self.send_event('wake_word_detected', {
                            'wake_word': wake_word,
                            'confidence': float(confidence),
                            'latency_ms': latency,
                            'device': self.actual_device
                        })
                        
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
    try:
        detector = NPUWakeWordDetector()
        detector.run()
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
