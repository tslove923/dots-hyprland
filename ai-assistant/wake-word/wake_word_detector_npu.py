#!/usr/bin/env python3
"""
NPU-Accelerated Wake Word Detection Service
Uses OpenVINO for Intel NPU acceleration, inspired by voxd-npu architecture
Coordinates microphone access with voxd to prevent conflicts

KNOWN ISSUE: Python 3.14.2 has a critical bug where onnxruntime import causes
malloc corruption when combined with other imports (numpy, sounddevice, socket).
This crashes the program before any code executes. Workaround: Use Python 3.12/3.13
or wait for Python 3.14.3 bugfix.
"""

import os
import sys
import time
import struct
import sounddevice as sd
import numpy as np
from pathlib import Path
import socket
import json
# onnx imported lazily to avoid multiprocessing conflicts
from typing import Optional
# scipy imported lazily to avoid multiprocessing conflicts with OpenVINO
from collections import deque

# Add parent directory to path for imports
# TEMPORARILY DISABLED TO TEST IF THIS CAUSES CRASH
# sys.path.insert(0, str(Path(__file__).parent.parent))
AUDIO_COORDINATION = False  # Disabled for testing

# try:
#     # TEMPORARILY disabled due to multiprocessing conflict with OpenVINO NPU
#     # TODO: Fix multiprocessing/NPU driver conflict
#     if os.getenv('AUDIO_COORDINATION', '0') == '1':
#         from common.audio_manager import AudioResourceManager
#         AUDIO_COORDINATION = True
#     else:
#         AUDIO_COORDINATION = False
# except ImportError:
#     print("⚠️  Audio coordination not available (common/audio_manager.py missing)")
#     AUDIO_COORDINATION = False

# Configuration
WAKE_WORDS = ["alexa"]  # ONNX model names (available: alexa, hey_mycroft, hey_rhasspy)
THRESHOLD = 0.5
CHUNK_SIZE = 1280  # 80ms at 16kHz
SAMPLE_RATE = 16000
CHANNELS = 1
DTYPE = 'int16'  # sounddevice dtype

# Device selection (NPU > GPU > CPU)
DEVICE = "CPU"  # Temporarily using CPU to test if NPU is causing crashes
FALLBACK_TO_CPU = True
USE_ONNX_ONLY = True  # Skip OpenVINO to avoid multiprocessing/malloc corruption

SOCKET_PATH = "/tmp/ai-assistant.sock"
MODELS_DIR = Path.home() / ".local/share/ai-assistant/wake-word-models"

# Audio device selection (can be overridden via AUDIO_DEVICE_INDEX env var)
DEFAULT_DEVICE_INDEX = 16  # Laptop built-in microphones
AUDIO_DEVICE_INDEX = int(os.environ.get('AUDIO_DEVICE_INDEX', DEFAULT_DEVICE_INDEX))

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
        self.paused = False
        print("[debug] Basic vars initialized")
        
        # Detect audio device BEFORE OpenVINO to prevent conflicts
        self.input_device_index = self.get_input_device()
        print(f"[audio] Pre-selected device: {self.input_device_index}")
        print("[debug] Audio device selected")
        
        # Audio resource coordination
        if AUDIO_COORDINATION:
            self.audio_manager = AudioResourceManager('wake_word')
            print("✅ Audio coordination enabled")
        else:
            self.audio_manager = None
        print("[debug] Audio coordination setup complete")
        
        # Initialize OpenVINO (AFTER PyAudio to avoid driver conflicts)
        self._initialize_openvino()
        print("[debug] OpenVINO initialized")
        
        # Load wake word models
        self._load_models()
        print("[debug] Models loaded")
        
        # Device sample rate detection will happen in run() to handle dynamic changes
        self.device_sample_rate = None
        self.resample_ratio = None
        self.resample_buffer = deque()  # Use deque for efficient appending
        
        # Create socket for IPC
        self.setup_socket()
        
        print(f"✅ Using device: {self.actual_device}")
        print(f"✅ Loaded models: {list(self.models.keys())}")
        print(f"✅ Audio device: {self.input_device_index}")
        
    def _initialize_openvino(self):
        """Initialize OpenVINO Runtime with device detection"""
        # Skip OpenVINO if using ONNX-only mode to avoid multiprocessing crashes
        if USE_ONNX_ONLY:
            print("[onnx] Using ONNX Runtime only (skipping OpenVINO to avoid multiprocessing crash)")
            self.actual_device = "ONNX_CPU"
            return
            
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
        
        # If using ONNX Runtime, always use .onnx file
        if self.actual_device == "ONNX_CPU":
            if not onnx_model_path.exists():
                print(f"[model] Downloading {wake_word} ONNX model...")
                self._download_onnx_model(wake_word, onnx_model_path)
            print(f"[model] Using ONNX model: {onnx_model_path}")
            return onnx_model_path
        
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
        """Copy pre-trained ONNX wake word model from openwakeword package"""
        import shutil
        
        # Find bundled models in openwakeword package
        try:
            import openwakeword
            openwakeword_dir = Path(openwakeword.__file__).parent
            bundled_model = openwakeword_dir / "resources" / "models" / f"{wake_word}_v0.1.onnx"
            
            if not bundled_model.exists():
                raise FileNotFoundError(f"Model {wake_word} not found in openwakeword bundle")
            
            print(f"[model] Copying {wake_word} from openwakeword bundle...")
            shutil.copy2(bundled_model, target_path)
            print(f"[model] Model copied to {target_path}")
            
        except ImportError:
            raise RuntimeError("openwakeword package not found. Install with: pip install openwakeword")
        except FileNotFoundError as e:
            raise RuntimeError(f"Model not available: {e}")
    
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
        """Find best input device (prefers built-in mics, avoids Bluetooth)"""
        # If user explicitly set device, try that first
        if AUDIO_DEVICE_INDEX != 16:  # Not default
            try:
                info = sd.query_devices(AUDIO_DEVICE_INDEX)
                if info.get('max_input_channels', 0) > 0:
                    print(f"[audio] Using configured device {AUDIO_DEVICE_INDEX}: {info['name']}")
                    return AUDIO_DEVICE_INDEX
            except Exception as e:
                print(f"[audio] Configured device {AUDIO_DEVICE_INDEX} unavailable: {e}")
        
        # Search for built-in microphones (avoid Bluetooth)
        bluetooth_keywords = ['bluetooth', 'airpods', 'bt', 'wireless']
        builtin_keywords = ['microphone', 'internal mic', 'built-in', 'laptop', 'webcam']
        
        candidates = []
        devices = sd.query_devices()
        for i, info in enumerate(devices):
            try:
                name = info.get('name', '').lower()
                
                # Skip if no input channels
                if info.get('max_input_channels', 0) == 0:
                    continue
                
                # Skip Bluetooth devices
                if any(kw in name for kw in bluetooth_keywords):
                    continue
                
                # Prefer built-in microphones
                score = sum(kw in name for kw in builtin_keywords)
                if score > 0:
                    device_rate = int(info.get('default_samplerate', 48000))
                    candidates.append((score, i, info['name'], device_rate))
            except Exception:
                continue
            
        # Use highest scoring device
        if candidates:
            candidates.sort(reverse=True)
            device_index = candidates[0][1]
            device_name = candidates[0][2]
            device_rate = candidates[0][3]
            print(f"[audio] Auto-selected device {device_index}: {device_name} @ {device_rate}Hz")
            return device_index
        
        # Fallback to default
        default_device = sd.default.device[0]  # Input device
        print(f"[audio] No suitable device found, using default ({default_device})")
        return default_device
    
    def setup_socket(self):
        """Setup Unix socket for IPC"""
        if os.path.exists(SOCKET_PATH):
            os.remove(SOCKET_PATH)
        
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
        """Main detection loop with audio coordination"""
        
        # Request microphone access
        if self.audio_manager:
            if not self.audio_manager.request_access(blocking=True, timeout=10.0):
                print("❌ Could not get microphone access!")
                return
        
        # Get device sample rate for resampling (device already selected in __init__)
        device_info = sd.query_devices(self.input_device_index)
        self.device_sample_rate = int(device_info['default_samplerate'])
        self.resample_ratio = self.device_sample_rate / SAMPLE_RATE
        self.resample_buffer = deque()  # Reset deque for new stream
        
        print(f"✅ Audio device: {self.input_device_index} @ {self.device_sample_rate}Hz")
        
        # Calculate chunk size for device's native sample rate
        device_chunk_size = int(CHUNK_SIZE * self.resample_ratio)
        
        print("🎤 Listening for wake word...")
        print(f"   Device: {self.actual_device}")
        print(f"   Models: {WAKE_WORDS}")
        print(f"   Threshold: {THRESHOLD}")
        if self.audio_manager:
            print(f"   Audio coordination: ✅ Enabled")
        
        # Create audio stream with sounddevice
        with sd.InputStream(
            device=self.input_device_index,
            channels=CHANNELS,
            samplerate=self.device_sample_rate,
            blocksize=device_chunk_size,
            dtype=DTYPE
        ) as stream:
            try:
                while True:
                    # Check if we should pause for voxd
                    if self.audio_manager and self.audio_manager.should_pause():
                        if not self.paused:
                            print("⏸️  Pausing for voxd recording...")
                            self.paused = True
                        time.sleep(0.1)  # Wait while voxd is recording
                        continue
                    elif self.paused:
                        print("▶️  Resuming wake word detection...")
                        self.paused = False
                        # Re-request access
                        self.audio_manager.request_access()
                    
                    # Read audio chunk at device's native sample rate
                    audio_array_native, overflowed = stream.read(device_chunk_size)
                    if overflowed:
                        print("⚠️  Audio buffer overflow")
                    
                    # Convert to 1D array and correct dtype
                    audio_array_native = audio_array_native.flatten().astype(np.int16)
                    
                    # Resample to 16kHz if needed
                    if self.device_sample_rate != SAMPLE_RATE:
                        # Import scipy only when needed (after OpenVINO init to avoid multiprocessing conflicts)
                        from scipy import signal
                        
                        # Use scipy for high-quality resampling
                        audio_array = signal.resample_poly(
                            audio_array_native, 
                            up=SAMPLE_RATE, 
                            down=self.device_sample_rate
                        ).astype(np.int16)
                        
                        # Take exactly CHUNK_SIZE samples
                        if len(audio_array) >= CHUNK_SIZE:
                            audio_array = audio_array[:CHUNK_SIZE]
                        else:
                            # Pad if needed (shouldn't happen with correct chunk size)
                            audio_array = np.pad(audio_array, (0, CHUNK_SIZE - len(audio_array)))
                    else:
                        audio_array = audio_array_native
                    
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
                            
                            # Trigger AI assistant
                            self.trigger_event('wake_word_detected', {
                                'wake_word': wake_word,
                                'confidence': float(confidence),
                                'latency_ms': latency
                            })
                            
                            # Pause briefly after detection
                            time.sleep(2.0)
                            
            except KeyboardInterrupt:
                print("\n\n👋 Shutting down...")
            finally:
                if self.audio_manager:
                    self.audio_manager.release()
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
